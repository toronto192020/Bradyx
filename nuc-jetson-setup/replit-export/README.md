# Bradix — Replit Backup Interface

This is a lightweight version of the Bradix system designed to run on Replit as a backup or mobile-friendly interface.

It provides a simple web dashboard to view your case status, tasks, and deadlines when you're away from your MSI NUC.

---

## Why Replit?

- **Accessibility**: Access your case status from any device with a browser.
- **Redundancy**: If your home NUC is offline, this backup stays active.
- **Simplicity**: No complex setup — just import the repo and run.

---

## How to Deploy on Replit

1. **Import from GitHub**:
   - Go to [Replit](https://replit.com/).
   - Click **Create Repl** → **Import from GitHub**.
   - Use the URL: `https://github.com/toronto192020/Bradyx`.
   - Set the root directory to `nuc-jetson-setup/replit-export`.

2. **Configure Secrets**:
   - In Replit, go to **Secrets** (the padlock icon).
   - Add a secret named `CASE_DATA_PATH` and set it to `../case-data`.
   - Add any other secrets from your `.env` if you want to enable features like email.

3. **Run**:
   - Click the big green **Run** button.
   - Replit will install the dependencies and start the Flask server.
   - A web view will appear with your dashboard.

---

## Limitations

- **No AI Inference**: Local AI inference requires the NVIDIA Jetson hardware in your home. This Replit version is for viewing status and tracking tasks only.
- **No Orchestration**: n8n workflows run on your NUC. This is a read-only interface for the case data.

---

## Syncing Data

To keep the Replit version up-to-date, you can use the Replit GitHub integration to pull the latest changes from your `Bradyx` repository whenever you push updates from your NUC.
