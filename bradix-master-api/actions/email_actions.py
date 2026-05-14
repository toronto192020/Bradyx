
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from config import SMTP_SERVER, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
from handlers.notifications import send_telegram_notification

def _send_email(to_email: str, subject: str, body: str):
    if not SMTP_SERVER or not SMTP_PORT or not SMTP_USERNAME or not SMTP_PASSWORD:
        print("SMTP server details not configured.")
        send_telegram_notification(f"Failed to send email to {to_email}: SMTP not configured.")
        return False

    msg = MIMEMultipart()
    msg['From'] = SMTP_USERNAME
    msg['To'] = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"Email sent successfully to {to_email}")
        send_telegram_notification(f"Email sent to {to_email} with subject: {subject}")
        return True
    except Exception as e:
        print(f"Failed to send email to {to_email}: {e}")
        send_telegram_notification(f"Failed to send email to {to_email}: {e}")
        return False

def send_qsuper_late_registration_email():
    to_email = "qsuper@shine.com.au"
    subject = "Late Registration for QSuper Class Action - Member ID 194997808, Case CL00512793-00"
    with open("bradix-master-api/templates/qsuper_late_registration.md", "r") as f:
        body = f.read()
    return _send_email(to_email, subject, body)

def send_sper_payment_plan_email():
    to_email = "sper.intelligence@treasury.qld.gov.au"
    subject = "SPER Payment Plan Request - Warrant VSS100199025A, $19,958.80, Bruder Technologies"
    with open("bradix-master-api/templates/sper_payment_plan.md", "r") as f:
        body = f.read()
    return _send_email(to_email, subject, body)

def send_tmr_nomination_email(driver_name: str):
    to_email = "tmr@example.com" # Placeholder, TMR typically uses online forms or phone
    subject = f"TMR Driver Nomination for {driver_name}"
    template_map = {
        "Brett Connor": "bradix-master-api/templates/tmr_nomination_brett_connor.md",
        "Timothy Woodward": "bradix-master-api/templates/tmr_nomination_timothy_woodward.md",
    }
    if driver_name in template_map:
        with open(template_map[driver_name], "r") as f:
            body = f.read()
        return _send_email(to_email, subject, body)
    else:
        print(f"No template found for driver: {driver_name}")
        send_telegram_notification(f"Failed to send TMR nomination email: No template for {driver_name}.")
        return False

def send_afca_hollard_complaint_email():
    to_email = "info@afca.org.au" # Placeholder, AFCA typically uses online forms
    subject = "AFCA Complaint Against Hollard - Refused Insurance Claim"
    with open("bradix-master-api/templates/afca_hollard_complaint.md", "r") as f:
        body = f.read()
    return _send_email(to_email, subject, body)

def send_home_instead_complaint_email():
    to_email = "complaints@homeinstead.com.au" # Placeholder
    subject = "Complaint: Abandoned Care and Unrefunded Payment ($9,000)"
    with open("bradix-master-api/templates/home_instead_complaint.md", "r") as f:
        body = f.read()
    return _send_email(to_email, subject, body)

def send_ptq_complaint_email():
    to_email = "ombudsman@ptq.qld.gov.au" # Placeholder
    subject = "Complaint against Public Trustee QLD - Ref 20675093 (Depleted Funds)"
    with open("bradix-master-api/templates/ptq_complaint.md", "r") as f:
        body = f.read()
    return _send_email(to_email, subject, body)
