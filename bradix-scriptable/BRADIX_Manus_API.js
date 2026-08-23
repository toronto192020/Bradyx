// BRADIX Manus API bridge — Scriptable
// Store the task URL and token in Keychain; never hard-code secrets in a widget.
const endpoint = Keychain.contains("BRADIX_MANUS_TASK_URL") ? Keychain.get("BRADIX_MANUS_TASK_URL") : "";
const token = Keychain.contains("BRADIX_MANUS_TOKEN") ? Keychain.get("BRADIX_MANUS_TOKEN") : "";
const alert = new Alert(); alert.title = "BRADIX · Manus"; alert.message = endpoint ? "Send a task trigger?" : "Configure BRADIX_MANUS_TASK_URL first."; alert.addAction(endpoint ? "Send" : "Close"); alert.addCancelAction("Cancel");
if (await alert.presentAlert() === 0 && endpoint) { const request = new Request(endpoint); request.method = "POST"; request.headers = { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }; request.body = JSON.stringify({ source: "scriptable", createdAt: new Date().toISOString() }); const notification = new Notification(); notification.title = "BRADIX · Manus"; try { await request.loadJSON(); notification.body = "Task trigger accepted."; } catch (error) { notification.body = `Task trigger failed: ${error}`; } await notification.schedule(); }
Script.complete();
