#!/usr/bin/env bash
# ============================================================
# Bradix Daily Backup
# ============================================================
# Runs via cron at 2am Brisbane time.
# Backs up case data, n8n database, workflows, and configs.
# Copies to NAS if mounted. Rotates after 30 days.
# ============================================================

set -euo pipefail

BRADIX_DIR="/opt/bradix"
BACKUP_DIR="/opt/bradix/backups"
NAS_MOUNT="/mnt/nas-backup"
CASE_DATA_DIR="/opt/bradix/case-data"
ENV_FILE="${BRADIX_DIR}/one-click-install/docker/.env"
DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_NAME="bradix-backup-${DATE}"
KEEP_DAYS=30
LOG_FILE="/var/log/bradix/backup.log"

mkdir -p "${BACKUP_DIR}" "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

log "Starting backup: ${BACKUP_NAME}"

# 1. Archive case data and configs
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    -C / \
    opt/bradix/case-data \
    opt/bradix/one-click-install/docker/.env \
    opt/bradix/one-click-install/workflows \
    opt/bradix/one-click-install/monitoring \
    2>/dev/null || log "Warning: tar archive had issues"

# 2. Backup PostgreSQL database
if docker exec bradix-postgres pg_isready -U bradix &>/dev/null; then
    docker exec bradix-postgres pg_dump -U bradix n8n 2>/dev/null | \
        gzip > "${BACKUP_DIR}/${BACKUP_NAME}-db.sql.gz" || \
        log "Warning: PostgreSQL backup failed"
    log "PostgreSQL backup complete"
else
    log "Warning: PostgreSQL not reachable, skipping DB backup"
fi

# 3. Export n8n workflows via API
N8N_PASS=$(grep "^N8N_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "")
if [ -n "$N8N_PASS" ]; then
    curl -sf -u "andrew:${N8N_PASS}" http://localhost:5678/api/v1/workflows 2>/dev/null | \
        gzip > "${BACKUP_DIR}/${BACKUP_NAME}-workflows.json.gz" || \
        log "Warning: n8n workflow export failed"
    log "n8n workflow export complete"
fi

# 4. Copy to NAS if mounted
if mountpoint -q "$NAS_MOUNT" 2>/dev/null; then
    NAS_BACKUP_DIR="${NAS_MOUNT}/bradix-backups"
    mkdir -p "$NAS_BACKUP_DIR" 2>/dev/null || true

    for f in "${BACKUP_DIR}/${BACKUP_NAME}"*; do
        cp "$f" "$NAS_BACKUP_DIR/" 2>/dev/null || log "Warning: failed to copy $(basename "$f") to NAS"
    done
    log "Backup copied to NAS"

    # Rotate NAS backups
    find "$NAS_BACKUP_DIR" -name "bradix-backup-*" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
else
    log "NAS not mounted — backup stored locally only"
fi

# 5. Rotate local backups
find "${BACKUP_DIR}" -name "bradix-backup-*" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true

# 6. Calculate backup size
BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}"* 2>/dev/null | awk '{total+=$1} END {print total"M"}' || echo "?")
TOTAL_BACKUPS=$(ls -1 "${BACKUP_DIR}/" 2>/dev/null | wc -l)

log "Backup complete: ${BACKUP_NAME} (${TOTAL_BACKUPS} total backups)"
