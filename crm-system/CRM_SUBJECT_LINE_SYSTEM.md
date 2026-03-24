# BRADIX CRM Subject Line System
## Nothing Slips Protocol — Gmail + Notion + n8n Integration

---

## THE FORMAT

Every email Andrew sends or receives gets tagged with this structure:

```
[PRIORITY][CATEGORY][ENTITY] Description — Deadline/Action
```

### Priority Levels:
- `[CRITICAL]` — deadline within 48 hours, legal/financial consequence if missed
- `[URGENT]` — deadline within 1 week
- `[HIGH]` — deadline within 1 month
- `[MEDIUM]` — important but flexible timeline
- `[LOW]` — background/informational
- `[DONE]` — completed, archive

### Categories:
- `[LEGAL]` — court, tribunal, complaints, appeals
- `[FINANCIAL]` — money, fines, benefits, super, insurance
- `[CARE]` — Cheryl's care, medical, services
- `[SYSTEM]` — BRADIX build, tech, APIs
- `[PERSONAL]` — relationships, boundaries, wellbeing
- `[ADMIN]` — forms, registrations, renewals

### Entities (key players):
- `[AFCA]` — Australian Financial Complaints Authority
- `[SPER]` — State Penalties Enforcement Registry
- `[TMR]` — Transport and Main Roads
- `[PTQ]` — Public Trustee Queensland
- `[QCAT]` — Queensland Civil and Administrative Tribunal
- `[BLUECARE]` — BlueCare services
- `[QSUPER]` — QSuper class action
- `[HOME-INSTEAD]` — Home Instead Brisbane West
- `[BHC]` — Brisbane Housing Company
- `[HOLLARD]` — Hollard Insurance
- `[SHINE]` — Shine Lawyers
- `[LEGAL-AID]` — Legal Aid Queensland
- `[DAVID]` — David, EV Charging Solutions
- `[SAM]` — Sam (personal)
- `[MILLS]` — Andrew Mills
- `[CHERYL]` — Cheryl's care matters

---

## ANDREW'S CURRENT ACTIVE SUBJECT LINES

```
[CRITICAL][FINANCIAL][AFCA] Hollard Insurance Complaint — FILE TODAY 5 Mar 2026
[CRITICAL][LEGAL][SPER] Stat Dec for 4 Fines — JP Witness Required ASAP
[URGENT][CARE][BLUECARE] Service Agreement Signing — Call Suze 0455 256 397
[URGENT][LEGAL][TMR] Rego Cancellation Resend — regocancellations@tmr.qld.gov.au
[HIGH][FINANCIAL][QSUPER] Late Registration Class Action — Deadline 16 Apr 2026
[HIGH][LEGAL][PTQ] Queensland Ombudsman Complaint — This Month
[HIGH][LEGAL][HOME-INSTEAD] Aged Care Commission Complaint — This Month
[HIGH][LEGAL][QCAT] Section 61 Appeal + Section 63 Application — This Month
[MEDIUM][CARE][CHERYL] Nursing Visit Vanessa Ford — 6 Mar 12pm
[MEDIUM][CARE][CHERYL] Joe Dementia Consultancy — 12 Mar 1:30pm
[MEDIUM][LEGAL][LEGAL-AID] Means Test — Need Centrelink CIS + Bank Statement
[MEDIUM][SYSTEM][BRADIX] API Connections Checklist — This Week
[LOW][PERSONAL][DAVID] EV Charging Solutions Meeting — 5 Mar 2pm
```

---

## GMAIL FILTER RULES

Set these up in Gmail Settings → Filters and Blocked Addresses:

**Filter 1 — CRITICAL auto-star:**
- Has the words: `[CRITICAL]`
- Apply label: `BRADIX/CRITICAL`
- Star it: Yes
- Mark as important: Yes
- Never send to spam: Yes

**Filter 2 — URGENT label:**
- Has the words: `[URGENT]`
- Apply label: `BRADIX/URGENT`
- Mark as important: Yes

**Filter 3 — Legal matters:**
- Has the words: `[LEGAL]`
- Apply label: `BRADIX/LEGAL`

**Filter 4 — Care matters:**
- Has the words: `[CARE]`
- Apply label: `BRADIX/CARE`

**Filter 5 — Incoming institutional emails (auto-tag):**
- From: `@sper.qld.gov.au OR @tmr.qld.gov.au OR @pt.qld.gov.au OR @qcat.qld.gov.au`
- Apply label: `BRADIX/INSTITUTIONS`
- Mark as important: Yes
- Never send to spam: Yes

---

## NOTION DATABASE SCHEMA

Create a database called "BRADIX Case Tracker" with these fields:

| Field | Type | Options |
|---|---|---|
| Title | Text | Subject line format above |
| Priority | Select | CRITICAL / URGENT / HIGH / MEDIUM / LOW / DONE |
| Category | Select | LEGAL / FINANCIAL / CARE / SYSTEM / PERSONAL / ADMIN |
| Entity | Select | All entities listed above |
| Deadline | Date | Hard deadline |
| Status | Select | Not Started / In Progress / Waiting / Done / Blocked |
| Action Required | Text | What Andrew needs to do |
| Script | Text | What to say/write |
| Evidence | Text | Links to documents/emails |
| Created | Date | Auto |
| Last Updated | Date | Auto |

**Views to create:**
1. "TODAY" — filter: Deadline = today, sort by Priority
2. "THIS WEEK" — filter: Deadline = this week
3. "CRITICAL" — filter: Priority = CRITICAL
4. "DONE" — filter: Status = Done (archive view)

---

## n8n WORKFLOW — NOTHING SLIPS PROTOCOL

**Workflow 1 — Incoming Email Alert:**
- Trigger: Gmail new email
- Condition: Email from institutional domain OR contains [CRITICAL] or [URGENT]
- Action: Create Notion database entry + Send push notification to phone

**Workflow 2 — Deadline Reminder:**
- Trigger: Daily at 8am
- Action: Query Notion for items with Deadline = today or tomorrow
- Action: Send summary to Andrew's phone via push notification
- Format: "TODAY: [list of critical items]"

**Workflow 3 — Overdue Alert:**
- Trigger: Daily at 9am
- Action: Query Notion for items where Deadline < today AND Status != Done
- Action: Send urgent alert: "OVERDUE: [item] — Action required NOW"

**Workflow 4 — Weekly Review:**
- Trigger: Every Sunday at 9am
- Action: Query all BRADIX/URGENT and BRADIX/HIGH items
- Action: Generate weekly summary and send to Andrew

---

## THE NOTHING SLIPS RULE

1. Every incoming email from an institution gets tagged within 24 hours
2. Every action item gets a deadline in Notion
3. No deadline passes without a completed action or a documented reason for delay
4. If Andrew can't act on something, it gets tagged [BLOCKED] with a note explaining why
5. Weekly Sunday review: everything in CRITICAL or URGENT gets checked
6. Monthly review: everything in HIGH gets checked

**The test:** If Andrew is hospitalised tomorrow, can someone else pick up the BRADIX Notion database and know exactly what needs to happen? If yes — the system is working.

---

*Document prepared: March 2026 | BRADIX Case Management System*
