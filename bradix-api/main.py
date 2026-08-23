"""BRADIX Master API.

Local-first by default: task calls create an auditable draft status. External sends only
occur when ALLOW_EXTERNAL_SEND=true and the relevant connector is configured.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from config import settings
from notifications import send_telegram_notification
from handlers.controversial_situations import PLAYBOOKS

app = FastAPI(title="BRADIX Master API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

DATA_DIR = Path(os.getenv("BRADIX_DATA_DIR", "/data"))
STATUS_FILE = DATA_DIR / "task_status.json"
TEMPLATE_DIR = Path(__file__).parent / "templates"

class TaskRequest(BaseModel):
    source: str = Field(default="api")
    notes: str | None = None
    send: bool = False
    fields: dict[str, Any] = Field(default_factory=dict)


def _read_status() -> dict[str, Any]:
    try:
        return json.loads(STATUS_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def _write_status(status: dict[str, Any]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    STATUS_FILE.write_text(json.dumps(status, indent=2))


def _template(name: str) -> str:
    path = TEMPLATE_DIR / name
    try:
        return path.read_text()
    except OSError:
        return "Template unavailable."


def _record(task_id: str, label: str, request: TaskRequest, detail: str, state: str = "draft") -> dict[str, Any]:
    status = _read_status()
    item = {
        "task": task_id,
        "label": label,
        "state": state,
        "detail": detail,
        "source": request.source,
        "notes": request.notes,
        "updated_at": int(time.time()),
    }
    status[task_id] = item
    _write_status(status)
    send_telegram_notification(f"BRADIX: {label} → {state}\n{detail}")
    return item


def _maybe_send(task_id: str, label: str, request: TaskRequest, draft: str) -> dict[str, Any]:
    if not request.send or not settings.allow_external_send:
        return _record(task_id, label, request, "Draft prepared locally. External send disabled.", "draft") | {"draft": draft}
    # Connector adapters are intentionally explicit. SMTP/email provider wiring can be added
    # without changing the task contract; no silent network side effects are permitted.
    if not settings.outbound_webhook_url:
        return _record(task_id, label, request, "External send requested but no outbound webhook is configured.", "blocked") | {"draft": draft}
    try:
        response = requests.post(settings.outbound_webhook_url, json={"task": task_id, "label": label, "draft": draft, "fields": request.fields}, timeout=20)
        response.raise_for_status()
        return _record(task_id, label, request, "Outbound connector acknowledged the request.", "sent") | {"draft": draft, "connector": response.json() if response.content else {}}
    except requests.RequestException as exc:
        return _record(task_id, label, request, f"Outbound connector failed: {exc}", "blocked") | {"draft": draft}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "bradix-api", "mode": "external-send-enabled" if settings.allow_external_send else "draft-first"}


@app.get("/situations")
def get_situations() -> dict[str, Any]:
    return {"situations": PLAYBOOKS}


@app.get("/status")
def get_status() -> dict[str, Any]:
    return {"service": "BRADIX Master API", "version": app.version, "mode": "external-send-enabled" if settings.allow_external_send else "draft-first", "tasks": _read_status()}


@app.post("/execute-all")
def execute_all(request: TaskRequest | None = None) -> dict[str, Any]:
    request = request or TaskRequest(source="execute-all")
    results = []
    for task_id, label, filename in [
        ("nominate-mills", "Nominate Mills", "tmr_nomination_email.md"),
        ("nominate-woodward", "Nominate Woodward", "tmr_nomination_email.md"),
        ("sper-payment-plan", "SPER payment plan", "sper_email.md"),
        ("bluecare-activate", "BlueCare activation", "bluecare_email.md"),
        ("ptq-accounting", "PTQ accounting", "ptq_email.md"),
        ("protect-super", "Super protection", "super_fund_protection_letter.md"),
        ("qcat-review", "QCAT review", "qcat_review_application.md"),
    ]:
        results.append(_maybe_send(task_id, label, request, _template(filename)))
    return {"state": "complete", "results": results}


@app.post("/nominate-mills")
def nominate_mills(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("nominate-mills", "Nominate Mills", request or TaskRequest(), _template("tmr_nomination_email.md"))


@app.post("/nominate-woodward")
def nominate_woodward(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("nominate-woodward", "Nominate Woodward", request or TaskRequest(), _template("tmr_nomination_email.md"))


@app.post("/sper-payment-plan")
def sper_payment_plan(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("sper-payment-plan", "SPER payment plan", request or TaskRequest(), _template("sper_email.md"))


@app.post("/bluecare-activate")
def bluecare_activate(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("bluecare-activate", "BlueCare activation", request or TaskRequest(), _template("bluecare_email.md"))


@app.post("/ptq-accounting")
def ptq_accounting(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("ptq-accounting", "PTQ accounting", request or TaskRequest(), _template("ptq_email.md"))


@app.post("/protect-super")
def protect_super(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("protect-super", "Super protection", request or TaskRequest(), _template("super_fund_protection_letter.md"))


@app.post("/qcat-review")
def qcat_review(request: TaskRequest | None = None) -> dict[str, Any]:
    return _maybe_send("qcat-review", "QCAT review", request or TaskRequest(), _template("qcat_review_application.md"))


@app.post("/ollama-chat")
def ollama_chat(payload: dict[str, Any]) -> dict[str, Any]:
    prompt = str(payload.get("prompt", "")).strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="prompt is required")
    try:
        response = requests.post(f"{settings.ollama_host}/api/generate", json={"model": settings.ollama_model, "prompt": prompt, "stream": False}, timeout=90)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as exc:
        raise HTTPException(status_code=503, detail=f"Ollama unavailable: {exc}") from exc


@app.post("/n8n-webhook/{webhook_name}")
def n8n_webhook(webhook_name: str, payload: dict[str, Any]) -> dict[str, Any]:
    if not settings.n8n_webhook_base:
        raise HTTPException(status_code=503, detail="N8N_WEBHOOK_BASE is not configured")
    try:
        response = requests.post(f"{settings.n8n_webhook_base.rstrip('/')}/{webhook_name}", json=payload, timeout=30)
        response.raise_for_status()
        return response.json() if response.content else {"status": "ok"}
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"n8n unavailable: {exc}") from exc
