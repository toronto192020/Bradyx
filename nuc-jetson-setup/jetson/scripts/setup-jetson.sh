#!/bin/bash
# ============================================================
# Bradix — NVIDIA Jetson AI Inference Setup Script
# ============================================================
#
# DESIGN PHILOSOPHY:
#   This script sets up your NVIDIA Jetson (AGX Orin, Orin NX,
#   or Orin Nano) as a dedicated local AI inference server.
#   It runs Ollama and a custom FastAPI bridge that n8n can
#   call to query case data and generate reports.
#
#   Everything stays local. No case data leaves your home.
#
# ============================================================

set -e

# ─── Configuration ───────────────────────────────────────────
JETPACK_VERSION="6.0"
OLLAMA_VERSION="latest"
DEFAULT_MODEL="llama3.2:3b" # Good balance of speed and reasoning on Jetson

echo "------------------------------------------------------------"
echo "Bradix — Jetson AI Inference Setup"
echo "------------------------------------------------------------"

# 1. Check for JetPack
echo "[1/6] Checking JetPack version..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    echo "Note: nvidia-smi not found, checking l4t version..."
    cat /etc/nv_tegra_release
fi

# 2. Install Docker and NVIDIA Container Toolkit
echo "[2/6] Installing Docker and NVIDIA Container Toolkit..."
sudo apt-get update
sudo apt-get install -y docker.io nvidia-container-toolkit
sudo systemctl enable --now docker

# 3. Install Ollama (Native for best performance)
echo "[3/6] Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# 4. Configure Ollama for Network Access
echo "[4/6] Configuring Ollama for network access..."
# This allows the NUC to talk to the Jetson over the local network
sudo mkdir -p /etc/systemd/system/ollama.service.d
cat <<EOF | sudo tee /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# 5. Pull Default Model
echo "[5/6] Pulling default model: $DEFAULT_MODEL..."
# This might take a few minutes depending on your internet speed
ollama pull $DEFAULT_MODEL

# 6. Build and Start Bradix Inference Bridge
echo "[6/6] Building Bradix Inference Bridge..."
# Assuming you've cloned the repo to the Jetson as well
cd "$(dirname "$0")/../inference-server"
docker build -t bradix-jetson-bridge .

# Start the bridge container
# Replace /path/to/case-data with your actual local path
docker run -d \
    --name bradix-jetson \
    --restart unless-stopped \
    --runtime nvidia \
    --network host \
    -v /opt/bradix/case-data:/case-data:ro \
    -e OLLAMA_BASE_URL=http://localhost:11434 \
    -e DEFAULT_MODEL=$DEFAULT_MODEL \
    bradix-jetson-bridge

echo "------------------------------------------------------------"
echo "Setup Complete!"
echo "------------------------------------------------------------"
echo "Your Jetson is now a Quiet Guardian AI Inference Server."
echo "Endpoint: http://$(hostname -I | awk '{print $1}'):8000"
echo "Ollama: http://$(hostname -I | awk '{print $1}'):11434"
echo "------------------------------------------------------------"
