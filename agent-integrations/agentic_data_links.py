#!/usr/bin/env python3
"""
Bradix Agentic Data Links
==========================
Manages autonomous (agentic) connections to external APIs and systems.

Each "data link" is a registered connector that can:
  - Pull data from external sources on a schedule
  - Push data or trigger actions when conditions are met
  - Retry failed connections with exponential backoff
  - Log all interactions for audit and debugging

Data link types:
  - webhook  : HTTP POST to an endpoint (n8n, custom services)
  - rest_api : HTTP GET/POST to a REST API (AustLII, government portals)
  - jetson   : Local Jetson AI inference server
  - file     : Read from or write to a local file path

Usage:
    python3 agentic_data_links.py                   # Run all enabled links
    python3 agentic_data_links.py --list            # List all registered links
    python3 agentic_data_links.py --trigger <name>  # Trigger a specific link
    python3 agentic_data_links.py --status          # Show link health status
    python3 agentic_data_links.py --report          # Output JSON status report
"""

import os
import sys
import json
import time
import logging
import argparse
import traceback
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# ─── Configuration ────────────────────────────────────────────────────────────

LOG_DIR = os.getenv("BRADIX_LOG_DIR", os.path.expanduser("~/bradix/logs"))
STATE_FILE = os.path.join(LOG_DIR, "data_links_state.json")
JETSON_ENDPOINT = os.getenv("JETSON_ENDPOINT", "http://jetson.local:8000")
N8N_ENDPOINT = os.getenv("N8N_ENDPOINT", "http://localhost:5678")
CASE_DATA_PATH = os.getenv("CASE_DATA_PATH", os.path.expanduser("~/bradix/case-data"))

MAX_RETRIES = 3
RETRY_BASE_DELAY = 5  # seconds

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [bradix-links] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("bradix-links")


# ─── Types ────────────────────────────────────────────────────────────────────

class LinkType(str, Enum):
    WEBHOOK = "webhook"
    REST_API = "rest_api"
    JETSON = "jetson"
    FILE = "file"


class LinkStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    DOWN = "down"
    UNKNOWN = "unknown"
    DISABLED = "disabled"


# ─── Data Link Registry ───────────────────────────────────────────────────────

# Each entry defines a data link connector available to the agentic system.
# To add a new link, append an entry to DATA_LINKS_REGISTRY.
DATA_LINKS_REGISTRY: List[Dict[str, Any]] = [
    {
        "name": "n8n-webhook-deadline",
        "description": "Trigger n8n deadline check workflow",
        "type": LinkType.WEBHOOK,
        "enabled": True,
        "url": f"{N8N_ENDPOINT}/webhook/bradix-deadline-check",
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "payload": {"source": "agentic_data_links", "trigger": "deadline_check"},
        "timeout": 15,
    },
    {
        "name": "jetson-health",
        "description": "Check Jetson AI inference server health",
        "type": LinkType.JETSON,
        "enabled": True,
        "url": f"{JETSON_ENDPOINT}/health",
        "method": "GET",
        "timeout": 10,
    },
    {
        "name": "jetson-query",
        "description": "Query Jetson AI about case status",
        "type": LinkType.JETSON,
        "enabled": True,
        "url": f"{JETSON_ENDPOINT}/query",
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "payload": {
            "question": "What are the most urgent tasks in the next 48 hours?",
            "include_case_context": True,
        },
        "timeout": 120,
    },
    {
        "name": "austlii-legal-search",
        "description": "Search AustLII for relevant Queensland case law",
        "type": LinkType.REST_API,
        "enabled": True,
        "url": "https://www.austlii.edu.au/cgi-bin/sinosrch.cgi",
        "method": "GET",
        "params": {
            "method": "auto",
            "query": "QCAT guardianship capacity CAA Queensland",
            "db": "qld",
        },
        "timeout": 30,
    },
    {
        "name": "task-tracker-read",
        "description": "Read the agent task tracker file",
        "type": LinkType.FILE,
        "enabled": True,
        "path": os.path.join(
            CASE_DATA_PATH, "cheryl-bruce-sanders", "agent_task_tracker.json"
        ),
        "operation": "read",
    },
    {
        "name": "monitoring-alerts-read",
        "description": "Read the monitoring alerts configuration",
        "type": LinkType.FILE,
        "enabled": True,
        "path": os.path.join(
            CASE_DATA_PATH, "cheryl-bruce-sanders", "monitoring_alerts.yaml"
        ),
        "operation": "read",
    },
    {
        "name": "n8n-webhook-healing",
        "description": "Notify n8n when a healing action is taken",
        "type": LinkType.WEBHOOK,
        "enabled": True,
        "url": f"{N8N_ENDPOINT}/webhook/bradix-healing-event",
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "payload": {"source": "healing_automation", "event": "healing_action"},
        "timeout": 15,
    },
]


# ─── Core Link Executor ───────────────────────────────────────────────────────

def _http_request(
    url: str,
    method: str = "GET",
    headers: Optional[Dict] = None,
    payload: Optional[Dict] = None,
    params: Optional[Dict] = None,
    timeout: int = 15,
) -> Dict[str, Any]:
    """Execute an HTTP request and return a normalised result dict."""
    if not HAS_REQUESTS:
        return {
            "success": False,
            "error": "requests library not installed. Run: pip install requests",
        }
    try:
        kwargs: Dict[str, Any] = {"timeout": timeout, "headers": headers or {}}
        if params:
            kwargs["params"] = params
        if method.upper() == "POST":
            kwargs["json"] = payload or {}
        resp = requests.request(method.upper(), url, **kwargs)
        return {
            "success": resp.status_code < 400,
            "status_code": resp.status_code,
            "body": resp.text[:2000],  # Truncate long responses
        }
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def _file_operation(path: str, operation: str) -> Dict[str, Any]:
    """Execute a file read/write operation and return a normalised result dict."""
    try:
        if operation == "read":
            if not os.path.exists(path):
                return {"success": False, "error": f"File not found: {path}"}
            with open(path) as fh:
                content = fh.read()
            return {"success": True, "content": content[:4000], "path": path}
        return {"success": False, "error": f"Unknown file operation: {operation}"}
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def trigger_link(link: Dict[str, Any]) -> Dict[str, Any]:
    """
    Execute a single data link connector.

    Returns a result dict with at minimum:
        success  (bool)
        duration_ms (int)
        timestamp (str)
    """
    if not link.get("enabled", True):
        return {
            "name": link["name"],
            "success": True,
            "status": LinkStatus.DISABLED,
            "timestamp": datetime.now().isoformat(),
        }

    start = time.time()
    link_type = link.get("type")
    result: Dict[str, Any] = {}

    try:
        if link_type in (LinkType.WEBHOOK, LinkType.REST_API, LinkType.JETSON):
            result = _http_request(
                url=link["url"],
                method=link.get("method", "GET"),
                headers=link.get("headers"),
                payload=link.get("payload"),
                params=link.get("params"),
                timeout=link.get("timeout", 15),
            )
        elif link_type == LinkType.FILE:
            result = _file_operation(link["path"], link.get("operation", "read"))
        else:
            result = {"success": False, "error": f"Unknown link type: {link_type}"}
    except Exception as exc:
        result = {"success": False, "error": traceback.format_exc()}
        logger.error(f"[{link['name']}] Unhandled exception: {exc}")

    elapsed_ms = int((time.time() - start) * 1000)
    status = LinkStatus.HEALTHY if result.get("success") else LinkStatus.DOWN

    return {
        "name": link["name"],
        "description": link.get("description", ""),
        "type": str(link_type),
        "success": result.get("success", False),
        "status": str(status),
        "duration_ms": elapsed_ms,
        "timestamp": datetime.now().isoformat(),
        **{k: v for k, v in result.items() if k != "success"},
    }


def trigger_link_with_retry(link: Dict[str, Any]) -> Dict[str, Any]:
    """
    Trigger a data link with exponential backoff retry.

    Retries up to MAX_RETRIES times before giving up.
    Backoff: 5s, 10s, 20s (doubles each attempt).
    """
    last_result: Dict[str, Any] = {}
    delay = RETRY_BASE_DELAY

    for attempt in range(1, MAX_RETRIES + 1):
        result = trigger_link(link)
        last_result = result

        if result.get("success") or result.get("status") == str(LinkStatus.DISABLED):
            if attempt > 1:
                logger.info(
                    f"[{link['name']}] Recovered after {attempt} attempt(s)"
                )
            return result

        logger.warning(
            f"[{link['name']}] Attempt {attempt}/{MAX_RETRIES} failed: "
            f"{result.get('error', result.get('status_code', 'unknown'))}"
        )

        if attempt < MAX_RETRIES:
            logger.info(f"[{link['name']}] Retrying in {delay}s...")
            time.sleep(delay)
            delay *= 2

    last_result["retries_exhausted"] = True
    logger.error(f"[{link['name']}] All {MAX_RETRIES} attempts failed.")
    return last_result


# ─── State Persistence ────────────────────────────────────────────────────────

def _load_state() -> Dict[str, Any]:
    """Load persisted link state from disk."""
    os.makedirs(LOG_DIR, exist_ok=True)
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE) as fh:
                return json.load(fh)
    except Exception:
        pass
    return {}


def _save_state(state: Dict[str, Any]) -> None:
    """Persist link state to disk."""
    os.makedirs(LOG_DIR, exist_ok=True)
    try:
        with open(STATE_FILE, "w") as fh:
            json.dump(state, fh, indent=2)
    except Exception as exc:
        logger.warning(f"Could not save state: {exc}")


# ─── High-Level Actions ───────────────────────────────────────────────────────

def run_all_links(dry_run: bool = False) -> List[Dict[str, Any]]:
    """
    Trigger all enabled data links and return a list of results.

    In dry_run mode, shows what would be triggered without executing.
    """
    results = []
    state = _load_state()

    for link in DATA_LINKS_REGISTRY:
        if not link.get("enabled", True):
            logger.info(f"[{link['name']}] Skipped (disabled)")
            results.append(
                {
                    "name": link["name"],
                    "status": str(LinkStatus.DISABLED),
                    "success": True,
                }
            )
            continue

        if dry_run:
            logger.info(
                f"[DRY RUN] Would trigger: {link['name']} "
                f"({link.get('type', '?')}) — {link.get('description', '')}"
            )
            results.append(
                {
                    "name": link["name"],
                    "type": str(link.get("type")),
                    "description": link.get("description", ""),
                    "status": "dry_run",
                    "success": True,
                }
            )
            continue

        logger.info(f"[{link['name']}] Triggering ({link.get('type', '?')})...")
        result = trigger_link_with_retry(link)
        results.append(result)

        # Update persisted state
        state[link["name"]] = {
            "last_run": result["timestamp"],
            "last_status": result.get("status"),
            "last_success": result.get("success"),
        }

    _save_state(state)
    return results


def trigger_single_link(name: str) -> Optional[Dict[str, Any]]:
    """Find a link by name and trigger it (with retries)."""
    for link in DATA_LINKS_REGISTRY:
        if link["name"] == name:
            logger.info(f"Triggering link: {name}")
            return trigger_link_with_retry(link)
    logger.error(f"No link found with name: '{name}'")
    return None


def get_status() -> Dict[str, Any]:
    """Return current status of all links, merged with persisted state."""
    state = _load_state()
    links_status = []

    for link in DATA_LINKS_REGISTRY:
        entry: Dict[str, Any] = {
            "name": link["name"],
            "description": link.get("description", ""),
            "type": str(link.get("type")),
            "enabled": link.get("enabled", True),
        }
        if link["name"] in state:
            entry.update(state[link["name"]])
        else:
            entry["last_run"] = None
            entry["last_status"] = str(LinkStatus.UNKNOWN)
        links_status.append(entry)

    return {
        "timestamp": datetime.now().isoformat(),
        "total_links": len(DATA_LINKS_REGISTRY),
        "enabled_links": sum(1 for l in DATA_LINKS_REGISTRY if l.get("enabled", True)),
        "links": links_status,
    }


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bradix Agentic Data Links — autonomous connector manager"
    )
    parser.add_argument("--list", action="store_true", help="List all registered links")
    parser.add_argument("--trigger", metavar="NAME", help="Trigger a specific link by name")
    parser.add_argument("--status", action="store_true", help="Show link health status")
    parser.add_argument("--report", action="store_true", help="Output full JSON report")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be triggered")
    args = parser.parse_args()

    if args.list:
        print("\nRegistered Bradix Data Links:")
        print("-" * 60)
        for link in DATA_LINKS_REGISTRY:
            enabled = "ON " if link.get("enabled", True) else "OFF"
            print(f"  [{enabled}] {link['name']:<35} {link.get('description', '')}")
        print()
        return

    if args.trigger:
        result = trigger_single_link(args.trigger)
        if result:
            print(json.dumps(result, indent=2))
        else:
            sys.exit(1)
        return

    if args.status:
        status = get_status()
        print(f"\nBradix Data Links — {status['timestamp']}")
        print(f"  {status['enabled_links']}/{status['total_links']} links enabled")
        print("-" * 60)
        for link in status["links"]:
            last = link.get("last_status", "never run")
            ran = link.get("last_run", "—")
            enabled = "ON " if link.get("enabled") else "OFF"
            print(f"  [{enabled}] {link['name']:<35} {last}  (last: {ran})")
        print()
        return

    # Default: run all links (or dry-run)
    results = run_all_links(dry_run=args.dry_run)

    if args.report:
        report = {
            "timestamp": datetime.now().isoformat(),
            "dry_run": args.dry_run,
            "total": len(results),
            "succeeded": sum(1 for r in results if r.get("success")),
            "failed": sum(1 for r in results if not r.get("success")),
            "results": results,
        }
        print(json.dumps(report, indent=2))
        return

    # Summary output
    succeeded = sum(1 for r in results if r.get("success"))
    failed = len(results) - succeeded
    print(f"\n[bradix-links] Run complete — {succeeded} OK, {failed} failed")
    if failed > 0:
        print("Failed links:")
        for r in results:
            if not r.get("success"):
                print(f"  !! {r['name']}: {r.get('error', r.get('status', 'unknown'))}")
        sys.exit(1)


if __name__ == "__main__":
    main()
