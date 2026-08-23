"""Best-effort Telegram notifications for BRADIX."""
from __future__ import annotations

import logging

import requests

from config import settings

LOGGER = logging.getLogger("bradix.notifications")


def send_telegram_notification(message: str) -> bool:
    if not settings.telegram_token or not settings.telegram_chat_id:
        return False
    url = f"https://api.telegram.org/bot{settings.telegram_token}/sendMessage"
    try:
        response = requests.post(url, json={"chat_id": settings.telegram_chat_id, "text": message}, timeout=12)
        response.raise_for_status()
        return True
    except requests.RequestException as exc:
        LOGGER.warning("Telegram notification failed: %s", exc)
        return False
