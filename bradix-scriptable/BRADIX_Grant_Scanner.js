// BRADIX Grant Scanner — Scriptable
// Configure a public grants API/search endpoint if desired.
const endpoint = Keychain.contains("BRADIX_GRANTS_URL") ? Keychain.get("BRADIX_GRANTS_URL") : "";
const note = new Notification(); note.title = "BRADIX · Grant scan";
if (!endpoint) { note.body = "No grants endpoint configured. Add BRADIX_GRANTS_URL in Keychain."; await note.schedule(); Script.complete(); }
else { try { const request = new Request(endpoint); request.timeoutInterval = 20; const data = await request.loadJSON(); const count = Array.isArray(data) ? data.length : (data.results?.length || 0); note.body = `${count} grant opportunities found. Review the source before applying.`; await note.schedule(); } catch (error) { note.body = `Grant scan unavailable: ${error}`; await note.schedule(); } Script.complete(); }
