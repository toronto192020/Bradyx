"""Environment-backed BRADIX configuration."""
from __future__ import annotations

import os

from dotenv import load_dotenv

load_dotenv()


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


class Settings:
    telegram_token = os.getenv("TELEGRAM_TOKEN", "")
    telegram_chat_id = os.getenv("TELEGRAM_CHAT_ID", "")
    ollama_host = os.getenv("OLLAMA_HOST", "http://ollama:11434").rstrip("/")
    ollama_model = os.getenv("OLLAMA_MODEL", "nous-hermes2")
    n8n_webhook_base = os.getenv("N8N_WEBHOOK_BASE", "http://n8n:5678/webhook")
    outbound_webhook_url = os.getenv("OUTBOUND_WEBHOOK_URL", "").strip()
    allow_external_send = _bool("ALLOW_EXTERNAL_SEND", False)
    tailscale_ip = os.getenv("TAILSCALE_IP", "")
    cors_origins = [item.strip() for item in os.getenv("CORS_ORIGINS", "*").split(",") if item.strip()] or ["*"]


settings = Settings()
