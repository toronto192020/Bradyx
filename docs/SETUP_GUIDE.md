# BRADIX setup guide

## Before deployment

Use an Ubuntu machine with SSH access, a stable LAN connection, and enough disk space for Docker images and the Ollama model. Keep the NUC clock correct and ensure the account used for deployment has sudo access.

## Install

```bash
git clone https://github.com/toronto192020/Bradyx.git
cd Bradyx
cp .env.example .env
chmod 600 .env
nano .env
sudo bash BRADIX_DEPLOY.sh
```

Set `TAILSCALE_AUTHKEY` only if automatic enrollment is wanted. Otherwise install Tailscale, run `sudo tailscale up`, and place the resulting NUC address in `TAILSCALE_IP`. Set `BRADIX_API_URL` to `http://TAILSCALE_IP:8080` before rebuilding if the PWA is accessed from another device.

## Verify

```bash
docker compose ps
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/status
systemctl status bradix-compose
```

Open `http://TAILSCALE_IP/` for the PWA and `http://TAILSCALE_IP:5678` for n8n. Ollama remains bound to localhost by design; the API proxies chat requests internally.

## Telegram

Create a bot with BotFather, place the token and chat ID in `.env`, and provide a reachable HTTPS `TELEGRAM_WEBHOOK_URL`. Re-run the deployment script to register the webhook. If the NUC is only reachable through Tailscale, use a separate HTTPS relay or keep notifications outbound-only through the bot API.

## Maintenance

```bash
docker compose pull
docker compose up -d --build
docker compose logs --tail=100 bradix-api
```

Back up the Docker volumes before upgrades. Keep `ALLOW_EXTERNAL_SEND=false` until every outbound workflow is explicitly tested. To stop the stack, run `docker compose down`; to restart it, run `sudo systemctl restart bradix-compose`.
