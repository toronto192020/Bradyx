#!/usr/bin/env bash
# Optional dependency checkout helper. It never deletes or overwrites local changes.
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="${BRADIX_DEPS_DIR:-$ROOT_DIR/dependencies}"
mkdir -p "$DEPS_DIR"

clone_or_update() {
  local name="$1" url="$2" dir="$DEPS_DIR/$1"
  if [[ -d "$dir/.git" ]]; then
    printf '[BRADIX] Checking %s\n' "$name"
    git -C "$dir" fetch --all --prune
    if [[ -z "$(git -C "$dir" status --porcelain)" ]]; then
      git -C "$dir" pull --ff-only || printf '[BRADIX] %s needs manual update\n' "$name"
    else
      printf '[BRADIX] %s has local changes; skipped pull\n' "$name"
    fi
  else
    printf '[BRADIX] Cloning %s\n' "$name"
    git clone --depth=1 "$url" "$dir"
  fi
}

clone_or_update skyvern https://github.com/Skyvern-AI/skyvern.git
clone_or_update openhands https://github.com/All-Hands-AI/OpenHands.git
clone_or_update whisper https://github.com/openai/whisper.git
clone_or_update piper https://github.com/rhasspy/piper.git
clone_or_update comfyui https://github.com/comfyanonymous/ComfyUI.git
clone_or_update home-assistant https://github.com/home-assistant/core.git
clone_or_update n8n-nodes-base https://github.com/n8n-io/n8n-nodes-base.git
clone_or_update faster-whisper https://github.com/SYSTRAN/faster-whisper.git
clone_or_update ollama https://github.com/ollama/ollama.git
clone_or_update tailscale https://github.com/tailscale/tailscale.git

printf '\n[BRADIX] Dependency checkouts are in %s\n' "$DEPS_DIR"
