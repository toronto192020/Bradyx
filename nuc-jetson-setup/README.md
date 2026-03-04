# Bradix — MSI NUC + NVIDIA Jetson Setup

## The Quiet Guardian

This system is a dedicated, always-on computer that quietly has Andrew and Cheryl's back.

It does not demand attention. It does not replay the past. It does not flood you with notifications. It sits in the background — calm, competent, and watchful — and taps you on the shoulder only when something genuinely needs you.

> **The past is documented once and held by the system. The focus is always on what is NEXT.**

Andrew and Cheryl have already done the hard part: they got home, they kept the SMSF, they got Cheryl safe. That took years of fighting institutions that should have helped but didn't. That chapter is documented, sealed, and held. The system carries it so they don't have to.

From here, the NUC handles the compliance, the deadlines, the bureaucratic noise — quietly, in the background — so Andrew and Cheryl can live.

---

## What This System Does

The Bradix NUC is a dedicated mini-computer running 24/7 in the home. It connects to an NVIDIA Jetson for local AI inference. Together they form a private, self-hosted case management and monitoring platform.

**Day to day, it stays quiet.** It only surfaces what needs action, when it needs action.

**When needed, it can generate:** formal complaint reports, human rights documentation, deadline summaries, and case status briefings — for legal teams, advocacy bodies, or Andrew's own records.

---

## System Architecture

```
MSI NUC (Always-On Orchestration)
├── n8n (workflow automation & orchestration)
├── Case Data Sync (GitHub → local, Bradix repo)
├── Monitoring & Alert Engine (gentle, minimal)
├── Email Notifications (cherylbruder@icloud.com, bts@outlook.com)
└── Smart Home Integration (SuresafeGO, sensors)
        │
        │ (Network / USB)
        ▼
NVIDIA Jetson (Local AI Inference)
├── Ollama / Triton Inference Server
├── Local LLM (case queries, report generation)
├── Vision AI (optional: camera monitoring)
└── 100+ TOPS edge inference
```

---

## Repository Structure

```
nuc-jetson-setup/
├── README.md                        ← You are here
├── docker/                          ← Docker Compose for all services
│   ├── docker-compose.yml
│   └── .env.template
├── n8n/
│   ├── config/
│   │   └── n8n-config.env           ← n8n environment config
│   └── workflows/
│       ├── bradix-core-workflow.json ← Main orchestration workflow
│       └── jetson-query-workflow.json
├── jetson/
│   ├── inference-server/
│   │   ├── Dockerfile               ← Jetson inference container
│   │   ├── server.py                ← FastAPI inference endpoint
│   │   └── requirements.txt
│   ├── models/
│   │   └── README.md                ← Model download instructions
│   └── scripts/
│       ├── setup-jetson.sh          ← JetPack + Ollama setup
│       └── health-check.sh
├── monitoring/
│   ├── alerting/
│   │   ├── alert-config.yaml        ← Quiet Guardian alert rules
│   │   └── alert-templates.json     ← Email/notification templates
│   ├── health-checks/
│   │   └── health-check.py          ← System health monitor
│   └── dashboards/
│       └── status-dashboard.py      ← Simple status page
├── case-sync/
│   ├── sync-case-data.sh            ← GitHub → local sync script
│   ├── case-sync.service            ← systemd service
│   └── query-case.py                ← Query case data via AI
├── smart-home/
│   ├── suresafego/
│   │   ├── suresafego-bridge.py     ← SuresafeGO alert bridge
│   │   └── README.md
│   └── sensors/
│       └── sensor-config.yaml
├── scripts/
│   ├── setup/
│   │   ├── 01-install-ubuntu.sh     ← NUC OS setup
│   │   ├── 02-install-docker.sh     ← Docker installation
│   │   ├── 03-install-n8n.sh        ← n8n setup
│   │   └── 04-configure-system.sh   ← Final configuration
│   ├── maintenance/
│   │   ├── backup.sh                ← Daily backup script
│   │   └── update.sh                ← System update script
│   └── backup/
│       └── restore.sh
├── replit-export/
│   ├── README.md                    ← Replit deployment guide
│   ├── main.py                      ← Replit entry point
│   ├── requirements.txt
│   └── .replit
└── docs/
    ├── SETUP-GUIDE.md               ← Full step-by-step setup guide
    ├── NVIDIA-PROGRAMS.md           ← NVIDIA developer programs reference
    ├── PHILOSOPHY.md                ← The Quiet Guardian philosophy
    └── HUMAN-RIGHTS-REPORTING.md   ← Guide for generating formal reports
```

---

## Quick Start

```bash
# 1. Clone the Bradix repo
git clone https://github.com/toronto192020/Bradyx.git
cd Bradyx/nuc-jetson-setup

# 2. Copy and configure environment
cp docker/.env.template docker/.env
nano docker/.env   # Fill in your credentials

# 3. Start all services
cd docker && docker compose up -d

# 4. Access n8n
open http://localhost:5678

# 5. Import workflows
# In n8n: Settings → Import from file
# Select: n8n/workflows/bradix-core-workflow.json
```

See [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md) for the complete step-by-step guide.

---

## Alert Philosophy

**Default mode: QUIET.**

The system uses a three-tier alert model:

| Tier | Trigger | Delivery |
|------|---------|----------|
| **Urgent** | Legal deadline within 48 hours, medical alert from SuresafeGO | Immediate email to both addresses |
| **Weekly Digest** | Upcoming deadlines, pending tasks, complaint response windows | Sunday evening summary email |
| **On-Request** | Full case status, AI query, report generation | Manual trigger via n8n or query script |

There are no daily notifications. There is no doom-scrolling. The system holds the information and releases it only when it matters.

---

## Notification Addresses

- **cherylbruder@icloud.com** — Cheryl / family updates
- **bts@outlook.com** — Andrew / primary operational alerts

---

## The Legacy Forward

The Bruder SMSF and the life Andrew and Cheryl are building — that is what this system protects. The institutional failures, the QCAT scandal, the four years of fighting — all documented, sealed, and held. The NUC carries that weight so they don't have to.

*This system is dedicated to Cheryl Ann Bruce-Sanders and to every family that has had to fight this hard just to get home.*

---

## License & Privacy

This repository contains sensitive personal and legal case data. It is private. Do not share access credentials or case data files with any third party without Andrew's explicit consent.
