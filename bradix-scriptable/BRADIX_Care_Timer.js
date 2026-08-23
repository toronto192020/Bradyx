// BRADIX Care Timer — Scriptable
const key = "BRADIX_CARE_TIMERS";
const timers = JSON.parse(Keychain.contains(key) ? Keychain.get(key) : JSON.stringify({ Toilet: 90, Water: 60, Food: 120, Medicine: 240 }));
const alert = new Alert(); alert.title = "Care rhythm"; alert.message = "Reset a timer after the check-in.";
Object.keys(timers).forEach((name) => alert.addAction(`${name} · ${timers[name]} min`)); alert.addCancelAction("Cancel");
const choice = await alert.presentSheet();
if (choice >= 0) { const name = Object.keys(timers)[choice]; const prompt = new Alert(); prompt.title = `${name} timer`; prompt.message = "Minutes until next check-in"; prompt.addTextField("Minutes", String(timers[name])); prompt.addAction("Arm"); prompt.addCancelAction("Cancel"); if (await prompt.presentAlert() === 0) { timers[name] = Math.max(1, Number(prompt.textFieldValue(0)) || timers[name]); Keychain.set(key, JSON.stringify(timers)); const note = new Notification(); note.title = `BRADIX · ${name}`; note.body = `Next check-in in ${timers[name]} minutes`; note.schedule(); } }
Script.complete();
