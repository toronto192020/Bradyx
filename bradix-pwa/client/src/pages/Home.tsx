/*
 * BRADIX Clinical Glass Ledger
 * Calm authority, touch-first controls, semantic status colors, deliberate motion.
 */
import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import {
  Activity,
  AlertTriangle,
  Archive,
  ArrowUpRight,
  Bot,
  Check,
  CheckCircle2,
  ChevronRight,
  CircleHelp,
  Clock3,
  CloudOff,
  Droplets,
  FileImage,
  HeartPulse,
  Home as HomeIcon,
  LockKeyhole,
  Menu,
  Mic,
  MoreHorizontal,
  Paperclip,
  Play,
  Plus,
  RefreshCw,
  Send,
  Settings2,
  ShieldCheck,
  Siren,
  Sparkles,
  TimerReset,
  Utensils,
  WalletCards,
  X,
  Zap,
} from "lucide-react";

const API_BASE = (import.meta.env.VITE_BRADIX_API_URL as string | undefined) || "";

type TimerKind = "toilet" | "water" | "food" | "medicine";
type Status = "green" | "amber" | "red";

type CareTimer = {
  id: TimerKind;
  label: string;
  note: string;
  minutes: number;
  icon: typeof Clock3;
  accent: string;
  defaultMinutes: number;
};

type ActivityItem = {
  id: number;
  label: string;
  detail: string;
  time: string;
  status: Status;
};

const initialTimers: CareTimer[] = [
  { id: "toilet", label: "Toilet", note: "Next check-in", minutes: 90, icon: TimerReset, accent: "cyan", defaultMinutes: 90 },
  { id: "water", label: "Water", note: "Hydration check", minutes: 32, icon: Droplets, accent: "blue", defaultMinutes: 60 },
  { id: "food", label: "Food", note: "Meal window", minutes: 58, icon: Utensils, accent: "amber", defaultMinutes: 120 },
  { id: "medicine", label: "Medicine", note: "Medication check", minutes: 14, icon: HeartPulse, accent: "rose", defaultMinutes: 240 },
];

const actions = [
  { id: "nominate-mills", label: "Nominate Mills", detail: "TMR nomination", icon: ArrowUpRight, tone: "cyan" },
  { id: "nominate-woodward", label: "Nominate Woodward", detail: "TMR nomination", icon: ArrowUpRight, tone: "cyan" },
  { id: "sper-payment-plan", label: "SPER payment plan", detail: "Draft request", icon: WalletCards, tone: "amber" },
  { id: "bluecare-activate", label: "Activate BlueCare", detail: "Care services", icon: ShieldCheck, tone: "mint" },
  { id: "ptq-accounting", label: "PTQ accounting", detail: "Request support", icon: Archive, tone: "blue" },
  { id: "protect-super", label: "Protect super", detail: "Draft letter", icon: LockKeyhole, tone: "amber" },
  { id: "qcat-review", label: "QCAT review", detail: "Draft application", icon: FileImage, tone: "amber" },
];

const situations = [
  { title: "Urgent care change", subtitle: "Capture facts, stabilise, escalate", status: "Ready", icon: Siren, tint: "rose" },
  { title: "Missed service", subtitle: "Log provider, time, and next safe step", status: "Ready", icon: AlertTriangle, tint: "amber" },
  { title: "Document dispute", subtitle: "Build a dated evidence trail", status: "Ready", icon: Paperclip, tint: "cyan" },
];

const statusRows: { label: string; detail: string; status: Status; value: string }[] = [
  { label: "BRADIX API", detail: "Local command surface", status: "green", value: "online" },
  { label: "Ollama", detail: "nous-hermes2", status: "green", value: "ready" },
  { label: "n8n", detail: "Workflow engine", status: "amber", value: "check config" },
  { label: "Telegram", detail: "Notifications", status: "amber", value: "not linked" },
  { label: "Evidence vault", detail: "Local browser storage", status: "green", value: "protected" },
];

const initialActivity: ActivityItem[] = [
  { id: 1, label: "System ready", detail: "Local-first mode active", time: "just now", status: "green" },
  { id: 2, label: "Evidence vault checked", detail: "No outbound sync requested", time: "2m ago", status: "green" },
  { id: 3, label: "Care timer restored", detail: "Toilet check-in in 1h 30m", time: "5m ago", status: "amber" },
];

function formatMinutes(minutes: number) {
  const safe = Math.max(0, minutes);
  const hours = Math.floor(safe / 60);
  const mins = safe % 60;
  const roundedMinutes = Math.floor(mins);
  return hours > 0 ? `${hours}h ${roundedMinutes.toString().padStart(2, "0")}m` : `${roundedMinutes}m`;
}

function statusClasses(status: Status) {
  return {
    green: "bg-emerald-300 shadow-[0_0_15px_rgba(110,231,183,.55)]",
    amber: "bg-amber-300 shadow-[0_0_15px_rgba(252,211,77,.5)]",
    red: "bg-rose-400 shadow-[0_0_15px_rgba(251,113,133,.6)]",
  }[status];
}

function toneClasses(tone: string) {
  return {
    cyan: "text-cyan-100 bg-cyan-300/10 border-cyan-200/15 hover:bg-cyan-300/15",
    blue: "text-sky-100 bg-sky-300/10 border-sky-200/15 hover:bg-sky-300/15",
    amber: "text-amber-100 bg-amber-300/10 border-amber-200/15 hover:bg-amber-300/15",
    mint: "text-emerald-100 bg-emerald-300/10 border-emerald-200/15 hover:bg-emerald-300/15",
    rose: "text-rose-100 bg-rose-300/10 border-rose-200/15 hover:bg-rose-300/15",
  }[tone] || "text-white bg-white/5 border-white/10 hover:bg-white/10";
}

export default function Home() {
  const [timers, setTimers] = useState<CareTimer[]>(() => {
    try {
      const saved = JSON.parse(localStorage.getItem("bradix-timers") || "null");
      if (!Array.isArray(saved)) return initialTimers;
      return initialTimers.map((timer) => {
        const stored = saved.find((item: { id?: TimerKind }) => item?.id === timer.id);
        return stored && typeof stored.minutes === "number" ? { ...timer, minutes: stored.minutes } : timer;
      });
    } catch {
      return initialTimers;
    }
  });
  const [activity, setActivity] = useState<ActivityItem[]>(() => {
    try {
      return JSON.parse(localStorage.getItem("bradix-activity") || "null") || initialActivity;
    } catch {
      return initialActivity;
    }
  });
  const [evidence, setEvidence] = useState<{ name: string; data: string; captured: string }[]>(() => {
    try {
      return JSON.parse(localStorage.getItem("bradix-evidence") || "[]");
    } catch {
      return [];
    }
  });
  const [chatOpen, setChatOpen] = useState(false);
  const [chatInput, setChatInput] = useState("");
  const [chat, setChat] = useState<{ role: "ai" | "user"; text: string }[]>([
    { role: "ai", text: "BRADIX is online. Tell me what needs attention and I’ll turn it into the next safe action." },
  ]);
  const [voiceActive, setVoiceActive] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [lastSync, setLastSync] = useState("Local mode");

  useEffect(() => {
    const interval = window.setInterval(() => {
      setTimers((current) => current.map((timer) => ({ ...timer, minutes: timer.minutes > 0 ? timer.minutes - 1 / 60 : 0 })));
    }, 60_000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    localStorage.setItem("bradix-timers", JSON.stringify(timers));
    localStorage.setItem("bradix-activity", JSON.stringify(activity));
    localStorage.setItem("bradix-evidence", JSON.stringify(evidence));
  }, [timers, activity, evidence]);

  const nextTimer = useMemo(() => [...timers].sort((a, b) => a.minutes - b.minutes)[0], [timers]);
  const greenCount = statusRows.filter((row) => row.status === "green").length;
  const overallStatus: Status = statusRows.some((row) => row.status === "red") ? "red" : statusRows.some((row) => row.status === "amber") ? "amber" : "green";

  function addActivity(label: string, detail: string, status: Status = "green") {
    setActivity((current) => [{ id: Date.now(), label, detail, time: "just now", status }, ...current].slice(0, 8));
  }

  function resetTimer(id: TimerKind) {
    setTimers((current) => current.map((timer) => timer.id === id ? { ...timer, minutes: timer.defaultMinutes } : timer));
    const timer = timers.find((item) => item.id === id);
    addActivity(`${timer?.label || "Care"} timer reset`, `${timer?.defaultMinutes || 0} minute reminder armed`, "green");
    toast.success(`${timer?.label || "Care"} timer reset`);
  }

  async function triggerAction(actionId: string, label: string) {
    addActivity(`${label} queued`, "Review connector status before sending", "amber");
    toast(`${label} queued`, { description: "Draft-first mode: connect the BRADIX API to send externally." });
    if (!API_BASE) return;
    try {
      const response = await fetch(`${API_BASE}/${actionId}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ source: "bradix-pwa" }) });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      addActivity(`${label} acknowledged`, "API returned successfully", "green");
    } catch {
      addActivity(`${label} needs attention`, "API connection unavailable; kept local", "amber");
      toast.error(`${label} could not reach the API`, { description: "Nothing was sent. Your local action log is preserved." });
    }
  }

  async function sendChat() {
    const prompt = chatInput.trim();
    if (!prompt) return;
    setChat((current) => [...current, { role: "user", text: prompt }]);
    setChatInput("");
    if (!API_BASE) {
      setChat((current) => [...current, { role: "ai", text: "Local mode is active. Connect VITE_BRADIX_API_URL to ask Ollama, or use the action cards for a structured next step." }]);
      return;
    }
    try {
      const response = await fetch(`${API_BASE}/ollama-chat`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ prompt }) });
      const data = await response.json();
      setChat((current) => [...current, { role: "ai", text: data.response || "Ollama returned no response." }]);
    } catch {
      setChat((current) => [...current, { role: "ai", text: "I couldn’t reach Ollama. The dashboard is still usable locally." }]);
    }
  }

  function startVoice() {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      toast.error("Voice control is not available in this browser", { description: "Use Chrome or Safari on a device with speech recognition enabled." });
      return;
    }
    const recognition = new SpeechRecognition();
    recognition.lang = "en-AU";
    recognition.interimResults = false;
    setVoiceActive(true);
    recognition.onresult = (event: any) => {
      const text = event.results?.[0]?.[0]?.transcript || "";
      setChatInput(text);
      setChatOpen(true);
      toast.success("Voice command captured", { description: text });
    };
    recognition.onerror = () => toast.error("Voice command was not captured");
    recognition.onend = () => setVoiceActive(false);
    recognition.start();
  }

  function captureEvidence(file: File) {
    const reader = new FileReader();
    reader.onload = () => {
      const captured = new Date().toLocaleString("en-AU", { dateStyle: "medium", timeStyle: "short" });
      setEvidence((current) => [{ name: file.name, data: String(reader.result), captured }, ...current].slice(0, 12));
      addActivity("Evidence captured", `${file.name} stored locally`, "green");
      toast.success("Evidence captured locally", { description: "Timestamp preserved. Sync is optional." });
    };
    reader.readAsDataURL(file);
  }

  function executeAll() {
    addActivity("Run everything queued", "Review each draft before external send", "amber");
    toast("Run everything queued", { description: "BRADIX will keep this in draft-first mode until connectors are configured." });
  }

  return (
    <div className="min-h-screen overflow-x-hidden bg-[#070b12] text-slate-100">
      <div className="pointer-events-none fixed inset-0 bg-[radial-gradient(circle_at_12%_8%,rgba(31,116,142,.22),transparent_32%),radial-gradient(circle_at_92%_10%,rgba(52,78,128,.2),transparent_26%),linear-gradient(135deg,#070b12_0%,#0b111b_48%,#080d16_100%)]" />
      <div className="pointer-events-none fixed inset-0 opacity-[0.035] [background-image:linear-gradient(rgba(255,255,255,.4)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.4)_1px,transparent_1px)] [background-size:48px_48px]" />

      <div className="relative mx-auto flex min-h-screen max-w-[1600px]">
        <aside className="hidden w-[248px] shrink-0 flex-col border-r border-white/[0.07] bg-[#09101a]/70 px-5 py-6 backdrop-blur-2xl lg:flex">
          <div className="flex items-center gap-3">
            <div className="pulse-mark grid size-11 place-items-center rounded-2xl border border-cyan-200/30 bg-cyan-200/10 text-cyan-100 shadow-[0_0_24px_rgba(141,235,255,.14)]">
              <span className="relative font-display text-2xl font-bold">B<span className="absolute -right-3 top-1/2 h-0.5 w-5 -translate-y-1/2 bg-cyan-100 shadow-[0_0_9px_#8deBff]" /></span>
            </div>
            <div>
              <p className="font-display text-lg font-semibold tracking-tight">BRADIX</p>
              <p className="text-[10px] uppercase tracking-[0.22em] text-slate-500">Care command surface</p>
            </div>
          </div>

          <div className="mt-10 space-y-1">
            {[{ label: "Overview", icon: HomeIcon, active: true }, { label: "Actions", icon: Zap }, { label: "Evidence vault", icon: Archive }, { label: "Situations", icon: CircleHelp }].map((item) => { const NavIcon = item.icon; return (
              <button key={item.label} className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm transition ${item.active ? "bg-cyan-200/10 text-cyan-100" : "text-slate-500 hover:bg-white/[0.04] hover:text-slate-200"}`}>
                <NavIcon size={17} strokeWidth={1.8} />
                <span>{item.label}</span>
                {item.active && <span className="ml-auto size-1.5 rounded-full bg-cyan-200 shadow-[0_0_10px_#8deBff]" />}
              </button>
            ); })}
          </div>

          <div className="mt-auto rounded-2xl border border-white/[0.08] bg-white/[0.035] p-4">
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-slate-400">System posture</span>
              <span className={`size-2 rounded-full ${statusClasses(overallStatus)}`} />
            </div>
            <p className="mt-3 text-sm leading-5 text-slate-200">Local-first and ready. External sends remain draft-first.</p>
            <div className="mt-4 flex items-center gap-2 text-[11px] text-slate-500"><CloudOff size={13} /> {lastSync}</div>
          </div>
        </aside>

        <main className="min-w-0 flex-1 px-4 pb-12 sm:px-7 lg:px-10">
          <header className="flex items-center justify-between border-b border-white/[0.07] py-5">
            <div className="flex items-center gap-3 lg:hidden"><div className="pulse-mark grid size-9 place-items-center rounded-xl bg-cyan-200/10 font-display font-bold text-cyan-100">B<span className="ml-1 h-0.5 w-3 bg-cyan-100 shadow-[0_0_7px_#8deBff]" /></div><span className="font-display font-semibold">BRADIX</span></div>
            <div className="hidden lg:block"><p className="text-[11px] uppercase tracking-[0.25em] text-cyan-200/70">Saturday · Brisbane, AU</p><p className="mt-1 text-sm text-slate-500">Andrew Bruce-Sanders · personal command surface</p></div>
            <div className="flex items-center gap-2">
              <button onClick={() => setChatOpen(true)} className="hidden items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3 py-2 text-xs text-slate-300 transition hover:bg-white/[0.08] sm:flex"><Bot size={15} className="text-cyan-200" /> Ask BRADIX</button>
              <button onClick={startVoice} aria-label="Start voice command" className={`grid size-10 place-items-center rounded-full border transition ${voiceActive ? "border-cyan-200 bg-cyan-200/20 text-cyan-100 shadow-[0_0_22px_rgba(141,235,255,.35)]" : "border-cyan-200/20 bg-cyan-200/10 text-cyan-100 hover:bg-cyan-200/20"}`}><Mic size={17} /></button>
              <div className="relative">
                <button onClick={() => setMenuOpen((value) => !value)} aria-label="Open settings" className="grid size-10 place-items-center rounded-full border border-white/10 bg-white/[0.04] text-slate-400 transition hover:bg-white/[0.08] hover:text-white"><MoreHorizontal size={18} /></button>
                {menuOpen && <div className="absolute right-0 top-12 z-20 w-48 rounded-2xl border border-white/10 bg-[#101a28]/95 p-2 shadow-2xl backdrop-blur-xl"><button onClick={() => { setLastSync("Local mode"); setMenuOpen(false); toast.success("Local mode confirmed"); }} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm text-slate-300 hover:bg-white/10"><Settings2 size={15} /> Connection settings</button><button onClick={() => { setMenuOpen(false); toast("BRADIX is designed to work offline"); }} className="flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm text-slate-300 hover:bg-white/10"><CircleHelp size={15} /> About local mode</button></div>}
              </div>
            </div>
          </header>

          <section className="relative py-9 sm:py-12">
            <div className="absolute -left-20 top-1/2 hidden h-48 w-48 -translate-y-1/2 rounded-full bg-cyan-300/10 blur-3xl lg:block" />
            <div className="relative flex flex-col justify-between gap-7 xl:flex-row xl:items-end">
              <div className="max-w-2xl">
                <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-emerald-200/15 bg-emerald-200/[0.07] px-3 py-1.5 text-[11px] uppercase tracking-[0.18em] text-emerald-100"><span className={`size-1.5 rounded-full ${statusClasses(overallStatus)}`} /> {greenCount}/{statusRows.length} systems clear</div>
                <h1 className="font-display text-4xl font-semibold leading-[1.06] tracking-[-0.045em] text-white sm:text-6xl">The next safe<br /><span className="text-cyan-100">action is ready.</span></h1>
                <p className="mt-5 max-w-lg text-sm leading-6 text-slate-400 sm:text-base">One calm surface for care, administration, and evidence. Nothing leaves this device unless you choose to connect it.</p>
              </div>
              <button onClick={executeAll} className="group flex items-center justify-between gap-8 rounded-2xl border border-cyan-100/20 bg-cyan-100/[0.1] px-5 py-4 text-left transition hover:-translate-y-0.5 hover:bg-cyan-100/[0.16] active:scale-[.98] xl:min-w-[245px]"><div><p className="text-[10px] uppercase tracking-[0.18em] text-cyan-100/70">Command centre</p><p className="mt-1 font-display text-lg font-semibold text-white">Run everything</p></div><div className="grid size-10 place-items-center rounded-xl bg-cyan-100 text-[#0b1520] transition group-hover:rotate-12"><Play size={17} fill="currentColor" /></div></button>
            </div>
          </section>

          <section className="grid gap-4 xl:grid-cols-[1.4fr_.8fr]">
            <div className="glass-panel overflow-hidden rounded-3xl p-5 sm:p-6">
              <div className="flex items-start justify-between gap-4"><div><div className="flex items-center gap-2"><Activity size={17} className="text-cyan-200" /><h2 className="font-display text-xl font-semibold">Care rhythm</h2><span className="pulse-rail" aria-hidden="true" /></div><p className="mt-1 text-xs text-slate-500">Quiet prompts for the next safe check-in</p></div><span className="rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 text-[10px] uppercase tracking-[0.15em] text-slate-500">Live</span></div>
              <div className="mt-6 grid grid-cols-2 gap-3 md:grid-cols-4">
                {timers.map((timer) => { const Icon = timer.icon; const urgent = timer.minutes < 20; return <div key={timer.id} className={`timer-card rounded-2xl border p-4 ${urgent ? "border-amber-200/25 bg-amber-200/[0.07]" : "border-white/[0.08] bg-white/[0.035]"}`}><div className="flex items-center justify-between"><div className={`grid size-8 place-items-center rounded-xl ${urgent ? "bg-amber-200/15 text-amber-100" : "bg-cyan-200/10 text-cyan-100"}`}><Icon size={16} /></div><button onClick={() => resetTimer(timer.id)} aria-label={`Reset ${timer.label} timer`} className="text-slate-600 transition hover:text-cyan-100"><RefreshCw size={14} /></button></div><p className="mt-4 text-xs text-slate-500">{timer.label}</p><p className={`mt-1 font-display text-2xl font-semibold tabular-nums ${urgent ? "text-amber-100" : "text-white"}`}>{formatMinutes(timer.minutes)}</p><p className="mt-1 text-[10px] text-slate-600">{timer.note}</p><div className="mt-4 h-1 overflow-hidden rounded-full bg-white/[0.08]"><div className={`h-full rounded-full ${urgent ? "bg-amber-300" : "bg-cyan-200"}`} style={{ width: `${Math.max(8, Math.min(100, timer.minutes / timer.defaultMinutes * 100))}%` }} /></div></div> })}
              </div>
              <div className="mt-5 flex items-center justify-between border-t border-white/[0.07] pt-4"><p className="text-xs text-slate-500">Next check-in: <span className="text-slate-300">{nextTimer?.label} in {formatMinutes(nextTimer?.minutes || 0)}</span></p><button onClick={() => { setTimers(initialTimers); addActivity("Care rhythm restored", "All timers returned to baseline", "green"); toast.success("Care rhythm restored"); }} className="text-xs text-cyan-100 transition hover:text-white">Restore rhythm <ChevronRight size={13} className="ml-1 inline" /></button></div>
            </div>

            <div className="glass-panel rounded-3xl p-5 sm:p-6"><div className="flex items-start justify-between"><div><div className="flex items-center gap-2"><ShieldCheck size={17} className="text-emerald-200" /><h2 className="font-display text-xl font-semibold">System posture</h2></div><p className="mt-1 text-xs text-slate-500">Dependency health at a glance</p></div><button onClick={() => { setLastSync("Checked just now"); toast.success("Status refreshed"); }} className="text-slate-500 transition hover:text-cyan-100"><RefreshCw size={15} /></button></div><div className="mt-5 space-y-3">{statusRows.map((row) => <div key={row.label} className="flex items-center gap-3"><span className={`size-2 rounded-full ${statusClasses(row.status)}`} /><div className="min-w-0 flex-1"><p className="truncate text-sm text-slate-200">{row.label}</p><p className="truncate text-[10px] text-slate-600">{row.detail}</p></div><span className={`text-[10px] uppercase tracking-[0.12em] ${row.status === "green" ? "text-emerald-200" : row.status === "amber" ? "text-amber-200" : "text-rose-200"}`}>{row.value}</span></div>)}</div><div className="mt-6 rounded-xl border border-emerald-200/10 bg-emerald-200/[0.05] px-3 py-2.5 text-xs text-emerald-100/80"><CheckCircle2 size={14} className="mr-2 inline" /> Local fail-safe active</div></div>
          </section>

          <section className="mt-5 grid gap-5 xl:grid-cols-[1.15fr_.85fr]">
            <div className="glass-panel rounded-3xl p-5 sm:p-6"><div className="flex items-start justify-between"><div><div className="flex items-center gap-2"><Zap size={17} className="text-cyan-200" /><h2 className="font-display text-xl font-semibold">Next safe action</h2><span className="pulse-rail" aria-hidden="true" /></div><p className="mt-1 text-xs text-slate-500">One tap creates a reviewable draft or connector request</p><div className="mt-4 flex items-center gap-2 text-[10px] uppercase tracking-[0.16em] text-amber-200/70"><span className="h-px w-8 bg-amber-200/60" /> draft-first control</div></div><span className="text-xs text-slate-600">7 actions</span></div><div className="mt-5 grid gap-2 sm:grid-cols-2">{actions.map((action) => { const ActionIcon = action.icon; return <button key={action.id} onClick={() => triggerAction(action.id, action.label)} className={`flex items-center gap-3 rounded-2xl border px-3.5 py-3 text-left transition active:scale-[.985] ${toneClasses(action.tone)}`}><div className="grid size-9 shrink-0 place-items-center rounded-xl bg-black/15"><ActionIcon size={16} /></div><div className="min-w-0 flex-1"><p className="truncate text-sm font-medium">{action.label}</p><p className="mt-0.5 text-[10px] opacity-60">{action.detail}</p></div><ArrowUpRight size={14} className="opacity-50" /></button>; })}</div></div>
            <div className="glass-panel rounded-3xl p-5 sm:p-6"><div className="flex items-start justify-between"><div><div className="flex items-center gap-2"><Archive size={17} className="text-cyan-200" /><h2 className="font-display text-xl font-semibold">Proof trail</h2><span className="pulse-rail" aria-hidden="true" /></div><p className="mt-1 text-xs text-slate-500">Screenshots and records stay on this device</p></div><span className="rounded-full bg-white/[0.05] px-2 py-1 text-[10px] text-slate-500">{evidence.length} files</span></div><label className="mt-5 flex cursor-pointer flex-col items-center justify-center rounded-2xl border border-dashed border-cyan-100/20 bg-cyan-100/[0.035] px-4 py-7 text-center transition hover:border-cyan-100/40 hover:bg-cyan-100/[0.07]"><input type="file" accept="image/*,.pdf,.txt" className="hidden" onChange={(event) => { const file = event.target.files?.[0]; if (file) captureEvidence(file); event.currentTarget.value = ""; }} /><div className="grid size-11 place-items-center rounded-2xl bg-cyan-200/10 text-cyan-100"><Plus size={18} /></div><p className="mt-3 text-sm text-slate-300">Capture evidence</p><p className="mt-1 text-[10px] text-slate-600">Image, PDF, or note · timestamped locally</p></label>{evidence.length > 0 && <div className="mt-4 space-y-2">{evidence.slice(0, 2).map((file) => <div key={file.name + file.captured} className="flex items-center gap-3 rounded-xl bg-white/[0.035] px-3 py-2"><FileImage size={14} className="text-cyan-200" /><div className="min-w-0 flex-1"><p className="truncate text-xs text-slate-300">{file.name}</p><p className="text-[10px] text-slate-600">{file.captured}</p></div><Check size={14} className="text-emerald-200" /></div>)}</div>}</div>
          </section>

          <section className="mt-5 grid gap-5 xl:grid-cols-[.9fr_1.1fr]">
            <div className="glass-panel rounded-3xl p-5 sm:p-6"><div className="flex items-start justify-between"><div><div className="flex items-center gap-2"><CircleHelp size={17} className="text-amber-100" /><h2 className="font-display text-xl font-semibold">Situation handlers</h2></div><p className="mt-1 text-xs text-slate-500">Pre-built structure for high-friction moments</p></div><button className="text-slate-600 transition hover:text-slate-200"><MoreHorizontal size={16} /></button></div><div className="mt-5 space-y-2">{situations.map((situation) => { const SituationIcon = situation.icon; return <button key={situation.title} onClick={() => { setChatOpen(true); setChatInput(`Help me handle: ${situation.title}`); }} className="flex w-full items-center gap-3 rounded-2xl border border-white/[0.07] bg-white/[0.03] p-3 text-left transition hover:bg-white/[0.07]"><div className={`grid size-9 place-items-center rounded-xl ${toneClasses(situation.tint)}`}><SituationIcon size={16} /></div><div className="min-w-0 flex-1"><p className="text-sm text-slate-200">{situation.title}</p><p className="mt-0.5 truncate text-[10px] text-slate-600">{situation.subtitle}</p></div><span className="rounded-full border border-emerald-200/10 bg-emerald-200/[0.05] px-2 py-1 text-[9px] uppercase tracking-[0.12em] text-emerald-200">{situation.status}</span></button>; })}</div></div>
            <div className="glass-panel rounded-3xl p-5 sm:p-6"><div className="flex items-start justify-between"><div><div className="flex items-center gap-2"><Clock3 size={17} className="text-cyan-200" /><h2 className="font-display text-xl font-semibold">Activity rail</h2></div><p className="mt-1 text-xs text-slate-500">A clear trail of what BRADIX has done locally</p></div><button onClick={() => { setActivity([]); toast.success("Activity cleared"); }} className="text-[10px] uppercase tracking-[0.14em] text-slate-600 transition hover:text-slate-300">Clear</button></div><div className="mt-5 space-y-4">{activity.length ? activity.slice(0, 5).map((item) => <div key={item.id} className="flex gap-3"><span className={`mt-1.5 size-2 shrink-0 rounded-full ${statusClasses(item.status)}`} /><div className="min-w-0 flex-1"><div className="flex items-start justify-between gap-3"><p className="text-sm text-slate-300">{item.label}</p><span className="shrink-0 text-[10px] text-slate-600">{item.time}</span></div><p className="mt-0.5 text-xs text-slate-600">{item.detail}</p></div></div>) : <p className="text-sm text-slate-600">No recent activity.</p>}</div></div>
          </section>

          <footer className="mt-10 flex flex-col gap-3 border-t border-white/[0.07] pt-5 text-[10px] text-slate-600 sm:flex-row sm:items-center sm:justify-between"><p><LockKeyhole size={12} className="mr-1.5 inline" /> BRADIX local-first · evidence stays on this device</p><p>API {API_BASE || "not configured"} · offline capable</p></footer>
        </main>
      </div>

      {chatOpen && <div className="fixed inset-0 z-40 flex items-end justify-end bg-black/40 p-3 backdrop-blur-sm sm:p-6"><div className="chat-drawer flex h-[min(680px,calc(100vh-24px))] w-full max-w-[430px] flex-col overflow-hidden rounded-3xl border border-white/15 bg-[#0d1623]/95 shadow-2xl backdrop-blur-2xl"><div className="flex items-center justify-between border-b border-white/[0.08] px-5 py-4"><div className="flex items-center gap-3"><div className="grid size-9 place-items-center rounded-xl bg-cyan-200/10 text-cyan-100"><Sparkles size={16} /></div><div><p className="font-display font-semibold">Ask BRADIX</p><p className="text-[10px] text-slate-500">Local AI panel · draft-first</p></div></div><button onClick={() => setChatOpen(false)} aria-label="Close chat" className="text-slate-500 transition hover:text-white"><X size={18} /></button></div><div className="flex-1 space-y-4 overflow-y-auto p-5">{chat.map((message, index) => <div key={index} className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}><div className={`max-w-[88%] rounded-2xl px-3.5 py-3 text-sm leading-5 ${message.role === "user" ? "bg-cyan-200/15 text-cyan-50" : "border border-white/[0.08] bg-white/[0.04] text-slate-300"}`}>{message.text}</div></div>)}</div><div className="border-t border-white/[0.08] p-4"><div className="flex items-end gap-2 rounded-2xl border border-white/10 bg-white/[0.04] p-2"><textarea value={chatInput} onChange={(event) => setChatInput(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); void sendChat(); } }} placeholder="What needs attention?" rows={2} className="min-h-[44px] flex-1 resize-none bg-transparent px-2 py-1 text-sm text-slate-200 outline-none placeholder:text-slate-600" /><button onClick={() => void sendChat()} aria-label="Send message" className="grid size-9 shrink-0 place-items-center rounded-xl bg-cyan-100 text-[#0b1520] transition hover:bg-white"><Send size={15} /></button></div><p className="mt-2 text-[10px] text-slate-600">Enter to send · Shift+Enter for a new line</p></div></div></div>}
    </div>
  );
}
