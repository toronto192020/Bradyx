#!/usr/bin/env bash
# ============================================================
# BRADIX STATUS DASHBOARD
# ============================================================
# Run anytime to see the full system status at a glance.
#
#   bradix-status
#
# Or:
#   bash /opt/bradix/one-click-install/scripts/bradix-status.sh
# ============================================================

set -uo pipefail

# ─── CONSTANTS ──────────────────────────────────────────────
BRADIX_DIR="/opt/bradix"
ENV_FILE="${BRADIX_DIR}/one-click-install/docker/.env"
CASE_DATA_DIR="${BRADIX_DIR}/case-data"
LOG_DIR="/var/log/bradix"
NAS_MOUNT="/mnt/nas-backup"
BACKUP_DIR="${BRADIX_DIR}/backups"

# ─── COLOURS ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

OK="${GREEN}●${NC}"
WARN="${YELLOW}●${NC}"
FAIL="${RED}●${NC}"
UNKNOWN="${DIM}●${NC}"

# ─── HELPER FUNCTIONS ──────────────────────────────────────
check_http() {
    local url="$1"
    local timeout="${2:-5}"
    curl -sf --max-time "$timeout" "$url" &>/dev/null
}

get_container_status() {
    local name="$1"
    local status
    status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "not_found")
    echo "$status"
}

# ─── LOAD ENV ──────────────────────────────────────────────
JETSON_ENDPOINT="http://jetson.local:8000"
if [ -f "$ENV_FILE" ]; then
    JETSON_ENDPOINT=$(grep "^JETSON_ENDPOINT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "http://jetson.local:8000")
fi

# ============================================================
echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║              BRADIX SYSTEM STATUS DASHBOARD               ║${NC}"
echo -e "${CYAN}${BOLD}║                  The Quiet Guardian                       ║${NC}"
echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║${NC}  $(date '+%A, %d %B %Y  %H:%M %Z')                       ${CYAN}${BOLD}║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── NUC STACK STATUS ──────────────────────────────────────
echo -e "${BOLD}  NUC DOCKER STACK${NC}"
echo -e "  ─────────────────────────────────────────────"

# n8n
N8N_STATUS=$(get_container_status "bradix-n8n")
if [ "$N8N_STATUS" = "running" ] && check_http "http://localhost:5678/healthz"; then
    echo -e "  $OK n8n Orchestration     ${GREEN}HEALTHY${NC}    (port 5678)"
elif [ "$N8N_STATUS" = "running" ]; then
    echo -e "  $WARN n8n Orchestration     ${YELLOW}STARTING${NC}   (port 5678)"
else
    echo -e "  $FAIL n8n Orchestration     ${RED}DOWN${NC}       (container: $N8N_STATUS)"
fi

# PostgreSQL
PG_STATUS=$(get_container_status "bradix-postgres")
if [ "$PG_STATUS" = "running" ] && docker exec bradix-postgres pg_isready -U bradix &>/dev/null; then
    echo -e "  $OK PostgreSQL Database   ${GREEN}HEALTHY${NC}"
elif [ "$PG_STATUS" = "running" ]; then
    echo -e "  $WARN PostgreSQL Database   ${YELLOW}STARTING${NC}"
else
    echo -e "  $FAIL PostgreSQL Database   ${RED}DOWN${NC}       (container: $PG_STATUS)"
fi

# Monitor
MON_STATUS=$(get_container_status "bradix-monitor")
if [ "$MON_STATUS" = "running" ]; then
    echo -e "  $OK Monitoring Watchdog   ${GREEN}RUNNING${NC}"
elif [ "$MON_STATUS" = "not_found" ]; then
    echo -e "  $UNKNOWN Monitoring Watchdog   ${DIM}NOT DEPLOYED${NC}"
else
    echo -e "  $WARN Monitoring Watchdog   ${YELLOW}$MON_STATUS${NC}"
fi

# Watchtower
WT_STATUS=$(get_container_status "bradix-watchtower")
if [ "$WT_STATUS" = "running" ]; then
    echo -e "  $OK Auto-Updater          ${GREEN}RUNNING${NC}    (Watchtower)"
elif [ "$WT_STATUS" = "not_found" ]; then
    echo -e "  $UNKNOWN Auto-Updater          ${DIM}NOT DEPLOYED${NC}"
else
    echo -e "  $WARN Auto-Updater          ${YELLOW}$WT_STATUS${NC}"
fi

echo ""

# ─── JETSON CONNECTION STATUS ──────────────────────────────
echo -e "${BOLD}  JETSON AI INFERENCE${NC}"
echo -e "  ─────────────────────────────────────────────"

if check_http "${JETSON_ENDPOINT}/health" 5; then
    HEALTH=$(curl -sf --max-time 5 "${JETSON_ENDPOINT}/health" 2>/dev/null)
    OLLAMA_STATUS=$(echo "$HEALTH" | jq -r '.ollama // "unknown"' 2>/dev/null || echo "unknown")
    MODEL=$(echo "$HEALTH" | jq -r '.default_model // "unknown"' 2>/dev/null || echo "unknown")
    MODELS=$(echo "$HEALTH" | jq -r '.models // [] | join(", ")' 2>/dev/null || echo "")

    echo -e "  $OK Inference Server      ${GREEN}HEALTHY${NC}    ($JETSON_ENDPOINT)"
    echo -e "  $OK Ollama                ${GREEN}${OLLAMA_STATUS}${NC}"
    echo -e "     Default Model:         ${CYAN}${MODEL}${NC}"
    if [ -n "$MODELS" ]; then
        echo -e "     Available Models:      ${DIM}${MODELS}${NC}"
    fi
else
    echo -e "  $FAIL Inference Server      ${RED}UNREACHABLE${NC}"
    echo -e "     Endpoint: ${DIM}${JETSON_ENDPOINT}${NC}"

    # Check if discovery timer is running
    if systemctl is-active --quiet bradix-discover-jetson.timer 2>/dev/null; then
        echo -e "  $WARN Auto-Discovery        ${YELLOW}SEARCHING${NC}  (every 5 min)"
    else
        echo -e "     ${DIM}Run: sudo systemctl start bradix-discover-jetson.timer${NC}"
    fi
fi

echo ""

# ─── NAS BACKUP STATUS ────────────────────────────────────
echo -e "${BOLD}  NAS BACKUP${NC}"
echo -e "  ─────────────────────────────────────────────"

if mountpoint -q "$NAS_MOUNT" 2>/dev/null; then
    NAS_SIZE=$(df -h "$NAS_MOUNT" 2>/dev/null | tail -1 | awk '{print $2}')
    NAS_USED=$(df -h "$NAS_MOUNT" 2>/dev/null | tail -1 | awk '{print $5}')
    NAS_BACKUPS=$(ls -1 "${NAS_MOUNT}/bradix-backups/" 2>/dev/null | wc -l)
    echo -e "  $OK NAS Mount              ${GREEN}MOUNTED${NC}    ($NAS_MOUNT)"
    echo -e "     Capacity:              ${NAS_SIZE} (${NAS_USED} used)"
    echo -e "     Backups on NAS:        ${NAS_BACKUPS} files"
else
    echo -e "  $FAIL NAS Mount              ${RED}NOT MOUNTED${NC}"
    echo -e "     ${DIM}Check NAS power and network connection${NC}"
fi

# Local backups
if [ -d "$BACKUP_DIR" ]; then
    LOCAL_BACKUPS=$(ls -1 "${BACKUP_DIR}/" 2>/dev/null | wc -l)
    LATEST_BACKUP=$(ls -1t "${BACKUP_DIR}/" 2>/dev/null | head -1)
    echo -e "  $OK Local Backups          ${GREEN}${LOCAL_BACKUPS} files${NC}"
    if [ -n "$LATEST_BACKUP" ]; then
        echo -e "     Latest:                ${DIM}${LATEST_BACKUP}${NC}"
    fi
else
    echo -e "  $WARN Local Backups          ${YELLOW}NO BACKUPS YET${NC}"
fi

# Last backup log
if [ -f "${LOG_DIR}/backup.log" ]; then
    LAST_BACKUP_LOG=$(tail -1 "${LOG_DIR}/backup.log" 2>/dev/null || echo "")
    if [ -n "$LAST_BACKUP_LOG" ]; then
        echo -e "     Last Run:              ${DIM}${LAST_BACKUP_LOG}${NC}"
    fi
fi

echo ""

# ─── TAILSCALE NETWORK STATUS ─────────────────────────────
echo -e "${BOLD}  TAILSCALE NETWORK${NC}"
echo -e "  ─────────────────────────────────────────────"

if command -v tailscale &>/dev/null; then
    TS_STATUS=$(tailscale status --json 2>/dev/null)
    if [ -n "$TS_STATUS" ]; then
        TS_SELF_IP=$(echo "$TS_STATUS" | jq -r '.Self.TailscaleIPs[0] // "unknown"' 2>/dev/null || echo "unknown")
        TS_SELF_NAME=$(echo "$TS_STATUS" | jq -r '.Self.HostName // "unknown"' 2>/dev/null || echo "unknown")
        TS_ONLINE=$(echo "$TS_STATUS" | jq -r '.Self.Online // false' 2>/dev/null || echo "false")

        if [ "$TS_ONLINE" = "true" ]; then
            echo -e "  $OK This Device            ${GREEN}ONLINE${NC}"
        else
            echo -e "  $WARN This Device            ${YELLOW}OFFLINE${NC}"
        fi
        echo -e "     Hostname:              ${CYAN}${TS_SELF_NAME}${NC}"
        echo -e "     Tailscale IP:          ${CYAN}${TS_SELF_IP}${NC}"
        echo -e "     n8n via Phone:         ${BLUE}http://${TS_SELF_IP}:5678${NC}"

        # Show other Bradix devices on Tailscale
        PEERS=$(echo "$TS_STATUS" | jq -r '.Peer | to_entries[] | select(.value.HostName | test("bradix|jetson"; "i")) | "\(.value.HostName): \(.value.TailscaleIPs[0]) (\(if .value.Online then "online" else "offline" end))"' 2>/dev/null || echo "")
        if [ -n "$PEERS" ]; then
            echo -e "     Peers:"
            echo "$PEERS" | while read -r peer; do
                echo -e "       ${DIM}${peer}${NC}"
            done
        fi
    else
        echo -e "  $WARN Tailscale              ${YELLOW}NOT AUTHENTICATED${NC}"
        echo -e "     ${DIM}Run: sudo tailscale up${NC}"
    fi
else
    echo -e "  $FAIL Tailscale              ${RED}NOT INSTALLED${NC}"
fi

echo ""

# ─── TASKS DUE SOON ───────────────────────────────────────
echo -e "${BOLD}  TASKS & DEADLINES${NC}"
echo -e "  ─────────────────────────────────────────────"

TASK_FILE="${CASE_DATA_DIR}/cheryl-bruce-sanders/agent_task_tracker.json"
if [ -f "$TASK_FILE" ]; then
    TOTAL=$(jq 'length' "$TASK_FILE" 2>/dev/null || echo "?")
    DONE=$(jq '[.[] | select(.status == "done")] | length' "$TASK_FILE" 2>/dev/null || echo "0")
    PENDING=$(jq '[.[] | select(.status == "pending")] | length' "$TASK_FILE" 2>/dev/null || echo "0")
    URGENT=$(jq '[.[] | select(.deadline_category == "48hrs" and .status != "done")] | length' "$TASK_FILE" 2>/dev/null || echo "0")
    THIS_WEEK=$(jq '[.[] | select(.deadline_category == "this_week" and .status != "done")] | length' "$TASK_FILE" 2>/dev/null || echo "0")
    THIS_MONTH=$(jq '[.[] | select(.deadline_category == "this_month" and .status != "done")] | length' "$TASK_FILE" 2>/dev/null || echo "0")

    echo -e "     Total Tasks:           ${BOLD}${TOTAL}${NC}"
    echo -e "     Completed:             ${GREEN}${DONE}${NC}"
    echo -e "     Pending:               ${YELLOW}${PENDING}${NC}"
    echo ""

    if [ "$URGENT" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  !! ${URGENT} URGENT (48h) task(s) !!${NC}"
        jq -r '.[] | select(.deadline_category == "48hrs" and .status != "done") | "     → [\(.task_id)] \(.description)"' "$TASK_FILE" 2>/dev/null
        echo ""
    fi

    if [ "$THIS_WEEK" -gt 0 ]; then
        echo -e "  $WARN ${THIS_WEEK} task(s) due this week:"
        jq -r '.[] | select(.deadline_category == "this_week" and .status != "done") | "     → [\(.task_id)] \(.description)"' "$TASK_FILE" 2>/dev/null
        echo ""
    fi

    if [ "$THIS_MONTH" -gt 0 ]; then
        echo -e "     ${DIM}${THIS_MONTH} task(s) due this month${NC}"
    fi
else
    echo -e "  $FAIL Task data not found at ${TASK_FILE}"
fi

echo ""

# ─── LAST ALERT SENT ──────────────────────────────────────
echo -e "${BOLD}  RECENT ACTIVITY${NC}"
echo -e "  ─────────────────────────────────────────────"

# Check n8n execution history
if check_http "http://localhost:5678/healthz"; then
    N8N_PASS=$(grep "^N8N_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "")
    if [ -n "$N8N_PASS" ]; then
        LAST_EXEC=$(curl -sf -u "andrew:${N8N_PASS}" "http://localhost:5678/api/v1/executions?limit=3" 2>/dev/null)
        if [ -n "$LAST_EXEC" ]; then
            EXEC_COUNT=$(echo "$LAST_EXEC" | jq '.data | length' 2>/dev/null || echo "0")
            if [ "$EXEC_COUNT" -gt 0 ]; then
                echo -e "     Last workflow executions:"
                echo "$LAST_EXEC" | jq -r '.data[:3][] | "       \(.startedAt // "?") — \(.workflowData.name // "unknown") (\(.status // "?"))"' 2>/dev/null || echo "       (could not parse)"
            else
                echo -e "     ${DIM}No workflow executions yet${NC}"
            fi
        fi
    fi
fi

# Last alert cooldown file
if [ -f "${LOG_DIR}/last_alert.json" ]; then
    echo -e "     Last alerts:"
    jq -r 'to_entries[] | "       \(.key): \(.value)"' "${LOG_DIR}/last_alert.json" 2>/dev/null || echo "       (no data)"
fi

# Last sync
if [ -f "${LOG_DIR}/last_sync.txt" ]; then
    LAST_SYNC=$(cat "${LOG_DIR}/last_sync.txt" 2>/dev/null)
    echo -e "     Last GitHub Sync:      ${DIM}${LAST_SYNC}${NC}"
fi

echo ""

# ─── SYSTEM HEALTH ─────────────────────────────────────────
echo -e "${BOLD}  SYSTEM HEALTH${NC}"
echo -e "  ─────────────────────────────────────────────"

# CPU and Memory
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "?")
MEM_TOTAL=$(free -h | awk '/^Mem:/{print $2}' 2>/dev/null || echo "?")
MEM_USED=$(free -h | awk '/^Mem:/{print $3}' 2>/dev/null || echo "?")
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' 2>/dev/null || echo "?")
UPTIME=$(uptime -p 2>/dev/null || echo "unknown")

echo -e "     CPU Usage:             ${CPU_USAGE}%"
echo -e "     Memory:                ${MEM_USED} / ${MEM_TOTAL}"
echo -e "     Disk Usage:            ${DISK_USAGE}"
echo -e "     Uptime:                ${UPTIME}"

# Docker disk usage
DOCKER_SIZE=$(docker system df 2>/dev/null | grep "Images" | awk '{print $4}' || echo "?")
echo -e "     Docker Images:         ${DOCKER_SIZE}"

echo ""
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  The Quiet Guardian is ${GREEN}active${NC}${BOLD}. The system is watching.${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
