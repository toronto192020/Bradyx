#!/bin/bash
# ============================================================
#  BRADIX AUTO-ACTION ORCHESTRATOR
#  Runs all BRADIX scripts in the correct order
#  Usage: bash BRADIX_AUTO_ACTION.sh
#  Run from your NUC: wget <raw_github_url> && bash BRADIX_AUTO_ACTION.sh
# ============================================================

set -e
BRADIX_DIR="$HOME/bradix_documents"
LOG="$BRADIX_DIR/auto_action_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$BRADIX_DIR"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }
ok()  { echo "  ✅ $1" | tee -a "$LOG"; }
warn(){ echo "  ⚠️  $1" | tee -a "$LOG"; }
skip(){ echo "  ⏭️  $1 — skipping" | tee -a "$LOG"; }

echo "============================================================" | tee -a "$LOG"
echo "  BRADIX AUTO-ACTION ORCHESTRATOR" | tee -a "$LOG"
echo "  Started: $(date)" | tee -a "$LOG"
echo "============================================================" | tee -a "$LOG"

# ─── STEP 1: SYNC GITHUB REPO ────────────────────────────────
log "STEP 1: Syncing Bradyx GitHub repo..."
REPO_DIR="$HOME/Bradyx"
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR" && git pull 2>&1 | tail -2 | tee -a "$LOG"
    ok "Repo updated"
else
    git clone https://github.com/toronto192020/Bradyx.git "$REPO_DIR" 2>&1 | tail -3 | tee -a "$LOG"
    ok "Repo cloned"
fi
cp "$REPO_DIR"/*.py "$BRADIX_DIR/" 2>/dev/null || true
cp "$REPO_DIR"/*.sh "$BRADIX_DIR/" 2>/dev/null || true

# ─── STEP 2: INSTALL DEPENDENCIES ───────────────────────────
log "STEP 2: Installing Python dependencies..."
pip3 install -q obd openai pymupdf pdfplumber requests chromadb llama-index 2>&1 | tail -3 | tee -a "$LOG"
ok "Dependencies installed"

# ─── STEP 3: CLONE ALL DEPENDENCY REPOS ─────────────────────
log "STEP 3: Cloning dependency repos..."
if [ -f "$BRADIX_DIR/clone_repos.sh" ]; then
    bash "$BRADIX_DIR/clone_repos.sh" 2>&1 | tail -10 | tee -a "$LOG"
    ok "Repos cloned"
else
    warn "clone_repos.sh not found — run BRADIX_RUN_ALL.sh first"
fi

# ─── STEP 4: PDF EXTRACTION ──────────────────────────────────
log "STEP 4: Extracting text from all PDFs..."
PDFS_DIR="$HOME/bradix_pdfs"
INDEX_DIR="$BRADIX_DIR/vector_index"
mkdir -p "$INDEX_DIR"

PDF_COUNT=$(find "$PDFS_DIR" "$BRADIX_DIR" -name "*.pdf" 2>/dev/null | wc -l)
if [ "$PDF_COUNT" -gt 0 ]; then
    python3 - <<'PYEOF' 2>&1 | tail -5 | tee -a "$LOG"
import os, glob
try:
    import pdfplumber
    pdf_dirs = [os.path.expanduser("~/bradix_pdfs"), os.path.expanduser("~/bradix_documents")]
    extracted = []
    for d in pdf_dirs:
        for pdf in glob.glob(f"{d}/*.pdf"):
            try:
                with pdfplumber.open(pdf) as p:
                    text = "\n".join(page.extract_text() or "" for page in p.pages)
                    out = pdf.replace(".pdf", "_extracted.txt")
                    with open(out, "w") as f:
                        f.write(text)
                    extracted.append(os.path.basename(pdf))
            except Exception as e:
                print(f"  Skip {pdf}: {e}")
    print(f"Extracted {len(extracted)} PDFs: {', '.join(extracted[:5])}")
except ImportError:
    print("pdfplumber not available — install with: pip3 install pdfplumber")
PYEOF
    ok "PDF extraction complete"
else
    skip "No PDFs found in $PDFS_DIR"
fi

# ─── STEP 5: BUILD VECTOR INDEX ──────────────────────────────
log "STEP 5: Building searchable vector index..."
python3 - <<'PYEOF' 2>&1 | tail -5 | tee -a "$LOG"
import os, glob
index_dir = os.path.expanduser("~/bradix_documents/vector_index")
os.makedirs(index_dir, exist_ok=True)
try:
    from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, StorageContext
    from llama_index.core import load_index_from_storage
    docs_dir = os.path.expanduser("~/bradix_documents")
    if os.path.exists(os.path.join(index_dir, "docstore.json")):
        print("Index already exists — loading existing index")
    else:
        reader = SimpleDirectoryReader(docs_dir, required_exts=[".txt", ".md"])
        docs = reader.load_data()
        index = VectorStoreIndex.from_documents(docs)
        index.storage_context.persist(persist_dir=index_dir)
        print(f"Index built from {len(docs)} documents")
except ImportError:
    # Fallback: simple keyword index
    import json
    docs = {}
    for f in glob.glob(os.path.expanduser("~/bradix_documents/*.md")) + \
             glob.glob(os.path.expanduser("~/bradix_documents/*.txt")):
        with open(f) as fh:
            docs[os.path.basename(f)] = fh.read()[:500]
    with open(os.path.join(index_dir, "simple_index.json"), "w") as fh:
        json.dump(docs, fh, indent=2)
    print(f"Simple index built from {len(docs)} files (llama_index not available)")
PYEOF
ok "Vector index ready"

# ─── STEP 6: OBD SCAN (if AIOBD connected) ───────────────────
log "STEP 6: OBD vehicle scan..."
if python3 -c "import obd" 2>/dev/null; then
    if ls /dev/rfcomm* 2>/dev/null | grep -q rfcomm; then
        log "  AIOBD detected — running scan..."
        python3 "$BRADIX_DIR/OBD_AUTO_SOLVE.py" 2>&1 | tail -20 | tee -a "$LOG"
        ok "OBD scan complete"
    else
        skip "AIOBD not connected (/dev/rfcomm0 not found)"
        log "  To connect: bluetoothctl -> pair AIOBD -> rfcomm bind /dev/rfcomm0 <MAC>"
    fi
else
    skip "obd library not installed — run: pip3 install obd"
fi

# ─── STEP 7: CLOUD INGESTION CHECK ───────────────────────────
log "STEP 7: Cloud ingestion status check..."

# Ring footage check
if python3 -c "import ring_doorbell" 2>/dev/null; then
    if [ -n "$RING_EMAIL" ] && [ -n "$RING_PASSWORD" ]; then
        log "  Ring credentials found — downloading footage..."
        python3 - <<'PYEOF' 2>&1 | tail -5 | tee -a "$LOG"
import ring_doorbell, json, os
auth = ring_doorbell.Auth("BRADIX/1.0", None, lambda: input("2FA Code: "))
try:
    auth.fetch_token(os.environ["RING_EMAIL"], os.environ["RING_PASSWORD"])
    ring = ring_doorbell.Ring(auth)
    ring.update_data()
    for device in ring.video_doorbells + ring.stickup_cams:
        print(f"  Device: {device.name}")
        for event in device.history(limit=5):
            print(f"    {event['created_at']} — {event['kind']}")
    print("Ring check complete")
except Exception as e:
    print(f"Ring error: {e}")
PYEOF
        ok "Ring check complete"
    else
        skip "Ring credentials not set (export RING_EMAIL=x RING_PASSWORD=x)"
    fi
else
    skip "ring_doorbell not installed — run: pip3 install ring_doorbell"
fi

# iCloud check
if command -v icloudpd &>/dev/null; then
    if [ -n "$ICLOUD_EMAIL" ]; then
        log "  iCloud sync available — run manually: icloudpd --directory ~/icloud_photos --username $ICLOUD_EMAIL"
    else
        skip "ICLOUD_EMAIL not set"
    fi
else
    skip "icloudpd not installed — run: pip3 install icloudpd"
fi

# ─── STEP 8: GENERATE STATUS REPORT ─────────────────────────
log "STEP 8: Generating BRADIX status report..."
python3 - <<'PYEOF' 2>&1 | tee -a "$LOG"
import os, glob, json
from datetime import datetime

docs = glob.glob(os.path.expanduser("~/bradix_documents/*.md"))
pdfs = glob.glob(os.path.expanduser("~/bradix_pdfs/*.pdf"))
reports = glob.glob(os.path.expanduser("~/bradix_documents/OBD_REPORT_*.md"))
index_exists = os.path.exists(os.path.expanduser("~/bradix_documents/vector_index"))

report = f"""# BRADIX SYSTEM STATUS
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}

## Documents
- Markdown files: {len(docs)}
- PDFs: {len(pdfs)}
- OBD Reports: {len(reports)}
- Vector index: {'✅ Built' if index_exists else '❌ Not built'}

## Key Files
"""
for f in sorted(docs)[-10:]:
    size = os.path.getsize(f)
    report += f"- {os.path.basename(f)} ({size} bytes)\n"

report += """
## Next Actions
1. Run OBD scan: python3 ~/bradix_documents/OBD_AUTO_SOLVE.py
2. Query documents: python3 ~/bradix_documents/query_docs.py "your question"
3. Sync GitHub: cd ~/Bradyx && git pull
4. Check deadlines: cat ~/bradix_documents/BRADIX_R1_CONTEXT.txt

*BRADIX Auto-Action Orchestrator*
"""

out = os.path.expanduser(f"~/bradix_documents/STATUS_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md")
with open(out, "w") as f:
    f.write(report)
print(report)
print(f"Status saved to: {out}")
PYEOF
ok "Status report generated"

# ─── STEP 9: PUSH EVERYTHING TO GITHUB ───────────────────────
log "STEP 9: Pushing all new files to GitHub..."
cd "$REPO_DIR"
git add -A
CHANGED=$(git status --porcelain | wc -l)
if [ "$CHANGED" -gt 0 ]; then
    git commit -m "BRADIX auto-action sync $(date '+%Y-%m-%d %H:%M')" 2>&1 | tail -2 | tee -a "$LOG"
    git push 2>&1 | tail -3 | tee -a "$LOG"
    ok "Pushed $CHANGED changed files to GitHub"
else
    ok "GitHub already up to date"
fi

# ─── DONE ────────────────────────────────────────────────────
echo "" | tee -a "$LOG"
echo "============================================================" | tee -a "$LOG"
echo "  ✅ BRADIX AUTO-ACTION COMPLETE" | tee -a "$LOG"
echo "  Log: $LOG" | tee -a "$LOG"
echo "============================================================" | tee -a "$LOG"
echo ""
echo "NEXT STEPS:"
echo "  Query your docs:  python3 $BRADIX_DIR/query_docs.py 'What are my SPER fines?'"
echo "  OBD scan:         python3 $BRADIX_DIR/OBD_AUTO_SOLVE.py"
echo "  View status:      cat $BRADIX_DIR/STATUS_*.md | tail -30"
