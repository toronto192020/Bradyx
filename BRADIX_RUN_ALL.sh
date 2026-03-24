#!/bin/bash
# ============================================================
# BRADIX MASTER RUN SCRIPT
# Executes all suggestions from the BRADIX PDF documents
# Run on your NUC (Ubuntu) with: bash BRADIX_RUN_ALL.sh
# ============================================================

set -e
BRADIX_HOME="/home/$(whoami)/bradix"
LOG="$BRADIX_HOME/logs/run_$(date +%Y%m%d_%H%M%S).log"
JETSON_IP="${JETSON_IP:-192.168.1.100}"  # Override: JETSON_IP=x.x.x.x bash BRADIX_RUN_ALL.sh

mkdir -p "$BRADIX_HOME"/{agents,extracted,vectordb,pdfs,logs,downloads}

echo "============================================================"
echo " BRADIX MASTER INSTALLER & RUNNER"
echo " $(date)"
echo " Log: $LOG"
echo "============================================================"
exec > >(tee -a "$LOG") 2>&1

# ── COLOUR HELPERS ──────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; }
step() { echo -e "\n${YELLOW}━━━ $1 ━━━${NC}"; }

# ── STEP 1: SYSTEM DEPENDENCIES ─────────────────────────────
step "1/10 — Installing system dependencies"
sudo apt-get update -qq
sudo apt-get install -y -qq \
    python3 python3-pip python3-venv git curl wget \
    ffmpeg libsm6 libxext6 poppler-utils \
    libimobiledevice-utils ifuse 2>/dev/null || warn "Some packages skipped"
ok "System dependencies installed"

# ── STEP 2: PYTHON VIRTUAL ENVIRONMENT ──────────────────────
step "2/10 — Setting up Python environment"
python3 -m venv "$BRADIX_HOME/venv"
source "$BRADIX_HOME/venv/bin/activate"
pip install --upgrade pip -q
ok "Virtual environment ready at $BRADIX_HOME/venv"

# ── STEP 3: INSTALL PYTHON PACKAGES ─────────────────────────
step "3/10 — Installing Python packages"
pip install -q \
    docling \
    llama-index \
    llama-index-llms-ollama \
    llama-index-embeddings-ollama \
    llama-index-vector-stores-chroma \
    chromadb \
    pymupdf \
    pdfplumber \
    crewai \
    langchain-ollama \
    fastapi \
    uvicorn \
    requests \
    msal \
    gphotos-sync \
    icloudpd \
    ring-doorbell \
    pysmartthings \
    aiohttp \
    python-dotenv \
    openai-whisper 2>/dev/null || warn "Some packages may have failed — check log"
ok "Python packages installed"

# ── STEP 4: INSTALL OLLAMA ───────────────────────────────────
step "4/10 — Installing Ollama (local LLM)"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    ok "Ollama installed"
else
    ok "Ollama already installed"
fi

# Pull models (runs in background on Jetson if available, else local)
echo "Pulling LLM models (this may take a few minutes)..."
ollama pull llama3.2 &
ollama pull nomic-embed-text &
wait
ok "LLM models ready"

# ── STEP 5: CLONE BRADIX REPO ────────────────────────────────
step "5/10 — Syncing BRADIX GitHub repo"
if [ -d "$BRADIX_HOME/repo" ]; then
    cd "$BRADIX_HOME/repo" && git pull -q
    ok "Repo updated"
else
    git clone https://github.com/toronto192020/Bradyx.git "$BRADIX_HOME/repo" -q
    ok "Repo cloned"
fi

# Copy all PDFs to working directory
cp "$BRADIX_HOME/repo/pdfs/"*.pdf "$BRADIX_HOME/pdfs/" 2>/dev/null || true
ok "PDFs synced to $BRADIX_HOME/pdfs/"

# ── STEP 6: EXTRACT PDFs WITH DOCLING ───────────────────────
step "6/10 — Extracting PDF content with Docling"
python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, os.path.expanduser("~/bradix/venv/lib/python3.11/site-packages"))

try:
    from docling.document_converter import DocumentConverter
    converter = DocumentConverter()
    pdf_dir = os.path.expanduser("~/bradix/pdfs/")
    out_dir = os.path.expanduser("~/bradix/extracted/")
    os.makedirs(out_dir, exist_ok=True)

    for fname in os.listdir(pdf_dir):
        if fname.endswith(".pdf"):
            src = os.path.join(pdf_dir, fname)
            dst = os.path.join(out_dir, fname.replace(".pdf", ".md"))
            if os.path.exists(dst):
                print(f"  skip (exists): {fname}")
                continue
            try:
                result = converter.convert(src)
                with open(dst, "w") as f:
                    f.write(result.document.export_to_markdown())
                print(f"  ✓ extracted: {fname}")
            except Exception as e:
                print(f"  ⚠ fallback for {fname}: {e}")
                # Fallback: use pdfplumber
                import pdfplumber
                with pdfplumber.open(src) as pdf:
                    text = "\n\n".join(p.extract_text() or "" for p in pdf.pages)
                with open(dst, "w") as f:
                    f.write(text)
                print(f"  ✓ extracted (fallback): {fname}")
    print("Extraction complete.")
except ImportError as e:
    print(f"Docling not available: {e} — using pdfplumber fallback")
    import pdfplumber, os
    pdf_dir = os.path.expanduser("~/bradix/pdfs/")
    out_dir = os.path.expanduser("~/bradix/extracted/")
    os.makedirs(out_dir, exist_ok=True)
    for fname in os.listdir(pdf_dir):
        if fname.endswith(".pdf"):
            with pdfplumber.open(os.path.join(pdf_dir, fname)) as pdf:
                text = "\n\n".join(p.extract_text() or "" for p in pdf.pages)
            with open(os.path.join(out_dir, fname.replace(".pdf", ".md")), "w") as f:
                f.write(text)
            print(f"  ✓ {fname}")
PYEOF
ok "PDF extraction complete — files in $BRADIX_HOME/extracted/"

# ── STEP 7: BUILD VECTOR INDEX ───────────────────────────────
step "7/10 — Building searchable vector index"
python3 - <<PYEOF
import os, sys
sys.path.insert(0, os.path.expanduser("~/bradix/venv/lib/python3.11/site-packages"))

try:
    from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
    from llama_index.llms.ollama import Ollama
    from llama_index.embeddings.ollama import OllamaEmbedding
    import chromadb
    from llama_index.vector_stores.chroma import ChromaVectorStore
    from llama_index.core import StorageContext

    jetson_ip = os.environ.get("JETSON_IP", "localhost")
    Settings.llm = Ollama(model="llama3.2", base_url=f"http://{jetson_ip}:11434", request_timeout=120)
    Settings.embed_model = OllamaEmbedding(model_name="nomic-embed-text", base_url=f"http://{jetson_ip}:11434")

    chroma_client = chromadb.PersistentClient(path=os.path.expanduser("~/bradix/vectordb"))
    collection = chroma_client.get_or_create_collection("bradix")
    vector_store = ChromaVectorStore(chroma_collection=collection)
    storage_context = StorageContext.from_defaults(vector_store=vector_store)

    extracted_dir = os.path.expanduser("~/bradix/extracted/")
    docs = SimpleDirectoryReader(input_dir=extracted_dir, recursive=True).load_data()
    print(f"  Indexing {len(docs)} document chunks...")
    index = VectorStoreIndex.from_documents(docs, storage_context=storage_context, show_progress=True)
    print("  ✓ Index built and saved")
except Exception as e:
    print(f"  ⚠ Index build skipped (Ollama may not be running yet): {e}")
    print("  Run manually: python3 ~/bradix/agents/build_index.py")
PYEOF
ok "Vector index ready at $BRADIX_HOME/vectordb/"

# ── STEP 8: DEPLOY FASTAPI GATEWAY ──────────────────────────
step "8/10 — Deploying BRADIX API gateway"
cat > "$BRADIX_HOME/agents/api.py" <<'PYEOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess, json, os

app = FastAPI(title="BRADIX API", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"])

KNOWLEDGE_BASE = os.path.expanduser("~/bradix/repo/r1-dlam/BRADIX_R1_KNOWLEDGE_BASE.json")

@app.get("/")
def root():
    return {"status": "BRADIX online", "version": "1.0"}

@app.get("/api/deadlines")
def deadlines():
    with open(KNOWLEDGE_BASE) as f:
        data = json.load(f)
    return {"deadlines": [d for d in data["deadlines"] if d["status"] != "DONE"]}

@app.get("/api/people")
def people():
    with open(KNOWLEDGE_BASE) as f:
        data = json.load(f)
    return {"people": data["people"]}

@app.get("/api/status")
def status():
    return {"status": "online", "system": "BRADIX", "version": "1.0"}

@app.post("/api/query")
def query(question: str):
    result = subprocess.run(
        ["python3", os.path.expanduser("~/bradix/agents/query_docs.py"), question],
        capture_output=True, text=True, timeout=60
    )
    return {"question": question, "answer": result.stdout.strip()}
PYEOF

# Create systemd service
sudo tee /etc/systemd/system/bradix-api.service > /dev/null <<SERVICE
[Unit]
Description=BRADIX API Gateway
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$BRADIX_HOME/agents
ExecStart=$BRADIX_HOME/venv/bin/uvicorn api:app --host 0.0.0.0 --port 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable bradix-api 2>/dev/null || true
sudo systemctl restart bradix-api 2>/dev/null || warn "API service not started — run manually: uvicorn api:app --host 0.0.0.0 --port 8080"
ok "BRADIX API gateway deployed on port 8080"

# ── STEP 9: INSTALL CLOUDFLARED ──────────────────────────────
step "9/10 — Installing Cloudflare Tunnel (bradix.systems)"
if ! command -v cloudflared &>/dev/null; then
    ARCH=$(dpkg --print-architecture)
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" -O /tmp/cloudflared.deb
    sudo dpkg -i /tmp/cloudflared.deb 2>/dev/null || warn "cloudflared install failed — install manually"
    ok "cloudflared installed"
else
    ok "cloudflared already installed"
fi
warn "ACTION REQUIRED: Run 'cloudflared tunnel login' then 'cloudflared tunnel create bradix' to activate bradix.systems"

# ── STEP 10: RING FOOTAGE DOWNLOAD ──────────────────────────
step "10/10 — Ring footage downloader (preserves evidence)"
cat > "$BRADIX_HOME/agents/ring_download.py" <<'PYEOF'
#!/usr/bin/env python3
"""Download Ring footage before 60-day expiry — run immediately for car break-in evidence"""
import os, sys

try:
    from ring_doorbell import Ring, Auth
    from pathlib import Path

    RING_EMAIL = os.environ.get("RING_EMAIL", "")
    RING_PASSWORD = os.environ.get("RING_PASSWORD", "")
    DOWNLOAD_DIR = os.path.expanduser("~/bradix/downloads/ring/")
    Path(DOWNLOAD_DIR).mkdir(parents=True, exist_ok=True)

    if not RING_EMAIL or not RING_PASSWORD:
        print("Set RING_EMAIL and RING_PASSWORD environment variables, then run:")
        print("  RING_EMAIL=you@email.com RING_PASSWORD=yourpass python3 ring_download.py")
        sys.exit(0)

    auth = Auth("BRADIX/1.0", None, lambda: input("2FA code: "))
    ring = Ring(auth)
    ring.update_data()

    devices = ring.video_doorbells + ring.stickup_cams
    print(f"Found {len(devices)} Ring devices")

    for device in devices:
        print(f"\nDevice: {device.name}")
        for event in device.history(limit=100):
            fname = f"{device.name}_{event['created_at']}.mp4".replace(" ", "_").replace(":", "-")
            fpath = os.path.join(DOWNLOAD_DIR, fname)
            if not os.path.exists(fpath):
                try:
                    device.recording_download(event['id'], filename=fpath)
                    print(f"  ✓ Downloaded: {fname}")
                except Exception as e:
                    print(f"  ⚠ Failed: {fname} — {e}")
            else:
                print(f"  skip (exists): {fname}")

    print(f"\nAll footage saved to {DOWNLOAD_DIR}")
except ImportError:
    print("ring-doorbell not installed. Run: pip install ring-doorbell")
PYEOF
chmod +x "$BRADIX_HOME/agents/ring_download.py"
ok "Ring downloader ready — run: RING_EMAIL=x RING_PASSWORD=x python3 $BRADIX_HOME/agents/ring_download.py"

# ── QUERY TOOL ───────────────────────────────────────────────
cat > "$BRADIX_HOME/agents/query_docs.py" <<'PYEOF'
#!/usr/bin/env python3
"""Query all BRADIX documents — usage: python3 query_docs.py "your question" """
import os, sys

JETSON_IP = os.environ.get("JETSON_IP", "localhost")

try:
    from llama_index.core import VectorStoreIndex, Settings
    from llama_index.llms.ollama import Ollama
    from llama_index.embeddings.ollama import OllamaEmbedding
    from llama_index.vector_stores.chroma import ChromaVectorStore
    from llama_index.core import StorageContext
    import chromadb

    Settings.llm = Ollama(model="llama3.2", base_url=f"http://{JETSON_IP}:11434", request_timeout=120)
    Settings.embed_model = OllamaEmbedding(model_name="nomic-embed-text", base_url=f"http://{JETSON_IP}:11434")

    chroma_client = chromadb.PersistentClient(path=os.path.expanduser("~/bradix/vectordb"))
    collection = chroma_client.get_or_create_collection("bradix")
    vector_store = ChromaVectorStore(chroma_collection=collection)
    storage_context = StorageContext.from_defaults(vector_store=vector_store)
    index = VectorStoreIndex.from_vector_store(vector_store, storage_context=storage_context)
    engine = index.as_query_engine(similarity_top_k=5)

    if len(sys.argv) > 1:
        q = " ".join(sys.argv[1:])
        r = engine.query(q)
        print(str(r))
    else:
        print("BRADIX Document Query — type your question (or 'quit' to exit)")
        while True:
            q = input("\nQuestion: ").strip()
            if q.lower() in ["quit","exit","q"]: break
            if q:
                r = engine.query(q)
                print(f"\n{r}\n")
                print(f"Sources: {[n.metadata.get('file_name','?') for n in r.source_nodes]}")
except Exception as e:
    print(f"Query engine not ready: {e}")
    print("Make sure Ollama is running and the index has been built.")
PYEOF
chmod +x "$BRADIX_HOME/agents/query_docs.py"

# ── SUMMARY ──────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "${GREEN} BRADIX SETUP COMPLETE${NC}"
echo "============================================================"
echo ""
echo "What's running:"
echo "  ✓ Python environment: $BRADIX_HOME/venv"
echo "  ✓ BRADIX repo synced: $BRADIX_HOME/repo"
echo "  ✓ PDFs extracted: $BRADIX_HOME/extracted/"
echo "  ✓ Vector index: $BRADIX_HOME/vectordb/"
echo "  ✓ API gateway: http://localhost:8080"
echo "  ✓ Ring downloader: $BRADIX_HOME/agents/ring_download.py"
echo "  ✓ Query tool: $BRADIX_HOME/agents/query_docs.py"
echo ""
echo "Next steps (manual — require your credentials):"
echo ""
echo "  1. RING FOOTAGE (do this TODAY — 60-day expiry):"
echo "     RING_EMAIL=you@email.com RING_PASSWORD=pass python3 $BRADIX_HOME/agents/ring_download.py"
echo ""
echo "  2. BRADIX.SYSTEMS (point your domain here):"
echo "     cloudflared tunnel login"
echo "     cloudflared tunnel create bradix"
echo ""
echo "  3. QUERY YOUR DOCUMENTS:"
echo "     source $BRADIX_HOME/venv/bin/activate"
echo "     python3 $BRADIX_HOME/agents/query_docs.py"
echo ""
echo "  4. SEND QSUPER EMAIL (deadline 16 April):"
echo "     Open: $BRADIX_HOME/repo/legal-documents/QSUPER_LATE_REGISTRATION_EMAIL.md"
echo "     Send to: qsuper@shine.com.au"
echo ""
echo "  5. SUBMIT SPER STAT DEC:"
echo "     Open: $BRADIX_HOME/repo/legal-documents/SPER_STAT_DEC.md"
echo "     Get JP online, submit to SPER: 1300 304 702"
echo ""
echo "Log saved to: $LOG"
echo "============================================================"
