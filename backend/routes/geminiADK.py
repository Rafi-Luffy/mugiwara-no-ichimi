from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import JSONResponse
import google.generativeai as genai
import json
import os
from datetime import datetime
from init import db
import re

router = APIRouter(tags=["Smart Actions"])

# Configure Gemini API
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-1.5-flash")

def convert_firestore_data(data):
    """Recursively convert Firestore data to JSON-serializable types."""
    if isinstance(data, dict):
        return {k: convert_firestore_data(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [convert_firestore_data(item) for item in data]
    elif hasattr(data, 'isoformat'):  # Firestore timestamp or datetime
        return data.isoformat()
    else:
        return data

@router.get("/smart-actions")
async def get_smart_actions(
    receipt_id: str = Query(..., description="Receipt ID from extracted_texts collection"),
    user_id: str = Query(..., description="User ID for validation")
):
    try:
        # Fetch document
        receipt_doc = db.collection("extracted_texts").document(receipt_id).get()
        if not receipt_doc.exists:
            raise HTTPException(status_code=404, detail="Receipt not found")

        receipt_data = convert_firestore_data(receipt_doc.to_dict())
        structured_output = receipt_data.get("structured_output", "")
        user_preferences = receipt_data.get("user_preferences", {})

        if not structured_output:
            raise HTTPException(status_code=400, detail="Missing structured_output field")

        # Remove markdown if present
        cleaned_output = re.sub(r"^```json\n(.*?)\n```$", r"\1", structured_output.strip(), flags=re.DOTALL)

        try:
            structured_data = json.loads(cleaned_output)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid JSON in structured_output")

        smart_actions = await generate_smart_actions_with_gemini(structured_data, user_preferences)

        return {
            "success": True,
            "receipt_id": receipt_id,
            "smartactions": convert_firestore_data(smart_actions),
            "generated_at": datetime.utcnow().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


async def generate_smart_actions_with_gemini(structured_output: dict, user_preferences: dict) -> dict:
    prompt = f"""
You are a smart action suggesting agent.
Analyze two inputs:
1. structured_output: JSON of extracted receipt data.
2. user_preferences: JSON of user-configured preferences.

Your task:
For each user preference where "enabled": true, generate a **smart, personalized suggestion** based on the receipt data.

Output format:
{{ "smartactions": {{ "preference_key": {{ "question": "...", "value": ..., "currency": ... }} }} }}

Example behaviors:
- auto_split_receipt → Suggest splitting total_amount.
- detect_similar_purchases → Suggest finding similar purchases from shop_name.
- export_format → Ask if user wants PDF/CSV export.
- generate_invoice_pdf → Ask if PDF should be sent to preferred email.
- preferred_language → Just include the language.
- receipt_expiry → Mention the number of days.
- savings_pot → Suggest saving an amount.

Only return valid JSON under a top-level key "smartactions".

structured_output:
{json.dumps(convert_firestore_data(structured_output), indent=2)}

user_preferences:
{json.dumps(convert_firestore_data(user_preferences), indent=2)}
    """

    try:
        response = model.generate_content(prompt)
        response_text = response.text.strip()

        # Strip Markdown if needed
        if response_text.startswith("```json"):
            response_text = response_text[7:-3].strip()
        elif response_text.startswith("```"):
            response_text = response_text[3:-3].strip()

        result = json.loads(response_text)
        return result.get("smartactions", {})

    except json.JSONDecodeError as e:
        print(f"JSON parse error: {e}\nRaw response: {response.text}")
        return generate_fallback_smart_actions(structured_output, user_preferences)

    except Exception as e:
        print(f"Gemini API error: {e}")
        return generate_fallback_smart_actions(structured_output, user_preferences)


def generate_fallback_smart_actions(structured_output: dict, user_preferences: dict) -> dict:
    smart_actions = {}
    shop_name = structured_output.get("shop_name", "this store")
    total_amount = structured_output.get("total_amount", "0")
    currency_symbol = "₹"

    for key, config in user_preferences.items():
        if not isinstance(config, dict) or not config.get("enabled", False):
            continue

        if key == "auto_split_receipt":
            smart_actions[key] = {
                "question": f"Would you like to auto-split this {currency_symbol}{total_amount} receipt with friends?",
                "value": config.get("value", total_amount),
                "currency": currency_symbol
            }
        elif key == "detect_similar_purchases":
            smart_actions[key] = {
                "question": f"Detect similar purchases from {shop_name}?"
            }
        elif key == "export_format":
            formats = config.get("value", ["PDF"])
            format_str = " and ".join(formats if isinstance(formats, list) else [formats])
            smart_actions[key] = {
                "question": f"Export this receipt in {format_str} format?",
                "value": formats
            }
        elif key == "generate_invoice_pdf":
            email = config.get("value", "your email")
            smart_actions[key] = {
                "question": f"Would you like a PDF invoice sent to {email}?",
                "value": email
            }
        elif key == "preferred_language":
            lang = config.get("value", "English")
            smart_actions[key] = {
                "question": f"Display in {lang}",
                "value": lang
            }
        elif key == "receipt_expiry":
            days = config.get("days", 90)
            msg = "permanently" if days == -1 else f"for {days} days"
            smart_actions[key] = {
                "question": f"This receipt will be saved {msg}.",
                "value": days
            }
        elif key == "savings_pot":
            amount = config.get("value", 0)
            currency = config.get("currency", currency_symbol)
            smart_actions[key] = {
                "question": f"Add {currency}{amount} from this receipt to your savings pot?",
                "value": amount,
                "currency": currency
            }

    return smart_actions
