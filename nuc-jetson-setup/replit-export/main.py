"""
Bradix — Replit Backup Interface
================================
This is a lightweight version of the Bradix system designed
to run on Replit as a backup or mobile interface.

It provides:
- A simple web interface to view case status
- A read-only view of tasks and deadlines
- A manual trigger for email summaries (if SMTP is configured)

Note: This version does NOT include local AI inference or
n8n orchestration. It is a 'Quiet Guardian' for your pocket.
"""

import os
import json
import yaml
from datetime import datetime
from flask import Flask, render_template, jsonify, request

app = Flask(__name__)

# ─── Configuration ───────────────────────────────────────────
CASE_DATA_PATH = os.getenv("CASE_DATA_PATH", "case-data")
REPLIT_DB_URL = os.getenv("REPLIT_DB_URL") # For persistent storage if needed

def load_case_data():
    """Load case data from the local directory."""
    try:
        with open(os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders/case_data.json")) as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}

def load_tasks():
    """Load tasks from the local directory."""
    try:
        with open(os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders/agent_task_tracker.json")) as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}

def load_alerts():
    """Load alert config from the local directory."""
    try:
        with open(os.path.join(CASE_DATA_PATH, "cheryl-bruce-sanders/monitoring_alerts.yaml")) as f:
            return yaml.safe_load(f)
    except Exception as e:
        return {"error": str(e)}


# ─── Routes ──────────────────────────────────────────────────
@app.route('/')
def index():
    """Main dashboard view."""
    case_data = load_case_data()
    tasks = load_tasks()
    
    # Filter for open tasks
    open_tasks = [t for t in tasks.get('tasks', []) if t.get('status') != 'done']
    
    return render_template('index.html', 
                           case=case_data, 
                           tasks=open_tasks,
                           now=datetime.now().strftime("%Y-%m-%d %H:%M"))

@app.route('/api/status')
def status():
    """JSON status endpoint for mobile apps or widgets."""
    return jsonify({
        "status": "active",
        "last_sync": datetime.now().isoformat(),
        "open_tasks": len([t for t in load_tasks().get('tasks', []) if t.get('status') != 'done'])
    })

@app.route('/health')
def health():
    return "OK", 200

if __name__ == "__main__":
    # Replit uses port 8080 by default
    app.run(host='0.0.0.0', port=8080)
