#!/bin/bash
# ============================================================
# BRADIX REPO CLONER
# Clones all required repos onto your NUC
# Run: bash clone_repos.sh
# ============================================================

REPOS_DIR="${HOME}/bradix/repos"
mkdir -p "$REPOS_DIR"
cd "$REPOS_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
skip() { echo -e "${YELLOW}→ skip (exists): $1${NC}"; }

clone_repo() {
    local name="$1"
    local url="$2"
    local desc="$3"
    echo ""
    echo "[$name] $desc"
    if [ -d "$name" ]; then
        skip "$name — updating..."
        cd "$name" && git pull -q 2>/dev/null && cd ..
        ok "$name updated"
    else
        git clone --depth=1 "$url" "$name" -q 2>&1
        if [ $? -eq 0 ]; then
            ok "$name cloned"
        else
            warn "$name — clone failed, check URL"
        fi
    fi
}

echo "============================================================"
echo " BRADIX REPO CLONER"
echo " Destination: $REPOS_DIR"
echo " $(date)"
echo "============================================================"

# ── YOUR OWN REPO ────────────────────────────────────────────
echo -e "\n${YELLOW}━━━ YOUR BRADIX REPO ━━━${NC}"
clone_repo "Bradyx" \
    "https://github.com/toronto192020/Bradyx" \
    "Your BRADIX case management system"

clone_repo "andrew-dashboard" \
    "https://github.com/toronto192020/andrew-dashboard" \
    "Your personal dashboard"

# ── LOCAL AI / LLM ───────────────────────────────────────────
echo -e "\n${YELLOW}━━━ LOCAL AI / LLM STACK ━━━${NC}"

clone_repo "open-webui" \
    "https://github.com/open-webui/open-webui" \
    "Chat UI for your Jetson LLMs — works on iPhone browser"

clone_repo "ollama" \
    "https://github.com/ollama/ollama" \
    "Run LLMs locally on Jetson (llama3.2, mistral, etc)"

# ── AGENTIC AI ───────────────────────────────────────────────
echo -e "\n${YELLOW}━━━ AGENTIC AI FRAMEWORKS ━━━${NC}"

clone_repo "crewAI" \
    "https://github.com/crewAIInc/crewAI" \
    "Multi-agent framework — legal/care/evidence/finance agents"

clone_repo "langgraph" \
    "https://github.com/langchain-ai/langgraph" \
    "Stateful agent workflows — complex case management"

clone_repo "OpenHands" \
    "https://github.com/All-Hands-AI/OpenHands" \
    "Autonomous task agent — formerly OpenDevin"

clone_repo "openclaw" \
    "https://github.com/steinberger/openclaw" \
    "Viral personal AI agent — R1 interface layer"

# ── DOCUMENT PROCESSING ──────────────────────────────────────
echo -e "\n${YELLOW}━━━ DOCUMENT PROCESSING ━━━${NC}"

clone_repo "docling" \
    "https://github.com/DS4SD/docling" \
    "IBM PDF extractor — handles scanned docs and tables"

clone_repo "llama_index" \
    "https://github.com/run-llama/llama_index" \
    "Document indexing and query engine"

clone_repo "marker" \
    "https://github.com/VikParuchuri/marker" \
    "Fast PDF to Markdown converter — GPU accelerated"

# ── CLOUD INGESTION ──────────────────────────────────────────
echo -e "\n${YELLOW}━━━ CLOUD INGESTION ━━━${NC}"

clone_repo "icloud_photos_downloader" \
    "https://github.com/icloud-photos-downloader/icloud_photos_downloader" \
    "Download Cheryl's iCloud photos — evidence preservation"

clone_repo "python-ring-doorbell" \
    "https://github.com/python-ring-doorbell/python-ring-doorbell" \
    "Ring footage download — run TODAY for car break-in evidence"

clone_repo "gphotos-sync" \
    "https://github.com/gilesknap/gphotos-sync" \
    "Google Photos sync to NAS"

# ── HOME AUTOMATION / CARE MONITORING ────────────────────────
echo -e "\n${YELLOW}━━━ HOME AUTOMATION / CARE MONITORING ━━━${NC}"

clone_repo "home-assistant-core" \
    "https://github.com/home-assistant/core" \
    "Home Assistant — Ring, Alexa, Samsung, fall detection"

clone_repo "n8n" \
    "https://github.com/n8n-io/n8n" \
    "Workflow automation brain — ties everything together"

# ── SPEECH / TRANSCRIPTION ───────────────────────────────────
echo -e "\n${YELLOW}━━━ SPEECH & TRANSCRIPTION ━━━${NC}"

clone_repo "whisper" \
    "https://github.com/openai/whisper" \
    "Transcribe DTMR voice memo and all recordings on Jetson"

clone_repo "OpenVoice" \
    "https://github.com/myshell-ai/OpenVoice" \
    "Voice cloning — calming AI companion voice for Cheryl"

# ── HOLOGRAPHIC / AVATAR ─────────────────────────────────────
echo -e "\n${YELLOW}━━━ HOLOGRAPHIC CARE SYSTEM ━━━${NC}"

clone_repo "SadTalker" \
    "https://github.com/OpenTalker/SadTalker" \
    "Animated talking avatar — holographic companion for Cheryl"

clone_repo "wav2lip" \
    "https://github.com/Rudrabha/Wav2Lip" \
    "Lip sync for avatar — makes companion look realistic"

# ── LEGAL AI ─────────────────────────────────────────────────
echo -e "\n${YELLOW}━━━ LEGAL AI ━━━${NC}"

clone_repo "free-law-project" \
    "https://github.com/freelawproject/courtlistener" \
    "Court listener — search Australian and international case law"

# ── SECURITY / NETWORK ───────────────────────────────────────
echo -e "\n${YELLOW}━━━ SECURITY & NETWORK ━━━${NC}"

clone_repo "tailscale" \
    "https://github.com/tailscale/tailscale" \
    "Secure private network — connect NUC, Jetson, iPhone"

# ── SUMMARY ──────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN} ALL REPOS CLONED TO: $REPOS_DIR${NC}"
echo "============================================================"
echo ""
echo "PRIORITY — run these first:"
echo ""
echo "  1. OPEN-WEBUI (talk to Jetson from iPhone NOW):"
echo "     cd $REPOS_DIR/open-webui"
echo "     docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway \\"
echo "       -v open-webui:/app/backend/data --name open-webui --restart always \\"
echo "       ghcr.io/open-webui/open-webui:main"
echo "     Open: http://[NUC-IP]:3000 on your iPhone"
echo ""
echo "  2. RING FOOTAGE (TODAY — 60-day expiry):"
echo "     cd $REPOS_DIR/python-ring-doorbell"
echo "     pip install ring-doorbell"
echo "     RING_EMAIL=x RING_PASSWORD=x python3 ~/bradix/agents/ring_download.py"
echo ""
echo "  3. N8N (workflow automation):"
echo "     docker run -d -p 5678:5678 -v n8n_data:/home/node/.n8n \\"
echo "       --name n8n --restart always n8nio/n8n"
echo "     Open: http://[NUC-IP]:5678"
echo ""
echo "  4. HOME ASSISTANT (Cheryl fall detection):"
echo "     docker run -d --name homeassistant --privileged --restart=unless-stopped \\"
echo "       -v /home/$(whoami)/homeassistant:/config \\"
echo "       -p 8123:8123 ghcr.io/home-assistant/home-assistant:stable"
echo "     Open: http://[NUC-IP]:8123"
echo ""
echo "============================================================"
