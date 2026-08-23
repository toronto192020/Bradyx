"""Structured, non-escalatory situation playbooks for the BRADIX API."""
from __future__ import annotations

PLAYBOOKS = {
    "urgent-care-change": {
        "title": "Urgent care change",
        "steps": ["Stabilise immediate needs", "Record time and observable facts", "Contact the appropriate service", "Preserve the response and next deadline"],
    },
    "missed-service": {
        "title": "Missed service",
        "steps": ["Record provider, scheduled time, and impact", "Check the service agreement", "Request a written explanation", "Escalate through the provider’s formal channel if unresolved"],
    },
    "document-dispute": {
        "title": "Document dispute",
        "steps": ["Keep the original unchanged", "Create a dated chronology", "Separate fact from interpretation", "Request correction or review in writing"],
    },
}


def get_playbook(slug: str) -> dict[str, object]:
    return PLAYBOOKS.get(slug, {"title": "Unknown situation", "steps": ["Record the facts", "Pause before sending", "Choose the next reversible action"]})
