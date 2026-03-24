# OpenClaw Integration Guide for BRADIX
## Agentic AI Layer — NUC + Jetson + bradix.systems

---

## WHAT IS OPENCLAW?

OpenClaw (originally Clawdbot/Moltbot) is an open-source, self-hosted AI agent released in early 2026 by Peter Steinberger. It runs on your own hardware, connects to any LLM (Claude, Gemini, local Ollama models), and acts as a **proactive personal agent** — it reads your files, monitors your messages, and takes action without being asked.

Key capabilities relevant to BRADIX:
- Reads and indexes local files (your case data, evidence timeline, legal documents)
- Monitors email accounts for triggers (new institutional emails, deadline reminders)
- Drafts documents, emails, and legal responses
- Executes multi-step workflows autonomously
- Connects to external APIs (AFCA, AustLII, government portals)
- Runs 100% locally — no data leaves your network

**GitHub:** github.com/steinberger/openclaw (check for latest repo name)

---

## RECOMMENDATION: USE CREWAI + OLLAMA INSTEAD

For Andrew's specific use case — fighting QCAT, PTQ, AFCA, SPER in Queensland with local privacy — **CrewAI + Ollama on Jetson** is actually the better stack than OpenClaw alone. Here's why:

| Tool | Best For | Andrew's Use |
|---|---|---|
| OpenClaw | Personal assistant, file reading | Good for daily queries on R1 |
| CrewAI | Multi-agent workflows, legal tasks | Best for autonomous case management |
| Ollama | Running LLMs locally on Jetson | Privacy-first AI inference |
| LangGraph | Complex stateful agent workflows | BRADIX orchestration layer |
| n8n | Workflow automation, API triggers | Already planned — use this |

**Recommended stack:** n8n (orchestration) → CrewAI agents (reasoning) → Ollama/Jetson (inference) → OpenClaw (personal interface/R1)

---

## INSTALLATION ON NUC (Ubuntu)

### Step 1 — Install Ollama (local LLM on Jetson)
```bash
# On Jetson (ARM64)
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2
ollama pull mistral
# Test
ollama run llama3.2 "What are Andrew's most urgent deadlines?"
```

### Step 2 — Install OpenClaw on NUC
```bash
# Prerequisites
sudo apt update && sudo apt install -y python3 python3-pip git nodejs npm

# Clone OpenClaw
git clone https://github.com/steinberger/openclaw.git
cd openclaw
pip3 install -r requirements.txt

# Configure
cp config.example.yaml config.yaml
nano config.yaml
# Set: llm_provider: ollama
# Set: ollama_host: http://[JETSON-IP]:11434
# Set: model: llama3.2
```

### Step 3 — Load BRADIX Knowledge Base into OpenClaw
```bash
# Copy your knowledge base
cp /path/to/BRADIX_R1_KNOWLEDGE_BASE.json openclaw/knowledge/bradix.json
cp /path/to/BRADIX_R1_CONTEXT.txt openclaw/system_prompt.txt

# Index all BRADIX documents
openclaw index /home/ubuntu/bradix_documents/
openclaw index /path/to/Bradyx/case-data/
```

### Step 4 — Set Up BRADIX Agents in CrewAI
```bash
pip3 install crewai langchain-ollama
```

Create `/home/ubuntu/bradix_agents/agents.py`:
```python
from crewai import Agent, Task, Crew
from langchain_ollama import OllamaLLM

llm = OllamaLLM(model="llama3.2", base_url="http://[JETSON-IP]:11434")

# Legal Agent
legal_agent = Agent(
    role="Legal Case Manager",
    goal="Monitor Andrew's legal cases, track deadlines, draft complaints and appeals",
    backstory="Expert in Queensland law, QCAT, AFCA, SPER, and aged care regulations",
    llm=llm,
    verbose=True
)

# Care Agent  
care_agent = Agent(
    role="Care Coordinator",
    goal="Monitor Cheryl's care schedule, medication, and wellbeing",
    backstory="Specialist in dementia care, CAA, and Home Care Package management",
    llm=llm,
    verbose=True
)

# Evidence Agent
evidence_agent = Agent(
    role="Evidence Analyst",
    goal="Process new documents and emails, extract key facts, update evidence timeline",
    backstory="Expert in document analysis and legal evidence compilation",
    llm=llm,
    verbose=True
)

# Finance Agent
finance_agent = Agent(
    role="Financial Advocate",
    goal="Track all financial matters including PTQ, QSuper, Hollard, SPER fines",
    backstory="Specialist in government financial accountability and consumer rights",
    llm=llm,
    verbose=True
)
```

---

## CONNECTING TO RABBIT R1 VIA DLAM

1. Load `BRADIX_R1_CONTEXT.txt` as your DLAM system prompt
2. Set DLAM endpoint to point to OpenClaw API running on NUC:
   - OpenClaw default port: `http://[NUC-TAILSCALE-IP]:8080`
3. Voice commands that work:
   - "What's my most urgent deadline?" → Legal Agent responds
   - "Draft a follow-up email to SPER" → Legal Agent drafts, n8n sends
   - "Is Mum's nurse coming today?" → Care Agent checks calendar
   - "What did Andrew Mills owe me?" → Evidence Agent queries knowledge base
   - "Draft the QSuper late registration email" → Returns ready-to-send email

---

## AUSTLII INTEGRATION (Free Australian Legal Database)

AustLII (austlii.edu.au) is free and open access — the best legal database for Queensland cases.

```python
# Search AustLII for relevant precedents
import requests

def search_austlii(query):
    url = f"https://www.austlii.edu.au/cgi-bin/sinosrch.cgi?method=auto&query={query}&db=au"
    response = requests.get(url)
    return response.text

# Useful searches for Andrew's cases:
# "QCAT guardianship capacity CAA"
# "Public Trustee ultra vires Queensland"
# "AFCA insurance complaint time limit"
# "SPER statutory declaration review"
```

---

## DAILY AGENT WORKFLOW (automated via n8n)

```
6:00 AM — Care Agent: Check Cheryl's schedule for today, send summary to Andrew's phone
8:00 AM — Legal Agent: Check for overdue deadlines, send CRITICAL alerts
9:00 AM — Evidence Agent: Process any new emails received overnight, flag important items
12:00 PM — Finance Agent: Check SPER/PTQ/QSuper status, any new correspondence
6:00 PM — Summary Agent: Daily briefing — what happened today, what's due tomorrow
```

---

*Document prepared: March 2026 | BRADIX Case Management System*
