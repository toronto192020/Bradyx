#!/usr/bin/env bash
# ============================================================
# BRADIX JETSON AUTO-SETUP
# ============================================================
# Companion script for the NVIDIA Jetson.
# Pushed automatically by bradix-install.sh on the NUC,
# or run manually on the Jetson.
#
# What it does:
#   1. Installs JetPack dependencies
#   2. Installs Ollama (native, for GPU inference)
#   3. Downloads a capable local LLM (llama3.2:3b)
#   4. Deploys FastAPI inference server as systemd service
#   5. Registers with NUC via mDNS/Avahi
#   6. Installs Tailscale for remote access
#
# Everything stays local. No case data leaves the home.
# ============================================================

set -euo pipefail

# ─── CONSTANTS ──────────────────────────────────────────────
DEFAULT_MODEL="llama3.2:3b"
FALLBACK_MODEL="phi3:mini"
BRADIX_DIR="/opt/bradix-jetson"
INFERENCE_PORT=8000
OLLAMA_PORT=11434

# ─── COLOURS ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[BRADIX-JETSON]${NC} $1"; }
warn() { echo -e "${YELLOW}[BRADIX-JETSON]${NC} $1"; }
err()  { echo -e "${RED}[BRADIX-JETSON ERROR]${NC} $1"; }

banner() {
    echo ""
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo ""
}

banner "BRADIX JETSON AI SETUP"
echo -e "${BOLD}Setting up local AI inference for the Quiet Guardian${NC}"
echo ""

# ─── CHECK JETSON HARDWARE ──────────────────────────────────
banner "STEP 1/7: Detecting Jetson Hardware"

if [ -f /etc/nv_tegra_release ]; then
    log "Jetson detected:"
    cat /etc/nv_tegra_release
elif command -v nvidia-smi &>/dev/null; then
    log "NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true
else
    warn "No NVIDIA hardware detected. Ollama will use CPU mode."
fi

# Check JetPack version
if [ -f /etc/nv_tegra_release ]; then
    JETPACK_VER=$(dpkg -l 2>/dev/null | grep nvidia-jetpack | awk '{print $3}' | head -1 || echo "unknown")
    log "JetPack version: $JETPACK_VER"
fi

# ─── INSTALL SYSTEM DEPENDENCIES ───────────────────────────
banner "STEP 2/7: Installing Dependencies"

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -qq
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
    jq \
    net-tools \
    2>/dev/null

# Install Python packages for inference server
sudo pip3 install --quiet \
    fastapi==0.115.0 \
    "uvicorn[standard]==0.30.6" \
    httpx==0.27.2 \
    pydantic==2.8.2 \
    python-multipart==0.0.9 \
    2>/dev/null || true

log "Dependencies installed."

# ─── INSTALL OLLAMA ─────────────────────────────────────────
banner "STEP 3/7: Installing Ollama"

if command -v ollama &>/dev/null; then
    log "Ollama already installed: $(ollama --version 2>/dev/null || echo 'installed')"
else
    log "Installing Ollama (this may take a few minutes)..."
    curl -fsSL https://ollama.com/install.sh | sh
    log "Ollama installed."
fi

# Configure Ollama to listen on all interfaces (so NUC can reach it)
sudo mkdir -p /etc/systemd/system/ollama.service.d
cat <<'OLLAMAEOF' | sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"
OLLAMAEOF

sudo systemctl daemon-reload
sudo systemctl enable --now ollama
sleep 5

log "Ollama configured for network access on port $OLLAMA_PORT."

# ─── DOWNLOAD LLM MODEL ────────────────────────────────────
banner "STEP 4/7: Downloading AI Model"

log "Pulling $DEFAULT_MODEL (this may take 5-15 minutes on first run)..."

if ollama pull "$DEFAULT_MODEL" 2>/dev/null; then
    log "Model $DEFAULT_MODEL ready."
    ACTIVE_MODEL="$DEFAULT_MODEL"
else
    warn "Could not pull $DEFAULT_MODEL. Trying fallback: $FALLBACK_MODEL..."
    if ollama pull "$FALLBACK_MODEL" 2>/dev/null; then
        log "Fallback model $FALLBACK_MODEL ready."
        ACTIVE_MODEL="$FALLBACK_MODEL"
    else
        err "Could not download any model. Check internet connection."
        ACTIVE_MODEL="$DEFAULT_MODEL"
    fi
fi

# Verify model is available
ollama list 2>/dev/null || true

# ─── DEPLOY INFERENCE SERVER ───────────────────────────────
banner "STEP 5/7: Deploying Inference Server"

sudo mkdir -p "$BRADIX_DIR" /opt/bradix/case-data/cheryl-bruce-sanders
sudo chown -R "$USER:$USER" "$BRADIX_DIR"

# Write the FastAPI inference server
cat > "${BRADIX_DIR}/server.py" <<'SERVEREOF'
#!/usr/bin/env python3
"""
Bradix Jetson Inference Server
===============================
FastAPI server exposing local LLM (via Ollama) for case queries.
All processing is on-device. No data leaves the home.
"""

import os
import json
import time
import httpx
import logging
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "llama3.2:3b")
CASE_DATA_PATH = os.getenv("CASE_DATA_PATH", "/opt/bradix/case-data")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "2048"))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("bradix-jetson")

app = FastAPI(
    title="Bradix Jetson Inference Server",
    description="Local AI inference for the Bradix case management system.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

class QueryRequest(BaseModel):
    question: str
    context: Optional[str] = None
    model: Optional[str] = None
    include_case_context: bool = True

class ReportRequest(BaseModel):
    report_type: str
    format: str = "markdown"
    model: Optional[str] = None

class SummarizeRequest(BaseModel):
    text: str
    style: str = "brief"
    model: Optional[str] = None

class InferenceResponse(BaseModel):
    response: str
    model: str
    processing_time_ms: int
    timestamp: str

def load_case_context() -> str:
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
        except Exception as e:
            logger.warning(f"Could not load {full_path}: {e}")
    return "\n\n".join(context_parts)

SYSTEM_PROMPT = """You are the Bradix AI assistant — a calm, competent, and private case management AI
running on local hardware in Andrew's home. You assist Andrew Bruce-Sanders in managing his mother
Cheryl's elder care advocacy case.

Your role:
- Answer questions about the case clearly and accurately
- Generate formal documents and reports when requested
- Help track deadlines and next steps
- Draft correspondence for legal, medical, or advocacy purposes

Your tone: Calm, professional, forward-looking, factual, supportive.
All case data is private and sensitive. Never suggest sharing it externally.
You are running on local hardware. No data leaves this device."""

async def call_ollama(prompt: str, model: str, system: str = SYSTEM_PROMPT) -> str:
    async with httpx.AsyncClient(timeout=180.0) as client:
        payload = {
            "model": model,
            "prompt": prompt,
            "system": system,
            "stream": False,
            "options": {"num_predict": MAX_TOKENS, "temperature": 0.3},
        }
        try:
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
            resp.raise_for_status()
            return resp.json()["response"]
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail="Ollama is not running.")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")

@app.get("/health")
async def health_check():
    ollama_ok = False
    models = []
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            if resp.status_code == 200:
                ollama_ok = True
                models = [m["name"] for m in resp.json().get("models", [])]
    except Exception:
        pass
    return {
        "status": "healthy" if ollama_ok else "degraded",
        "ollama": "running" if ollama_ok else "not_running",
        "models": models,
        "default_model": DEFAULT_MODEL,
        "timestamp": datetime.now().isoformat(),
    }

@app.get("/models")
async def list_models():
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
    start = time.time()
    model = request.model or DEFAULT_MODEL
    if request.include_case_context:
        case_context = request.context or load_case_context()
        prompt = f"Case Context:\n{case_context}\n\nQuestion: {request.question}\n\nAnswer based on the case context. Be concise and actionable."
    else:
        prompt = request.question
    response = await call_ollama(prompt, model)
    elapsed_ms = int((time.time() - start) * 1000)
    return InferenceResponse(response=response, model=model, processing_time_ms=elapsed_ms, timestamp=datetime.now().isoformat())

@app.post("/generate-report", response_model=InferenceResponse)
async def generate_report(request: ReportRequest):
    start = time.time()
    model = request.model or DEFAULT_MODEL
    case_context = load_case_context()
    prompts = {
        "full_case": f"Generate a comprehensive case status report.\n\nCase Data:\n{case_context}",
        "human_rights": f"Generate a formal human rights and elder abuse report.\n\nCase Data:\n{case_context}",
        "bluecare_brief": f"Generate a BlueCare team briefing document.\n\nCase Data:\n{case_context}",
        "smsf_status": f"Generate an SMSF status summary.\n\nCase Data:\n{case_context}",
        "weekly_digest": f"Generate a weekly status digest covering upcoming deadlines, open tasks, and system health.\n\nCase Data:\n{case_context}",
    }
    if request.report_type not in prompts:
        raise HTTPException(status_code=400, detail=f"Unknown report type. Valid: {list(prompts.keys())}")
    response = await call_ollama(prompts[request.report_type], model)
    elapsed_ms = int((time.time() - start) * 1000)
    return InferenceResponse(response=response, model=model, processing_time_ms=elapsed_ms, timestamp=datetime.now().isoformat())

@app.post("/summarize", response_model=InferenceResponse)
async def summarize_document(request: SummarizeRequest):
    start = time.time()
    model = request.model or DEFAULT_MODEL
    styles = {"brief": "Provide a 2-3 sentence summary.", "detailed": "Provide a detailed structured summary.", "legal": "Provide a legal analysis."}
    instruction = styles.get(request.style, styles["brief"])
    response = await call_ollama(f"{instruction}\n\nDocument:\n{request.text}", model)
    elapsed_ms = int((time.time() - start) * 1000)
    return InferenceResponse(response=response, model=model, processing_time_ms=elapsed_ms, timestamp=datetime.now().isoformat())

@app.post("/analyze-deadlines")
async def analyze_deadlines():
    """Analyze current task deadlines and return urgency assessment."""
    start = time.time()
    case_context = load_case_context()
    prompt = f"""Analyze the following case tasks and deadlines. For each task:
1. Assess urgency (OVERDUE, URGENT, THIS_WEEK, THIS_MONTH)
2. Recommend next action
3. Flag any tasks that are blocked by dependencies

Be concise. Format as a structured list.

Case Data:
{case_context}"""
    response = await call_ollama(prompt, DEFAULT_MODEL)
    elapsed_ms = int((time.time() - start) * 1000)
    return {"analysis": response, "processing_time_ms": elapsed_ms, "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
SERVEREOF

log "Inference server deployed to ${BRADIX_DIR}/server.py"

# ─── CREATE SYSTEMD SERVICE ────────────────────────────────
banner "STEP 6/7: Creating System Service"

sudo tee /etc/systemd/system/bradix-jetson.service > /dev/null <<SVCEOF
[Unit]
Description=Bradix Jetson AI Inference Server
After=network-online.target ollama.service
Wants=network-online.target ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=${BRADIX_DIR}
Environment="OLLAMA_BASE_URL=http://localhost:11434"
Environment="DEFAULT_MODEL=${ACTIVE_MODEL:-llama3.2:3b}"
Environment="CASE_DATA_PATH=/opt/bradix/case-data"
Environment="MAX_TOKENS=2048"
ExecStart=/usr/bin/python3 ${BRADIX_DIR}/server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable --now bradix-jetson.service

log "Inference server running as systemd service."
log "Endpoint: http://$(hostname -I | awk '{print $1}'):${INFERENCE_PORT}"

# ─── CONFIGURE mDNS / AVAHI ────────────────────────────────
log "Configuring mDNS (Avahi) for network discovery..."

# Set hostname to jetson for mDNS discovery
sudo hostnamectl set-hostname jetson 2>/dev/null || true

# Create Avahi service file for bradix-jetson
sudo mkdir -p /etc/avahi/services
sudo tee /etc/avahi/services/bradix-jetson.service > /dev/null <<AVAHIEOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>Bradix Jetson AI</name>
  <service>
    <type>_http._tcp</type>
    <port>${INFERENCE_PORT}</port>
    <txt-record>path=/health</txt-record>
    <txt-record>role=bradix-jetson-inference</txt-record>
  </service>
</service-group>
AVAHIEOF

sudo systemctl enable --now avahi-daemon
sudo systemctl restart avahi-daemon

log "mDNS registered: jetson.local:${INFERENCE_PORT}"

# ─── INSTALL TAILSCALE ──────────────────────────────────────
banner "STEP 7/7: Installing Tailscale"

if command -v tailscale &>/dev/null; then
    log "Tailscale already installed."
else
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

sudo systemctl enable --now tailscaled

if tailscale status &>/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "pending")
    log "Tailscale connected: $TS_IP"
else
    log "Starting Tailscale..."
    sudo tailscale up --hostname=bradix-jetson --accept-routes --accept-dns || {
        warn "Tailscale auth needed. Run 'sudo tailscale up' to connect."
    }
fi

# ─── VERIFY EVERYTHING ─────────────────────────────────────
banner "JETSON SETUP COMPLETE"

echo ""
JETSON_IP=$(hostname -I | awk '{print $1}')
TS_IP=$(tailscale ip -4 2>/dev/null || echo "not connected")

echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}│         BRADIX JETSON STATUS                    │${NC}"
echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────┤${NC}"

# Ollama
if curl -sf http://localhost:${OLLAMA_PORT}/api/tags &>/dev/null; then
    echo -e "${CYAN}│${NC}  Ollama:          ${GREEN}● RUNNING${NC}                     ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  Ollama:          ${YELLOW}● STARTING${NC}                    ${CYAN}│${NC}"
fi

# Model
MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ', ' || echo "loading...")
echo -e "${CYAN}│${NC}  Models:          ${GREEN}${MODELS}${NC}              ${CYAN}│${NC}"

# Inference Server
if curl -sf http://localhost:${INFERENCE_PORT}/health &>/dev/null; then
    echo -e "${CYAN}│${NC}  Inference API:   ${GREEN}● HEALTHY${NC}                      ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  Inference API:   ${YELLOW}● STARTING${NC}                    ${CYAN}│${NC}"
fi

# Tailscale
echo -e "${CYAN}│${NC}  Tailscale IP:    ${GREEN}${TS_IP}${NC}                     ${CYAN}│${NC}"

echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  Local:  ${CYAN}http://${JETSON_IP}:${INFERENCE_PORT}${NC}              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  mDNS:   ${CYAN}http://jetson.local:${INFERENCE_PORT}${NC}              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${BOLD}The Jetson is ready. It will serve the NUC quietly.${NC}"
echo ""
