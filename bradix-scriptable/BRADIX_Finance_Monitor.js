// BRADIX Finance Monitor — Scriptable
const endpoint = Keychain.contains("BRADIX_FINANCE_URL") ? Keychain.get("BRADIX_FINANCE_URL") : "";
const notification = new Notification(); notification.title = "BRADIX · Finance";
if (!endpoint) notification.body = "No finance endpoint configured. Add BRADIX_FINANCE_URL in Keychain.";
else { try { const request = new Request(endpoint); const data = await request.loadJSON(); notification.body = `Finance snapshot received: ${JSON.stringify(data).slice(0, 220)}`; } catch (error) { notification.body = `Finance monitor unavailable: ${error}`; } }
await notification.schedule(); Script.complete();
