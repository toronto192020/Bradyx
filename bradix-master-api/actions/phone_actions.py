
import requests
from config import VAPI_API_KEY
from handlers.notifications import send_telegram_notification

def _make_vapi_call(phone_number: str, message: str):
    if not VAPI_API_KEY:
        print("Vapi API key not configured.")
        send_telegram_notification(f"Failed to make Vapi call to {phone_number}: Vapi API key not configured.")
        return False

    headers = {
        "Authorization": f"Bearer {VAPI_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "phoneNumber": phone_number,
        "message": message
    }
    try:
        # This is a placeholder for Vapi API call. Actual Vapi integration might require more parameters.
        # Refer to Vapi documentation for exact API usage.
        response = requests.post("https://api.vapi.ai/call", headers=headers, json=payload)
        response.raise_for_status()
        print(f"Vapi call initiated to {phone_number}")
        send_telegram_notification(f"Vapi call initiated to {phone_number} with message: {message}")
        return True
    except Exception as e:
        print(f"Failed to initiate Vapi call to {phone_number}: {e}")
        send_telegram_notification(f"Failed to initiate Vapi call to {phone_number}: {e}")
        return False

def call_sper_payment_plan():
    phone_number = "1300365635"
    message = "Director of Bruder Technologies, SPER Party ID 100199025. I want a payment plan and variation of warrant VSS100199025A under section 64."
    return _make_vapi_call(phone_number, message)

def call_bluecare_suze():
    phone_number = "0455256397"
    message = "Calling to discuss the service agreement to unlock the $18k surplus."
    return _make_vapi_call(phone_number, message)

def call_tmr_nominations():
    phone_number = "137468"
    message = "Calling to discuss infringement nominations."
    return _make_vapi_call(phone_number, message)
