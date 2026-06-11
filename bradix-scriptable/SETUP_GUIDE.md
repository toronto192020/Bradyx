# BRADIX Master Automation Bridge — Setup Guide

## What This Does

One script on your iPhone controls everything:
- Tap a button → nominates Mills/Woodward
- Tap a button → calls SPER/BlueCare via Vapi
- Tap a button → sends emails to QSuper/AFCA/PTQ
- Voice command on R1 → triggers any action
- Automatic care alerts → water, food, toilet, medicine
- Grants intelligence → LittlebirdAI searches automatically
- AI analysis → local Hermes on Jetson analyses any situation

---

## Step 1: Create Your Telegram Bot (2 minutes, FREE)

1. Open Telegram → search for **@BotFather**
2. Send: `/newbot`
3. Name it: `BRADIX Command`
4. Username: `bradix_command_bot` (or whatever's available)
5. Copy the **token** it gives you
6. Now message **@userinfobot** → it replies with your **chat ID**
7. Paste both into the script CONFIG section

---

## Step 2: Set Up Taskade (3 minutes, FREE tier)

1. Go to: https://taskade.com
2. Sign up (free)
3. Create a workspace called "BRADIX"
4. Create a project called "Command Centre"
5. Go to Settings → API → Generate API key
6. Copy: API key, workspace ID, project ID
7. Paste into CONFIG section

---

## Step 3: LittlebirdAI (5 minutes, trial/free)

1. Go to: https://littlebirdai.com
2. Sign up
3. Navigate to API/Developer section
4. Generate API key
5. Paste into CONFIG section

This gives you automated grant/funding opportunity searches.

---

## Step 4: Connect to Your NUC (already done if Tailscale is running)

1. On your NUC, run: `tailscale ip`
2. Note the 100.x.x.x address
3. Replace all `100.x.x.x` in CONFIG with your NUC's Tailscale IP
4. Make sure BRADIX Master API is running: `cd ~/Bradyx/bradix-master-api && docker-compose up -d`
5. Test: Open `http://100.x.x.x:8080/status` in browser

---

## Step 5: Install on iPhone

1. Open **Scriptable** app (free from App Store)
2. Tap **+** to create new script
3. Paste the entire `BRADIX_Master_Automation.js` content
4. Name it: "BRADIX Command"
5. Tap ▶️ to test — should show "Initializing Master Automation Bridge..."

---

## Step 6: Create iOS Shortcuts (optional but powerful)

For each action, create a Shortcut:

1. Open **Shortcuts** app
2. New Shortcut → Add Action → "Run Scriptable Script"
3. Select "BRADIX Command"
4. Set Parameter to the action name (e.g., "nominate-mills")
5. Add to Home Screen with custom icon

### Suggested Shortcuts:

| Shortcut Name | Parameter | What It Does |
|---------------|-----------|--------------|
| Nominate Mills | `nominate-mills` | Submits fine nomination |
| Nominate Woodward | `nominate-woodward` | Submits fine nomination |
| Call SPER | `call-sper` | Triggers Vapi call |
| Call BlueCare | `call-bluecare` | Triggers Vapi call |
| QSuper Email | `email-qsuper` | Sends late registration |
| AFCA Complaint | `file-afca` | Files insurance complaint |
| Full Status | `status` | Shows everything |
| EXECUTE ALL | `execute-all` | Does everything at once |
| Water Reminder | `care-water` | Sends hydration alert |
| Grant Search | `grants` | Searches LittlebirdAI |

---

## Step 7: Rabbit R1 Integration

The R1 connects through your NUC as a relay:

1. Load `BRADIX_R1_CONTEXT.txt` as your R1's DLAM context
2. The NUC API has a `/r1/command` endpoint
3. When R1 processes a voice command, it hits the NUC
4. NUC routes to the correct action
5. Result comes back through Telegram notification

Voice commands that work:
- "What's my SPER balance?" → status check
- "Nominate Mills" → triggers nomination
- "Call BlueCare" → triggers Vapi
- "How much do they owe me?" → calculates recovery total

---

## Step 8: n8n Workflows (self-hosted, unlimited, FREE)

On your NUC:
```bash
docker run -d --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n n8nio/n8n
```

Create workflows for:
- Daily status report → Telegram at 8am
- Care cycle alerts → every 90 minutes
- Water reminders → every 30 minutes
- Grant opportunity checks → daily
- Evidence backup → nightly to GitHub

---

## Architecture

```
iPhone (Scriptable) 
    ↓ (Tailscale)
NUC (BRADIX Master API + n8n)
    ↓
Jetson (Ollama/Hermes AI)
    ↓
Raspberry Pi (Dashboard PWA + sensors)
    ↓
Rabbit R1 (Voice commands via DLAM)
    ↓
Telegram (Notifications back to you)
```

Everything talks to everything. You talk to any one of them. The system does the work.

---

## Monthly Cost

| Service | Cost |
|---------|------|
| Telegram Bot | $0 |
| Scriptable | $0 |
| Tailscale | $0 (personal) |
| n8n (self-hosted) | $0 |
| Ollama (self-hosted) | $0 |
| Taskade (free tier) | $0 |
| LittlebirdAI (trial) | $0 initially |
| Your hardware (NUC + Jetson + Pi) | Already owned |
| **TOTAL** | **$0/month** |

---

## One Command to Rule Them All

On your iPhone, create a single Shortcut called **"BRADIX GO"** that runs parameter `execute-all`.

One tap. Everything fires. Nominations submitted. Emails sent. Calls triggered. Status reported. Evidence logged.

That's it. The machine works for you now.
