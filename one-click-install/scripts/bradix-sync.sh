#!/usr/bin/env bash
# ============================================================
# Bradix GitHub Sync
# ============================================================
# Pulls latest case data from GitHub every hour via cron.
# Updates local case data files used by n8n and Jetson.
# ============================================================

set -euo pipefail

BRADIX_DIR="/opt/bradix"
REPO_DIR="${BRADIX_DIR}/repo"
CASE_DATA_DIR="${BRADIX_DIR}/case-data"
LOG_FILE="/var/log/bradix/sync.log"

mkdir -p "$(dirname "$LOG_FILE")" "${CASE_DATA_DIR}/cheryl-bruce-sanders"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# Pull latest from GitHub
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR"
    git fetch origin main --quiet 2>/dev/null || { log "Warning: git fetch failed"; exit 0; }
    git reset --hard origin/main --quiet 2>/dev/null || { log "Warning: git reset failed"; exit 0; }
    log "Git pull complete"
else
    log "Warning: repo not found at $REPO_DIR"
    exit 0
fi

# Copy updated case data files
UPDATED=0
for f in case_data.json agent_task_tracker.json entity_registry.json monitoring_alerts.yaml cheryl_case_summary_raw.md; do
    found=$(find "$REPO_DIR" -name "$f" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        cp "$found" "${CASE_DATA_DIR}/cheryl-bruce-sanders/"
        UPDATED=$((UPDATED + 1))
    fi
done

# Record sync timestamp
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /var/log/bradix/last_sync.txt

log "Sync complete: ${UPDATED} files updated"
