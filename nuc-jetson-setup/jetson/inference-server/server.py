#!/usr/bin/env python3
"""
Bradix Jetson Inference Server
===============================
A FastAPI server that exposes the Jetson's local LLM (via Ollama)
as an HTTP endpoint that n8n can call for case queries and report
generation.

The AI runs entirely on local hardware — no case data is sent
to external cloud services.

Endpoints:
    GET  /health              — Health check
    POST /query               — Ask a question about the case
    POST /generate-report     — Generate a formatted report
    POST /summarize           — Summarize a document or text
    GET  /models              — List available local models
    POST /agent/trigger       — Trigger an agentic workflow step
    GET  /health/diagnose     — Extended system diagnostics

Usage:
    python3 server.py
    # Or via Docker: docker run -p 8000:8000 bradix-jetson
"""

import os
import json
import time
import httpx
import logging
import platform
import shutil
import subprocess
from datetime import datetime
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ─── Configuration ───────────────────────────────────────────
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "llama3.2:3b")
CASE_DATA_PATH = os.getenv("CASE_DATA_PATH", "/case-data")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "2048"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

logging.basicConfig(level=getattr(logging, LOG_LEVEL))
logger = logging.getLogger("bradix-jetson")

app = FastAPI(
    title="Bradix Jetson Inference Server",
    description="Local AI inference for the Bradix case management system. All processing is on-device.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5678", "http://nuc.local:5678"],  # n8n only
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ─── Models ──────────────────────────────────────────────────
class QueryRequest(BaseModel):
    question: str
    context: Optional[str] = None
    model: Optional[str] = None
    include_case_context: bool = True


class ReportRequest(BaseModel):
    report_type: str  # "full_case", "human_rights", "bluecare_brief", "smsf_status"
    format: str = "markdown"  # "markdown" | "plain"
    model: Optional[str] = None


class SummarizeRequest(BaseModel):
    text: str
    style: str = "brief"  # "brief" | "detailed" | "legal"
    model: Optional[str] = None


class InferenceResponse(BaseModel):
    response: str
    model: str
    processing_time_ms: int
    timestamp: str


class AgentTriggerRequest(BaseModel):
    workflow: str  # "deadline_check", "weekly_digest", "healing_scan", "custom"
    payload: Optional[Dict[str, Any]] = None
    model: Optional[str] = None
    async_exec: bool = False  # If True, return immediately and run in background


class AgentTriggerResponse(BaseModel):
    workflow: str
    status: str  # "triggered", "completed", "queued"
    result: Optional[str] = None
    processing_time_ms: Optional[int] = None
    timestamp: str


# ─── Case Data Loader ────────────────────────────────────────
def load_case_context() -> str:
    """Load case data files and return a structured context string."""
    context_parts = []

    files = {
        "case_data": "cheryl-bruce-sanders/case_data.json",
        "tasks": "cheryl-bruce-sanders/agent_task_tracker.json",
        "entities": "cheryl-bruce-sanders/entity_registry.json",
    }

    for name, path in files.items():
        full_path = os.path.join(CASE_DATA_PATH, path)
        try:
            with open(full_path) as f:
                data = json.load(f)
            context_parts.append(f"=== {name.upper()} ===\n{json.dumps(data, indent=2)}")
        except FileNotFoundError:
            logger.warning(f"Case data file not found: {full_path}")
        except Exception as e:
            logger.error(f"Error loading {full_path}: {e}")

    return "\n\n".join(context_parts)


SYSTEM_PROMPT = """You are the Bradix AI assistant — a calm, competent, and private case management AI
running on local hardware in Andrew's home. You assist Andrew Bruce-Sanders in managing his mother
Cheryl's elder care advocacy case.

Your role:
- Answer questions about the case clearly and accurately
- Generate formal documents and reports when requested
- Help track deadlines and next steps
- Draft correspondence for legal, medical, or advocacy purposes

Your tone:
- Calm and professional — never alarmist
- Forward-looking — focus on what needs to happen next
- Factual — stick to what is documented
- Supportive — Andrew and Cheryl have been through a great deal

Important:
- All case data is private and sensitive. Never suggest sharing it externally.
- You are running on local hardware. No data leaves this device.
- When generating formal reports, use precise legal and medical language.
- When answering day-to-day questions, be concise and actionable.
"""


# ─── Ollama Client ───────────────────────────────────────────
async def call_ollama(prompt: str, model: str, system: str = SYSTEM_PROMPT) -> str:
    """Call the local Ollama instance."""
    async with httpx.AsyncClient(timeout=120.0) as client:
        payload = {
            "model": model,
            "prompt": prompt,
            "system": system,
            "stream": False,
            "options": {
                "num_predict": MAX_TOKENS,
                "temperature": 0.3,  # Lower temperature for factual case work
            },
        }
        try:
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
            resp.raise_for_status()
            return resp.json()["response"]
        except httpx.ConnectError:
            raise HTTPException(
                status_code=503,
                detail="Ollama is not running. Start it with: ollama serve"
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")


# ─── Routes ──────────────────────────────────────────────────
@app.get("/health")
async def health_check():
    """Health check endpoint for the Quiet Guardian monitor."""
    ollama_ok = False
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            ollama_ok = resp.status_code == 200
    except Exception:
        pass

    return {
        "status": "healthy" if ollama_ok else "degraded",
        "ollama": "running" if ollama_ok else "not_running",
        "model": DEFAULT_MODEL,
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/models")
async def list_models():
    """List available local models."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            resp.raise_for_status()
            models = [m["name"] for m in resp.json().get("models", [])]
            return {"models": models, "default": DEFAULT_MODEL}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Cannot reach Ollama: {str(e)}")


@app.post("/query", response_model=InferenceResponse)
async def query_case(request: QueryRequest):
    """
    Ask a question about the case. The AI uses local case data as context.

    Example:
        POST /query
        {"question": "What is the current status of the Section 61 appeal?"}
    """
    start = time.time()
    model = request.model or DEFAULT_MODEL

    # Build prompt with optional case context
    if request.include_case_context:
        case_context = request.context or load_case_context()
        prompt = f"""Case Context:
{case_context}

Question: {request.question}

Please answer based on the case context above. Be concise and actionable."""
    else:
        prompt = request.question

    response = await call_ollama(prompt, model)
    elapsed_ms = int((time.time() - start) * 1000)

    logger.info(f"Query answered in {elapsed_ms}ms using {model}")

    return InferenceResponse(
        response=response,
        model=model,
        processing_time_ms=elapsed_ms,
        timestamp=datetime.now().isoformat(),
    )


@app.post("/generate-report", response_model=InferenceResponse)
async def generate_report(request: ReportRequest):
    """
    Generate a formatted report from case data.

    Report types:
    - full_case: Complete case status report
    - human_rights: Formal human rights / elder abuse report
    - bluecare_brief: Briefing document for BlueCare team
    - smsf_status: SMSF status summary
    """
    start = time.time()
    model = request.model or DEFAULT_MODEL
    case_context = load_case_context()

    report_prompts = {
        "full_case": f"""Using the case data below, generate a comprehensive case status report for Andrew Bruce-Sanders.

Include:
1. Case overview (patient, carer, key references)
2. Current open tasks and deadlines
3. Legal strategy status
4. Complaint status for each institution
5. Medical status
6. SMSF status
7. Evidence inventory summary

Format as a professional {request.format} document with clear headings.

Case Data:
{case_context}""",

        "human_rights": f"""Using the case data below, generate a formal human rights and elder abuse report
suitable for submission to the Queensland Human Rights Commission, Aged Care Quality and Safety Commission,
or Australian Human Rights Commission.

Include:
1. Executive Summary
2. Parties Involved (complainant, respondents)
3. Chronology of Events (with specific dates)
4. Institutional Failures (documented with evidence references)
5. Legal Framework (relevant legislation: Guardianship and Administration Act, Aged Care Act, Human Rights Act 2019 Qld)
6. Evidence References
7. Remedies Sought

Use formal legal language. Be precise and factual.

Case Data:
{case_context}""",

        "bluecare_brief": f"""Using the case data below, generate a professional briefing document for the BlueCare team
who are providing care services to Cheryl Ann Bruce-Sanders.

Include:
1. Patient Overview (name, DOB, medical summary)
2. Capacity Framework (fluctuating, environmentally dependent, supported decision-making)
3. Current Care Needs
4. Communication Preferences (calm environment, no stress triggers)
5. Key Contacts (Andrew as primary carer and EPOA advocate)
6. Important Context (brief, factual, without dwelling on past failures)

Tone: Professional, care-focused, forward-looking.

Case Data:
{case_context}""",

        "smsf_status": f"""Using the case data below, generate a concise SMSF status summary for Andrew.

Include current status, any pending actions, PTQ position, and recommended next steps.

Case Data:
{case_context}""",
    }

    if request.report_type not in report_prompts:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown report type: {request.report_type}. Valid types: {list(report_prompts.keys())}"
        )

    response = await call_ollama(report_prompts[request.report_type], model)
    elapsed_ms = int((time.time() - start) * 1000)

    logger.info(f"Report '{request.report_type}' generated in {elapsed_ms}ms using {model}")

    return InferenceResponse(
        response=response,
        model=model,
        processing_time_ms=elapsed_ms,
        timestamp=datetime.now().isoformat(),
    )


@app.post("/summarize", response_model=InferenceResponse)
async def summarize_document(request: SummarizeRequest):
    """
    Summarize a document or text passage.

    Styles:
    - brief: 2-3 sentence summary
    - detailed: Full structured summary
    - legal: Legal analysis and key points
    """
    start = time.time()
    model = request.model or DEFAULT_MODEL

    style_instructions = {
        "brief": "Provide a 2-3 sentence summary of the key points.",
        "detailed": "Provide a detailed structured summary with key facts, dates, and implications.",
        "legal": "Provide a legal analysis identifying key facts, relevant legal issues, and potential actions.",
    }

    instruction = style_instructions.get(request.style, style_instructions["brief"])
    prompt = f"{instruction}\n\nDocument:\n{request.text}"

    response = await call_ollama(prompt, model)
    elapsed_ms = int((time.time() - start) * 1000)

    return InferenceResponse(
        response=response,
        model=model,
        processing_time_ms=elapsed_ms,
        timestamp=datetime.now().isoformat(),
    )


# ─── Agentic Workflow Trigger ─────────────────────────────────────────────────

# Workflow prompts executed autonomously by the agent trigger endpoint.
DEFAULT_AGENT_PROMPT = "Provide a status update on the current case."

AGENT_WORKFLOW_PROMPTS: Dict[str, str] = {
    "deadline_check": (
        "Review the current case data and identify ALL tasks with deadlines within "
        "the next 7 days. For each task list: task ID, description, deadline, "
        "current status, and the single most important next action. "
        "Be concise and prioritise by urgency."
    ),
    "weekly_digest": (
        "Generate a concise weekly briefing for Andrew covering: "
        "(1) Critical items requiring action this week, "
        "(2) Progress made on open legal and care matters, "
        "(3) Any upcoming care appointments for Cheryl, "
        "(4) Financial or compliance deadlines. "
        "Keep it under 400 words and lead with the most urgent item."
    ),
    "healing_scan": (
        "Based on the current case data, identify any tasks, deadlines, or "
        "evidence items that appear to be stalled, overdue, or inconsistent "
        "with expectations. Suggest one corrective action for each issue found."
    ),
}


async def _run_agent_workflow(workflow: str, payload: Optional[Dict], model: str) -> str:
    """Execute an agent workflow and return the AI response."""
    base_prompt = AGENT_WORKFLOW_PROMPTS.get(
        workflow,
        (payload.get("prompt", DEFAULT_AGENT_PROMPT) if payload else DEFAULT_AGENT_PROMPT),
    )
    case_context = load_case_context()
    full_prompt = f"Case Context:\n{case_context}\n\nTask:\n{base_prompt}"
    return await call_ollama(full_prompt, model)


@app.post("/agent/trigger", response_model=AgentTriggerResponse)
async def agent_trigger(request: AgentTriggerRequest, background_tasks: BackgroundTasks):
    """
    Trigger an agentic workflow step on the local AI.

    Workflows:
    - deadline_check : Scan case data for upcoming deadlines
    - weekly_digest  : Generate a weekly briefing
    - healing_scan   : Identify stalled or inconsistent tasks
    - custom         : Run a custom prompt (provide payload.prompt)

    Set async_exec=true to return immediately (fire-and-forget).

    Example:
        POST /agent/trigger
        {"workflow": "deadline_check"}
    """
    valid_workflows = list(AGENT_WORKFLOW_PROMPTS.keys()) + ["custom"]
    if request.workflow not in valid_workflows:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unknown workflow: '{request.workflow}'. "
                f"Valid workflows: {valid_workflows}"
            ),
        )
    if request.workflow == "custom" and not (request.payload or {}).get("prompt"):
        raise HTTPException(
            status_code=400,
            detail="Workflow 'custom' requires payload.prompt to be set.",
        )

    model = request.model or DEFAULT_MODEL
    timestamp = datetime.now().isoformat()

    if request.async_exec:
        # Fire and forget — return immediately
        background_tasks.add_task(
            _run_agent_workflow, request.workflow, request.payload, model
        )
        logger.info(f"Agent workflow '{request.workflow}' queued (async)")
        return AgentTriggerResponse(
            workflow=request.workflow,
            status="queued",
            result=None,
            timestamp=timestamp,
        )

    # Synchronous execution
    start = time.time()
    result = await _run_agent_workflow(request.workflow, request.payload, model)
    elapsed_ms = int((time.time() - start) * 1000)
    logger.info(f"Agent workflow '{request.workflow}' completed in {elapsed_ms}ms")

    return AgentTriggerResponse(
        workflow=request.workflow,
        status="completed",
        result=result,
        processing_time_ms=elapsed_ms,
        timestamp=timestamp,
    )


# ─── Extended Diagnostics ─────────────────────────────────────────────────────

@app.get("/health/diagnose")
async def health_diagnose():
    """
    Extended system diagnostics endpoint.

    Returns detailed health information beyond the basic /health check:
    - Ollama status and available models
    - Disk usage on the working directory
    - Case data file presence
    - Python runtime and platform info
    - Inference server version
    """
    timestamp = datetime.now().isoformat()

    # Ollama status
    ollama_ok = False
    available_models: List[str] = []
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            if resp.status_code == 200:
                ollama_ok = True
                available_models = [m["name"] for m in resp.json().get("models", [])]
    except Exception:
        pass

    # Disk usage
    disk_info: Dict[str, Any] = {}
    try:
        total, used, free = shutil.disk_usage(CASE_DATA_PATH if os.path.exists(CASE_DATA_PATH) else "/")
        disk_info = {
            "path": CASE_DATA_PATH,
            "total_gb": round(total / (1024 ** 3), 1),
            "used_gb": round(used / (1024 ** 3), 1),
            "free_gb": round(free / (1024 ** 3), 1),
            "percent_used": int(used / total * 100),
        }
    except Exception as exc:
        disk_info = {"error": "disk_usage_unavailable"}
        logger.warning(f"Could not read disk usage: {exc}")

    # Case data presence
    case_files = {
        "case_data.json": os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders", "case_data.json"),
        "agent_task_tracker.json": os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders", "agent_task_tracker.json"),
        "entity_registry.json": os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders", "entity_registry.json"),
    }
    case_data_status = {
        name: os.path.exists(path) for name, path in case_files.items()
    }

    return {
        "status": "healthy" if ollama_ok else "degraded",
        "timestamp": timestamp,
        "inference_server": {
            "version": app.version,
            "default_model": DEFAULT_MODEL,
            "ollama_url": OLLAMA_BASE_URL,
        },
        "ollama": {
            "running": ollama_ok,
            "available_models": available_models,
        },
        "disk": disk_info,
        "case_data": {
            "path": CASE_DATA_PATH,
            "files": case_data_status,
            "all_present": all(case_data_status.values()),
        },
        "runtime": {
            "python": platform.python_version(),
            "platform": platform.system(),
            "hostname": platform.node(),
        },
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
