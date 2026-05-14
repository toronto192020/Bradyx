
from fastapi import FastAPI, HTTPException
from typing import Dict

from actions.email_actions import (
    send_qsuper_late_registration_email,
    send_sper_payment_plan_email,
    send_tmr_nomination_email,
    send_afca_hollard_complaint_email,
    send_home_instead_complaint_email,
    send_ptq_complaint_email
)
from actions.phone_actions import (
    call_sper_payment_plan,
    call_bluecare_suze,
    call_tmr_nominations
)
from actions.recovery_actions import (
    perform_ppsr_search,
    generate_zillmere_demand_letter,
    request_mercedes_sale_accounting
)
from handlers.controversial import (
    handle_bmw_x5_seizure_risk,
    handle_zillmere_unlawful_seizure,
    handle_andrew_mills_director_duties,
    handle_qcat_guardianship_challenge,
    handle_health_crisis,
    get_all_controversial_solutions
)
from handlers.notifications import send_telegram_notification

app = FastAPI()

@app.post("/execute-all")
async def execute_all_actions():
    results = {}
    send_telegram_notification("Starting execution of all actions.")

    # Section 1.1 SPER Payment Plan
    results["sper_payment_plan_call"] = call_sper_payment_plan()
    results["sper_payment_plan_email"] = send_sper_payment_plan_email()
    results["mercedes_sale_accounting_request"] = request_mercedes_sale_accounting()

    # Section 1.2 Nominate Actual Drivers
    results["tmr_nomination_brett_connor"] = send_tmr_nomination_email("Brett Connor")
    results["tmr_nomination_timothy_woodward"] = send_tmr_nomination_email("Timothy Woodward")
    results["tmr_nominations_call"] = call_tmr_nominations()

    # Section 1.4 QSuper Late Registration Email
    results["qsuper_late_registration_email"] = send_qsuper_late_registration_email()

    # Section 1.5 AFCA Complaint Against Hollard
    results["afca_hollard_complaint_email"] = send_afca_hollard_complaint_email()

    # Section 4 Asset Recovery - Home Instead & PTQ
    results["home_instead_complaint_email"] = send_home_instead_complaint_email()
    results["ptq_complaint_email"] = send_ptq_complaint_email()

    # BlueCare Suze call
    results["bluecare_suze_call"] = call_bluecare_suze()

    send_telegram_notification("Completed execution of all actions.")
    return {"message": "All actions executed", "results": results}

@app.post("/send-email/{action_id}")
async def send_specific_email_endpoint(action_id: str):
    if action_id == "qsuper_late_registration":
        success = send_qsuper_late_registration_email()
    elif action_id == "sper_payment_plan":
        success = send_sper_payment_plan_email()
    elif action_id == "tmr_nomination_brett_connor":
        success = send_tmr_nomination_email("Brett Connor")
    elif action_id == "tmr_nomination_timothy_woodward":
        success = send_tmr_nomination_email("Timothy Woodward")
    elif action_id == "afca_hollard_complaint":
        success = send_afca_hollard_complaint_email()
    elif action_id == "home_instead_complaint":
        success = send_home_instead_complaint_email()
    elif action_id == "ptq_complaint":
        success = send_ptq_complaint_email()
    else:
        raise HTTPException(status_code=404, detail="Action ID not found")
    
    if success:
        return {"message": f"Email for action_id: {action_id} sent successfully"}
    else:
        raise HTTPException(status_code=500, detail=f"Failed to send email for action_id: {action_id}")

@app.post("/make-call/{action_id}")
async def trigger_vapi_call_endpoint(action_id: str):
    if action_id == "sper_payment_plan":
        success = call_sper_payment_plan()
    elif action_id == "bluecare_suze":
        success = call_bluecare_suze()
    elif action_id == "tmr_nominations":
        success = call_tmr_nominations()
    else:
        raise HTTPException(status_code=404, detail="Action ID not found")

    if success:
        return {"message": f"Vapi call for action_id: {action_id} triggered successfully"}
    else:
        raise HTTPException(status_code=500, detail=f"Failed to trigger Vapi call for action_id: {action_id}")

@app.get("/status")
async def get_all_task_statuses():
    # This is a placeholder. In a real system, this would query a database or state manager.
    return {"message": "Retrieving all task statuses", "status": "Not implemented yet"}

@app.get("/controversial")
async def get_controversial_situations_endpoint():
    solutions = get_all_controversial_solutions()
    return {"message": "Retrieving controversial situations and solutions", "solutions": solutions}
