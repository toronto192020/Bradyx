#!/usr/bin/env bash
# BRADIX one-shot deployment for Andrew's MSI NUC (Ubuntu).
# Usage: sudo bash BRADIX_DEPLOY.sh
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
SERVICE_NAME="bradix-compose"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

log() { printf '\n\033[1;36m[BRADIX]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[BRADIX WARNING]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[BRADIX ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'fail "Deployment failed on line $LINENO. Check: docker compose logs --tail=100"' ERR

[[ $EUID -eq 0 ]] || fail "Run with sudo: sudo bash BRADIX_DEPLOY.sh"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine and Compose plugin"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' "$(dpkg --print-architecture)" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  log "Docker already installed"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  warn "Created .env from .env.example. Add secrets before enabling external sends."
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

log "Building and starting BRADIX services"
docker compose --env-file "$ENV_FILE" up -d --build

log "Bootstrapping Ollama model: ${OLLAMA_MODEL:-nous-hermes2}"
for attempt in {1..12}; do
  if docker compose exec -T ollama ollama list >/dev/null 2>&1; then
    docker compose exec -T ollama ollama pull "${OLLAMA_MODEL:-nous-hermes2}" || warn "Model pull failed; retry with: docker compose exec ollama ollama pull ${OLLAMA_MODEL:-nous-hermes2}"
    break
  fi
  sleep 5
done

if command -v tailscale >/dev/null 2>&1; then
  if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
    log "Connecting Tailscale"
    tailscale up --authkey "$TAILSCALE_AUTHKEY" --hostname "${TAILSCALE_HOSTNAME:-bradix-nuc}" --accept-dns=true || warn "Tailscale connection needs manual review"
  else
    warn "TAILSCALE_AUTHKEY not set; skipping automatic Tailscale login"
  fi
else
  warn "Tailscale is not installed. Install it from https://tailscale.com/download/linux and rerun."
fi

if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_WEBHOOK_URL:-}" ]]; then
  log "Configuring Telegram webhook"
  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook" --data-urlencode "url=${TELEGRAM_WEBHOOK_URL}" || warn "Telegram webhook configuration failed"
else
  warn "TELEGRAM_TOKEN or TELEGRAM_WEBHOOK_URL missing; skipping Telegram webhook"
fi

log "Installing systemd autostart service"
cat > "$SERVICE_FILE" <<UNIT
[Unit]
Description=BRADIX Docker Compose Stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$ROOT_DIR
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose --env-file $ENV_FILE up -d
ExecStop=/usr/bin/docker compose --env-file $ENV_FILE down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

log "Deployment complete"
printf 'Dashboard: http://%s:%s\n' "${TAILSCALE_IP:-localhost}" "${BRADIX_PWA_PORT:-80}"
printf 'API health: http://%s:%s/health\n' "${TAILSCALE_IP:-localhost}" "${BRADIX_API_PORT:-8080}"
printf 'n8n: http://%s:%s\n' "${TAILSCALE_IP:-localhost}" "${N8N_PORT:-5678}"
printf 'Status: docker compose ps\n'
