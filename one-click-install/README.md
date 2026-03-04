# Bradix One-Click Install

**One script. One run. Everything works.**

This directory contains the complete autonomous installation system for the Bradix Quiet Guardian platform.

---

## What is this?

A single bash script that transforms a bare MSI NUC into a fully operational case management and monitoring system. It installs Docker, n8n, PostgreSQL, Tailscale, and all supporting services. It auto-discovers and configures the NVIDIA Jetson for local AI inference. It finds the D-Link NAS and sets up daily backups. It does everything.

---

## Quick Start

See [INSTRUCTIONS.md](INSTRUCTIONS.md) for the five-step guide.

```bash
curl -sL https://raw.githubusercontent.com/toronto192020/Bradyx/main/one-click-install/bradix-install.sh | bash
```

---

## What gets installed

| Component | Purpose |
|-----------|---------|
| Docker + Docker Compose | Container runtime for all services |
| n8n | Workflow automation (deadline checks, email alerts, AI queries) |
| PostgreSQL 15 | Database for n8n workflows and execution history |
| Tailscale | Secure remote access from phone/anywhere |
| Avahi/mDNS | Local network device discovery (Jetson, NAS) |
| Watchtower | Automatic container updates (Sundays 3am) |
| Cron jobs | Hourly GitHub sync, daily backups, health checks |

---

## Directory structure

```
one-click-install/
├── INSTRUCTIONS.md              ← Five-step setup guide
├── README.md                    ← This file
├── bradix-install.sh            ← THE one-click installer (run on NUC)
├── docker/
│   ├── docker-compose.yml       ← Full Docker stack definition
│   └── .env.template            ← Environment variable reference
├── workflows/
│   └── bradix-core-workflow.json ← Autonomous n8n workflow
├── jetson/
│   └── bradix-jetson-auto.sh    ← Jetson companion setup script
├── monitoring/
│   ├── health-check.py          ← System health monitor
│   └── alert-config.yaml        ← Alert rules and configuration
└── scripts/
    ├── bradix-status.sh         ← System status dashboard
    ├── bradix-backup.sh         ← Daily backup script
    └── bradix-sync.sh           ← Hourly GitHub sync script
```

---

## Autonomous behaviour

Once installed, the system runs without intervention:

| Schedule | Action |
|----------|--------|
| Daily 8am | Check all task deadlines, send urgent alerts |
| Daily 10am | Escalate overdue tasks (daily until acknowledged) |
| Monday 9am | Weekly email digest to both addresses |
| Every hour | Sync case data from GitHub |
| Daily 2am | Full backup to NAS (30-day rotation) |
| Sunday 3am | Auto-update Docker containers |
| Every 5 min | Search for Jetson if not yet found |
| On boot | Auto-start all services |

---

## Alert emails

Alerts are sent to:
- **bts@outlook.com** (Andrew)
- **cherylbruder@icloud.com** (Cheryl)

Alert types:
- **Urgent**: 48-hour deadline warning (immediate)
- **Overdue**: Daily escalation until acknowledged
- **Weekly**: Monday morning digest
- **System**: Only if a critical service is down

---

## Hardware

| Device | Role |
|--------|------|
| MSI Cubi N ADL (Intel N100) | Always-on orchestration hub |
| NVIDIA Jetson (100+ TOPS) | Local AI inference (Ollama + FastAPI) |
| D-Link DNS-320 NAS | Backup storage (SMB mount) |
| Tailscale | Secure remote access mesh |

---

*The Quiet Guardian — for Andrew and Cheryl.*
