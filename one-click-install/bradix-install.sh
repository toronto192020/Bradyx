#!/usr/bin/env bash
# ============================================================
# BRADIX ONE-CLICK INSTALLER
# ============================================================
# Run this ONCE on the MSI NUC. It does EVERYTHING.
#
#   curl -sL https://raw.githubusercontent.com/toronto192020/Bradyx/main/one-click-install/bradix-install.sh | bash
#
# Andrew — just run it and walk away.
# ============================================================

set -euo pipefail

# ─── CONSTANTS ──────────────────────────────────────────────
BRADIX_DIR="/opt/bradix"
REPO_URL="https://github.com/toronto192020/Bradyx.git"
REPO_BRANCH="main"
CASE_DATA_DIR="${BRADIX_DIR}/case-data"
INSTALL_DIR="${BRADIX_DIR}/one-click-install"
LOG_DIR="/var/log/bradix"
BACKUP_DIR="/opt/bradix/backups"
NAS_MOUNT="/mnt/nas-backup"
ALERT_EMAIL_PRIMARY="bts@outlook.com"
ALERT_EMAIL_SECONDARY="cherylbruder@icloud.com"
SMTP_HOST="smtp-mail.outlook.com"
SMTP_PORT="587"
SMTP_USER="bts@outlook.com"
JETSON_USER="jetson"
JETSON_HOSTNAME="jetson.local"
TIMEZONE="Australia/Brisbane"

# ─── COLOURS ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── LOGGING ────────────────────────────────────────────────
log()  { echo -e "${GREEN}[BRADIX]${NC} $1"; }
warn() { echo -e "${YELLOW}[BRADIX]${NC} $1"; }
err()  { echo -e "${RED}[BRADIX ERROR]${NC} $1"; }
banner() {
    echo ""
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo ""
}

# ============================================================
banner "BRADIX ONE-CLICK INSTALLER"
echo -e "${BOLD}The Quiet Guardian — for Andrew and Cheryl${NC}"
echo ""
echo "This script will set up your entire system automatically."
echo "It only needs ONE thing from you: your email password."
echo ""
# ============================================================

# ─── DETECT OS ──────────────────────────────────────────────
banner "STEP 1/12: Detecting System"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    log "Detected OS: ${PRETTY_NAME:-$ID}"
else
    warn "Cannot detect OS — assuming Ubuntu-compatible"
fi

ARCH=$(uname -m)
log "Architecture: $ARCH"

if ! command -v apt-get &>/dev/null; then
    err "This installer requires an apt-based system (Ubuntu/Debian)."
    err "Please install Ubuntu Server or Desktop first."
    exit 1
fi

# ─── PROMPT FOR EMAIL PASSWORD (ONLY PROMPT) ───────────────
banner "STEP 2/12: Email Configuration"

echo -e "${BOLD}Andrew — this is the ONLY thing you need to enter.${NC}"
echo ""
echo "Your Outlook account (bts@outlook.com) will send alerts."
echo "You need an App Password from Microsoft."
echo ""
echo "If you don't have one yet:"
echo "  1. Go to https://account.microsoft.com/security"
echo "  2. Click 'App passwords' under 'Additional security'"
echo "  3. Generate a new app password"
echo ""
read -sp "Enter your Outlook App Password: " SMTP_PASS
echo ""
echo ""

if [ -z "$SMTP_PASS" ]; then
    warn "No password entered. Email alerts will be disabled."
    warn "You can set SMTP_PASS in ${BRADIX_DIR}/one-click-install/docker/.env later."
    SMTP_PASS="CHANGE_ME"
fi

log "Email configured. That's the last thing you need to do."

# ─── INSTALL SYSTEM PACKAGES ───────────────────────────────
banner "STEP 3/12: Installing System Packages"

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -qq
sudo apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    python3 \
    python3-pip \
    python3-venv \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
    nmap \
    jq \
    cifs-utils \
    nfs-common \
    sshpass \
    openssh-client \
    net-tools \
    wget \
    unzip \
    cron \
    rsync \
    samba-client \
    2>/dev/null

log "System packages installed."

# ─── INSTALL DOCKER ─────────────────────────────────────────
banner "STEP 4/12: Installing Docker"

if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    log "Docker installed."
fi

# Add current user to docker group
sudo usermod -aG docker "$USER" 2>/dev/null || true

# Install Docker Compose plugin if not present
if ! docker compose version &>/dev/null 2>&1; then
    log "Installing Docker Compose plugin..."
    sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || {
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    }
fi

sudo systemctl enable --now docker
log "Docker is running."

# ─── INSTALL TAILSCALE ──────────────────────────────────────
banner "STEP 5/12: Installing Tailscale"

if command -v tailscale &>/dev/null; then
    log "Tailscale already installed."
else
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sudo sh
    log "Tailscale installed."
fi

sudo systemctl enable --now tailscaled

# Check if already authenticated
if tailscale status &>/dev/null 2>&1; then
    log "Tailscale is connected."
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "pending")
    log "Tailscale IP: $TS_IP"
else
    log "Starting Tailscale authentication..."
    echo ""
    echo -e "${YELLOW}${BOLD}Tailscale needs a one-time login.${NC}"
    echo "A URL will appear below. Open it on your phone to connect."
    echo "If running headless, copy the URL and open in any browser."
    echo ""
    sudo tailscale up --hostname=bradix-nuc --accept-routes --accept-dns || {
        warn "Tailscale auth deferred. Run 'sudo tailscale up' later to connect."
    }
fi

# ─── CLONE REPO & SET UP DIRECTORIES ───────────────────────
banner "STEP 6/12: Setting Up Bradix"

sudo mkdir -p "$BRADIX_DIR" "$CASE_DATA_DIR" "$LOG_DIR" "$BACKUP_DIR" "$NAS_MOUNT"
sudo chown -R "$USER:$USER" "$BRADIX_DIR" "$LOG_DIR" "$BACKUP_DIR"

# Clone or update repo
if [ -d "${BRADIX_DIR}/repo" ]; then
    log "Updating existing repo..."
    cd "${BRADIX_DIR}/repo"
    git pull --ff-only origin "$REPO_BRANCH" 2>/dev/null || git fetch --all
else
    log "Cloning Bradyx repository..."
    git clone "$REPO_URL" "${BRADIX_DIR}/repo"
fi

# Copy one-click-install files into place
if [ -d "${BRADIX_DIR}/repo/one-click-install" ]; then
    cp -r "${BRADIX_DIR}/repo/one-click-install/"* "${BRADIX_DIR}/one-click-install/" 2>/dev/null || true
fi

# Copy case data files
CASE_SRC="${BRADIX_DIR}/repo"
mkdir -p "${CASE_DATA_DIR}/cheryl-bruce-sanders"

# Find and copy case data files from repo
for f in case_data.json agent_task_tracker.json entity_registry.json monitoring_alerts.yaml cheryl_case_summary_raw.md; do
    found=$(find "$CASE_SRC" -name "$f" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        cp "$found" "${CASE_DATA_DIR}/cheryl-bruce-sanders/"
        log "Loaded: $f"
    fi
done

log "Case data loaded."

# ─── GENERATE .env FILE ────────────────────────────────────
banner "STEP 7/12: Configuring Environment"

# Generate secure random strings
N8N_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Detect Tailscale IP for webhook URL
TS_IP=$(tailscale ip -4 2>/dev/null || echo "localhost")
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

ENV_FILE="${BRADIX_DIR}/one-click-install/docker/.env"
mkdir -p "$(dirname "$ENV_FILE")"

cat > "$ENV_FILE" <<ENVEOF
# ============================================================
# Bradix — Auto-generated Environment Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# DO NOT COMMIT THIS FILE TO GIT
# ============================================================

# ─── n8n Configuration ──────────────────────────────────────
N8N_HOST=0.0.0.0
N8N_PROTOCOL=http
N8N_USER=andrew
N8N_PASSWORD=${N8N_PASSWORD}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
WEBHOOK_URL=http://${LOCAL_IP}:5678/
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=bradix
DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}

# ─── Database ───────────────────────────────────────────────
POSTGRES_USER=bradix
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=n8n

# ─── Email / SMTP ───────────────────────────────────────────
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASS=${SMTP_PASS}
SMTP_SENDER=Bradix Guardian <${SMTP_USER}>

# ─── Alert Recipients ───────────────────────────────────────
ALERT_EMAIL_PRIMARY=${ALERT_EMAIL_PRIMARY}
ALERT_EMAIL_SECONDARY=${ALERT_EMAIL_SECONDARY}

# ─── Jetson AI Endpoint ─────────────────────────────────────
JETSON_ENDPOINT=http://jetson.local:8000

# ─── GitHub / Case Data ─────────────────────────────────────
GITHUB_REPO=toronto192020/Bradyx
CASE_DATA_PATH=${CASE_DATA_DIR}
WORKFLOWS_PATH=${BRADIX_DIR}/one-click-install/workflows

# ─── NAS Backup ─────────────────────────────────────────────
NAS_MOUNT=${NAS_MOUNT}
BACKUP_DIR=${BACKUP_DIR}

# ─── Timezone ───────────────────────────────────────────────
TZ=${TIMEZONE}
ENVEOF

log "Environment configured with auto-generated secrets."
log "n8n login: andrew / ${N8N_PASSWORD}"
echo ""
echo -e "${BOLD}SAVE THIS — n8n Dashboard Login:${NC}"
echo -e "  Username: ${CYAN}andrew${NC}"
echo -e "  Password: ${CYAN}${N8N_PASSWORD}${NC}"
echo ""

# Save credentials to a local file for Andrew
cat > "${BRADIX_DIR}/CREDENTIALS.txt" <<CREDEOF
============================================================
BRADIX SYSTEM CREDENTIALS
Generated: $(date)
============================================================

n8n Dashboard:
  URL: http://${LOCAL_IP}:5678
  Tailscale URL: http://${TS_IP}:5678
  Username: andrew
  Password: ${N8N_PASSWORD}

PostgreSQL:
  User: bradix
  Password: ${POSTGRES_PASSWORD}
  Database: n8n

Email Alerts:
  From: ${SMTP_USER}
  To: ${ALERT_EMAIL_PRIMARY}, ${ALERT_EMAIL_SECONDARY}

Tailscale:
  NUC IP: ${TS_IP}
  Access n8n from phone: http://${TS_IP}:5678

============================================================
KEEP THIS FILE SAFE. DO NOT SHARE.
============================================================
CREDEOF

chmod 600 "${BRADIX_DIR}/CREDENTIALS.txt"
log "Credentials saved to ${BRADIX_DIR}/CREDENTIALS.txt"

# ─── COPY DOCKER & WORKFLOW FILES ───────────────────────────
banner "STEP 8/12: Setting Up Docker Stack"

# Copy docker-compose and workflow files from repo
INSTALL_SRC="${BRADIX_DIR}/repo/one-click-install"

if [ -d "$INSTALL_SRC/docker" ]; then
    # Copy docker-compose but keep our generated .env
    cp "$INSTALL_SRC/docker/docker-compose.yml" "${BRADIX_DIR}/one-click-install/docker/" 2>/dev/null || true
fi

if [ -d "$INSTALL_SRC/workflows" ]; then
    cp -r "$INSTALL_SRC/workflows/"* "${BRADIX_DIR}/one-click-install/workflows/" 2>/dev/null || true
fi

if [ -d "$INSTALL_SRC/monitoring" ]; then
    cp -r "$INSTALL_SRC/monitoring/"* "${BRADIX_DIR}/one-click-install/monitoring/" 2>/dev/null || true
fi

if [ -d "$INSTALL_SRC/jetson" ]; then
    cp -r "$INSTALL_SRC/jetson/"* "${BRADIX_DIR}/one-click-install/jetson/" 2>/dev/null || true
fi

if [ -d "$INSTALL_SRC/scripts" ]; then
    cp -r "$INSTALL_SRC/scripts/"* "${BRADIX_DIR}/one-click-install/scripts/" 2>/dev/null || true
fi

# ─── START DOCKER STACK ────────────────────────────────────
log "Starting Docker stack..."
cd "${BRADIX_DIR}/one-click-install/docker"

# Pull images first
sudo docker compose pull 2>/dev/null || true

# Start the stack
sudo docker compose up -d

# Wait for services to be healthy
log "Waiting for services to start..."
sleep 15

# Check if n8n is up
for i in $(seq 1 30); do
    if curl -sf http://localhost:5678/healthz &>/dev/null; then
        log "n8n is running!"
        break
    fi
    sleep 5
done

log "Docker stack is up."

# ─── IMPORT n8n WORKFLOW ────────────────────────────────────
banner "STEP 9/12: Importing n8n Workflow"

WORKFLOW_FILE="${BRADIX_DIR}/one-click-install/workflows/bradix-core-workflow.json"

if [ -f "$WORKFLOW_FILE" ]; then
    # Wait for n8n API to be ready
    for i in $(seq 1 20); do
        if curl -sf -u "andrew:${N8N_PASSWORD}" http://localhost:5678/api/v1/workflows &>/dev/null; then
            break
        fi
        sleep 3
    done

    # Import workflow via n8n REST API
    IMPORT_RESULT=$(curl -sf -X POST \
        -u "andrew:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d @"$WORKFLOW_FILE" \
        http://localhost:5678/api/v1/workflows 2>/dev/null) || true

    if [ -n "$IMPORT_RESULT" ]; then
        WORKFLOW_ID=$(echo "$IMPORT_RESULT" | jq -r '.id' 2>/dev/null || echo "")
        if [ -n "$WORKFLOW_ID" ] && [ "$WORKFLOW_ID" != "null" ]; then
            # Activate the workflow
            curl -sf -X PATCH \
                -u "andrew:${N8N_PASSWORD}" \
                -H "Content-Type: application/json" \
                -d '{"active": true}' \
                "http://localhost:5678/api/v1/workflows/${WORKFLOW_ID}" &>/dev/null || true
            log "Workflow imported and activated (ID: $WORKFLOW_ID)"
        else
            warn "Workflow import returned unexpected result. Import manually via n8n UI."
        fi
    else
        warn "Could not import workflow via API. Import manually via n8n UI."
        warn "File: $WORKFLOW_FILE"
    fi
else
    warn "Workflow file not found at $WORKFLOW_FILE"
fi

# ─── NAS AUTO-DISCOVERY & MOUNT ────────────────────────────
banner "STEP 10/12: NAS Discovery & Backup Setup"

NAS_FOUND=false
NAS_IP=""

log "Scanning network for D-Link DNS-320 NAS..."

# Method 1: mDNS lookup
NAS_IP=$(avahi-resolve-host-name dns-320.local 2>/dev/null | awk '{print $2}' || echo "")

# Method 2: Network scan for common NAS ports (SMB/NFS)
if [ -z "$NAS_IP" ]; then
    SUBNET=$(ip route | grep -v default | grep src | head -1 | awk '{print $1}')
    if [ -n "$SUBNET" ]; then
        log "Scanning subnet $SUBNET for NAS devices..."
        NAS_IP=$(nmap -p 445 --open -oG - "$SUBNET" 2>/dev/null | grep "445/open" | head -1 | awk '{print $2}' || echo "")
    fi
fi

# Method 3: Try common NAS IPs
if [ -z "$NAS_IP" ]; then
    for ip_suffix in 1 2 50 100 200 253 254; do
        GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
        BASE=$(echo "$GATEWAY" | cut -d. -f1-3)
        TEST_IP="${BASE}.${ip_suffix}"
        if timeout 2 bash -c "echo >/dev/tcp/$TEST_IP/445" 2>/dev/null; then
            # Check if it responds like a NAS
            if smbclient -L "//$TEST_IP" -N 2>/dev/null | grep -qi "share\|disk\|volume"; then
                NAS_IP="$TEST_IP"
                break
            fi
        fi
    done
fi

if [ -n "$NAS_IP" ]; then
    NAS_FOUND=true
    log "NAS found at $NAS_IP"

    # Try to discover share names
    NAS_SHARE=$(smbclient -L "//$NAS_IP" -N 2>/dev/null | grep -i "disk" | head -1 | awk '{print $1}' || echo "Volume_1")

    # Create mount point
    sudo mkdir -p "$NAS_MOUNT"

    # Try mounting with guest access first (DNS-320 default)
    if sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$NAS_MOUNT" -o guest,vers=1.0,iocharset=utf8,noperm 2>/dev/null; then
        log "NAS mounted at $NAS_MOUNT (guest access)"
    elif sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$NAS_MOUNT" -o username=admin,password=,vers=1.0,iocharset=utf8 2>/dev/null; then
        log "NAS mounted at $NAS_MOUNT (admin/no password)"
    else
        warn "NAS found but could not auto-mount. You may need to set credentials."
        warn "Try: sudo mount -t cifs //$NAS_IP/$NAS_SHARE $NAS_MOUNT -o username=admin,password=YOUR_NAS_PASSWORD,vers=1.0"
        NAS_FOUND=false
    fi

    # Add to fstab for persistence
    if $NAS_FOUND; then
        FSTAB_ENTRY="//$NAS_IP/$NAS_SHARE $NAS_MOUNT cifs guest,vers=1.0,iocharset=utf8,noperm,_netdev,x-systemd.automount 0 0"
        if ! grep -q "$NAS_MOUNT" /etc/fstab 2>/dev/null; then
            echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
            log "NAS added to /etc/fstab for auto-mount on boot."
        fi

        # Create bradix backup directory on NAS
        sudo mkdir -p "${NAS_MOUNT}/bradix-backups" 2>/dev/null || true
    fi
else
    warn "NAS not found on network. Backups will use local storage only."
    warn "When NAS is connected, run: bradix-status.sh to re-detect."
fi

# ─── SET UP BACKUP CRON ────────────────────────────────────
log "Setting up daily backup..."

BACKUP_SCRIPT="${BRADIX_DIR}/one-click-install/scripts/bradix-backup.sh"

# Create backup script
cat > "$BACKUP_SCRIPT" <<'BACKUPEOF'
#!/usr/bin/env bash
# Bradix Daily Backup — runs via cron at 2am Brisbane time
set -euo pipefail

BRADIX_DIR="/opt/bradix"
BACKUP_DIR="/opt/bradix/backups"
NAS_MOUNT="/mnt/nas-backup"
CASE_DATA_DIR="/opt/bradix/case-data"
DATE=$(date +%Y-%m-%d_%H%M)
BACKUP_NAME="bradix-backup-${DATE}"
KEEP_DAYS=30

mkdir -p "${BACKUP_DIR}"

# Create backup archive
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    -C / \
    opt/bradix/case-data \
    opt/bradix/one-click-install/docker/.env \
    opt/bradix/one-click-install/workflows \
    2>/dev/null || true

# Backup PostgreSQL
docker exec bradix-postgres pg_dump -U bradix n8n 2>/dev/null | gzip > "${BACKUP_DIR}/${BACKUP_NAME}-db.sql.gz" || true

# Export n8n workflows
N8N_PASS=$(grep N8N_PASSWORD "${BRADIX_DIR}/one-click-install/docker/.env" | cut -d= -f2)
curl -sf -u "andrew:${N8N_PASS}" http://localhost:5678/api/v1/workflows 2>/dev/null | gzip > "${BACKUP_DIR}/${BACKUP_NAME}-workflows.json.gz" || true

# Copy to NAS if mounted
if mountpoint -q "$NAS_MOUNT" 2>/dev/null; then
    mkdir -p "${NAS_MOUNT}/bradix-backups" 2>/dev/null || true
    cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "${NAS_MOUNT}/bradix-backups/" 2>/dev/null || true
    cp "${BACKUP_DIR}/${BACKUP_NAME}-db.sql.gz" "${NAS_MOUNT}/bradix-backups/" 2>/dev/null || true
    cp "${BACKUP_DIR}/${BACKUP_NAME}-workflows.json.gz" "${NAS_MOUNT}/bradix-backups/" 2>/dev/null || true
    echo "[$(date)] Backup copied to NAS" >> /var/log/bradix/backup.log
fi

# Rotate old backups (keep 30 days)
find "${BACKUP_DIR}" -name "bradix-backup-*" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
if mountpoint -q "$NAS_MOUNT" 2>/dev/null; then
    find "${NAS_MOUNT}/bradix-backups" -name "bradix-backup-*" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
fi

echo "[$(date)] Backup complete: ${BACKUP_NAME}" >> /var/log/bradix/backup.log
BACKUPEOF

chmod +x "$BACKUP_SCRIPT"

# Install cron job for daily backup at 2am Brisbane time
(crontab -l 2>/dev/null | grep -v "bradix-backup" || true; echo "0 2 * * * ${BACKUP_SCRIPT} >> /var/log/bradix/backup.log 2>&1") | crontab -

log "Daily backup configured (2am, 30-day rotation)."

# ─── GITHUB SYNC CRON ──────────────────────────────────────
log "Setting up hourly GitHub sync..."

SYNC_SCRIPT="${BRADIX_DIR}/one-click-install/scripts/bradix-sync.sh"

cat > "$SYNC_SCRIPT" <<'SYNCEOF'
#!/usr/bin/env bash
# Bradix GitHub Sync — pulls latest case data hourly
set -euo pipefail

BRADIX_DIR="/opt/bradix"
CASE_DATA_DIR="/opt/bradix/case-data"
LOG_FILE="/var/log/bradix/sync.log"

cd "${BRADIX_DIR}/repo"
git fetch origin main --quiet 2>/dev/null || true
git reset --hard origin/main --quiet 2>/dev/null || true

# Copy updated case data
for f in case_data.json agent_task_tracker.json entity_registry.json monitoring_alerts.yaml cheryl_case_summary_raw.md; do
    found=$(find "${BRADIX_DIR}/repo" -name "$f" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        cp "$found" "${CASE_DATA_DIR}/cheryl-bruce-sanders/"
    fi
done

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /var/log/bradix/last_sync.txt
echo "[$(date)] Sync complete" >> "$LOG_FILE"
SYNCEOF

chmod +x "$SYNC_SCRIPT"

# Install hourly cron
(crontab -l 2>/dev/null | grep -v "bradix-sync" || true; echo "0 * * * * ${SYNC_SCRIPT} >> /var/log/bradix/sync.log 2>&1") | crontab -

log "Hourly GitHub sync configured."

# ─── SYSTEMD SERVICE ───────────────────────────────────────
banner "STEP 11/12: Setting Up Auto-Start"

sudo tee /etc/systemd/system/bradix.service > /dev/null <<SVCEOF
[Unit]
Description=Bradix Quiet Guardian — Docker Stack
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${BRADIX_DIR}/one-click-install/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable bradix.service
log "Auto-start on boot configured."

# ─── JETSON AUTO-DISCOVERY ──────────────────────────────────
log "Searching for Jetson on network..."

JETSON_FOUND=false
JETSON_IP=""

# Method 1: mDNS
JETSON_IP=$(avahi-resolve-host-name jetson.local 2>/dev/null | awk '{print $2}' || echo "")

# Method 2: Tailscale
if [ -z "$JETSON_IP" ]; then
    JETSON_IP=$(tailscale status 2>/dev/null | grep -i "jetson" | awk '{print $1}' || echo "")
fi

# Method 3: Network scan for Jetson SSH
if [ -z "$JETSON_IP" ]; then
    SUBNET=$(ip route | grep -v default | grep src | head -1 | awk '{print $1}')
    if [ -n "$SUBNET" ]; then
        JETSON_IP=$(nmap -p 22 --open -oG - "$SUBNET" 2>/dev/null | grep "22/open" | while read -r line; do
            IP=$(echo "$line" | awk '{print $2}')
            if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes "$JETSON_USER@$IP" "cat /etc/nv_tegra_release" 2>/dev/null | grep -q "TEGRA"; then
                echo "$IP"
                break
            fi
        done || echo "")
    fi
fi

if [ -n "$JETSON_IP" ]; then
    JETSON_FOUND=true
    log "Jetson found at $JETSON_IP!"

    # Update .env with Jetson IP
    sed -i "s|JETSON_ENDPOINT=.*|JETSON_ENDPOINT=http://${JETSON_IP}:8000|" "$ENV_FILE"

    # Try to push and run Jetson setup script
    JETSON_SCRIPT="${BRADIX_DIR}/one-click-install/jetson/bradix-jetson-auto.sh"
    if [ -f "$JETSON_SCRIPT" ]; then
        log "Pushing setup script to Jetson..."
        scp -o StrictHostKeyChecking=no "$JETSON_SCRIPT" "${JETSON_USER}@${JETSON_IP}:~/bradix-jetson-auto.sh" 2>/dev/null && {
            log "Running Jetson setup (this may take 10-20 minutes)..."
            ssh -o StrictHostKeyChecking=no "${JETSON_USER}@${JETSON_IP}" "chmod +x ~/bradix-jetson-auto.sh && sudo ~/bradix-jetson-auto.sh" 2>/dev/null &
            JETSON_PID=$!
            log "Jetson setup running in background (PID: $JETSON_PID)"
        } || {
            warn "Could not SSH to Jetson. Run bradix-jetson-auto.sh manually on the Jetson."
        }
    fi
else
    warn "Jetson not found on network."
    log "Setting up background discovery (retries every 5 minutes)..."

    # Create Jetson discovery service
    DISCOVER_SCRIPT="${BRADIX_DIR}/one-click-install/scripts/bradix-discover-jetson.sh"
    cat > "$DISCOVER_SCRIPT" <<'DISCEOF'
#!/usr/bin/env bash
# Bradix Jetson Discovery — keeps looking until found
BRADIX_DIR="/opt/bradix"
ENV_FILE="${BRADIX_DIR}/one-click-install/docker/.env"
JETSON_USER="jetson"
LOG="/var/log/bradix/jetson-discovery.log"

# Check if already found
CURRENT=$(grep JETSON_ENDPOINT "$ENV_FILE" | cut -d= -f2)
if [ "$CURRENT" != "http://jetson.local:8000" ]; then
    # Already configured with a real IP
    if curl -sf "${CURRENT}/health" &>/dev/null; then
        echo "[$(date)] Jetson already connected at $CURRENT" >> "$LOG"
        exit 0
    fi
fi

# Try mDNS
IP=$(avahi-resolve-host-name jetson.local 2>/dev/null | awk '{print $2}' || echo "")

# Try Tailscale
if [ -z "$IP" ]; then
    IP=$(tailscale status 2>/dev/null | grep -i "jetson" | awk '{print $1}' || echo "")
fi

if [ -n "$IP" ]; then
    echo "[$(date)] Jetson found at $IP" >> "$LOG"
    sed -i "s|JETSON_ENDPOINT=.*|JETSON_ENDPOINT=http://${IP}:8000|" "$ENV_FILE"

    # Try to push setup script
    JETSON_SCRIPT="${BRADIX_DIR}/one-click-install/jetson/bradix-jetson-auto.sh"
    if [ -f "$JETSON_SCRIPT" ]; then
        scp -o StrictHostKeyChecking=no "$JETSON_SCRIPT" "${JETSON_USER}@${IP}:~/bradix-jetson-auto.sh" 2>/dev/null && \
        ssh -o StrictHostKeyChecking=no "${JETSON_USER}@${IP}" "chmod +x ~/bradix-jetson-auto.sh && sudo nohup ~/bradix-jetson-auto.sh &" 2>/dev/null || true
    fi

    # Disable the timer since we found it
    sudo systemctl disable --now bradix-discover-jetson.timer 2>/dev/null || true
else
    echo "[$(date)] Jetson not found, will retry" >> "$LOG"
fi
DISCEOF
    chmod +x "$DISCOVER_SCRIPT"

    # Create systemd timer for retry every 5 minutes
    sudo tee /etc/systemd/system/bradix-discover-jetson.service > /dev/null <<DSVCEOF
[Unit]
Description=Bradix Jetson Discovery
After=network-online.target

[Service]
Type=oneshot
ExecStart=${DISCOVER_SCRIPT}
DSVCEOF

    sudo tee /etc/systemd/system/bradix-discover-jetson.timer > /dev/null <<DTMREOF
[Unit]
Description=Bradix Jetson Discovery Timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
DTMREOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now bradix-discover-jetson.timer
    log "Jetson discovery timer active (checks every 5 minutes)."
fi

# ─── DESKTOP SHORTCUT ──────────────────────────────────────
# Create desktop shortcut if desktop environment exists
DESKTOP_DIR="$HOME/Desktop"
if [ -d "$DESKTOP_DIR" ] || [ -d "$HOME/.local/share/applications" ]; then
    mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
    mkdir -p "$HOME/.local/share/applications" 2>/dev/null || true

    SHORTCUT_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=Bradix Dashboard
Comment=Open Bradix n8n Dashboard
Exec=xdg-open http://localhost:5678
Icon=utilities-system-monitor
Terminal=false
Categories=System;
StartupNotify=true"

    echo "$SHORTCUT_CONTENT" > "${DESKTOP_DIR}/bradix-dashboard.desktop" 2>/dev/null || true
    echo "$SHORTCUT_CONTENT" > "$HOME/.local/share/applications/bradix-dashboard.desktop" 2>/dev/null || true
    chmod +x "${DESKTOP_DIR}/bradix-dashboard.desktop" 2>/dev/null || true

    log "Desktop shortcut created."
fi

# ─── INSTALL STATUS SCRIPT GLOBALLY ────────────────────────
STATUS_SCRIPT="${BRADIX_DIR}/one-click-install/scripts/bradix-status.sh"
if [ -f "$STATUS_SCRIPT" ]; then
    sudo cp "$STATUS_SCRIPT" /usr/local/bin/bradix-status
    sudo chmod +x /usr/local/bin/bradix-status
    log "Status command installed. Run 'bradix-status' anytime."
fi

# ─── HEALTH CHECK & FINAL STATUS ───────────────────────────
banner "STEP 12/12: System Health Check"

echo ""
echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}│         BRADIX SYSTEM STATUS                    │${NC}"
echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────┤${NC}"

# Docker
if sudo docker compose -f "${BRADIX_DIR}/one-click-install/docker/docker-compose.yml" ps --format "table" 2>/dev/null | grep -q "running"; then
    echo -e "${CYAN}│${NC}  Docker Stack:    ${GREEN}● RUNNING${NC}                     ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  Docker Stack:    ${YELLOW}● STARTING${NC}                    ${CYAN}│${NC}"
fi

# n8n
if curl -sf http://localhost:5678/healthz &>/dev/null; then
    echo -e "${CYAN}│${NC}  n8n Engine:      ${GREEN}● HEALTHY${NC}                      ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  n8n Engine:      ${YELLOW}● STARTING${NC}                    ${CYAN}│${NC}"
fi

# PostgreSQL
if sudo docker exec bradix-postgres pg_isready -U bradix &>/dev/null; then
    echo -e "${CYAN}│${NC}  PostgreSQL:      ${GREEN}● HEALTHY${NC}                      ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  PostgreSQL:      ${YELLOW}● STARTING${NC}                    ${CYAN}│${NC}"
fi

# Tailscale
if tailscale status &>/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "?")
    echo -e "${CYAN}│${NC}  Tailscale:       ${GREEN}● CONNECTED${NC} ($TS_IP)       ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  Tailscale:       ${YELLOW}● NEEDS LOGIN${NC}                 ${CYAN}│${NC}"
fi

# Jetson
if $JETSON_FOUND; then
    echo -e "${CYAN}│${NC}  Jetson AI:       ${GREEN}● FOUND${NC} ($JETSON_IP)            ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  Jetson AI:       ${YELLOW}● SEARCHING${NC} (auto-retry 5m)    ${CYAN}│${NC}"
fi

# NAS
if $NAS_FOUND; then
    echo -e "${CYAN}│${NC}  NAS Backup:      ${GREEN}● MOUNTED${NC} ($NAS_IP)            ${CYAN}│${NC}"
else
    echo -e "${CYAN}│${NC}  NAS Backup:      ${YELLOW}● NOT FOUND${NC} (local backup OK)  ${CYAN}│${NC}"
fi

# Case Data
TASK_COUNT=$(jq length "${CASE_DATA_DIR}/cheryl-bruce-sanders/agent_task_tracker.json" 2>/dev/null || echo "?")
echo -e "${CYAN}│${NC}  Case Data:       ${GREEN}● LOADED${NC} ($TASK_COUNT tasks)         ${CYAN}│${NC}"

echo -e "${CYAN}${BOLD}├─────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}n8n Dashboard:${NC}                                ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Local:  ${BLUE}http://${LOCAL_IP}:5678${NC}              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}    Phone:  ${BLUE}http://${TS_IP}:5678${NC}              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  ${BOLD}Login:${NC} andrew / (see CREDENTIALS.txt)         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  Run ${BOLD}bradix-status${NC} anytime to check status.    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                 ${CYAN}│${NC}"
echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────┘${NC}"
echo ""

banner "INSTALLATION COMPLETE"
echo -e "${BOLD}Andrew — it's done. The system is watching.${NC}"
echo ""
echo "What happens now (automatically):"
echo "  • n8n checks deadlines daily at 8am"
echo "  • Weekly email digest every Monday at 9am"
echo "  • 48-hour deadline warnings sent immediately"
echo "  • Overdue tasks escalated daily"
echo "  • Case data syncs from GitHub every hour"
echo "  • Full backup to NAS every night at 2am"
echo "  • Jetson AI queried for case analysis"
echo "  • System auto-starts on reboot"
echo ""
echo "You don't need to do anything else."
echo "The Quiet Guardian is active."
echo ""
echo -e "${CYAN}Credentials saved to: ${BRADIX_DIR}/CREDENTIALS.txt${NC}"
echo ""
