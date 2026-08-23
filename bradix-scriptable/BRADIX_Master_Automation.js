// BRADIX Master Automation — Scriptable for iOS
// Set apiBase to the NUC Tailscale address before use.
const settings = { apiBase: Keychain.contains("BRADIX_API_BASE") ? Keychain.get("BRADIX_API_BASE") : "http://bradix-nuc:8080" };
const actions = [
  ["Run everything", "/execute-all"], ["Nominate Mills", "/nominate-mills"], ["Nominate Woodward", "/nominate-woodward"],
  ["SPER payment plan", "/sper-payment-plan"], ["BlueCare activate", "/bluecare-activate"], ["PTQ accounting", "/ptq-accounting"],
  ["Protect super", "/protect-super"], ["QCAT review", "/qcat-review"], ["Status", "/status"],
];
async function call(path, method = "POST", body = {}) {
  const request = new Request(`${settings.apiBase}${path}`); request.method = method; request.headers = { "Content-Type": "application/json" }; request.body = JSON.stringify({ source: "scriptable", ...body });
  return await request.loadJSON();
}
const alert = new Alert(); alert.title = "BRADIX"; alert.message = "Choose a local-first action.";
for (const [label] of actions) alert.addAction(label); alert.addCancelAction("Cancel");
const choice = await alert.presentSheet();
if (choice >= 0) { const result = await call(actions[choice][1], actions[choice][1] === "/status" ? "GET" : "POST"); const message = JSON.stringify(result, null, 2).slice(0, 1200); const out = new Alert(); out.title = actions[choice][0]; out.message = message; out.addAction("Done"); await out.present(); }
Script.complete();
