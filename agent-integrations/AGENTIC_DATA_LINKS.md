# Bradix Agentic Data Links
## Autonomous External Connections for the Bradix Platform

---

## WHAT ARE AGENTIC DATA LINKS?

An **agentic data link** is an autonomous connector that allows Bradix to communicate with external APIs and local systems *without requiring manual input*. Rather than relying on Andrew to manually check statuses and copy data between systems, data links allow Bradix to:

- **Pull** information from external sources on a schedule
- **Push** alerts and actions to external endpoints when conditions are met
- **Self-correct** when a connection fails, using built-in retry logic
- **Log** every interaction for auditability

Think of data links as the nervous system of the Bradix agentic layer — they provide the actionable connections that turn isolated tools into an integrated, self-operating platform.

---

## HOW IT WORKS

```
BRADIX AGENTIC DATA LINKS
─────────────────────────
External Sources                   Bradix Core                    Outputs
─────────────                      ────────────                   ───────
AustLII ──────────────────────────→ agentic_data_links.py ──────→ Case data updates
n8n workflows ────────────────────→ (retry + backoff)    ──────→ n8n webhook triggers
Jetson AI server ─────────────────→ (logging + state)    ──────→ AI analysis results
Local case files ─────────────────→                      ──────→ Status reports
```

---

## ARCHITECTURE

`agent-integrations/agentic_data_links.py` implements:

### Data Link Registry

Every connector is defined as a dictionary entry in `DATA_LINKS_REGISTRY`. Adding a new connector requires no code changes beyond adding an entry to the registry.

**Link types:**

| Type | Description | Example |
|------|-------------|---------|
| `webhook` | HTTP POST to trigger a remote workflow | n8n, Zapier |
| `rest_api` | HTTP GET/POST to a data-returning API | AustLII, government portals |
| `jetson` | Local Jetson AI inference server | `/query`, `/generate-report` |
| `file` | Read from or write to a local file | case_data.json, alerts.yaml |

### Pre-built Links

| Name | Type | Description |
|------|------|-------------|
| `n8n-webhook-deadline` | webhook | Trigger n8n deadline check |
| `jetson-health` | jetson | Check Jetson AI server health |
| `jetson-query` | jetson | Query AI about urgent tasks |
| `austlii-legal-search` | rest_api | Search Queensland case law |
| `task-tracker-read` | file | Read agent_task_tracker.json |
| `monitoring-alerts-read` | file | Read alert configuration |
| `n8n-webhook-healing` | webhook | Notify n8n of healing events |

### Retry Logic

All links use exponential backoff retry:

```
Attempt 1 → fail → wait 5s
Attempt 2 → fail → wait 10s
Attempt 3 → fail → log error, continue
```

Retry behaviour can be tuned via `MAX_RETRIES` and `RETRY_BASE_DELAY`.

### State Persistence

Link state (last run time, last status) is saved to `~/bradix/logs/data_links_state.json`. This allows the system to track link health across restarts.

---

## USAGE

### Run All Links

```bash
# Trigger all enabled data links
python3 agent-integrations/agentic_data_links.py

# See what would be triggered (no actual requests)
python3 agent-integrations/agentic_data_links.py --dry-run

# Full JSON report
python3 agent-integrations/agentic_data_links.py --report
```

### List Registered Links

```bash
python3 agent-integrations/agentic_data_links.py --list

# Output:
# Registered Bradix Data Links:
# ─────────────────────────────────────────────────────────
#   [ON ] n8n-webhook-deadline          Trigger n8n deadline check workflow
#   [ON ] jetson-health                 Check Jetson AI inference server health
#   [ON ] jetson-query                  Query Jetson AI about case status
#   [ON ] austlii-legal-search          Search AustLII for relevant Queensland case law
#   [ON ] task-tracker-read             Read the agent task tracker file
#   [ON ] monitoring-alerts-read        Read the monitoring alerts configuration
#   [ON ] n8n-webhook-healing           Notify n8n when a healing action is taken
```

### Trigger a Specific Link

```bash
python3 agent-integrations/agentic_data_links.py --trigger jetson-query
```

### Check Link Status

```bash
python3 agent-integrations/agentic_data_links.py --status
```

---

## ADDING A NEW DATA LINK

To connect Bradix to a new external service, add an entry to `DATA_LINKS_REGISTRY` in `agentic_data_links.py`:

```python
{
    "name": "my-new-link",
    "description": "What this link does",
    "type": LinkType.WEBHOOK,      # or REST_API, JETSON, FILE
    "enabled": True,
    "url": "https://api.example.com/endpoint",
    "method": "POST",
    "headers": {"Authorization": f"Bearer {os.getenv('MY_API_KEY', '')}"},
    "payload": {"key": "value"},
    "timeout": 15,
},
```

No other code changes are required. The link will automatically be:
- Included in `--list` output
- Executed on the next run
- Included in state tracking and status reports

---

## ENVIRONMENT VARIABLES

| Variable | Default | Description |
|----------|---------|-------------|
| `JETSON_ENDPOINT` | `http://jetson.local:8000` | Jetson inference server URL |
| `N8N_ENDPOINT` | `http://localhost:5678` | n8n workflow engine URL |
| `CASE_DATA_PATH` | `~/bradix/case-data` | Path to case data files |
| `BRADIX_LOG_DIR` | `~/bradix/logs` | Log and state file directory |

---

## AUTOMATION (Cron)

Add to crontab to run all data links automatically:

```bash
# Run all Bradix data links every 30 minutes
*/30 * * * * cd /path/to/Bradyx && python3 agent-integrations/agentic_data_links.py >> ~/bradix/logs/data_links.log 2>&1
```

Or integrate with the existing n8n workflow by calling the link runner from an n8n HTTP Request node.

---

## INTEGRATION WITH HEALING AUTOMATION

When a data link triggers a healing event (e.g., the `n8n-webhook-healing` link), it notifies n8n that a healing action was taken. This closes the loop:

```
Health check detects issue
        ↓
Healing Automation attempts fix
        ↓
agentic_data_links fires n8n-webhook-healing
        ↓
n8n logs the event, updates case data, and notifies Andrew if needed
```

See [HEALING_AUTOMATION.md](./HEALING_AUTOMATION.md) for details.

---

*Document prepared: April 2026 | BRADIX Case Management System*
