# Bradix Healing Automation
## Autonomous Self-Correction and System Maintenance

---

## WHAT IS HEALING AUTOMATION?

**Healing Automation** is the self-correction layer of the Bradix platform. When the Quiet Guardian health check detects a problem, instead of only sending Andrew an alert, the Healing Automation system:

1. **Diagnoses** — identifies exactly what is broken and why
2. **Heals** — attempts automatic corrective actions
3. **Verifies** — runs a second diagnostic to confirm the fix worked
4. **Escalates** — only alerts Andrew if automatic healing failed

The principle: *Andrew should only be interrupted for things the system genuinely cannot fix itself.*

---

## HOW IT WORKS

```
BRADIX HEALING AUTOMATION CYCLE
─────────────────────────────────────────────────────────────

  1. PRE-CHECK (full diagnostics)
     ├─ Docker containers running?
     ├─ n8n HTTP responding?
     ├─ Jetson AI reachable?
     ├─ Disk space acceptable?
     └─ Case data files intact?
             ↓
  2. ISSUE DETECTION
     └─ Collect list of unhealthy components
             ↓
  3. HEALING ACTIONS (per issue type)
     ├─ Container down → docker restart <container>
     ├─ Disk high     → clean old rotated logs
     └─ [extensible]  → add new healers as needed
             ↓
  4. POST-CHECK (repeat diagnostics)
     └─ Compare before/after to determine what was fixed
             ↓
  5. OUTCOME
     ├─ All resolved → log success, stay quiet
     └─ Still broken → log failure, email Andrew
```

---

## WHAT CAN BE HEALED AUTOMATICALLY

### Docker Containers

If a container is stopped or crashed, the system runs `docker restart <container>`:

| Container | Criticality | Action |
|-----------|-------------|--------|
| `bradix-n8n` | Critical | Restart |
| `bradix-postgres` | Critical | Restart |
| `bradix-redis` | Non-critical | Restart |

### Disk Space

If disk usage exceeds 85% on monitored paths (`/` or `~/`), the system:
- Scans configured log directories for rotated log files (`.gz`, `.1`, `.2`, `.3`)
- Removes files older than 30 days
- Reports how many files were cleaned and how much space was freed

> **Safe by design:** Only removes rotated/numbered log archives, never current log files or case data.

### Tailscale Reconnection

If Tailscale has dropped its VPN connection, the system runs `tailscale up` to reconnect. This ensures Bradix remains accessible remotely even after a network interruption.

---

## WHAT REQUIRES MANUAL INTERVENTION

The system escalates to Andrew (via email) when:

- A Docker container cannot be restarted (engine error, image issue)
- Disk space cannot be freed sufficiently (full disk, no old logs to clean)
- Case data files are corrupted or missing (JSON parse errors)
- Any critical service fails to recover after automatic healing

---

## USAGE

### Full Healing Cycle

```bash
# Run full diagnostics + healing + verification
python3 one-click-install/monitoring/healing_automation.py

# Preview what would be done (no changes made)
python3 one-click-install/monitoring/healing_automation.py --dry-run

# Full JSON report
python3 one-click-install/monitoring/healing_automation.py --report
```

### Diagnostics Only

```bash
# Check system status without any healing actions
python3 one-click-install/monitoring/healing_automation.py --status

# Diagnostics as JSON
python3 one-click-install/monitoring/healing_automation.py --status --report
```

### Example Output

```
[bradix-healing] Starting Bradix healing cycle...
[bradix-healing] Healing container 'bradix-n8n' (status: exited)
[bradix-healing] Waiting 10s for services to stabilise...
[bradix-healing] Resolved: container:bradix-n8n
[bradix-healing] Healing cycle complete — 1 action(s) taken, 1 resolved, 0 unresolved
```

---

## HEALING LOG

Every healing cycle is logged to `~/bradix/logs/healing_actions.json`. Each entry records:

```json
{
  "timestamp": "2026-04-03T08:15:00",
  "dry_run": false,
  "actions_taken": 1,
  "resolved": ["container:bradix-n8n"],
  "unresolved": [],
  "overall_healed": true
}
```

The log retains the last 100 entries (older entries are automatically rotated out).

---

## ENVIRONMENT VARIABLES

| Variable | Default | Description |
|----------|---------|-------------|
| `BRADIX_LOG_DIR` | `~/bradix/logs` | Log directory for healing records |
| `CASE_DATA_PATH` | `~/bradix/case-data` | Path to case data files |
| `JETSON_ENDPOINT` | `http://jetson.local:8000` | Jetson AI server URL |
| `DISK_WARN_PERCENT` | `85` | Disk % at which cleaning starts |
| `DISK_CRIT_PERCENT` | `95` | Disk % at which alert is sent |
| `SMTP_HOST` | *(empty)* | SMTP server for escalation emails |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(empty)* | SMTP username |
| `SMTP_PASS` | *(empty)* | SMTP password |
| `SMTP_SENDER` | `Bradix Guardian <bts@outlook.com>` | Email From header |
| `ALERT_EMAIL_PRIMARY` | `bts@outlook.com` | Primary alert recipient |

---

## AUTOMATION (Cron)

Add to crontab to run healing checks automatically:

```bash
# Run healing automation every 15 minutes (same cadence as health-check)
*/15 * * * * python3 /path/to/Bradyx/one-click-install/monitoring/healing_automation.py >> ~/bradix/logs/healing.log 2>&1
```

This replaces or supplements the existing `health-check.py` cron entry. Both scripts can run concurrently — `health-check.py` handles alerting, `healing_automation.py` handles repair.

---

## EXTENDING THE HEALING ENGINE

To add a new healing action:

1. Add a new `heal_<thing>()` function in `healing_automation.py`:

```python
def heal_cloudflared(dry_run: bool = False) -> Dict[str, Any]:
    """Restart the Cloudflare Tunnel if it has stopped."""
    action = "systemctl restart cloudflared"
    if dry_run:
        return {"action": action, "dry_run": True, "success": True}
    try:
        result = subprocess.run(
            ["systemctl", "restart", "cloudflared"],
            capture_output=True, text=True, timeout=30
        )
        return {
            "action": action,
            "success": result.returncode == 0,
            "detail": result.stdout.strip() or result.stderr.strip(),
        }
    except Exception as exc:
        return {"action": action, "success": False, "detail": str(exc)}
```

2. Call it in `run_healing_cycle()` after the appropriate diagnostic check.

3. Add the corresponding diagnostic check to `run_full_diagnostics()` if not already present.

---

## INTEGRATION WITH AGENTIC DATA LINKS

When healing completes, it can notify n8n via the `n8n-webhook-healing` data link. This allows:

- n8n to log the healing event in the case tracker
- n8n to update a dashboard or monitoring view
- n8n to escalate if healing keeps failing on the same component

See [AGENTIC_DATA_LINKS.md](./AGENTIC_DATA_LINKS.md) for details.

---

## JETSON INFERENCE SERVER — NEW ENDPOINTS

The Jetson inference server (`nuc-jetson-setup/jetson/inference-server/server.py`) now includes two new endpoints that support agentic and healing workflows:

### `POST /agent/trigger`

Triggers an agentic workflow step using the local LLM.

**Supported workflows:**

| Workflow | Description |
|----------|-------------|
| `deadline_check` | Scan case data for upcoming deadlines |
| `weekly_digest` | Generate a weekly briefing |
| `healing_scan` | Identify stalled or inconsistent tasks |
| `custom` | Run a custom prompt (set `payload.prompt`) |

**Example:**

```bash
curl -X POST http://jetson.local:8000/agent/trigger \
  -H "Content-Type: application/json" \
  -d '{"workflow": "deadline_check"}'
```

**Async mode** (returns immediately, runs in background):

```bash
curl -X POST http://jetson.local:8000/agent/trigger \
  -H "Content-Type: application/json" \
  -d '{"workflow": "healing_scan", "async_exec": true}'
```

### `GET /health/diagnose`

Extended system diagnostics — returns more detail than the basic `/health` endpoint:

```bash
curl http://jetson.local:8000/health/diagnose
```

Returns:
- Ollama status and available models
- Disk usage on the case data path
- Case data file presence check
- Python runtime and platform info

---

*Document prepared: April 2026 | BRADIX Case Management System*
