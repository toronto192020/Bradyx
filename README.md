# BRADIX

BRADIX is Andrew Bruce-Sanders’ local-first care, administration, evidence, and automation command surface for an Ubuntu MSI NUC in Brisbane. The repository contains the FastAPI master API, a responsive installable PWA, Scriptable modules for iOS, Docker Compose orchestration, optional dependency checkouts, templates, and operational documentation.

## One-command deployment

```bash
git clone https://github.com/toronto192020/Bradyx.git
cd Bradyx
cp .env.example .env
chmod 600 .env
nano .env
sudo bash BRADIX_DEPLOY.sh
```

The default configuration is **draft-first**. Set `ALLOW_EXTERNAL_SEND=true` only after the outbound connector has been tested and the intended review process is clear. The dashboard runs on port 80, the API on 8080, n8n on 5678, and Ollama is bound to localhost on 11434.

## Repository map

| Path | Purpose |
|---|---|
| `BRADIX_DEPLOY.sh` | Installs Docker, starts the stack, bootstraps Ollama, configures optional Tailscale/Telegram, and installs systemd autostart. |
| `docker-compose.yml` | Runs the API, PWA, n8n, and Ollama services. |
| `bradix-api/` | FastAPI endpoints, status file persistence, templates, notifications, and handlers. |
| `bradix-pwa/` | React/Tailwind PWA with care timers, voice control, AI chat, action queue, evidence vault, and offline shell. |
| `bradix-scriptable/` | iOS Scriptable automations. |
| `docs/` | Setup, entitlement, grant, protection, nomination, and link playbooks. |

## Export and link

In Manus, open the PWA project’s Code panel and select **Download all files**. The stable project version is `manus-webdev://5ac5c6ce`. To merge the exported PWA into this repository, place it under `bradix-pwa/`, then run `git add . && git commit -m "Add BRADIX PWA" && git push`.

## Safety

BRADIX is an operational aid, not legal, medical, financial, or government advice. It does not fabricate evidence, reviews, ratings, or testimonials. Review every generated draft and every outbound action before sending.
