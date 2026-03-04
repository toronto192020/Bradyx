# Bradix — Complete Setup Guide

This guide provides step-by-step instructions for setting up the MSI NUC and NVIDIA Jetson as a dedicated "Quiet Guardian" for Andrew and Cheryl's case management.

---

## Prerequisites

- **MSI NUC** (Intel Core Ultra 5/7 recommended)
- **NVIDIA Jetson** (AGX Orin, Orin NX, or Orin Nano for 100+ TOPS)
- **Ubuntu 22.04 LTS** (Installed on the NUC)
- **JetPack 6.0+** (Installed on the Jetson)
- **GitHub Personal Access Token** (For syncing case data)
- **SMTP Credentials** (For email notifications: Gmail App Password or Outlook)

---

## Step 1: MSI NUC OS Setup

1. **Install Ubuntu 22.04 LTS**:
   - Download the Ubuntu Desktop or Server ISO.
   - Flash to a USB drive and boot the NUC.
   - Follow the installation prompts. Choose "Minimal Installation" to keep the system light.

2. **Update and Install Docker**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y docker.io docker-compose
   sudo usermod -aG docker $USER
   # Log out and log back in for group changes to take effect
   ```

3. **Clone the Bradix Repository**:
   ```bash
   cd ~
   git clone https://github.com/toronto192020/Bradyx.git
   cd Bradyx/nuc-jetson-setup
   ```

---

## Step 2: Configure Environment

1. **Create the `.env` file**:
   ```bash
   cp docker/.env.template docker/.env
   nano docker/.env
   ```

2. **Fill in your credentials**:
   - `N8N_PASSWORD`: Set a strong password for the n8n UI.
   - `SMTP_USER/PASS`: Use your email and an App Password.
   - `JETSON_ENDPOINT`: Set this to the Jetson's local IP (e.g., `http://192.168.1.50:8000`).
   - `GITHUB_TOKEN`: Your GitHub token to pull case data.

---

## Step 3: Launch Services

1. **Start the Docker Stack**:
   ```bash
   cd docker
   docker-compose up -d
   ```

2. **Verify Services**:
   - Access n8n: `http://localhost:5678`
   - Access Dashboard: `http://localhost:8080`
   - Check logs: `docker-compose logs -f`

---

## Step 4: NVIDIA Jetson Connection & Setup

1. **Connect the Jetson**:
   - Connect the Jetson to your local network via Ethernet (preferred) or Wi-Fi.
   - Ensure it has a static IP or use `jetson.local` if mDNS is active.

2. **Run the Setup Script**:
   On the Jetson, run the provided setup script:
   ```bash
   # Copy the script to the Jetson or clone the repo there
   scp jetson/scripts/setup-jetson.sh user@jetson.local:~/
   ssh user@jetson.local
   chmod +x setup-jetson.sh
   ./setup-jetson.sh
   ```

3. **Verify AI Inference**:
   Test the endpoint from your NUC:
   ```bash
   curl http://jetson.local:8000/health
   ```

---

## Step 5: Configure n8n Workflows

1. **Log in to n8n**: `http://localhost:5678`
2. **Import the Core Workflow**:
   - Go to **Workflows** → **Import from File**.
   - Select `n8n/workflows/bradix-core-workflow.json`.
3. **Configure Credentials**:
   - In n8n, go to **Credentials** and set up your **SMTP** and **GitHub** credentials.
4. **Activate the Workflow**:
   - Click the toggle to set the workflow to **Active**.

---

## Step 6: Case Data Sync

1. **Set up the Sync Service**:
   The NUC needs to pull the latest `agent_task_tracker.json` and `case_data.json` from GitHub periodically.
   ```bash
   cd ~/Bradyx/nuc-jetson-setup/case-sync
   sudo cp case-sync.service /etc/systemd/system/
   sudo systemctl enable --now case-sync.service
   ```

---

## Step 7: Smart Home & SuresafeGO

1. **SuresafeGO Alerts**:
   - SuresafeGO sends alerts via SMS/Email.
   - Configure your SuresafeGO account to send alerts to the email address specified in your `.env`.
   - The `bradix-monitor` service watches this inbox and triggers the **Urgent** alert flow in n8n.

2. **Sensors**:
   - Add smart home sensors (Zigbee/Matter) via n8n's Home Assistant node or MQTT if needed.

---

## Step 8: Monitoring & Maintenance

1. **Health Checks**:
   The `bradix-monitor` container runs the `health-check.py` script every 15 minutes. It will only email you if a critical service (n8n or Database) goes down.

2. **Backups**:
   A daily backup of the n8n database and case data is stored in `~/bradix-backups`.
   ```bash
   # Manual backup
   ./scripts/maintenance/backup.sh
   ```

3. **Updates**:
   The **Watchtower** service automatically updates your Docker containers every Sunday at 3:00 AM.

---

## Troubleshooting

- **No Emails**: Check your SMTP credentials in `.env` and n8n settings.
- **Jetson Offline**: Ensure the Jetson is on the same network and the IP in `.env` matches.
- **Sync Failing**: Check your GitHub Personal Access Token permissions (needs `repo` scope).

---

*The Bradix system is now active. It is watching, so you don't have to. Turn the page.*
