
from handlers.notifications import send_telegram_notification
from actions.recovery_actions import perform_ppsr_search, generate_zillmere_demand_letter
from actions.email_actions import send_afca_hollard_complaint_email
from actions.phone_actions import call_sper_payment_plan

def handle_bmw_x5_seizure_risk():
    solution = "Initiate SPER payment plan and nominate driver for fine #7 to reduce debt and protect BMW X5."
    print(f"Handling BMW X5 seizure risk: {solution}")
    send_telegram_notification(f"Controversial situation: BMW X5 seizure risk. Solution: {solution}")
    call_sper_payment_plan() # Assuming this also covers the nomination aspect or triggers a follow-up
    return {"situation": "BMW X5 seizure risk", "solution": solution}

def handle_zillmere_unlawful_seizure():
    solution = "Perform PPSR search for Zillmere assets and issue a demand letter for their return."
    print(f"Handling Zillmere unlawful seizure: {solution}")
    send_telegram_notification(f"Controversial situation: Zillmere unlawful seizure. Solution: {solution}")
    # Assuming we know the VIN/serial for PPSR search, placeholder for now
    perform_ppsr_search("Zillmere_Assets_VIN_or_Serial") 
    generate_zillmere_demand_letter()
    return {"situation": "Zillmere unlawful seizure", "solution": solution}

def handle_andrew_mills_director_duties():
    solution = "Document all interactions and potential breaches of director duties by Andrew Mills. Consult legal counsel."
    print(f"Handling Andrew Mills director duties: {solution}")
    send_telegram_notification(f"Controversial situation: Andrew Mills director duties. Solution: {solution}")
    return {"situation": "Andrew Mills director duties", "solution": solution}

def handle_qcat_guardianship_challenge():
    solution = "Gather all relevant documentation for QCAT guardianship challenge. Seek legal advice and prepare for hearing."
    print(f"Handling QCAT guardianship challenge: {solution}")
    send_telegram_notification(f"Controversial situation: QCAT guardianship challenge. Solution: {solution}")
    return {"situation": "QCAT guardianship challenge", "solution": solution}

def handle_health_crisis():
    solution = "Utilize Carer Gateway Crisis (1800 422 737) or Lifeline (13 11 14) for immediate support and respite."
    print(f"Handling health crisis: {solution}")
    send_telegram_notification(f"Controversial situation: Health crisis. Solution: {solution}")
    return {"situation": "Health crisis", "solution": solution}

def get_all_controversial_solutions():
    return {
        "bmw_x5_seizure_risk": "Initiate SPER payment plan and nominate driver for fine #7 to reduce debt and protect BMW X5.",
        "zillmere_unlawful_seizure": "Perform PPSR search for Zillmere assets and issue a demand letter for their return.",
        "andrew_mills_director_duties": "Document all interactions and potential breaches of director duties by Andrew Mills. Consult legal counsel.",
        "qcat_guardianship_challenge": "Gather all relevant documentation for QCAT guardianship challenge. Seek legal advice and prepare for hearing.",
        "health_crisis": "Utilize Carer Gateway Crisis (1800 422 737) or Lifeline (13 11 14) for immediate support and respite."
    }
