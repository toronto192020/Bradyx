# BRADIX UNBREAKABLE CONNECTIONS

This guide outlines the resilient, unbreakable connections between all components of the BRADIX system. It is designed to ensure that if one component fails, the others continue to operate seamlessly, providing continuous support for Andrew and Cheryl.

## 1. System Architecture and Connections

The BRADIX ecosystem relies on a distributed architecture with built-in redundancies. Here is how each system connects, what it does, and how to make it unbreakable.

### Manus (AI Agent) ↔ BRADIX
*   **What it does:** Manus acts as the primary intelligence layer, executing complex tasks, researching legal precedents, and managing the overall BRADIX system.
*   **How to set it up:** Manus connects to BRADIX via GitHub integrations and secure API endpoints.
*   **What breaks it:** Loss of internet connectivity or API rate limits.
*   **How to make it resilient:** Implement local fallback to the NVIDIA Jetson running Ollama. If Manus is unreachable, the system automatically routes queries to the local LLM.

### Tailscale (Private Network)
*   **What it does:** Creates a secure, zero-configuration virtual private network (VPN) connecting all devices (iPhone, NUC, Jetson, Rabbit R1) regardless of their physical location.
*   **How to set it up:** Install Tailscale on all devices and authenticate with the same account. Enable "MagicDNS" for easy hostname resolution (e.g., `ping nuc`).
*   **What breaks it:** Tailscale authentication expiry or network firewalls blocking UDP traffic.
*   **How to make it resilient:** Set Tailscale authentication keys to non-expiring for critical infrastructure devices. Use Tailscale DERP relays as a fallback if direct peer-to-peer connections fail.

### Rabbit R1 with DLAM
*   **What it does:** Serves as the primary voice interface for Andrew, allowing hands-free interaction with the BRADIX system while caring for Cheryl.
*   **How to set it up:** Connect the Rabbit R1 to the Tailscale network and configure DLAM to point to the OpenClaw API running on the NUC (e.g., `http://[NUC-TAILSCALE-IP]:8080`).
*   **What breaks it:** Wi-Fi disconnection or OpenClaw API downtime.
*   **How to make it resilient:** Ensure the Rabbit R1 has a cellular backup. If the NUC API is down, configure a fallback endpoint to a cloud-hosted instance or a direct SMS interface via n8n.

### NVIDIA Jetson (Local AI)
*   **What it does:** Provides local, privacy-first AI inference using Ollama (e.g., Llama 3.2). It processes sensitive legal and medical data without sending it to the cloud.
*   **How to set it up:** Install Ollama on the Jetson and pull the required models. Ensure it is accessible via Tailscale.
*   **What breaks it:** Power outages or hardware overheating.
*   **How to make it resilient:** Connect the Jetson to an Uninterruptible Power Supply (UPS). Implement a fallback to a cloud LLM (via n8n) if the local API times out.

### OpenClaw / Claw that learns (Agentic AI)
*   **What it does:** Manages personal assistant tasks, file reading, and serves as the backend for the Rabbit R1 interface.
*   **How to set it up:** Install OpenClaw on the NUC, configure it to use the Ollama API on the Jetson, and index the BRADIX knowledge base.
*   **What breaks it:** Corrupted knowledge base index or NUC hardware failure.
*   **How to make it resilient:** Schedule automated daily backups of the OpenClaw configuration and knowledge base to GitHub.

### Skyvern (Browser Automation Agent)
*   **What it does:** Automates complex web interactions, such as filling out government forms or checking portals (e.g., SPER, TMR) that lack public APIs.
*   **How to set it up:** Deploy Skyvern via Docker on the NUC and trigger it via n8n webhooks.
*   **What breaks it:** Changes to target website layouts or CAPTCHAs.
*   **How to make it resilient:** Use robust CSS selectors and implement failure alerts in n8n. If Skyvern fails, n8n should alert Andrew via SMS to manually intervene.

### n8n (Workflow Automation)
*   **What it does:** The central nervous system of BRADIX. It orchestrates workflows, triggers alerts, and connects all the disparate systems.
*   **How to set it up:** Run n8n in Docker on the NUC. Create workflows for daily briefings, urgent alerts, and system health checks.
*   **What breaks it:** Database corruption or webhook endpoint changes.
*   **How to make it resilient:** Use PostgreSQL for the n8n database instead of SQLite for better stability. Export workflows to JSON and sync them to the GitHub repository automatically.

### GitHub (toronto192020/Bradyx repo)
*   **What it does:** Acts as the single source of truth for all code, configurations, and non-sensitive documentation.
*   **How to set it up:** Use the `gh` CLI to manage the repository. Implement automated sync scripts on the NUC.
*   **What breaks it:** Merge conflicts or accidental deletions.
*   **How to make it resilient:** Enforce branch protection rules and use automated backup scripts to maintain a local copy of the repository on the NUC.

### bradix.systems domain
*   **What it does:** Provides a unified, memorable address for accessing BRADIX services.
*   **How to set it up:** Configure DNS records to point to the Tailscale IP addresses or a secure reverse proxy (like Cloudflare Tunnels).
*   **What breaks it:** DNS misconfiguration or domain expiry.
*   **How to make it resilient:** Enable auto-renew on the domain registrar and use multiple DNS providers if possible.

---

## 2. Urgent Action: TMR Nomination Link

The standard TMR link (`service.transport.qld.gov.au/nominateinfringement`) is currently experiencing issues.

**Correct Working URL:**
To transfer or nominate an infringement, use the official Queensland Government portal:
[https://www.qld.gov.au/transport/safety/fines/how-to-transfer-a-fine](https://www.qld.gov.au/transport/safety/fines/how-to-transfer-a-fine) [1]

**Alternative Methods:**
If the online system fails on your iPhone, you must complete a statutory declaration.
1.  Use the partly pre-filled statutory declaration sent with the infringement notice.
2.  Have it witnessed by a Justice of the Peace (JP) or Commissioner for Declarations.
3.  Mail it to:
    Queensland Revenue Office
    GPO Box 1447
    BRISBANE QLD 4001 [1]

---

## 3. Urgent Action: SPER Suspension Clarification

**What does SPER suspension mean?**
The State Penalties Enforcement Registry (SPER) has suspended your driver licence due to an unpaid enforcement order. It is an offence to drive while suspended; doing so can result in penalties or a 6-month disqualification [2].

**How to get it lifted:**
You must pay the total amount owed or set up an approved payment plan. Once paid or a plan is established, the suspension is typically lifted within 5 minutes [2].

**The Fastest Path:**
1.  **Online Payment Plan:** The quickest way to resolve this is to apply for an instalment plan online. If approved, the suspension is lifted almost immediately [3].
2.  **Centrepay:** If you receive eligible Centrelink payments, you can set up deductions directly through SPER online [3].
3.  **Hardship / Work and Development Order:** If you cannot afford payments, you may be eligible for a work and development order, though this takes longer to process [2].

**What number to call:**
If you cannot complete this online via your iPhone, call SPER directly:
**1300 365 635** (Monday to Friday, 8am to 5pm) [2] [3].

---

## References
[1] Queensland Government. "How to transfer a fine." https://www.qld.gov.au/transport/safety/fines/how-to-transfer-a-fine
[2] Queensland Government. "Driver licence suspension by SPER." https://www.qld.gov.au/law/fines-and-penalties/fine-enforcement/licence-suspension
[3] Queensland Government. "Pay your SPER debt by instalments." https://www.qld.gov.au/law/fines-and-penalties/overdue-fines/instalment-plans
