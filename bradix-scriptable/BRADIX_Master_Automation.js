// ==UserScript==
// @name         BRADIX Master Automation Bridge
// @description  Full iOS Scriptable automation: Telegram, n8n, NUC API, R1 DLAM, Taskade, LittlebirdAI
// @version      2.0
// @author       Andrew Bruce-Sanders / BRADIX Systems
// ==/UserScript==

// ============================================
// CONFIGURATION — FILL IN YOUR DETAILS
// ============================================
const CONFIG = {
  // 1. Telegram Bot (free — create via @BotFather)
  telegram: {
    token: "YOUR_TELEGRAM_BOT_TOKEN",  // From @BotFather
    chatId: "YOUR_CHAT_ID"              // Message @userinfobot to get this
  },

  // 2. BRADIX NUC/Pi API (your local server via Tailscale)
  bradix: {
    baseUrl: "http://100.x.x.x:8080",  // Your NUC's Tailscale IP + port
    // Alternative: "http://bradix.local:8080" if mDNS works
  },

  // 3. n8n Workflow Engine (self-hosted on NUC)
  n8n: {
    baseUrl: "http://100.x.x.x:5678",  // n8n Tailscale IP
    webhookPath: "/webhook/bradix-trigger"
  },

  // 4. Taskade (free tier — AI agents + task boards)
  taskade: {
    apiKey: "YOUR_TASKADE_API_KEY",     // From taskade.com/settings/api
    workspaceId: "YOUR_WORKSPACE_ID",
    projectId: "YOUR_PROJECT_ID"
  },

  // 5. LittlebirdAI (grants intelligence)
  littlebird: {
    baseUrl: "https://api.littlebirdai.com/v1",
    apiKey: "YOUR_LITTLEBIRD_API_KEY"
  },

  // 6. Rabbit R1 DLAM Bridge (via NUC relay)
  r1: {
    endpoint: "http://100.x.x.x:8080/r1/command"  // NUC relays to R1
  },

  // 7. Ollama (local LLM on Jetson via Tailscale)
  ollama: {
    baseUrl: "http://100.x.x.x:11434",  // Jetson Tailscale IP
    model: "nous-hermes2"
  }
};

// ============================================
// CORE REQUEST WRAPPER
// ============================================
async function sendRequest(url, method = "GET", headers = {}, body = null) {
  let req = new Request(url);
  req.method = method;
  req.headers = Object.assign({ "Content-Type": "application/json" }, headers);
  if (body) req.body = typeof body === "string" ? body : JSON.stringify(body);

  try {
    console.log(`📡 [${method}] ${url}`);
    let responseText = await req.loadString();
    let json;
    try { json = JSON.parse(responseText); } catch(e) { json = { raw: responseText }; }

    if (req.response.statusCode >= 200 && req.response.statusCode < 300) {
      console.log(`✅ Success (${req.response.statusCode})`);
      return json;
    } else {
      console.error(`❌ HTTP ${req.response.statusCode}: ${responseText}`);
      return null;
    }
  } catch (error) {
    console.error(`🚨 Connection Failed: ${error}`);
    return null;
  }
}

// ============================================
// MODULE 1: TELEGRAM NOTIFICATIONS
// ============================================
async function notifyTelegram(message, silent = false) {
  const url = `https://api.telegram.org/bot${CONFIG.telegram.token}/sendMessage`;
  return await sendRequest(url, "POST", {}, {
    chat_id: CONFIG.telegram.chatId,
    text: message,
    parse_mode: "Markdown",
    disable_notification: silent
  });
}

async function sendTelegramDocument(filePath, caption) {
  // For sending evidence files
  const url = `https://api.telegram.org/bot${CONFIG.telegram.token}/sendDocument`;
  // Note: File upload requires multipart — use for future implementation
  console.log(`📎 Document queued: ${caption}`);
}

// ============================================
// MODULE 2: BRADIX NUC API — DIRECT ACTIONS
// ============================================

// Execute ALL actions at once
async function executeAll() {
  return await sendRequest(`${CONFIG.bradix.baseUrl}/execute-all`, "POST");
}

// Individual action triggers
async function nominateMills() {
  await notifyTelegram("🔄 *Nominating Andrew Mills* for fines P010523745 + P010543118...");
  const result = await sendRequest(`${CONFIG.bradix.baseUrl}/actions/nominate-mills`, "POST");
  if (result) await notifyTelegram("✅ *Mills nominated* — $11,766.40 removed from warrant");
  return result;
}

async function nominateWoodward() {
  await notifyTelegram("🔄 *Nominating Timothy Woodward* for fine P0109696807...");
  const result = await sendRequest(`${CONFIG.bradix.baseUrl}/actions/nominate-woodward`, "POST");
  if (result) await notifyTelegram("✅ *Woodward nominated* — $6,474.35 removed from warrant");
  return result;
}

async function callSPER() {
  await notifyTelegram("📞 *Triggering SPER call* via Vapi...\nParty ID: 100199025\nRequest: Payment plan + Section 64 variation");
  return await sendRequest(`${CONFIG.bradix.baseUrl}/actions/call-sper`, "POST");
}

async function callBlueCare() {
  await notifyTelegram("📞 *Calling BlueCare Suze* (0455 256 397)...\nRequest: Sign service agreement, activate $18K surplus");
  return await sendRequest(`${CONFIG.bradix.baseUrl}/actions/call-bluecare`, "POST");
}

async function sendQSuperEmail() {
  await notifyTelegram("📧 *Sending QSuper late registration email*...\nMember: 194997808\nCase: CL00512793-00");
  const result = await sendRequest(`${CONFIG.bradix.baseUrl}/actions/email-qsuper`, "POST");
  if (result) await notifyTelegram("✅ *QSuper email sent* to qsuper@shine.com.au");
  return result;
}

async function fileAFCA() {
  await notifyTelegram("📋 *Filing AFCA complaint* against Hollard...");
  const result = await sendRequest(`${CONFIG.bradix.baseUrl}/actions/file-afca`, "POST");
  if (result) await notifyTelegram("✅ *AFCA complaint filed*");
  return result;
}

async function sendPTQComplaint() {
  await notifyTelegram("📋 *Filing PTQ complaint* with QLD Ombudsman...\nRef: 20675093");
  return await sendRequest(`${CONFIG.bradix.baseUrl}/actions/complaint-ptq`, "POST");
}

async function sendHomeInsistComplaint() {
  await notifyTelegram("📋 *Filing Home Instead complaint* with Aged Care Quality Commission...\n$9,000 taken, care abandoned");
  return await sendRequest(`${CONFIG.bradix.baseUrl}/actions/complaint-home-instead`, "POST");
}

// ============================================
// MODULE 3: n8n WORKFLOW TRIGGERS
// ============================================
async function triggerN8nWorkflow(workflowName, data = {}) {
  const url = `${CONFIG.n8n.baseUrl}${CONFIG.n8n.webhookPath}`;
  return await sendRequest(url, "POST", {}, {
    workflow: workflowName,
    timestamp: new Date().toISOString(),
    source: "Scriptable_iOS",
    data: data
  });
}

// ============================================
// MODULE 4: TASKADE — AI AGENTS + TASKS
// ============================================
async function createTaskadeTask(title, description, priority = "high") {
  const url = `https://www.taskade.com/api/v1/projects/${CONFIG.taskade.projectId}/tasks`;
  return await sendRequest(url, "POST", {
    "Authorization": `Bearer ${CONFIG.taskade.apiKey}`
  }, {
    title: title,
    description: description,
    priority: priority
  });
}

async function triggerTaskadeAgent(agentId, prompt) {
  const url = `https://www.taskade.com/api/v1/agents/${agentId}/run`;
  return await sendRequest(url, "POST", {
    "Authorization": `Bearer ${CONFIG.taskade.apiKey}`
  }, { prompt: prompt });
}

// ============================================
// MODULE 5: LITTLEBIRD AI — GRANTS INTELLIGENCE
// ============================================
async function searchGrants(query) {
  const url = `${CONFIG.littlebird.baseUrl}/grants/search`;
  return await sendRequest(url, "GET", {
    "Authorization": `Bearer ${CONFIG.littlebird.apiKey}`,
    "X-Query": query
  });
}

async function checkGrantStatus() {
  await notifyTelegram("🔍 *Checking grant opportunities*...");
  const results = await searchGrants("R&D tax incentive AI automation Queensland");
  if (results) {
    await notifyTelegram(`📊 *Grant Results:*\n${JSON.stringify(results, null, 2).substring(0, 500)}`);
  }
  return results;
}

// ============================================
// MODULE 6: RABBIT R1 DLAM BRIDGE
// ============================================
async function sendR1Command(command) {
  return await sendRequest(CONFIG.r1.endpoint, "POST", {}, {
    command: command,
    context: "bradix_master",
    timestamp: new Date().toISOString()
  });
}

async function r1StatusUpdate() {
  // Push current system status to R1 so voice queries are up to date
  const status = {
    sper_warrant: "$19,958.80 (pending nominations: -$18,240.75)",
    nominations_pending: ["Mills: $11,766.40", "Woodward: $6,474.35"],
    bluecare_surplus: "$18,000 (awaiting service agreement)",
    qcat_case: "G52248 (review pending)",
    ptq_ref: "20675093",
    health_alerts: ["Water reminder", "Food reminder", "Doctor needed"]
  };
  return await sendRequest(CONFIG.r1.endpoint, "POST", {}, {
    command: "update_context",
    data: status
  });
}

// ============================================
// MODULE 7: LOCAL AI (OLLAMA ON JETSON)
// ============================================
async function askHermes(prompt) {
  const url = `${CONFIG.ollama.baseUrl}/api/generate`;
  const result = await sendRequest(url, "POST", {}, {
    model: CONFIG.ollama.model,
    prompt: prompt,
    stream: false
  });
  return result ? result.response : null;
}

async function analyseControversialSituation(situation) {
  const prompt = `You are BRADIX, Andrew's AI system. Analyse this situation and provide:
1. ISSUE (one line)
2. SOLUTION (specific action)
3. RISK (what could go wrong)
4. FALLBACK (if solution fails)

Situation: ${situation}`;

  const analysis = await askHermes(prompt);
  if (analysis) {
    await notifyTelegram(`⚠️ *Controversial Situation Analysis:*\n\n${analysis}`);
  }
  return analysis;
}

// ============================================
// MODULE 8: CARE MONITOR
// ============================================
async function careAlert(type) {
  const alerts = {
    toilet: "🚽 *Cheryl — 90 minute cycle*\nCheck on Mum. Assist if needed.",
    water: "💧 *Andrew — Drink water NOW*\nYour kidneys need it. Not optional.",
    food: "🍽️ *Andrew — EAT SOMETHING*\nYou haven't eaten. Anything. Now.",
    medicine: "💊 *Cheryl — Medicine time*\nCheck prescription schedule."
  };

  const message = alerts[type] || `⏰ Care alert: ${type}`;
  return await notifyTelegram(message);
}

// ============================================
// MODULE 9: EVIDENCE CAPTURE
// ============================================
async function logEvidence(category, description, metadata = {}) {
  const evidence = {
    timestamp: new Date().toISOString(),
    category: category,  // "financial", "care", "legal", "vehicle", "property"
    description: description,
    metadata: metadata,
    source: "iOS_Scriptable"
  };

  // Log to NUC
  await sendRequest(`${CONFIG.bradix.baseUrl}/evidence/log`, "POST", {}, evidence);

  // Notify
  await notifyTelegram(`📸 *Evidence logged:*\n${category}: ${description}`);

  return evidence;
}

// ============================================
// MODULE 10: STATUS DASHBOARD
// ============================================
async function getFullStatus() {
  const status = await sendRequest(`${CONFIG.bradix.baseUrl}/status`, "GET");
  if (status) {
    const msg = `📊 *BRADIX STATUS*\n\n` +
      `💰 SPER: ${status.sper || "Check pending"}\n` +
      `📋 Nominations: ${status.nominations || "Ready to submit"}\n` +
      `🏥 BlueCare: ${status.bluecare || "$18K awaiting signature"}\n` +
      `⚖️ QCAT: ${status.qcat || "G52248 — review needed"}\n` +
      `🏠 Property: ${status.property || "115 Bielby Rd — PTQ controlled"}\n` +
      `🚗 Vehicles: ${status.vehicles || "Merc + Giulietta seized, BMW X5 active"}\n` +
      `❤️ Health: ${status.health || "Doctor needed ASAP"}`;
    await notifyTelegram(msg);
  }
  return status;
}

// ============================================
// QUICK ACTION MENU (for Shortcuts integration)
// ============================================
async function quickAction(action) {
  const actions = {
    "status": getFullStatus,
    "nominate-mills": nominateMills,
    "nominate-woodward": nominateWoodward,
    "call-sper": callSPER,
    "call-bluecare": callBlueCare,
    "email-qsuper": sendQSuperEmail,
    "file-afca": fileAFCA,
    "complaint-ptq": sendPTQComplaint,
    "complaint-home-instead": sendHomeInsistComplaint,
    "execute-all": executeAll,
    "grants": checkGrantStatus,
    "care-toilet": () => careAlert("toilet"),
    "care-water": () => careAlert("water"),
    "care-food": () => careAlert("food"),
    "care-medicine": () => careAlert("medicine"),
    "r1-update": r1StatusUpdate
  };

  if (actions[action]) {
    return await actions[action]();
  } else {
    console.log(`Unknown action: ${action}. Available: ${Object.keys(actions).join(", ")}`);
  }
}

// ============================================
// RUNTIME — MAIN EXECUTION
// ============================================
async function run() {
  console.log("🚀 Initializing Master Automation Bridge...");

  // Check if called with a specific action (from Shortcuts)
  const args = args?.shortcutParameter;
  if (args) {
    await quickAction(args);
  } else {
    // Default: show status
    await getFullStatus();
  }

  console.log("✅ Bridge execution complete.");
  Script.complete();
}

// Execute
await run();
