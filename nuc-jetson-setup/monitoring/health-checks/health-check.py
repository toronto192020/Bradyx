#!/usr/bin/env python3
"""
Bradix Health Check — Quiet Guardian System Monitor
====================================================
Checks the health of all Bradix services and reports
only when something actually needs attention.

The default state is silence. This script runs every
15 minutes via cron and only sends an alert if a
service is genuinely down or degraded.

Usage:
    python3 health-check.py
    python3 health-check.py --verbose   # Show all status, not just issues
    python3 health-check.py --report    # Output JSON status report
"""

import os
import sys
import json
import time
import smtplib
import argparse
import requests
import subprocess
from datetime import datetime, timezone
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ─── Configuration ───────────────────────────────────────────
CONFIG = {
    "services": {
        "n8n": {
            "url": "http://localhost:5678/healthz",
            "name": "n8n Orchestration",
            "critical": True,
        },
        "jetson": {
            "url": os.getenv("JETSON_ENDPOINT", "http://jetson.local:8000") + "/health",
            "name": "Jetson AI Inference",
            "critical": False,  # Jetson offline doesn't stop core functions
        },
        "postgres": {
            "check": "docker",
            "container": "bradix-postgres",
            "name": "PostgreSQL Database",
            "critical": True,
        },
        "dashboard": {
            "url": "http://localhost:8080/health",
            "name": "Status Dashboard",
            "critical": False,
        },
    },
    "case_data": {
        "path": os.getenv("CASE_DATA_PATH", "/opt/bradix/case-data"),
        "required_files": [
            "cheryl-bruce-sanders/agent_task_tracker.json",
            "cheryl-bruce-sanders/case_data.json",
            "cheryl-bruce-sanders/monitoring_alerts.yaml",
        ],
    },
    "email": {
        "smtp_host": os.getenv("SMTP_HOST", ""),
        "smtp_port": int(os.getenv("SMTP_PORT", "587")),
        "smtp_user": os.getenv("SMTP_USER", ""),
        "smtp_pass": os.getenv("SMTP_PASS", ""),
        "sender": os.getenv("SMTP_SENDER", "Bradix Guardian <noreply@bradix.local>"),
        "recipients": [
            os.getenv("ALERT_EMAIL_PRIMARY", "bts@outlook.com"),
        ],
    },
    "alert_cooldown_file": "/var/log/bradix/last_alert.json",
    "cooldown_hours": 4,  # Don't re-alert for the same issue within 4 hours
}


def check_http_service(name: str, url: str) -> dict:
    """Check an HTTP service endpoint."""
    try:
        resp = requests.get(url, timeout=5)
        if resp.status_code == 200:
            return {"name": name, "status": "healthy", "url": url}
        else:
            return {
                "name": name,
                "status": "degraded",
                "url": url,
                "detail": f"HTTP {resp.status_code}",
            }
    except requests.exceptions.ConnectionError:
        return {"name": name, "status": "down", "url": url, "detail": "Connection refused"}
    except requests.exceptions.Timeout:
        return {"name": name, "status": "degraded", "url": url, "detail": "Timeout"}
    except Exception as e:
        return {"name": name, "status": "unknown", "url": url, "detail": str(e)}


def check_docker_container(name: str, container: str) -> dict:
    """Check if a Docker container is running."""
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format", "{{.State.Status}}", container],
            capture_output=True, text=True, timeout=5
        )
        status = result.stdout.strip()
        if status == "running":
            return {"name": name, "status": "healthy", "container": container}
        else:
            return {
                "name": name,
                "status": "down",
                "container": container,
                "detail": f"Container status: {status}",
            }
    except Exception as e:
        return {"name": name, "status": "unknown", "container": container, "detail": str(e)}


def check_case_data(config: dict) -> dict:
    """Check that case data files are present and readable."""
    issues = []
    for f in config["required_files"]:
        full_path = os.path.join(config["path"], f)
        if not os.path.exists(full_path):
            issues.append(f"Missing: {f}")
        elif not os.access(full_path, os.R_OK):
            issues.append(f"Unreadable: {f}")

    if issues:
        return {"name": "Case Data", "status": "degraded", "issues": issues}
    return {"name": "Case Data", "status": "healthy"}


def check_last_sync() -> dict:
    """Check when case data was last synced from GitHub."""
    sync_log = "/var/log/bradix/last_sync.txt"
    if not os.path.exists(sync_log):
        return {"name": "GitHub Sync", "status": "unknown", "detail": "No sync log found"}

    try:
        with open(sync_log) as f:
            last_sync_str = f.read().strip()
        last_sync = datetime.fromisoformat(last_sync_str)
        now = datetime.now(timezone.utc)
        hours_since = (now - last_sync.replace(tzinfo=timezone.utc)).total_seconds() / 3600

        if hours_since > 25:
            return {
                "name": "GitHub Sync",
                "status": "degraded",
                "detail": f"Last sync was {hours_since:.0f} hours ago",
            }
        return {
            "name": "GitHub Sync",
            "status": "healthy",
            "detail": f"Last sync: {last_sync_str}",
        }
    except Exception as e:
        return {"name": "GitHub Sync", "status": "unknown", "detail": str(e)}


def run_all_checks() -> dict:
    """Run all health checks and return a consolidated report."""
    results = []
    issues = []

    for svc_id, svc in CONFIG["services"].items():
        if svc.get("check") == "docker":
            result = check_docker_container(svc["name"], svc["container"])
        else:
            result = check_http_service(svc["name"], svc["url"])

        result["critical"] = svc.get("critical", False)
        results.append(result)

        if result["status"] != "healthy" and svc.get("critical", False):
            issues.append(result)

    results.append(check_case_data(CONFIG["case_data"]))
    results.append(check_last_sync())

    overall = "healthy" if not issues else "degraded"

    return {
        "timestamp": datetime.now().isoformat(),
        "overall": overall,
        "services": results,
        "critical_issues": issues,
    }


def should_send_alert(issue_key: str) -> bool:
    """Check cooldown to avoid spamming alerts for the same issue."""
    cooldown_file = CONFIG["alert_cooldown_file"]
    os.makedirs(os.path.dirname(cooldown_file), exist_ok=True)

    try:
        if os.path.exists(cooldown_file):
            with open(cooldown_file) as f:
                cooldowns = json.load(f)
            if issue_key in cooldowns:
                last_alert = datetime.fromisoformat(cooldowns[issue_key])
                hours_since = (datetime.now() - last_alert).total_seconds() / 3600
                if hours_since < CONFIG["cooldown_hours"]:
                    return False
    except Exception:
        pass
    return True


def record_alert_sent(issue_key: str):
    """Record that an alert was sent to enforce cooldown."""
    cooldown_file = CONFIG["alert_cooldown_file"]
    try:
        cooldowns = {}
        if os.path.exists(cooldown_file):
            with open(cooldown_file) as f:
                cooldowns = json.load(f)
        cooldowns[issue_key] = datetime.now().isoformat()
        with open(cooldown_file, "w") as f:
            json.dump(cooldowns, f)
    except Exception:
        pass


def send_alert_email(issues: list):
    """Send a calm, clear alert email for critical issues."""
    if not CONFIG["email"]["smtp_host"]:
        print("[bradix] Email not configured — skipping alert email")
        return

    issue_text = "\n".join([
        f"  • {i['name']}: {i.get('detail', i['status'])}"
        for i in issues
    ])

    body = f"""Hi Andrew,

The Bradix system has detected an issue that needs attention:

{issue_text}

This is a system health alert — your case data and workflows are not affected unless the database or n8n service is down.

To check status: http://nuc.local:8080
To restart services: cd /opt/bradix && docker compose restart

Bradix
"""

    msg = MIMEMultipart()
    msg["From"] = CONFIG["email"]["sender"]
    msg["To"] = ", ".join(CONFIG["email"]["recipients"])
    msg["Subject"] = f"Bradix — System issue detected ({datetime.now().strftime('%a %d %b')})"
    msg.attach(MIMEText(body, "plain"))

    try:
        with smtplib.SMTP(CONFIG["email"]["smtp_host"], CONFIG["email"]["smtp_port"]) as server:
            server.starttls()
            server.login(CONFIG["email"]["smtp_user"], CONFIG["email"]["smtp_pass"])
            server.sendmail(
                CONFIG["email"]["smtp_user"],
                CONFIG["email"]["recipients"],
                msg.as_string()
            )
        print(f"[bradix] Alert email sent for {len(issues)} issue(s)")
    except Exception as e:
        print(f"[bradix] Failed to send alert email: {e}")


def main():
    parser = argparse.ArgumentParser(description="Bradix Health Check")
    parser.add_argument("--verbose", action="store_true", help="Show all status, not just issues")
    parser.add_argument("--report", action="store_true", help="Output JSON status report")
    args = parser.parse_args()

    report = run_all_checks()

    if args.report:
        print(json.dumps(report, indent=2))
        return

    if args.verbose:
        print(f"[bradix] Health check — {report['timestamp']}")
        for svc in report["services"]:
            icon = "✓" if svc["status"] == "healthy" else "✗"
            print(f"  {icon} {svc['name']}: {svc['status']}")
        print(f"\nOverall: {report['overall'].upper()}")

    # Only alert on critical issues, with cooldown
    if report["critical_issues"]:
        new_issues = []
        for issue in report["critical_issues"]:
            issue_key = f"{issue['name']}_{issue['status']}"
            if should_send_alert(issue_key):
                new_issues.append(issue)
                record_alert_sent(issue_key)

        if new_issues:
            send_alert_email(new_issues)
        elif not args.verbose:
            pass  # Cooldown active — stay quiet


if __name__ == "__main__":
    main()
