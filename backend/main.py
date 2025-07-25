from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import firebase_admin
from firebase_admin import credentials, storage, firestore
from typing import Dict, Any, Optional, List, Union, Dict
import uuid
import os
import json
import re
from datetime import datetime
from pydantic import BaseModel, EmailStr
from fastapi import Query, Request

app = FastAPI()

# Allow CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change this to your Flutter web origin in prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Firebase init
cred = credentials.Certificate("secrets/mugiwara-no-ichimi-firebase-adminsdk-fbsvc-6bf822a736.json")
firebase_admin.initialize_app(cred, {
    'storageBucket': 'mugiwara-no-ichimi.firebasestorage.app'
})
bucket = storage.bucket()
db = firestore.client()

# Pydantic models for request validation
class PreferenceValue(BaseModel):
    enabled: bool
    value: Optional[Union[str, int, float, List[str]]] = None

class PreferencesPayload(BaseModel):
    user_id: str
    user_name: str
    user_email: EmailStr
    preferences: Dict[str, Union[bool, PreferenceValue]]

class UserPreferencesResponse(BaseModel):
    success: bool
    message: str
    preferences_id: Optional[str] = None
    saved_at: Optional[str] = None


def parse_date(date_str: str) -> datetime:
    """Parse date string in various formats"""
    try:
        # Try ISO format first
        return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except:
        try:
            # Try other common formats
            return datetime.strptime(date_str, '%Y-%m-%d %H:%M:%S')
        except:
            # If all else fails, return current time
            return datetime.utcnow()

@app.get("/ping")
def ping():
    return {"message": "Backend is alive!"}

@app.post("/upload")
async def upload_image(file: UploadFile = File(...)):
    try:
        content = await file.read()
        filename = f"receipts/{uuid.uuid4()}_{file.filename}"

        blob = bucket.blob(filename)
        blob.upload_from_string(content, content_type=file.content_type)

        # Optional: make file public or return URL
        blob.make_public()
        return {"message": "Uploaded", "url": blob.public_url}
    except Exception as e:
        return {"error": str(e)}

@app.get("/receipt/{doc_id}")
def get_structured_data(doc_id: str):
    doc_ref = db.collection("extracted_texts").document(doc_id)
    doc = doc_ref.get()

    if not doc.exists:
        return JSONResponse(status_code=404, content={"error": "Not found"})

    raw_output = doc.to_dict().get("structured_output", "")

    # Update timestamp only if structured_output exists
    if raw_output:
        doc_ref.update({"timestamp": firestore.SERVER_TIMESTAMP})

    # Remove ```json\n...\n``` if needed
    cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", raw_output.strip(), flags=re.DOTALL)

    try:
        parsed_output = json.loads(cleaned_output)
    except json.JSONDecodeError:
        return JSONResponse(status_code=500, content={"error": "Failed to parse structured output"})

    return parsed_output

@app.get("/debug-all")
def debug_all_receipts():
    try:
        docs = db.collection("extracted_texts").stream()
        all_receipts = []

        for doc in docs:
            data = doc.to_dict()
            all_receipts.append({
                "doc_id": doc.id,
                "data": data
            })
        return all_receipts
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/latest-receipt")
def get_latest_receipt():
    try:
        docs = db.collection("extracted_texts").stream()
        receipt_list = []

        for doc in docs:
            data = doc.to_dict()
            update_time_raw = data.get("status", {}).get("updateTime")

            if not update_time_raw:
                continue

            try:
                if isinstance(update_time_raw, datetime):
                    update_time = update_time_raw
                else:
                    update_time = parse_date(str(update_time_raw))
            except Exception as e:
                print(f"Skipping doc due to invalid date: {doc.id}, error: {e}")
                continue

            receipt_list.append({
                "doc_id": doc.id,
                "data": data,
                "update_time": update_time
            })

        if not receipt_list:
            return JSONResponse(status_code=404, content={"error": "No valid receipts with updateTime found"})

        # Sort by update_time descending
        sorted_receipts = sorted(receipt_list, key=lambda x: x["update_time"], reverse=True)
        latest = sorted_receipts[0]

        structured_output = latest["data"].get("structured_output", "")
        cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)
        print(f"Received structured_output for: {latest['doc_id']}")

        try:
            parsed_output = json.loads(cleaned_output)
        except json.JSONDecodeError:
            return JSONResponse(status_code=500, content={"error": "Invalid structured_output format"})

        return {
            "receipt_id": latest["doc_id"],
            "fetched_at": datetime.utcnow().isoformat() + "Z",  
            "data": parsed_output
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.post("/user-preferences", response_model=UserPreferencesResponse)
async def save_user_preferences(payload: PreferencesPayload):
    print("preferences endpoint is called")
    print(f"Received payload: {payload}")
    
    try:
        preference_id = str(uuid.uuid4())
        
        # Create a single consolidated preferences document
        user_preferences_doc = {
            "preference_id": preference_id,
            "user_id": payload.user_id,
            "user_name": payload.user_name,
            "user_email": payload.user_email,
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP,
            "version": "1.0",
            "preferences": {}  # All preferences will go here
        }

        # Process each preference
        for key, value in payload.preferences.items():
            preference_data = {
                "configured_at": firestore.SERVER_TIMESTAMP
            }
            
            if isinstance(value, dict) and "enabled" in value:
                # Handle PreferenceValue objects (enabled + value)
                pref_obj = PreferenceValue(**value)
                preference_data["enabled"] = pref_obj.enabled
                preference_data["value"] = pref_obj.value

                # Add specific validation and processing for different preference types
                if key == "preferred_language" and pref_obj.enabled:
                    preference_data["is_default"] = "Default" in str(pref_obj.value)

                elif key == "auto_split_receipt" and pref_obj.enabled:
                    try:
                        preference_data["value"] = float(pref_obj.value)
                        preference_data["currency"] = "USD"
                    except (ValueError, TypeError):
                        raise HTTPException(
                            status_code=400, 
                            detail="Invalid amount for auto_split_receipt"
                        )

                elif key == "generate_invoice_pdf" and pref_obj.enabled:
                    if not pref_obj.value or "@" not in str(pref_obj.value):
                        raise HTTPException(
                            status_code=400, 
                            detail="Invalid email for invoice"
                        )
                    preference_data["value"] = str(pref_obj.value).lower()

                elif key == "export_format" and pref_obj.enabled:
                    if not isinstance(pref_obj.value, list) or not pref_obj.value:
                        raise HTTPException(
                            status_code=400, 
                            detail="At least one export format must be selected"
                        )
                    preference_data["value"] = pref_obj.value

                elif key == "savings_pot" and pref_obj.enabled:
                    try:
                        amount = float(pref_obj.value)
                        if amount <= 0:
                            raise ValueError("Must be positive")
                        preference_data["value"] = amount
                        preference_data["currency"] = "USD"
                    except (ValueError, TypeError):
                        raise HTTPException(
                            status_code=400, 
                            detail="Invalid savings amount"
                        )

                elif key == "receipt_expiry" and pref_obj.enabled:
                    days_map = {
                        "30 days": 30,
                        "60 days": 60,
                        "90 days": 90,
                        "6 months": 180,
                        "1 year": 365,
                        "Never delete": -1
                    }
                    preference_data["days"] = days_map.get(str(pref_obj.value), 90)
            else:
                # Handle simple boolean preferences
                preference_data["enabled"] = bool(value)
            
            # Add this preference to the preferences object
            user_preferences_doc["preferences"][key] = preference_data

        # Save the single document to Firestore
        db.collection("user_preferences").document(preference_id).set(user_preferences_doc)
        print(f"Saved preferences successfully with ID: {preference_id}")

        return UserPreferencesResponse(
            success=True,
            message="Preferences saved successfully!",
            preferences_id=preference_id,
            saved_at=datetime.utcnow().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error saving preferences: {e}")
        raise HTTPException(status_code=500, detail=f"Error saving preferences: {str(e)}")


@app.get("/user-preferences-list")
async def get_user_preferences(user_id: str = Query(..., description="User ID to fetch preferences for")):
    try:
        # Query Firestore collection for user_id
        docs = db.collection("user_preferences").where("user_id", "==", user_id).stream()
        
        user_preferences = None
        for doc in docs:
            user_preferences = doc.to_dict()
            user_preferences["document_id"] = doc.id
            break  # Get the most recent one

        if not user_preferences:
            raise HTTPException(status_code=404, detail="User preferences not found")

        # Format the response
        return {
            "success": True,
            "message": "Preferences retrieved successfully",
            "data": {
                "preference_id": user_preferences.get("preference_id"),
                "user_id": user_preferences.get("user_id"),
                "user_name": user_preferences.get("user_name"),
                "user_email": user_preferences.get("user_email"),
                "preferences": user_preferences.get("preferences", {}),
                "created_at": user_preferences.get("created_at"),
                "updated_at": user_preferences.get("updated_at"),
                "version": user_preferences.get("version")
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error retrieving preferences: {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving preferences: {str(e)}")

@app.get("/latest-receipt")
def get_latest_receipt(user_id: str = Query(..., description="User ID from OAuth")):
    try:
        # Fetch user info from Firestore
        user_doc_ref = db.collection("users").document(user_id)
        user_doc = user_doc_ref.get()

        if not user_doc.exists:
            return JSONResponse(status_code=404, content={"error": "User not found"})

        user_data = user_doc.to_dict()
        user_name = user_data.get("user_name", "Anonymous")
        user_email = user_data.get("user_email", "")

        # Get all extracted_texts
        docs = db.collection("extracted_texts").stream()
        receipt_list = []

        for doc in docs:
            data = doc.to_dict()
            update_time_raw = data.get("status", {}).get("updateTime")

            if not update_time_raw:
                continue

            try:
                update_time = update_time_raw if isinstance(update_time_raw, datetime) else parse_date(str(update_time_raw))
            except Exception as e:
                print(f"Skipping doc due to invalid date: {doc.id}, error: {e}")
                continue

            receipt_list.append({
                "doc_id": doc.id,
                "data": data,
                "update_time": update_time
            })

        if not receipt_list:
            return JSONResponse(status_code=404, content={"error": "No valid receipts found"})

        # Sort by latest
        latest = sorted(receipt_list, key=lambda x: x["update_time"], reverse=True)[0]
        doc_id = latest["doc_id"]
        doc_ref = db.collection("extracted_texts").document(doc_id)

        # Update Firestore document with user info if not already added
        update_fields = {}
        if "user_id" not in latest["data"]:
            update_fields["user_id"] = user_id
        if "user_name" not in latest["data"]:
            update_fields["user_name"] = user_name
        if "user_email" not in latest["data"]:
            update_fields["user_email"] = user_email

        if update_fields:
            doc_ref.update(update_fields)
            print(f"✅ Updated receipt {doc_id} with user info")

        # Parse structured output
        structured_output = latest["data"].get("structured_output", "")
        cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)

        try:
            parsed_output = json.loads(cleaned_output)
        except json.JSONDecodeError:
            return JSONResponse(status_code=500, content={"error": "Invalid structured_output format"})

        return {
            "receipt_id": doc_id,
            "fetched_at": datetime.utcnow().isoformat() + "Z",
            "data": parsed_output
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
