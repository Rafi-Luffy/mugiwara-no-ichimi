from fastapi import APIRouter
from fastapi import File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from firebase_admin import firestore
import uuid
import json
import re
from datetime import datetime
from fastapi import Query
import google.generativeai as genai
from models.models import *
from services.default import parse_date, update_extracted_text
from init import bucket, db

router = APIRouter(tags=["Default"])

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel('gemini-1.5-flash')

@router.get("/ping")
def ping():
    return {"message": "Backend is alive!"}

@router.post("/upload")
async def upload_image(user_id: str = Query(..., description="User ID from OAuth"),file: UploadFile = File(...)):
    try:
        content = await file.read()

         # Sanitize filename: remove spaces, special chars (keep alphanumeric, dot, dash, underscore)
        original_filename = re.sub(r'[^\w.\-]', '_', file.filename)

        filename = f"receipts/{uuid.uuid4()}_{original_filename}"

        blob = bucket.blob(filename)
        blob.upload_from_string(content, content_type=file.content_type)

        # Optional: make file public or return URL
        blob.make_public()

        reciept = update_extracted_text(user_id,blob.public_url)
        return {"receipt_id":reciept["receipt_id"],"fetched_at": datetime.utcnow().isoformat() + "Z","data" : get_structured_data(reciept["receipt_id"])}
        # return {"message": "Uploaded", "url": blob.public_url, "reciept":reciept["receipt_id"]}
    except Exception as e:
        return {"error": str(e)}


@router.get("/receipt/{doc_id}")
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

@router.get("/debug-all")
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

@router.post("/user-preferences", response_model=UserPreferencesResponse)
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
            "preferences": {}
        }

        # Process each preference
        for key, value in payload.preferences.items():
            print(f"Processing key: {key}, value type: {type(value)}, value: {value}")
            preference_data = {
                "configured_at": firestore.SERVER_TIMESTAMP
            }

            # Detect if value is a PreferenceValue instance or a dict
            if isinstance(value, PreferenceValue):
                pref_obj = value
            elif isinstance(value, dict) and "enabled" in value:
                pref_obj = PreferenceValue(**value)
            else:
                pref_obj = None

            if pref_obj:
                preference_data["enabled"] = pref_obj.enabled
                preference_data["value"] = pref_obj.value

                # Specific validations per key
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
                # Simple boolean preference
                preference_data["enabled"] = bool(value)

            # Add to the preferences map
            user_preferences_doc["preferences"][key] = preference_data

        # Save to Firestore
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


@router.get("/user-preferences-list")
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

    
# @router.get("/latest-receipt")
# def get_latest_receipt(user_id: str = Query(..., description="User ID from OAuth")):
#     try:
#         # Fetch user info from Firestore
#         user_doc_ref = db.collection("users").document(user_id)
#         user_doc = user_doc_ref.get()

#         if not user_doc.exists:
#             return JSONResponse(status_code=404, content={"error": "User not found"})

#         user_data = user_doc.to_dict()
#         user_name = user_data.get("user_name", "Anonymous")
#         user_email = user_data.get("user_email", "")

#         # Get all extracted_texts
#         docs = db.collection("extracted_texts").stream()
#         receipt_list = []

#         for doc in docs:
#             data = doc.to_dict()
#             update_time_raw = data.get("status", {}).get("updateTime")

#             if not update_time_raw:
#                 continue

#             try:
#                 update_time = update_time_raw if isinstance(update_time_raw, datetime) else parse_date(str(update_time_raw))
#             except Exception as e:
#                 print(f"Skipping doc due to invalid date: {doc.id}, error: {e}")
#                 continue

#             receipt_list.append({
#                 "doc_id": doc.id,
#                 "data": data,
#                 "update_time": update_time
#             })

#         if not receipt_list:
#             return JSONResponse(status_code=404, content={"error": "No valid receipts found"})

#         # Sort by latest
#         latest = sorted(receipt_list, key=lambda x: x["update_time"], reverse=True)[0]
#         doc_id = latest["doc_id"]
#         doc_ref = db.collection("extracted_texts").document(doc_id)

#         # Update Firestore document with user info if not already added
#         update_fields = {}
#         if "user_id" not in latest["data"]:
#             update_fields["user_id"] = user_id
#         if "user_name" not in latest["data"]:
#             update_fields["user_name"] = user_name
#         if "user_email" not in latest["data"]:
#             update_fields["user_email"] = user_email

#         if update_fields:
#             doc_ref.update(update_fields)
#             print(f"✅ Updated receipt {doc_id} with user info")

#         # Parse structured output
#         structured_output = latest["data"].get("structured_output", "")
#         cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)

#         try:
#             parsed_output = json.loads(cleaned_output)
#         except json.JSONDecodeError:
#             return JSONResponse(status_code=500, content={"error": "Invalid structured_output format"})

#         return {
#             "receipt_id": doc_id,
#             "fetched_at": datetime.utcnow().isoformat() + "Z",
#             "data": parsed_output
#         }

#     except Exception as e:
#         return JSONResponse(status_code=500, content={"error": str(e)})
    
'''
@router.get("/latest-receipt")
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
'''

@router.get("/latest-receipt")
def get_latest_receipt(user_id: str = Query(..., description="User ID from OAuth")):
    try:
        # # Fetch user info from Firestore
        # user_doc_ref = db.collection("users").document(user_id)
        # user_doc = user_doc_ref.get()

        # if not user_doc.exists:
        #     return JSONResponse(status_code=404, content={"error": "User not found"})

        # user_data = user_doc.to_dict()
        # user_name = user_data.get("user_name", "Anonymous")
        # user_email = user_data.get("user_email", "")
        # preferences_id = user_data.get("preferences_id")

        # user_preferences = None
        # if preferences_id:
        #     preferences_doc = db.collection("user_preferences").document(preferences_id).get()
        #     if preferences_doc.exists:
        #         user_preferences = preferences_doc.to_dict().get("preferences", {})

        # # Get all extracted_texts documents
        # docs = db.collection("extracted_texts").stream()
        # receipt_list = []

        # for doc in docs:
        #     data = doc.to_dict()
        #     update_time_raw = data.get("status", {}).get("updateTime")

        #     if not update_time_raw:
        #         continue

        #     try:
        #         update_time = update_time_raw if isinstance(update_time_raw, datetime) else parse_date(str(update_time_raw))
        #     except Exception as e:
        #         print(f"Skipping doc due to invalid date: {doc.id}, error: {e}")
        #         continue

        #     receipt_list.append({
        #         "doc_id": doc.id,
        #         "data": data,
        #         "update_time": update_time
        #     })

        # if not receipt_list:
        #     return JSONResponse(status_code=404, content={"error": "No valid receipts found"})

        # # Sort by latest
        # latest = sorted(receipt_list, key=lambda x: x["update_time"], reverse=True)[0]
        # doc_id = latest["doc_id"]
        # doc_ref = db.collection("extracted_texts").document(doc_id)

        # # Update Firestore document with user info & preferences if not already added
        # update_fields = {}
        # if "user_id" not in latest["data"]:
        #     update_fields["user_id"] = user_id
        # if "user_name" not in latest["data"]:
        #     update_fields["user_name"] = user_name
        # if "user_email" not in latest["data"]:
        #     update_fields["user_email"] = user_email
        # if user_preferences and "user_preferences" not in latest["data"]:
        #     update_fields["user_preferences"] = user_preferences

        # if update_fields:
        #     doc_ref.update(update_fields)
        #     print(f"✅ Updated receipt {doc_id} with user info and preferences")

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

@router.get("/smart-actions")
async def get_smart_actions(
    receipt_id: str = Query(..., description="Receipt ID from combined_receipt collection"),
    user_id: str = Query(..., description="User ID for validation")
):
    try:
        # Fetch receipt data from combined_receipt collection
        receipt_docs = db.collection("combined_receipt").where("user_id", "==", user_id).stream()
        
        receipt_data = None
        for doc in receipt_docs:
            data = doc.to_dict()
            # Match by receipt_id or find the most recent one
            if receipt_id in str(doc.id) or not receipt_data:
                receipt_data = data
                break
        
        if not receipt_data:
            raise HTTPException(status_code=404, detail="Receipt not found")
        
        structured_output = receipt_data.get("structured_output", "")
        user_preferences = receipt_data.get("user_preferences", {})
        
        # Clean structured output if it has markdown formatting
        import re
        cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)
        
        try:
            structured_data = json.loads(cleaned_output)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid structured output format")
        
        # Generate smart actions using Gemini
        smart_actions = await generate_smart_actions_with_gemini(structured_data, user_preferences)
        
        return {
            "success": True,
            "receipt_id": receipt_id,
            "smartactions": smart_actions,
            "generated_at": datetime.utcnow().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error generating smart actions: {e}")
        raise HTTPException(status_code=500, detail=f"Error generating smart actions: {str(e)}")

async def generate_smart_actions_with_gemini(structured_output: dict, user_preferences: dict) -> dict:
    """Generate smart actions using Gemini AI based on receipt data and user preferences"""
    
    prompt = f"""You are a smart action suggesting agent.
Your job is to enhance the user experience by analyzing two inputs:
1. structured_output: a JSON object representing extracted receipt data.
2. user_preferences: a JSON object representing the user's configured preferences, including which features are enabled and their corresponding values.

Your task:
For each user preference where "enabled": true, generate a **smart, personalized suggestion** in the form of a question or action, based on the receipt content (like total amount, expense category, or items).

You must return a JSON object named "smartactions" where each key corresponds to a specific enabled preference.

Each preference key should contain:
- question: a meaningful, human-readable question or action prompt.
- value: only if the preference contains a value (e.g. export format, days, amount).
- currency: if the preference involves a currency-based value (e.g. savings, split, etc).

Rules for each preference (if enabled):
- auto_split_receipt: Suggest splitting the bill based on total_amount.
  Example: "Would you like to auto-split this $93 receipt with friends?"
- detect_similar_purchases: Suggest finding similar purchases.
  Example: "Detect similar purchases from Reliance Fresh?"
- export_format: Suggest exporting in the preferred formats.
  Example: "Export this receipt in PDF and CSV formats?"
- generate_invoice_pdf: Suggest sending a PDF invoice to the configured email.
  Example: "Would you like a PDF invoice sent to keerthana@example.com?"
- preferred_language: Just include the user's selected language as "value" (no question needed).
- receipt_expiry: Show the expiry period the user prefers.
  Example: "This receipt will be saved for 60 days."
- savings_pot: Suggest saving a certain amount into a virtual pot.
  Example: "Add $250 from this receipt to your savings pot?"

Input Data:
structured_output: {json.dumps(structured_output, indent=2)}

user_preferences: {json.dumps(user_preferences, indent=2)}

Return ONLY a valid JSON object with the "smartactions" key. Do not include any other text or formatting."""

    try:
        response = model.generate_content(prompt)
        
        # Extract JSON from response
        response_text = response.text.strip()
        
        # Remove any markdown formatting if present
        if response_text.startswith("```json"):
            response_text = response_text[7:-3].strip()
        elif response_text.startswith("```"):
            response_text = response_text[3:-3].strip()
        
        # Parse the JSON response
        result = json.loads(response_text)
        
        # Return the smartactions object
        return result.get("smartactions", {})
        
    except json.JSONDecodeError as e:
        print(f"Failed to parse Gemini response as JSON: {e}")
        print(f"Raw response: {response.text}")
        # Return fallback smart actions
        return generate_fallback_smart_actions(structured_output, user_preferences)
    except Exception as e:
        print(f"Error calling Gemini API: {e}")
        # Return fallback smart actions
        return generate_fallback_smart_actions(structured_output, user_preferences)

def generate_fallback_smart_actions(structured_output: dict, user_preferences: dict) -> dict:
    """Generate fallback smart actions when Gemini API fails"""
    
    smart_actions = {}
    shop_name = structured_output.get("shop_name", "this store")
    total_amount = structured_output.get("total_amount", "0")
    currency_symbol = "₹"  # Default to Indian Rupee, can be made dynamic
    
    # Generate actions for enabled preferences
    for pref_key, pref_data in user_preferences.items():
        if not isinstance(pref_data, dict) or not pref_data.get("enabled", False):
            continue
            
        if pref_key == "auto_split_receipt":
            split_amount = pref_data.get("value", total_amount)
            smart_actions[pref_key] = {
                "question": f"Would you like to auto-split this {currency_symbol}{total_amount} receipt with friends?",
                "value": split_amount,
                "currency": currency_symbol
            }
            
        elif pref_key == "detect_similar_purchases":
            smart_actions[pref_key] = {
                "question": f"Detect similar purchases from {shop_name}?"
            }
            
        elif pref_key == "export_format":
            formats = pref_data.get("value", ["PDF"])
            format_str = " and ".join(formats) if isinstance(formats, list) else str(formats)
            smart_actions[pref_key] = {
                "question": f"Export this receipt in {format_str} format?",
                "value": formats
            }
            
        elif pref_key == "generate_invoice_pdf":
            email = pref_data.get("value", "your email")
            smart_actions[pref_key] = {
                "question": f"Would you like a PDF invoice sent to {email}?",
                "value": email
            }
            
        elif pref_key == "preferred_language":
            language = pref_data.get("value", "English")
            smart_actions[pref_key] = {
                "question": f"Display in {language}",
                "value": language
            }
            
        elif pref_key == "receipt_expiry":
            days = pref_data.get("days", 90)
            if days == -1:
                smart_actions[pref_key] = {
                    "question": "This receipt will be saved permanently."
                }
            else:
                smart_actions[pref_key] = {
                    "question": f"This receipt will be saved for {days} days.",
                    "value": days
                }
                
        elif pref_key == "savings_pot":
            amount = pref_data.get("value", 0)
            currency = pref_data.get("currency", currency_symbol)
            smart_actions[pref_key] = {
                "question": f"Add {currency}{amount} from this receipt to your savings pot?",
                "value": amount,
                "currency": currency
            }
    
    return smart_actions
