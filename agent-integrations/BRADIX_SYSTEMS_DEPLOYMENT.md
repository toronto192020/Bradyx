# BRADIX.SYSTEMS Deployment Guide
## Deploy your dashboard and API gateway at bradix.systems

---

## OPTION A — CLOUDFLARE TUNNEL (Recommended — Free, Secure, No Port Forwarding)

Cloudflare Tunnel creates a secure connection from your NUC to Cloudflare's network, making bradix.systems accessible from anywhere without opening any ports on your router.

### Step 1 — Set Up Cloudflare (if not already done)
1. Go to **cloudflare.com** and create a free account
2. Add your domain: bradix.systems
3. Update your domain's nameservers to Cloudflare's (your registrar will have instructions)

### Step 2 — Install cloudflared on NUC
```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authenticate
cloudflared tunnel login
# Opens browser — log in to Cloudflare and select bradix.systems

# Create tunnel
cloudflared tunnel create bradix
# Note the tunnel ID shown
```

### Step 3 — Configure the Tunnel
```bash
# Create config
mkdir -p ~/.cloudflared
nano ~/.cloudflared/config.yml
```

```yaml
tunnel: [YOUR-TUNNEL-ID]
credentials-file: /home/ubuntu/.cloudflared/[TUNNEL-ID].json

ingress:
  - hostname: bradix.systems
    service: http://localhost:3000
  - hostname: api.bradix.systems
    service: http://localhost:8080
  - hostname: n8n.bradix.systems
    service: http://localhost:5678
  - service: http_status:404
```

### Step 4 — Point DNS to Tunnel
```bash
cloudflared tunnel route dns bradix [YOUR-TUNNEL-ID]
# This creates a CNAME record in Cloudflare automatically
```

### Step 5 — Run as System Service
```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

---

## OPTION B — TAILSCALE (Already Planned — Private Access Only)

If you only need to access bradix.systems from your own devices (phone, laptop):

```bash
# Install Tailscale on NUC (if not done)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Get your Tailscale IP
tailscale ip -4
# Example: 100.x.x.x

# Access from phone: http://100.x.x.x:3000
# Or set up MagicDNS in Tailscale admin to use bradix.systems
```

---

## DEPLOY THE DASHBOARD

The existing dashboard at andrewdash-rdsy5laf.manus.space needs to be self-hosted on your NUC.

### Option 1 — Clone and Run Locally
```bash
# The dashboard is a React app
# Clone from your GitHub
git clone https://github.com/toronto192020/andrew-dashboard.git
cd andrew-dashboard
npm install
npm run build

# Serve with nginx
sudo apt install -y nginx
sudo cp -r build/* /var/www/html/
sudo systemctl restart nginx
# Now accessible at http://localhost:80
```

### Option 2 — Docker (Cleaner)
```bash
sudo apt install -y docker.io
cd andrew-dashboard
docker build -t bradix-dashboard .
docker run -d -p 3000:80 --name bradix-dashboard bradix-dashboard
```

---

## API GATEWAY SETUP

This allows OpenClaw agents and the R1 to trigger actions via bradix.systems/api/

```bash
# Install FastAPI
pip3 install fastapi uvicorn

# Save as /home/ubuntu/bradix_api/main.py
```

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess, json

app = FastAPI(title="BRADIX API", version="1.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"])

@app.get("/api/deadlines")
def get_deadlines():
    with open("/home/ubuntu/bradix_documents/BRADIX_R1_KNOWLEDGE_BASE.json") as f:
        data = json.load(f)
    return {"deadlines": data["deadlines"]}

@app.get("/api/status")
def get_status():
    return {"status": "online", "system": "BRADIX", "version": "1.0"}

@app.post("/api/trigger/{agent}")
def trigger_agent(agent: str, task: str):
    # Trigger CrewAI agent
    result = subprocess.run(
        ["python3", f"/home/ubuntu/bradix_agents/{agent}_agent.py", task],
        capture_output=True, text=True
    )
    return {"result": result.stdout}

# Run: uvicorn main:app --host 0.0.0.0 --port 8080
```

### Run as Service
```bash
sudo nano /etc/systemd/system/bradix-api.service
```

```ini
[Unit]
Description=BRADIX API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/bradix_api
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8080
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable bradix-api
sudo systemctl start bradix-api
```

---

## MOBILE ACCESS FROM iPHONE

1. Install **Tailscale** app on iPhone
2. Connect to same Tailscale network as NUC
3. Open Safari: `http://[NUC-TAILSCALE-IP]:3000` or `https://bradix.systems`
4. Add to Home Screen: Share → Add to Home Screen → "BRADIX"
5. Now bradix.systems is a one-tap app on your iPhone

---

## FINAL ARCHITECTURE

```
iPhone (Safari/Tailscale)
         ↓
bradix.systems (Cloudflare Tunnel)
         ↓
NUC — nginx (dashboard :80) + FastAPI (API :8080) + n8n (workflows :5678)
         ↓
Jetson — Ollama (LLM :11434) + CrewAI agents
         ↓
D-Link NAS — all ingested data, photos, emails, evidence
```

---

*Document prepared: March 2026 | BRADIX Case Management System*
