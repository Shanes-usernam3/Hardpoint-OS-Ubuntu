/* HardPoint OS apps — Setup wizard, Updates, Accounts, Security.
   Talks to /usr/bin/hardpoint-app through window.webkit.messageHandlers.hp. */
"use strict";

// ------------------------------------------------------------------ bridge
const HP = {
  seq: 0, pending: {},
  call(cmd, extra = {}, onLine) {
    const id = String(++this.seq);
    return new Promise((resolve, reject) => {
      this.pending[id] = { resolve, reject, onLine };
      const msg = JSON.stringify({ id, cmd, ...extra });
      if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.hp) webkit.messageHandlers.hp.postMessage(msg);
      else Mock.handle(JSON.parse(msg));
    });
  },
  root(action, args = [], onLine) { return this.call("root", { action, args }, onLine); },
  _reply(id, ok, data) {
    const p = this.pending[id]; if (!p) return; delete this.pending[id];
    ok ? p.resolve(data) : p.reject(new Error(typeof data === "string" ? data : "failed"));
  },
  _line(id, text) { const p = this.pending[id]; if (p && p.onLine) p.onLine(text); },
};

// Preview data when the page is opened in a normal browser (design work, screenshots).
const Mock = {
  state: {
    user: "shane", realName: "Shane", host: "hardpoint-desktop", os: "HardPoint OS 24.04 (Zorin Edition)", live: false,
    setupDone: false, updateTimer: true, colorScheme: "prefer-dark", installedApps: ["com.github.tchx84.Flatseal"],
    entra: { available: true, enabled: false, domain: "", active: false, companyPortal: true },
    security: { lockdown: false, firewall: true, apparmor: true, secureBoot: "off", kernelLockdown: "none", encrypted: true, usbguard: false },
    catalog: [
      ["gaming", "io.github.unknownskl.greenlight", "Greenlight (Xbox Cloud Gaming)", 1, "Play Xbox Cloud Gaming and stream from your Xbox"],
      ["gaming", "org.libretro.RetroArch", "RetroArch", 1, "All-in-one emulator frontend"],
      ["gaming", "org.DolphinEmu.dolphin-emu", "Dolphin", 1, "GameCube and Wii"],
      ["gaming", "net.pcsx2.PCSX2", "PCSX2", 1, "PlayStation 2"],
      ["gaming", "io.mgba.mGBA", "mGBA", 1, "Game Boy Advance"],
      ["dev", "com.google.AndroidStudio", "Android Studio", 1, "Android app development"],
      ["it", "com.rustdesk.RustDesk", "RustDesk", 1, "Remote support for clients"],
      ["it", "com.github.tchx84.Flatseal", "Flatseal", 1, "Manage app permissions"],
    ].map(([category, id, name, d, description]) => ({ category, id, name, default: !!d, description })),
  },
  handle(m) {
    const reply = (ok, data, ms = 350) => setTimeout(() => HP._reply(m.id, ok, data), ms);
    if (m.cmd === "state") return reply(true, this.state, 50);
    if (m.cmd === "updates-list") return reply(true, { checked: Date.now() / 1000, items: [
      { kind: "system", id: "apt:openssl", name: "openssl", from: "3.0.13-0ubuntu3.5", to: "3.0.13-0ubuntu3.6", security: true, source: "noble-security" },
      { kind: "system", id: "apt:linux-firmware", name: "linux-firmware", from: "20240318.git3b128b60-0ubuntu2.6", to: "20240318.git3b128b60-0ubuntu2.7", security: false, source: "noble-updates" },
      { kind: "system", id: "apt:code", name: "code", from: "1.104.2", to: "1.105.0", security: false, source: "stable" },
      { kind: "app", id: "flatpak:app/org.libretro.RetroArch/x86_64/stable", name: "RetroArch", from: "", to: "1.21.0", security: false, source: "Flathub" },
      { kind: "firmware", id: "fw:0123456789abcdef0123456789abcdef01234567", name: "UEFI System Firmware", from: "1.12", to: "1.14", security: true, source: "Lenovo" },
    ] }, 600);
    if (m.cmd === "root") {
      const lines = ["Asking for administrator permission…", "Working…", "Done."];
      lines.forEach((l, i) => setTimeout(() => HP._line(m.id, l), 300 * (i + 1)));
      return reply(true, "done", 1200);
    }
    reply(true, "");
  },
};

// ------------------------------------------------------------------ helpers
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const CHECK = '<span class="check"><svg viewBox="0 0 24 24" fill="none" stroke="#0A0E17" stroke-width="3.5"><path d="M5 12l5 5L20 7"/></svg></span>';
const ICON = {
  user: '<svg viewBox="0 0 24 24" fill="none" stroke="#03F4D4" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></svg>',
  work: '<svg viewBox="0 0 24 24" fill="none" stroke="#FF2E96" stroke-width="2"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/></svg>',
};
const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DOMAIN = /^[a-z0-9-]+(\.[a-z0-9-]+)+$/i;

function toast(text, ms = 2600) {
  const t = $("#toast"); t.textContent = text; t.classList.add("show");
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove("show"), ms);
}
function consoleBox(el) {
  el.textContent = ""; el.classList.add("show");
  return (line) => { el.textContent += line + "\n"; el.scrollTop = el.scrollHeight; };
}
async function busy(btn, label, fn) {
  const old = btn.innerHTML; btn.disabled = true;
  btn.innerHTML = `<span class="row" style="gap:10px"><span class="spinner"></span>${esc(label)}</span>`;
  try { return await fn(); } finally { btn.disabled = false; btn.innerHTML = old; }
}
function toggleHTML(id, on) { return `<label class="toggle"><input type="checkbox" id="${id}" ${on ? "checked" : ""}><i></i></label>`; }

let S = null; // system state
async function refresh() { S = await HP.call("state"); return S; }

// ------------------------------------------------------------------ views
const params = new URLSearchParams(location.search);
let view = params.get("view") || "setup";
const firstRun = params.get("first") === "1";

function show(v) {
  view = v;
  $("#shell").classList.toggle("wizard", v === "setup");
  $$(".nav").forEach((n) => n.classList.toggle("on", n.dataset.view === v));
  ({ setup: Setup.start, updates: Updates.render, accounts: Accounts.render, security: Security.render })[v]();
}
$$(".nav").forEach((n) => n.addEventListener("click", () => show(n.dataset.view)));

// ================================================================== SETUP
const Setup = {
  steps: ["welcome", "look", "account", "apps", "security", "done"],
  i: 0,
  picks: null,
  start() { Setup.i = 0; Setup.go(0); },
  go(i) {
    Setup.i = Math.max(0, Math.min(Setup.steps.length - 1, i));
    const name = Setup.steps[Setup.i];
    const dots = Setup.steps.map((_, k) => `<i class="${k === Setup.i ? "on" : k < Setup.i ? "done" : ""}"></i>`).join("");
    $("#main").innerHTML = `<div class="steps">${dots}</div><section class="page" id="page"></section>`;
    Setup[name]($("#page"));
  },
  foot(page, { back = true, next = "Continue", skip = false } = {}) {
    const f = document.createElement("div"); f.className = "foot";
    f.innerHTML = `<div>${back ? '<button class="btn ghost" id="back">Back</button>' : ""}</div>
      <div class="row">${skip ? '<button class="btn ghost" id="skip">Skip for now</button>' : ""}
      ${next ? `<button class="btn primary" id="next">${esc(next)}</button>` : ""}</div>`;
    page.appendChild(f);
    $("#back", f)?.addEventListener("click", () => Setup.go(Setup.i - 1));
    $("#skip", f)?.addEventListener("click", () => Setup.go(Setup.i + 1));
    $("#next", f)?.addEventListener("click", () => Setup.go(Setup.i + 1));
    return f;
  },

  welcome(page) {
    const first = (S.realName || S.user || "").split(" ")[0];
    page.innerHTML = `<div class="hero">
        <img class="logo" src="logo.svg" alt="">
        <h1>Welcome to <span class="grad-text">HardPoint OS</span></h1>
        <p>Hi ${esc(first)} — let's get this PC ready. It takes about two minutes, and you can change everything later.</p>
        <div class="feature-row">
          <span class="pill cyan">Secure by default</span><span class="pill">Dev &amp; IT tools</span>
          <span class="pill">Steam &amp; emulators</span><span class="pill">Work or school sign-in</span>
        </div>
      </div>`;
    const f = Setup.foot(page, { back: false, next: "Get started" });
    if (S.setupDone) {
      const c = document.createElement("button"); c.className = "btn ghost"; c.textContent = "Close";
      c.onclick = () => HP.call("close"); f.firstElementChild.appendChild(c);
    }
  },

  look(page) {
    const dark = S.colorScheme !== "default" && S.colorScheme !== "prefer-light";
    page.innerHTML = `<div class="head"><h2>Choose your look</h2><p>Byte Dark is the HardPoint signature style. Light works well in bright rooms.</p></div>
      <div class="body"><div class="grid2">
        <button class="choice ${dark ? "on" : ""}" data-v="dark"><div class="preview dark"></div><h3>Byte Dark</h3><p class="small">Navy glass with neon accents</p></button>
        <button class="choice ${dark ? "" : "on"}" data-v="light"><div class="preview light"></div><h3>Byte Light</h3><p class="small">Clean and bright</p></button>
      </div>
      <p class="small" style="margin-top:16px">More options (taskbar layout, fonts, effects) are in <a href="#" id="more">Appearance settings</a>.</p></div>`;
    $$(".choice", page).forEach((c) => c.addEventListener("click", async () => {
      $$(".choice", page).forEach((x) => x.classList.toggle("on", x === c));
      await HP.call("appearance", { args: [c.dataset.v] }).catch(() => {});
      S.colorScheme = c.dataset.v === "dark" ? "prefer-dark" : "default";
    }));
    $("#more", page).addEventListener("click", (e) => { e.preventDefault(); HP.call("open", { app: "appearance" }).catch((x) => toast(x.message)); });
    Setup.foot(page);
  },

  account(page) {
    const e = S.entra;
    page.innerHTML = `<div class="head"><h2>How will you sign in?</h2><p>You already have a local account (${esc(S.user)}). You can also connect this PC to your organisation.</p></div>
      <div class="body">
        <div class="grid2">
          <button class="choice ${e.enabled ? "" : "on"}" data-v="local"><div class="ico">${ICON.user}</div>
            <h3>Personal</h3><p class="small">Keep using your local account. Nothing to set up.</p></button>
          <button class="choice ${e.enabled ? "on" : ""}" data-v="work" ${e.available ? "" : "disabled"}><div class="ico">${ICON.work}</div>
            <h3>Work or school</h3><p class="small">Sign in with Microsoft Entra ID (Azure AD). Optional Intune enrolment.</p></button>
        </div>
        <div id="workform" class="card hidden" style="margin-top:16px"></div>
      </div>`;
    const form = $("#workform", page);
    const pick = (v) => {
      $$(".choice", page).forEach((x) => x.classList.toggle("on", x.dataset.v === v));
      form.classList.toggle("hidden", v !== "work");
      if (v === "work") Accounts.form(form, () => refresh());
    };
    $$(".choice", page).forEach((c) => c.addEventListener("click", () => pick(c.dataset.v)));
    if (e.enabled) pick("work");
    if (!e.available) form.insertAdjacentHTML("afterend", '<p class="small" style="margin-top:12px">Work/school sign-in packages are not included in this build.</p>');
    Setup.foot(page);
  },

  apps(page) {
    const have = new Set(S.installedApps);
    if (!Setup.picks) Setup.picks = new Set(S.catalog.filter((a) => a.default && !have.has(a.id)).map((a) => a.id));
    const cats = { gaming: "Gaming & emulators", dev: "Development", it: "IT & remote support", media: "Media" };
    let html = "";
    for (const [k, label] of Object.entries(cats)) {
      const list = S.catalog.filter((a) => a.category === k);
      if (!list.length) continue;
      html += `<div class="cat">${label}</div>` + list.map((a) => {
        const inst = have.has(a.id);
        return `<div class="item ${inst || Setup.picks.has(a.id) ? "on" : ""}" data-id="${esc(a.id)}" ${inst ? 'data-installed="1"' : ""}>
          ${CHECK}<div class="grow"><div class="name">${esc(a.name)}</div><div class="sub">${esc(a.description)}</div></div>
          ${inst ? '<span class="pill ok">Installed</span>' : ""}</div>`;
      }).join("");
    }
    page.innerHTML = `<div class="head"><h2>Add your apps</h2><p>Steam, VS Code, Edge, Docker and the IT toolkit are already installed. Pick extras from Flathub — they install in the background.</p></div>
      <div class="body"><div class="card" style="padding:8px 10px">${html}</div>
      <div id="appstatus" class="card hidden"><div class="row between"><h3 id="appmsg">Installing apps…</h3><span class="pill" id="appcount"></span></div>
      <div class="bar busy" style="margin-top:12px"><i></i></div><div class="console mono" id="applog"></div></div></div>`;
    const f = Setup.foot(page, { next: "", skip: true });
    const btn = Object.assign(document.createElement("button"), { className: "btn primary", id: "next" });
    f.lastElementChild.appendChild(btn);
    const label = () => { btn.textContent = Setup.picks.size ? `Install ${Setup.picks.size} app${Setup.picks.size > 1 ? "s" : ""}` : "Continue"; };
    label();
    $$(".item", page).forEach((it) => it.addEventListener("click", () => {
      if (it.dataset.installed || btn.disabled) return;
      const id = it.dataset.id;
      Setup.picks.has(id) ? Setup.picks.delete(id) : Setup.picks.add(id);
      it.classList.toggle("on", Setup.picks.has(id));
      label();
    }));
    btn.addEventListener("click", async () => {
      if (!Setup.picks.size) return Setup.go(Setup.i + 1);
      const ids = [...Setup.picks];
      $("#appstatus", page).classList.remove("hidden");
      const log = consoleBox($("#applog", page));
      let done = 0;
      $("#appcount", page).textContent = `0 / ${ids.length}`;
      btn.disabled = true;
      try {
        await HP.root("flatpak-install", ids, (l) => {
          log(l);
          const m = l.match(/^\[(\d+)\/(\d+)\]/); if (m) { done = +m[1]; $("#appcount", page).textContent = `${done} / ${ids.length}`; }
        });
        $("#appmsg", page).textContent = "Apps installed";
        $(".bar", page).classList.remove("busy"); $(".bar i", page).style.width = "100%";
        Setup.picks.clear(); await refresh();
        setTimeout(() => Setup.go(Setup.i + 1), 900);
      } catch (e) {
        $("#appmsg", page).textContent = e.message === "cancelled" ? "Install cancelled" : "Some apps could not be installed";
        $(".bar", page).classList.remove("busy");
        btn.disabled = false; btn.textContent = "Try again";
      }
    });
  },

  security(page) {
    const s = S.security;
    page.innerHTML = `<div class="head"><h2>Security &amp; updates</h2><p>HardPoint OS is locked down by default without getting in the way of games and dev work.</p></div>
      <div class="body stack">
        ${Security.statusGrid(s)}
        <div class="card row between"><div><h3>Lockdown Mode</h3><p class="small">Extra protection for travel or sensitive work: new USB devices blocked until approved, Bluetooth off, debuggers admin-only. Turn it off for gaming or Android debugging.</p></div>${toggleHTML("lock", s.lockdown)}</div>
        <div class="card row between"><div><h3>Check for updates every 6 hours</h3><p class="small">You get a notification and choose exactly which updates to install.</p></div>${toggleHTML("timer", S.updateTimer)}</div>
      </div>`;
    Security.wire(page);
    Setup.foot(page);
  },

  done(page) {
    page.innerHTML = `<div class="hero">
        <img class="logo" src="logo.svg" alt="">
        <h1>You're all set</h1>
        <p>HardPoint OS is ready. Setup, Updates, Accounts and Security are always in the app menu.</p>
        <div class="feature-row">
          <button class="btn" id="o-upd">Check for updates</button>
          ${S.entra.enabled && S.entra.companyPortal ? '<button class="btn" id="o-cp">Open Company Portal</button>' : ""}
        </div>
      </div>`;
    $("#o-upd", page).onclick = () => show("updates");
    $("#o-cp", page)?.addEventListener("click", () => HP.call("open", { app: "company-portal" }).catch((e) => toast(e.message)));
    const f = Setup.foot(page, { next: "Start using HardPoint OS" });
    $("#next", f).replaceWith(Object.assign(document.createElement("button"), { className: "btn primary", id: "finish", textContent: "Start using HardPoint OS" }));
    $("#finish", f).onclick = async () => { await HP.call("setup-done").catch(() => {}); HP.call("close"); };
  },
};

// ================================================================== ACCOUNTS
const Accounts = {
  async render() {
    await refresh();
    const e = S.entra;
    $("#main").innerHTML = `<div class="head"><h1>Accounts</h1><p>Local accounts always work. Connect this PC to Microsoft Entra ID to sign in with work or school accounts.</p></div>
      <div class="card"><div class="row between">
        <div class="row"><span class="dot ${e.enabled ? (e.active ? "ok" : "warn") : ""}"></span><div>
          <h3>Work or school sign-in: ${e.enabled ? "On" : "Off"}</h3>
          <p class="small">${e.enabled ? `Connected to <b>${esc(e.domain)}</b> · service ${e.active ? "running" : "not running"}` : "This PC only uses local accounts."}</p></div></div>
        ${e.enabled ? '<button class="btn danger small" id="off">Disconnect</button>' : ""}
      </div></div>
      <div class="card" id="form"></div>
      <div class="card"><h3>Intune (device management)</h3>
        <p class="small" style="margin-top:6px">After signing in with your work account, open <b>Company Portal</b> and sign in to enrol this PC.
        Your Intune admin must allow Linux devices and Microsoft Edge is used for sign-in. Microsoft officially supports Ubuntu for Intune; HardPoint OS is Ubuntu 24.04 based, but compliance checks that require “Ubuntu” as the distribution will fail.</p>
        <div class="row" style="margin-top:14px"><button class="btn" id="cp" ${e.companyPortal ? "" : "disabled"}>Open Company Portal</button>
        <button class="btn ghost" id="docs">Intune Linux guide</button></div></div>`;
    if (e.enabled) {
      $("#form").innerHTML = `<h3>Signing in with a work account</h3><ol class="small muted" style="margin:10px 0 0 18px;line-height:1.9">
        <li>Sign out (or restart).</li><li>On the login screen choose <b>Not listed?</b> and type your work email.</li>
        <li>Enter your password and approve the MFA prompt.</li><li>Create a PIN — you'll use it to unlock this PC from then on.</li></ol>`;
      $("#off").onclick = async (ev) => {
        const log = consoleBox(Object.assign(document.createElement("div"), { className: "console mono" }));
        await busy(ev.currentTarget, "Disconnecting…", () => HP.root("entra-disable", [], log)).then(() => toast("Work/school sign-in turned off")).catch((x) => toast(x.message));
        Accounts.render();
      };
    } else if (!e.available) {
      $("#form").innerHTML = `<p class="small">The work/school sign-in packages are not included in this build.</p>`;
    } else Accounts.form($("#form"), () => Accounts.render());
    $("#cp").onclick = () => HP.call("open", { app: "company-portal" }).catch((x) => toast(x.message));
    $("#docs").onclick = () => HP.call("url", { url: "https://learn.microsoft.com/intune/intune-service/user-help/enroll-device-linux" });
  },

  form(el, after) {
    el.innerHTML = `<h3>Connect to Microsoft Entra ID</h3>
      <p class="small" style="margin:6px 0 16px">In the Entra admin center, <b>Devices → Device settings → “Users may join devices to Microsoft Entra”</b> must include the people who will sign in.</p>
      <div class="stack">
        <label class="field"><span>Your organisation's domain</span><input type="text" id="dom" placeholder="contoso.com" spellcheck="false"></label>
        <details class="small"><summary class="muted" style="cursor:pointer">Advanced: restrict who can sign in or be admin</summary>
          <div class="grid2" style="margin-top:12px">
            <label class="field"><span>Admin group Object ID (optional)</span><input type="text" id="adm" placeholder="00000000-0000-0000-0000-000000000000" spellcheck="false"></label>
            <label class="field"><span>Allowed-to-sign-in group Object ID (optional)</span><input type="text" id="alw" placeholder="00000000-0000-0000-0000-000000000000" spellcheck="false"></label>
          </div></details>
        <div class="row"><button class="btn primary" id="connect">Connect this PC</button><span class="small muted" id="hint"></span></div>
      </div>
      <div class="console mono" id="elog"></div>`;
    const dom = $("#dom", el), adm = $("#adm", el), alw = $("#alw", el), hint = $("#hint", el);
    $("#connect", el).onclick = async (ev) => {
      const d = dom.value.trim(), a = adm.value.trim(), w = alw.value.trim();
      if (!DOMAIN.test(d)) { hint.textContent = "Enter a domain like contoso.com"; dom.focus(); return; }
      if ((a && !GUID.test(a)) || (w && !GUID.test(w))) { hint.textContent = "Group IDs must be Object IDs (GUIDs) from Entra"; return; }
      hint.textContent = "";
      const log = consoleBox($("#elog", el));
      try {
        await busy(ev.currentTarget, "Connecting…", () => HP.root("entra-enable", [d, a || "-", w || "-"], log));
        toast(`Connected to ${d}`);
        el.insertAdjacentHTML("beforeend", `<div class="status" style="margin-top:14px"><span class="dot ok"></span><div><b>Connected.</b>
          <p class="small">Sign out, choose <b>Not listed?</b> on the login screen and sign in with your ${esc(d)} email. Then open Company Portal to enrol in Intune.</p></div></div>`);
        after && after();
      } catch (e) { hint.textContent = e.message === "cancelled" ? "Cancelled" : "Could not connect — see the details above."; }
    };
  },
};

// ================================================================== SECURITY
const Security = {
  statusGrid(s) {
    const tile = (cls, title, text) => `<div class="status"><span class="dot ${cls}"></span><div><b>${title}</b><p class="small">${text}</p></div></div>`;
    return `<div class="grid3">
      ${tile(s.firewall ? "ok" : "bad", "Firewall", s.firewall ? "Blocking all incoming connections" : "Off")}
      ${tile(s.apparmor ? "ok" : "warn", "App protection", s.apparmor ? "AppArmor confining apps" : "AppArmor not running")}
      ${tile(s.encrypted ? "ok" : "warn", "Disk encryption", s.encrypted ? "Your disk is encrypted" : "Not encrypted — choose encryption when installing")}
      ${tile(s.secureBoot === "on" ? "ok" : "warn", "Secure Boot", s.secureBoot === "on" ? "On" : s.secureBoot === "off" ? "Off — turn it on in the BIOS" : "Unknown")}
      ${tile(s.lockdown ? "ok" : "", "Lockdown Mode", s.lockdown ? "On" : "Off (everyday protection)")}
      ${tile("ok", "Kernel hardening", "Always on: pointer hiding, exploit mitigations")}
    </div>`;
  },
  wire(root) {
    const lock = $("#lock", root), timer = $("#timer", root);
    lock && lock.addEventListener("change", async () => {
      const want = lock.checked;
      try { await HP.root("lockdown", [want ? "on" : "off"]); toast(`Lockdown Mode ${want ? "on" : "off"}`); await refresh(); }
      catch (e) { lock.checked = !want; toast(e.message === "cancelled" ? "Cancelled" : e.message); }
    });
    timer && timer.addEventListener("change", async () => {
      try { await HP.call("update-timer", { args: [timer.checked ? "on" : "off"] }); toast(timer.checked ? "Automatic checks on" : "Automatic checks off"); }
      catch (e) { timer.checked = !timer.checked; toast(e.message); }
    });
  },
  async render() {
    await refresh();
    const s = S.security;
    $("#main").innerHTML = `<div class="head"><h1>Security</h1><p>Everyday protection is always on. Lockdown Mode adds more when you need it.</p></div>
      <div class="stack">${Security.statusGrid(s)}
      <div class="card row between"><div><h3>Lockdown Mode</h3><p class="small">New USB devices blocked until approved · Bluetooth off · debuggers admin-only · io_uring off · pings ignored. Games, Steam, browsers and Flatpak apps keep working.</p></div>${toggleHTML("lock", s.lockdown)}</div>
      <div class="card row between"><div><h3>Automatic update checks</h3><p class="small">Every 6 hours, with a checklist so you choose what installs.</p></div>${toggleHTML("timer", S.updateTimer)}</div>
      ${s.lockdown ? '<div class="card"><h3>Allowing a blocked USB device</h3><p class="small" style="margin-top:6px">Open Terminal and run <code>sudo usbguard list-devices --blocked</code>, then <code>sudo usbguard allow-device -p &lt;number&gt;</code> for devices you recognise.</p></div>' : ""}
      </div>`;
    Security.wire($("#main"));
  },
};

// ================================================================== UPDATES
const Updates = {
  data: null, sel: new Set(),
  async render(refetch = true) {
    $("#main").innerHTML = `<div class="head row between"><div><h1>Updates</h1><p id="usub">Checking…</p></div>
      <div class="row"><button class="btn ghost" id="snaps" title="Undo a bad update">Snapshots</button><button class="btn" id="refresh">Check now</button><button class="btn primary" id="apply" disabled>Install selected</button></div></div>
      <div id="ulist"><div class="card"><div class="bar busy"><i></i></div></div></div>
      <div class="card hidden" id="ulogc"><div class="row between"><h3 id="umsg">Installing updates…</h3></div><div class="bar busy" style="margin-top:12px"><i></i></div><div class="console mono" id="ulog"></div></div>`;
    $("#refresh").onclick = (e) => busy(e.currentTarget, "Checking…", async () => {
      await HP.root("apt-refresh").catch((x) => toast(x.message === "cancelled" ? "Cancelled" : x.message));
      await Updates.load();
    });
    $("#apply").onclick = Updates.apply;
    $("#snaps").onclick = () => HP.call("open", { app: "snapshots" }).catch((x) => toast(x.message));
    if (refetch || !Updates.data) await Updates.load(); else Updates.draw();
  },
  async load() {
    try { Updates.data = await HP.call("updates-list"); }
    catch (e) { Updates.data = { items: [], error: e.message }; }
    Updates.sel = new Set(Updates.data.items.map((i) => i.id));
    Updates.draw();
  },
  draw() {
    const items = Updates.data.items || [];
    const when = Updates.data.checked ? new Date(Updates.data.checked * 1000).toLocaleString() : "";
    $("#usub").textContent = Updates.data.error ? `Could not check: ${Updates.data.error}`
      : items.length ? `${items.length} update${items.length > 1 ? "s" : ""} available${when ? " · checked " + when : ""}` : `You're up to date${when ? " · checked " + when : ""}`;
    if (!items.length) {
      $("#ulist").innerHTML = `<div class="card hero" style="padding:46px"><img class="logo" style="width:84px;height:84px" src="logo.svg" alt=""><h2>All up to date</h2><p>We'll let you know when something new arrives. A safety snapshot is taken before every system update.</p></div>`;
      $("#apply").disabled = true; return;
    }
    const groups = [["Security fixes", (i) => i.security], ["System", (i) => !i.security && i.kind === "system"],
      ["Apps", (i) => !i.security && i.kind === "app"], ["Firmware", (i) => !i.security && i.kind === "firmware"]];
    let html = `<div class="card" style="padding:8px 10px"><div class="item" id="all">${CHECK}<div class="grow"><div class="name">Select all</div></div></div>`;
    for (const [label, f] of groups) {
      const list = items.filter(f); if (!list.length) continue;
      html += `<div class="cat">${label}</div>` + list.map((i) => `<div class="item" data-id="${esc(i.id)}">${CHECK}
        <div class="grow"><div class="name">${esc(i.name)}</div><div class="sub mono">${i.from ? esc(i.from) + " → " : ""}${esc(i.to)}</div></div>
        ${i.security ? '<span class="pill sec">Security</span>' : ""}<span class="pill">${esc(i.kind === "system" ? i.source : i.kind === "app" ? "App" : "Firmware")}</span></div>`).join("");
    }
    $("#ulist").innerHTML = html + "</div>";
    const sync = () => {
      $$("#ulist .item[data-id]").forEach((it) => it.classList.toggle("on", Updates.sel.has(it.dataset.id)));
      $("#all").classList.toggle("on", Updates.sel.size === items.length);
      $("#apply").disabled = !Updates.sel.size;
      $("#apply").textContent = Updates.sel.size ? `Install ${Updates.sel.size} update${Updates.sel.size > 1 ? "s" : ""}` : "Install selected";
    };
    $$("#ulist .item[data-id]").forEach((it) => it.addEventListener("click", () => {
      Updates.sel.has(it.dataset.id) ? Updates.sel.delete(it.dataset.id) : Updates.sel.add(it.dataset.id); sync();
    }));
    $("#all").onclick = () => { Updates.sel = Updates.sel.size === items.length ? new Set() : new Set(items.map((i) => i.id)); sync(); };
    sync();
  },
  async apply() {
    const ids = [...Updates.sel]; if (!ids.length) return;
    $("#ulogc").classList.remove("hidden");
    const log = consoleBox($("#ulog"));
    let restart = false;
    $("#apply").disabled = $("#refresh").disabled = true;
    try {
      await HP.root("apply-updates", ids, (l) => { log(l); if (l.startsWith("RESTART NEEDED")) restart = true; });
      $("#umsg").textContent = restart ? "Updates installed — restart to finish" : "Updates installed";
      toast("Updates installed");
    } catch (e) {
      $("#umsg").textContent = e.message === "cancelled" ? "Cancelled" : "Some updates failed";
    }
    $("#ulogc .bar").classList.remove("busy"); $("#ulogc .bar i").style.width = "100%";
    $("#refresh").disabled = false;
    await Updates.load();
  },
};

// Enter = the main button on each Setup page (unless typing in a field)
document.addEventListener("keydown", (e) => {
  if (e.key !== "Enter" || view !== "setup" || /INPUT|TEXTAREA|BUTTON/.test(document.activeElement?.tagName || "")) return;
  const b = $("#finish") || $("#next"); if (b && !b.disabled) { e.preventDefault(); b.click(); }
});

// ------------------------------------------------------------------ boot
(async () => {
  try { await refresh(); } catch (e) { $("#main").innerHTML = `<div class="card">Could not read system state: ${esc(e.message)}</div>`; return; }
  show(view);
})();
