from google.generativeai import GenerativeModel
import os

# Ensure you set your environment variable or replace with actual key
# os.environ["GOOGLE_API_KEY"] = "AIzaSyAyzZnCciBGhjqKpsNsLw-SewCqyhf3Eo4"

model = GenerativeModel(model_name="models/gemini-2.0-flash")

def process_with_gemini(extracted_text: str) -> dict:
    """
    Sends the extracted receipt text to Gemini and returns structured data:
    - List of items
    - Expense category
    - Reimbursable items
    """

    prompt = f"""
    You are an intelligent expense analyzer. Given the raw text from a receipt, extract:
    1. A list of item names.
    2. An expense category like Food, Electronics, Groceries, Travel, etc.
    3. Identify if any item is reimbursable.

    Input Text:
    '''
    {extracted_text}

    '''
    Output JSON format:
    {{
        "items": ["item1", "item2", ...],
        "expense_category": "Predicted category",
        "reimbursable_items": ["item1", "item3"]
    }}
    """

    response = model.generate_content(prompt)

    # Attempt to parse JSON
    try:
        import json
        return json.loads(response.text)
    except Exception as e:
        print("Parsing error:", e)
        return {"error": "Failed to parse Gemini response"}
