import time
from fastapi import APIRouter
from fastapi import File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from google.cloud.firestore_v1.base_query import FieldFilter
from firebase_admin import firestore
import uuid
import json
import re
from datetime import datetime
from fastapi import Query

from models.models import *
from services.default import parse_date
from init import bucket, db

router = APIRouter(tags=["Chatbot"])

@router.post("/chat")
def chat_with_bot(user_id: str = Query(..., description="User ID from OAuth"), prompt: str = Query(..., description="User's prompt for the chatbot")):
    """
    Endpoint to chat with the bot.
    It processes the user's prompt and returns a response.
    """
    try:
        # Fetch user info
        user_doc_ref = db.collection("users").document(user_id)
        user_doc = user_doc_ref.get()

        if not user_doc.exists:
            return JSONResponse(status_code=404, content={"error": "User not found"})

        user_data = user_doc.to_dict()
        user_name = user_data.get("user_name", "Anonymous")
        user_email = user_data.get("user_email", "")

        receipts = db.collection("extracted_texts").where(filter=FieldFilter("user_id", "==", user_id)).stream()
        receipt_texts = []
        for doc in receipts:
            receipt = doc.to_dict()
            structured_output = receipt.get("structured_output")
            if not structured_output:
                continue
            cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)
            try:
                parsed_output = json.loads(cleaned_output)
            except json.JSONDecodeError:
                return JSONResponse(status_code=500, content={"error": "Invalid structured_output format"})
            if parsed_output:
                receipt_texts.append(parsed_output)
        print(receipt_texts)
        # Process the prompt (this is a placeholder for actual processing logic)
        _, ref = db.collection("messages").add({
            "prompt": f"Based on this context: {receipt_texts}, respond only to this prompt: {prompt}",
        })
        new_doc_id = ref.id
        max_polling_attempts = 30  # Max number of times to check (e.g., 30 attempts)
        polling_interval_seconds = 1 # How long to wait between checks (e.g., 2 seconds)
                                     # Total wait time: 30 * 2 = 60 seconds

        for attempt in range(max_polling_attempts):
            print(f"Polling attempt {attempt + 1}/{max_polling_attempts} for document {new_doc_id}...")
            # Fetch the latest state of the document
            current_doc_snapshot = ref.get()

            if current_doc_snapshot.exists:
                doc_data = current_doc_snapshot.to_dict()
                current_status_state = doc_data.get("status", {}).get("state")
                bot_response = doc_data.get("response")

                if current_status_state == "COMPLETED" and bot_response:
                    print(f"AI response received for document {new_doc_id}: {bot_response}")
                    return JSONResponse(content={"response": bot_response})
                elif current_status_state == "PROCESSING":
                    # Continue polling, wait for the next interval
                    # Use asyncio.sleep if you migrate to an async-compatible Firestore client
                    # For now, time.sleep() will block the current worker.
                    time.sleep(polling_interval_seconds)
                else:
                    # Handle other unexpected states (e.g., "ERROR" set by your backend)
                    print(f"Document {new_doc_id} has unexpected status: {current_status_state}. Data: {doc_data}")
                    return JSONResponse(
                        status_code=500,
                        content={"error": f"Asynchronous processing for message ID {new_doc_id} ended in unexpected state: {current_status_state}."}
                    )
            else:
                print(f"Document {new_doc_id} no longer exists during polling. This is unexpected.")
                return JSONResponse(status_code=500, content={"error": "Message processing document disappeared unexpectedly."})

        # If the loop finishes without the status becoming "COMPLETE"
        print(f"Polling timed out for document {new_doc_id}. AI response not received within {max_polling_attempts * polling_interval_seconds} seconds.")
        return JSONResponse(status_code=504, content={"error": "Chatbot response timed out. Please try again."})

        # response_text = f"Hello {user_name}, you said: {prompt}"

        # return JSONResponse(content={"response": response_text})

    except Exception as e:
        print(f"Error in chat_with_bot: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")