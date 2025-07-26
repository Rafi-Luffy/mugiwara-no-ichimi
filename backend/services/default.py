from datetime import datetime
from init import db
from fastapi import Query
from fastapi.responses import JSONResponse
from google.cloud.firestore_v1.base_query import FieldFilter
import time

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
        
def update_extracted_text(user_id: str = Query(..., description="User ID from OAuth"), fileUrl: str = ""):
    try:

        # Fetch user info
        user_doc_ref = db.collection("users").document(user_id)
        user_doc = user_doc_ref.get()

        if not user_doc.exists:
            return JSONResponse(status_code=404, content={"error": "User not found"})

        user_data = user_doc.to_dict()
        user_name = user_data.get("user_name", "Anonymous")
        user_email = user_data.get("user_email", "")
        preferences_id = user_data.get("preferences_id")

        user_preferences = None
        if preferences_id:
            preferences_doc = db.collection("user_preferences").document(preferences_id).get()
            if preferences_doc.exists:
                user_preferences = preferences_doc.to_dict().get("preferences", {})

        file_gs_url = fileUrl.replace("https://storage.googleapis.com/", "gs://")
        print(file_gs_url)

        # Query extracted_texts by file
        query = db.collection("extracted_texts").where(filter=FieldFilter("file", "==", file_gs_url))
        docs = query.get()

        if not docs:
            return JSONResponse(status_code=404, content={"error": "No matching document found for file"})

        doc_snapshot = docs[0]
        doc_id = doc_snapshot.id
        doc_data = doc_snapshot.to_dict()
        doc_ref = doc_snapshot.reference

        print("📄 Document ID:", doc_id)
        print("📄 Document Data:", doc_data)

        # Update fields
        update_fields = {
            "user_id": user_id,
            "user_name": user_name,
            "user_email": user_email,
            "user_preferences": user_preferences,
        }

        doc_ref.update(update_fields)
        print(f"✅ Updated receipt {doc_id} with user info and preferences")

        return {
            "receipt_id": doc_id,
            "fetched_at": datetime.utcnow().isoformat() + "Z",
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})