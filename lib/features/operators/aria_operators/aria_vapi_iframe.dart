// Web/HTML iframe wrapper for ARIA and operator calls.
//
// The “live call UI” is rendered inside the HTML (so it matches the Vapi Web SDK
// requirement). The HTML sends events back to Flutter via `window.parent.postMessage`.

import 'dart:math';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

import 'package:flutter/material.dart';

String _sanitizeAttr(String s) {
  return s.replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll("'", '').trim();
}

String _randomSessionId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}

class AriaVapiSessionIframe {
  static String createSessionId() => _randomSessionId();

  static String creatorHtml({
    required String sessionId,
    required String creatorAssistantId,
    required String publicKey,
    required String accountId,
    required String operatorId,
  }) {
    final aId = _sanitizeAttr(creatorAssistantId);
    final pKey = _sanitizeAttr(publicKey);
    final accId = _sanitizeAttr(accountId);
    final opId = _sanitizeAttr(operatorId);
    final sId = _sanitizeAttr(sessionId);

    return r'''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ARIA Operator Builder</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      background: #020617;
      color: #e5e7eb;
      min-height: 100vh;
      padding: 18px;
    }
    .grid {
      display: grid;
      grid-template-columns: 0.38fr 0.62fr;
      gap: 14px;
      min-height: calc(100vh - 36px);
    }
    @media (max-width: 900px) {
      .grid { grid-template-columns: 1fr; }
    }
    .panel {
      border: 1px solid #1f2937;
      border-radius: 18px;
      background: rgba(2, 6, 23, 0.6);
      padding: 14px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .leftTop {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 10px;
    }
    .tag {
      font-size: 12px;
      padding: 6px 10px;
      border-radius: 999px;
      border: 1px solid #334155;
      color: #94a3b8;
      background: rgba(15, 23, 42, 0.6);
      white-space: nowrap;
    }
    .pulseWrap {
      display: grid;
      place-items: center;
      flex: 1;
      padding: 18px 0;
    }
    .pulse {
      width: 160px;
      height: 160px;
      border-radius: 50%;
      border: 1px solid #1f2937;
      background: radial-gradient(circle at 30% 20%, rgba(165, 180, 252, 0.35), rgba(2,6,23,0.2));
      position: relative;
      display: grid;
      place-items: center;
    }
    .pulse::after {
      content: '';
      position: absolute;
      inset: -10px;
      border-radius: 50%;
      border: 2px solid rgba(165, 180, 252, 0.35);
      animation: ring 1.6s infinite ease-in-out;
    }
    @keyframes ring {
      0% { transform: scale(0.92); opacity: 0.35; }
      50% { transform: scale(1.04); opacity: 0.6; }
      100% { transform: scale(0.92); opacity: 0.35; }
    }
    .pulseTitle {
      font-size: 16px;
      color: #a5b4fc;
      font-weight: 650;
    }
    .sub {
      font-size: 12px;
      color: #94a3b8;
      margin-top: 6px;
      text-align: center;
      max-width: 220px;
    }
    .statusRow {
      display: flex;
      gap: 10px;
      margin-top: 10px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .dot {
      width: 10px; height: 10px; border-radius: 999px;
      background: #94a3b8;
      margin-right: 8px;
      display: inline-block;
    }
    .dot.live { background: #22c55e; }
    .dot.listen { background: #38bdf8; }
    .dot.error { background: #ef4444; }
    .mini {
      display: inline-flex; align-items: center;
      font-size: 12px; color: #cbd5e1;
      background: rgba(15, 23, 42, 0.5);
      border: 1px solid #334155;
      border-radius: 999px;
      padding: 7px 10px;
    }
    .progressWrap {
      margin-top: 10px;
    }
    .progress {
      height: 10px;
      border-radius: 999px;
      background: #0b1225;
      border: 1px solid #1f2937;
      overflow: hidden;
    }
    .bar {
      width: 0%;
      height: 100%;
      background: linear-gradient(90deg, #a5b4fc, #22c55e);
      transition: width 0.5s ease;
    }
    .transcript {
      flex: 1;
      overflow: auto;
      padding-right: 8px;
    }
    .line {
      margin: 8px 0;
      padding: 10px 12px;
      border-radius: 14px;
      border: 1px solid #0f172a;
      background: rgba(2,6,23,0.5);
      opacity: 0;
      transform: translateY(4px);
      animation: fadeIn 0.45s ease forwards;
    }
    @keyframes fadeIn {
      to { opacity: 1; transform: translateY(0); }
    }
    .line.aria { border-color: rgba(165, 180, 252, 0.35); }
    .line.you { border-color: rgba(56, 189, 248, 0.35); }
    .who {
      font-size: 12px;
      color: #94a3b8;
      margin-bottom: 3px;
      letter-spacing: 0.2px;
    }
    .msg { font-size: 14px; white-space: pre-wrap; line-height: 1.35; }
    .bottomBar {
      margin-top: 10px;
      display: flex;
      align-items: center;
      gap: 10px;
      justify-content: space-between;
      flex-wrap: wrap;
    }
    .btn {
      border: none;
      border-radius: 12px;
      padding: 10px 14px;
      font-weight: 700;
      cursor: pointer;
      background: #1f2937;
      color: #e5e7eb;
      border: 1px solid #334155;
    }
    .btn.primary {
      background: #a5b4fc;
      color: #020617;
      border-color: rgba(165, 180, 252, 0.6);
    }
    .btn.danger { background: #ef4444; color: white; border-color: rgba(239, 68, 68, 0.7); }
    .timer {
      font-size: 12px;
      color: #94a3b8;
      padding: 8px 10px;
      border-radius: 999px;
      border: 1px solid #334155;
      background: rgba(15, 23, 42, 0.5);
    }
  </style>
</head>
<body>
  <div class="grid">
    <div class="panel">
      <div class="leftTop">
        <div class="tag">ARIA Operator Builder</div>
        <div class="tag" id="phaseTag">Discovery</div>
      </div>

      <div class="pulseWrap">
        <div id="connectRow" style="text-align:center;margin-bottom:14px;width:100%;max-width:360px;">
          <button class="btn primary" id="connectBtn" type="button">Connect microphone &amp; start ARIA</button>
          <div class="sub" id="connectHint" style="margin-top:8px;max-width:320px;margin-left:auto;margin-right:auto;">Click here in this panel so the browser can use your microphone and play assistant audio (required for embedded calls on most browsers).</div>
          <div class="sub" id="connectStatus" style="margin-top:6px;color:#f87171;min-height:1.2em;"></div>
        </div>
        <div class="pulse" id="pulse">
          <div style="text-align:center;">
            <div class="pulseTitle" id="ariaState">ARIA is listening…</div>
            <div class="sub" id="subState">You speak naturally; ARIA will ask short, clarifying questions.</div>
          </div>
        </div>

        <div class="statusRow">
          <div class="mini"><span class="dot listen" id="listenDot"></span><span id="listenText">Listening…</span></div>
          <div class="mini"><span class="dot" id="ariaDot"></span><span id="ariaText">ARIA waiting</span></div>
        </div>

        <div class="progressWrap">
          <div class="progress"><div class="bar" id="progressBar"></div></div>
        </div>
      </div>
    </div>

    <div class="panel">
      <div style="display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:10px;">
        <div class="tag">Live transcript</div>
        <div class="timer" id="timer">00:00</div>
      </div>

      <div class="transcript" id="transcript"></div>

      <div class="bottomBar">
        <button class="btn" id="muteBtn">Mute</button>
        <div style="flex:1"></div>
        <button class="btn danger" id="endBtn">End session</button>
      </div>
    </div>
  </div>

  <script type="module">
    const publicKey = "'''+pKey+'''";
    let vapi = null;
    const assistantId = "'''+aId+'''";
    const sessionId = "'''+sId+'''";
    const accountId = "'''+accId+'''";
    const operatorId = "'''+opId+'''";

    const transcriptEl = document.getElementById("transcript");
    const ariaStateEl = document.getElementById("ariaState");
    const subStateEl = document.getElementById("subState");
    const timerEl = document.getElementById("timer");

    const listenDot = document.getElementById("listenDot");
    const ariaDot = document.getElementById("ariaDot");
    const listenText = document.getElementById("listenText");
    const ariaText = document.getElementById("ariaText");

    const phaseTag = document.getElementById("phaseTag");
    const progressBar = document.getElementById("progressBar");
    const connectBtn = document.getElementById("connectBtn");
    const connectRow = document.getElementById("connectRow");
    const connectStatus = document.getElementById("connectStatus");

    let muted = false;
    let startedAt = null;
    function fmt(ms) {
      const s = Math.floor(ms/1000);
      const m = Math.floor(s/60);
      const r = s % 60;
      return String(m).padStart(2,'0') + ':' + String(r).padStart(2,'0');
    }
    setInterval(() => {
      if (startedAt == null) return;
      timerEl.textContent = fmt(Date.now() - startedAt);
    }, 500);

    function postToFlutter(payload) {
      let o = "*";
      try {
        const raw = window.location.origin;
        if (raw && raw !== "null" && raw !== "undefined") o = raw;
      } catch (_) {}
      try {
        window.parent.postMessage(payload, o);
      } catch (_) {
        try { window.parent.postMessage(payload, "*"); } catch (e2) {}
      }
    }

    function serializeError(e) {
      try {
        if (e == null || e === undefined) return "null";
        if (typeof e === "string") return e;
        if (e instanceof Error) {
          return [e.name, e.message, e.stack && String(e.stack).slice(0, 600)].filter(Boolean).join(" | ");
        }
        if (typeof e === "object") {
          const parts = [];
          if (e.message) parts.push(String(e.message));
          if (e.name) parts.push("name=" + String(e.name));
          if (e.stack) parts.push("stack=" + String(e.stack).slice(0, 500));
          try {
            const j = JSON.stringify(e);
            parts.push(j.length < 900 ? j : j.slice(0, 900) + "…");
          } catch (_) {}
          return parts.length ? parts.join(" | ") : String(e);
        }
        return String(e);
      } catch (_) {
        return "serializeError_failed";
      }
    }

    function formatVapiSdkError(e) {
      try {
        if (e == null || e === undefined) return "Connection failed (empty error event)";
        if (typeof e === "string") return e;
        if (typeof e === "object" && typeof e.type === "string" && e.type.length) {
          const inner = e.error;
          let im = "";
          if (inner != null && typeof inner === "object") {
            im = String(inner.message || inner.errorMsg || inner.reason || inner.name || "").trim();
            if (!im) {
              try {
                const j = JSON.stringify(inner);
                im = j.length < 500 ? j : j.slice(0, 500) + "…";
              } catch (_) {}
            }
          } else if (typeof inner === "string") {
            im = inner.trim();
          }
          const stage = e.stage ? String(e.stage) : "";
          const head = [e.type, stage].filter(Boolean).join(" — ");
          if (/daily|start-method/i.test(e.type) || im) {
            return im ? head + ": " + im : head;
          }
        }
        if (typeof e.message === "string" && e.message.trim()) return e.message.trim();
        const inner2 = e.error;
        if (inner2 != null && typeof inner2 === "object") {
          const im = inner2.message || inner2.errorMsg || inner2.error || inner2.reason;
          const stage = e.stage || e.type || "";
          const bits = [stage, im && String(im), inner2.stack && String(inner2.stack).slice(0, 400)].filter(Boolean);
          if (bits.length) return bits.join(" — ");
        }
        const ser = serializeError(e);
        if (ser && ser !== "{}") return ser;
        return "Connection failed";
      } catch (_) {
        return "Connection failed";
      }
    }

    function resolveVapiConstructor(mod) {
      if (!mod || typeof mod !== "object") return null;
      function unwrap(cur) {
        let x = cur;
        for (let d = 0; d < 8 && x != null; d++) {
          if (typeof x === "function") return x;
          if (typeof x === "object" && Object.prototype.hasOwnProperty.call(x, "default")) {
            const n = x.default;
            if (n === x) break;
            x = n;
            continue;
          }
          break;
        }
        return null;
      }
      const a = mod.default !== undefined && mod.default !== null ? unwrap(mod.default) : null;
      if (typeof a === "function") return a;
      const b = unwrap(mod);
      if (typeof b === "function") return b;
      if (typeof mod.Vapi === "function") return mod.Vapi;
      return null;
    }

    async function loadVapiModule() {
      const urls = [
        "https://cdn.jsdelivr.net/npm/@vapi-ai/web@2.5.2/+esm",
        "https://esm.sh/@vapi-ai/web@2.5.2"
      ];
      const failures = [];
      for (const url of urls) {
        try {
          const mod = await import(url);
          const Ctor = resolveVapiConstructor(mod);
          if (typeof Ctor === "function") return Ctor;
          const def = mod && mod.default;
          const tag = def == null ? "no default" : (typeof def === "function" ? "fn" : typeof def);
          failures.push(url + ": Vapi export not constructible (default: " + tag + ")");
        } catch (err) {
          failures.push(url + ": " + serializeError(err));
        }
      }
      postToFlutter({
        type: "aria_call_error",
        session_id: sessionId,
        message: "Could not load Vapi web SDK (CDN blocked or unreachable). " + failures.join(" || "),
      });
      return null;
    }

    function appendLine(who, text, kind) {
      const line = document.createElement("div");
      line.className = "line " + kind;

      const whoEl = document.createElement("div");
      whoEl.className = "who";
      whoEl.textContent = who;

      const msgEl = document.createElement("div");
      msgEl.className = "msg";
      msgEl.textContent = text;

      line.appendChild(whoEl);
      line.appendChild(msgEl);
      transcriptEl.appendChild(line);
      transcriptEl.scrollTop = transcriptEl.scrollHeight;
    }

    let phaseIdx = 0;
    let seenUserLines = 0;

    function recordUserTranscript(who, trimmed) {
      const kind = who === "You" ? "you" : "aria";
      appendLine(who, trimmed, kind);
      if (kind === "you") {
        seenUserLines += 1;
        phaseIdx = Math.min(5, Math.floor(seenUserLines / 2));
        setPhase(phaseIdx, 6);
      }
      postToFlutter({ type: "aria_transcript", session_id: sessionId, who: who, text: trimmed });
    }

    function setStateListening() {
      listenDot.classList.add("live");
      ariaDot.classList.remove("live");
      ariaStateEl.textContent = "ARIA is listening…";
      subStateEl.textContent = "You speak naturally; ARIA will ask short, clarifying questions.";
      listenText.textContent = "Listening…";
      ariaText.textContent = "ARIA waiting";
    }

    function setStateSpeaking() {
      listenDot.classList.remove("live");
      ariaDot.classList.add("live");
      ariaStateEl.textContent = "ARIA is speaking…";
      subStateEl.textContent = "Answer naturally; ARIA will confirm what it heard.";
      listenText.textContent = "…";
      ariaText.textContent = "ARIA talking";
    }

    function setPhase(idx, total) {
      const phases = ["Discovery","Mission","Call Flow","Personality","Knowledge","Confirmation"];
      phaseTag.textContent = phases[Math.max(0, Math.min(phases.length-1, idx))] || "Discovery";
      const pct = Math.max(0, Math.min(100, Math.round(((idx+1)/total)*100)));
      progressBar.style.width = pct + "%";
    }

    // Default initial state
    setStateListening();
    setPhase(0, 6);

    // Same pattern as neyvo-website VapiDemo: final transcripts often arrive on `message`
    function wireVapiEvents() {
      if (!vapi) return;
      vapi.on("message", (m) => {
      try {
        if (!m || typeof m !== "object") return;
        if (m.type === "transcript" && m.transcriptType === "final") {
          const text = String(m.transcript || m.text || "").trim();
          if (!text) return;
          const role = String(m.role || "").toLowerCase();
          const who = role === "user" ? "You" : "ARIA";
          recordUserTranscript(who, text);
        }
      } catch (_) {}
    });

    vapi.on("call-start", () => {
      startedAt = Date.now();
      timerEl.textContent = "00:00";
      setStateListening();
    });

    vapi.on("speech-start", () => {
      setStateSpeaking();
    });
    vapi.on("speech-end", () => {
      setStateListening();
    });

    vapi.on("transcript", (t) => {
      // Best-effort handling of SDK transcript payloads.
      // Some SDK builds send { text, is_final, speaker }, others send a string.
      let text = "";
      let speaker = "aria";
      if (typeof t === "string") {
        text = t;
      } else if (t && typeof t === "object") {
        text = t.text || t.transcript || t.value || "";
        if (t.speaker) speaker = t.speaker;
        if (t.is_final === false && text) {
          // Interim lines: keep quiet unless it seems final enough.
        }
      }
      const trimmed = String(text || "").trim();
      if (!trimmed) return;

      // Speaker normalization: treat user vs aria by heuristic.
      const who = (String(speaker).toLowerCase().includes("user") ? "You" : "ARIA");
      recordUserTranscript(who, trimmed);
    });

    vapi.on("call-end", () => {
      postToFlutter({ type: "aria_call_end", session_id: sessionId, operator_id: operatorId, account_id: accountId });
    });

    vapi.on("error", (e) => {
      const msg = formatVapiSdkError(e);
      console.error("[ARIA iframe] vapi error", e);
      postToFlutter({ type: "aria_call_error", session_id: sessionId, message: msg });
    });
    }

    connectBtn.onclick = async function () {
      connectBtn.disabled = true;
      connectStatus.textContent = "Loading Vapi SDK…";
      connectStatus.style.color = "#94a3b8";

      const VapiCls = await loadVapiModule();
      if (!VapiCls) {
        connectStatus.textContent = "SDK load failed — allow cdn.jsdelivr.net and esm.sh or check console.";
        connectStatus.style.color = "#f87171";
        connectBtn.disabled = false;
        return;
      }

      const cleanKey = String(publicKey || "").trim();
      const hasOnlyValidChars = !/[^A-Za-z0-9._-]/.test(cleanKey);
      const validKey = hasOnlyValidChars
        && cleanKey.length >= 20
        && cleanKey.length <= 200
        && !/\s/.test(cleanKey)
        && !cleanKey.startsWith("sk_")
        && !cleanKey.startsWith("vapi_sk_");
      if (!validKey) {
        postToFlutter({
          type: "aria_call_error",
          session_id: sessionId,
          message: "Vapi public key is missing or malformed. Save the raw Vapi public web key (no quotes/spaces/newlines) in Firestore businesses/{account}/operators/aria_operator_creator or backend env VAPI_PUBLIC_KEY.",
        });
        connectStatus.textContent = "Invalid public key configuration.";
        connectStatus.style.color = "#f87171";
        connectBtn.disabled = false;
        return;
      }

      connectStatus.textContent = "Requesting microphone…";
      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
          postToFlutter({
            type: "aria_call_error",
            session_id: sessionId,
            message: "Microphone API is unavailable in this browser context. Use HTTPS and ensure the embedded iframe allows microphone access.",
          });
          connectStatus.textContent = "Microphone API unavailable.";
          connectStatus.style.color = "#f87171";
          connectBtn.disabled = false;
          return;
        }
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const tracks = (stream && stream.getAudioTracks) ? stream.getAudioTracks() : [];
        const hasLiveTrack = tracks.some((t) => t && t.readyState === "live" && t.enabled !== false);
        if (!hasLiveTrack) {
          try { tracks.forEach((t) => t.stop()); } catch (_) {}
          postToFlutter({
            type: "aria_call_error",
            session_id: sessionId,
            message: "Microphone permission was granted but no live audio track was detected. Check browser microphone settings and iframe allow permissions.",
          });
          connectStatus.textContent = "No live microphone track.";
          connectStatus.style.color = "#f87171";
          connectBtn.disabled = false;
          return;
        }
        try { tracks.forEach((t) => t.stop()); } catch (_) {}

        connectStatus.textContent = "Connecting to ARIA…";
        vapi = new VapiCls(cleanKey);
        wireVapiEvents();
        await vapi.start(assistantId, { metadata: { account_id: accountId, operator_id: operatorId, session_id: sessionId } });
        connectRow.style.display = "none";
      } catch (err) {
        let msg = serializeError(err);
        const errName = String((err && err.name) || "");
        if (errName === "NotAllowedError") {
          msg = "Microphone permission is blocked. Allow microphone for this site, then reload and try again.";
        } else if (errName === "NotFoundError") {
          msg = "No microphone input device was found. Connect a microphone and retry.";
        } else if (errName === "NotReadableError") {
          msg = "Microphone is already in use by another app/tab. Close other audio apps and retry.";
        }
        if (/401|unauthor/i.test(String(msg))) {
          msg += " — Use the Vapi public (web) key from the dashboard (same value as NEXT_PUBLIC_VAPI_KEY on the website) and aria_operator_creator_assistant_id from the same Vapi project. Set vapi_public_key in Firestore businesses/{account}/operators/aria_operator_creator or backend env VAPI_PUBLIC_KEY (VAPI_PRIVATE_KEY is server-only).";
        }
        postToFlutter({ type: "aria_call_error", session_id: sessionId, message: msg });
        console.error("[ARIA iframe] connect/start failed", err);
        connectStatus.textContent = msg.slice(0, 220) + (msg.length > 220 ? "…" : "");
        connectStatus.style.color = "#f87171";
        connectBtn.disabled = false;
      }
    };

    const muteBtn = document.getElementById("muteBtn");
    muteBtn.onclick = () => {
      muted = !muted;
      try { if (vapi) vapi.setMuted(muted); } catch (e) {}
      muteBtn.textContent = muted ? "Unmute" : "Mute";
    };

    document.getElementById("endBtn").onclick = () => {
      if (confirm("Are you sure? Your operator won't be created.")) {
        try { if (vapi) vapi.stop(); } catch (e) {}
        postToFlutter({ type: "aria_call_end", session_id: sessionId, operator_id: operatorId, account_id: accountId, ended_by_user: true });
      }
    };
  </script>
</body>
</html>''';
  }

  static String operatorCallHtml({
    required String sessionId,
    required String operatorAssistantId,
    required String publicKey,
    required String accountId,
    required String operatorId,
  }) {
    final aId = _sanitizeAttr(operatorAssistantId);
    final pKey = _sanitizeAttr(publicKey);
    final accId = _sanitizeAttr(accountId);
    final opId = _sanitizeAttr(operatorId);
    final sId = _sanitizeAttr(sessionId);

    return r'''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Operator Call</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif; background: #020617; color: #e5e7eb; min-height: 100vh; padding: 18px; }
    .card { max-width: 760px; margin: 0 auto; border: 1px solid #1f2937; border-radius: 18px; background: rgba(2,6,23,0.6); padding: 16px; }
    .row { display:flex; align-items:center; justify-content:space-between; gap: 10px; flex-wrap:wrap; margin-bottom: 12px; }
    .tag { font-size: 12px; padding: 6px 10px; border-radius: 999px; border: 1px solid #334155; color: #94a3b8; background: rgba(15, 23, 42, 0.6); }
    .btn { border:none; border-radius: 12px; padding: 10px 14px; font-weight: 700; cursor:pointer; background:#1f2937; color:#e5e7eb; border:1px solid #334155; }
    .primary { background: #a5b4fc; color: #020617; border-color: rgba(165, 180, 252, 0.6); }
    .danger { background: #ef4444; border-color: rgba(239, 68, 68, 0.7); color: white; }
    .log { border:1px solid #1f2937; border-radius: 14px; padding: 12px; min-height: 260px; max-height: 60vh; overflow:auto; background: rgba(2,6,23,0.3); }
    .line { margin: 8px 0; padding: 10px 12px; border-radius: 14px; border:1px solid #0f172a; background: rgba(2,6,23,0.5); }
    .who { font-size: 12px; color:#94a3b8; margin-bottom: 3px; }
    .msg { font-size: 14px; white-space: pre-wrap; line-height: 1.35; }
    .note { margin-top: 10px; font-size: 12px; color:#94a3b8; }
  </style>
</head>
<body>
  <div class="card">
    <div class="row">
      <div class="tag">Live operator call</div>
      <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
        <button class="btn" id="muteBtn">Mute</button>
        <button class="btn danger" id="endBtn">End call</button>
      </div>
    </div>
    <div class="row" id="connectRowOp" style="margin-bottom:10px;">
      <button class="btn primary" id="connectBtnOp" type="button">Connect microphone &amp; start call</button>
    </div>
    <div class="note" id="connectStatusOp" style="margin-bottom:8px;min-height:1.2em;color:#f87171;"></div>
    <div class="log" id="log"></div>
    <div class="note">This is a direct test call to your operator assistant. Tap Connect above first.</div>
  </div>

  <script type="module">
    const publicKey = "'''+pKey+'''";
    let vapi = null;
    const assistantId = "'''+aId+'''";
    const sessionId = "'''+sId+'''";
    const accountId = "'''+accId+'''";
    const operatorId = "'''+opId+'''";
    const logEl = document.getElementById("log");
    const connectBtnOp = document.getElementById("connectBtnOp");
    const connectRowOp = document.getElementById("connectRowOp");
    const connectStatusOp = document.getElementById("connectStatusOp");

    function postToFlutter(payload) {
      let o = "*";
      try {
        const raw = window.location.origin;
        if (raw && raw !== "null" && raw !== "undefined") o = raw;
      } catch (_) {}
      try {
        window.parent.postMessage(payload, o);
      } catch (_) {
        try { window.parent.postMessage(payload, "*"); } catch (e2) {}
      }
    }

    function serializeError(e) {
      try {
        if (e == null || e === undefined) return "null";
        if (typeof e === "string") return e;
        if (e instanceof Error) {
          return [e.name, e.message, e.stack && String(e.stack).slice(0, 600)].filter(Boolean).join(" | ");
        }
        if (typeof e === "object") {
          const parts = [];
          if (e.message) parts.push(String(e.message));
          if (e.name) parts.push("name=" + String(e.name));
          if (e.stack) parts.push("stack=" + String(e.stack).slice(0, 500));
          try {
            const j = JSON.stringify(e);
            parts.push(j.length < 900 ? j : j.slice(0, 900) + "…");
          } catch (_) {}
          return parts.length ? parts.join(" | ") : String(e);
        }
        return String(e);
      } catch (_) {
        return "serializeError_failed";
      }
    }

    function formatVapiSdkError(e) {
      try {
        if (e == null || e === undefined) return "Connection failed (empty error event)";
        if (typeof e === "string") return e;
        if (typeof e === "object" && typeof e.type === "string" && e.type.length) {
          const inner = e.error;
          let im = "";
          if (inner != null && typeof inner === "object") {
            im = String(inner.message || inner.errorMsg || inner.reason || inner.name || "").trim();
            if (!im) {
              try {
                const j = JSON.stringify(inner);
                im = j.length < 500 ? j : j.slice(0, 500) + "…";
              } catch (_) {}
            }
          } else if (typeof inner === "string") {
            im = inner.trim();
          }
          const stage = e.stage ? String(e.stage) : "";
          const head = [e.type, stage].filter(Boolean).join(" — ");
          if (/daily|start-method/i.test(e.type) || im) {
            return im ? head + ": " + im : head;
          }
        }
        if (typeof e.message === "string" && e.message.trim()) return e.message.trim();
        const inner2 = e.error;
        if (inner2 != null && typeof inner2 === "object") {
          const im = inner2.message || inner2.errorMsg || inner2.error || inner2.reason;
          const stage = e.stage || e.type || "";
          const bits = [stage, im && String(im), inner2.stack && String(inner2.stack).slice(0, 400)].filter(Boolean);
          if (bits.length) return bits.join(" — ");
        }
        const ser = serializeError(e);
        if (ser && ser !== "{}") return ser;
        return "Connection failed";
      } catch (_) {
        return "Connection failed";
      }
    }

    function resolveVapiConstructor(mod) {
      if (!mod || typeof mod !== "object") return null;
      function unwrap(cur) {
        let x = cur;
        for (let d = 0; d < 8 && x != null; d++) {
          if (typeof x === "function") return x;
          if (typeof x === "object" && Object.prototype.hasOwnProperty.call(x, "default")) {
            const n = x.default;
            if (n === x) break;
            x = n;
            continue;
          }
          break;
        }
        return null;
      }
      const a = mod.default !== undefined && mod.default !== null ? unwrap(mod.default) : null;
      if (typeof a === "function") return a;
      const b = unwrap(mod);
      if (typeof b === "function") return b;
      if (typeof mod.Vapi === "function") return mod.Vapi;
      return null;
    }

    async function loadVapiModule() {
      const urls = [
        "https://cdn.jsdelivr.net/npm/@vapi-ai/web@2.5.2/+esm",
        "https://esm.sh/@vapi-ai/web@2.5.2"
      ];
      const failures = [];
      for (const url of urls) {
        try {
          const mod = await import(url);
          const Ctor = resolveVapiConstructor(mod);
          if (typeof Ctor === "function") return Ctor;
          const def = mod && mod.default;
          const tag = def == null ? "no default" : (typeof def === "function" ? "fn" : typeof def);
          failures.push(url + ": Vapi export not constructible (default: " + tag + ")");
        } catch (err) {
          failures.push(url + ": " + serializeError(err));
        }
      }
      postToFlutter({
        type: "aria_call_error",
        session_id: sessionId,
        operator_id: operatorId,
        message: "Could not load Vapi web SDK (CDN blocked or unreachable). " + failures.join(" || "),
      });
      return null;
    }

    function appendLine(who, text) {
      const line = document.createElement("div");
      line.className = "line";
      const whoEl = document.createElement("div");
      whoEl.className = "who";
      whoEl.textContent = who;
      const msgEl = document.createElement("div");
      msgEl.className = "msg";
      msgEl.textContent = text;
      line.appendChild(whoEl);
      line.appendChild(msgEl);
      logEl.appendChild(line);
      logEl.scrollTop = logEl.scrollHeight;
    }

    function wireOperatorVapiEvents() {
      if (!vapi) return;
      vapi.on("message", (m) => {
        try {
          if (!m || typeof m !== "object") return;
          if (m.type === "transcript" && m.transcriptType === "final") {
            const text = String(m.transcript || m.text || "").trim();
            if (!text) return;
            const role = String(m.role || "").toLowerCase();
            const who = role === "user" ? "You" : "Operator";
            appendLine(who, text);
          }
        } catch (_) {}
      });

      vapi.on("transcript", (t) => {
        let text = "";
        let speaker = "aria";
        if (typeof t === "string") { text = t; }
        else if (t && typeof t === "object") {
          text = t.text || t.transcript || t.value || "";
          if (t.speaker) speaker = t.speaker;
        }
        const trimmed = String(text || "").trim();
        if (!trimmed) return;
        const who = (String(speaker).toLowerCase().includes("user") ? "You" : "Operator");
        appendLine(who, trimmed);
      });

      vapi.on("call-end", () => {
        postToFlutter({ type: "aria_call_end", session_id: sessionId, operator_id: operatorId });
      });
      vapi.on("error", (e) => {
        const msg = formatVapiSdkError(e);
        console.error("[ARIA operator iframe] vapi error", e);
        postToFlutter({ type: "aria_call_error", session_id: sessionId, operator_id: operatorId, message: msg });
      });
    }

    connectBtnOp.onclick = async function () {
      connectBtnOp.disabled = true;
      connectStatusOp.textContent = "Loading Vapi SDK…";
      connectStatusOp.style.color = "#94a3b8";

      const VapiCls = await loadVapiModule();
      if (!VapiCls) {
        connectStatusOp.textContent = "SDK load failed — allow cdn.jsdelivr.net and esm.sh.";
        connectStatusOp.style.color = "#f87171";
        connectBtnOp.disabled = false;
        return;
      }

      const cleanKey = String(publicKey || "").trim();
      const hasOnlyValidChars = !/[^A-Za-z0-9._-]/.test(cleanKey);
      const validKey = hasOnlyValidChars
        && cleanKey.length >= 20
        && cleanKey.length <= 200
        && !/\s/.test(cleanKey)
        && !cleanKey.startsWith("sk_")
        && !cleanKey.startsWith("vapi_sk_");
      if (!validKey) {
        postToFlutter({
          type: "aria_call_error",
          session_id: sessionId,
          operator_id: operatorId,
          message: "Vapi public key is missing or malformed. Fix businesses/{account}/operators/aria_operator_creator vapi_public_key or VAPI_PUBLIC_KEY.",
        });
        connectStatusOp.textContent = "Invalid public key.";
        connectStatusOp.style.color = "#f87171";
        connectBtnOp.disabled = false;
        return;
      }

      connectStatusOp.textContent = "Requesting microphone…";
      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
          postToFlutter({
            type: "aria_call_error",
            session_id: sessionId,
            operator_id: operatorId,
            message: "Microphone API is unavailable. Use HTTPS.",
          });
          connectBtnOp.disabled = false;
          return;
        }
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const tracks = (stream && stream.getAudioTracks) ? stream.getAudioTracks() : [];
        const hasLiveTrack = tracks.some((t) => t && t.readyState === "live" && t.enabled !== false);
        if (!hasLiveTrack) {
          try { tracks.forEach((t) => t.stop()); } catch (_) {}
          postToFlutter({
            type: "aria_call_error",
            session_id: sessionId,
            operator_id: operatorId,
            message: "No live microphone track.",
          });
          connectBtnOp.disabled = false;
          return;
        }
        try { tracks.forEach((t) => t.stop()); } catch (_) {}

        connectStatusOp.textContent = "Connecting…";
        vapi = new VapiCls(cleanKey);
        wireOperatorVapiEvents();
        await vapi.start(assistantId, { metadata: { account_id: accountId, operator_id: operatorId, session_id: sessionId } });
        connectRowOp.style.display = "none";
        connectStatusOp.textContent = "";
      } catch (err) {
        let msg = serializeError(err);
        const errName = String((err && err.name) || "");
        if (errName === "NotAllowedError") msg = "Microphone permission blocked.";
        else if (errName === "NotFoundError") msg = "No microphone found.";
        else if (errName === "NotReadableError") msg = "Microphone in use elsewhere.";
        if (/401|unauthor/i.test(String(msg))) {
          msg += " — Use Vapi public key + assistant from the same project.";
        }
        postToFlutter({ type: "aria_call_error", session_id: sessionId, operator_id: operatorId, message: msg });
        console.error("[ARIA operator iframe] start failed", err);
        connectStatusOp.textContent = msg.slice(0, 220) + (msg.length > 220 ? "…" : "");
        connectStatusOp.style.color = "#f87171";
        connectBtnOp.disabled = false;
      }
    };

    let muted = false;
    const muteBtn = document.getElementById("muteBtn");
    muteBtn.onclick = () => {
      muted = !muted;
      try { if (vapi) vapi.setMuted(muted); } catch (e) {}
      muteBtn.textContent = muted ? "Unmute" : "Mute";
    };

    document.getElementById("endBtn").onclick = () => {
      if (confirm("End this test call?")) {
        try { if (vapi) vapi.stop(); } catch (e) {}
        postToFlutter({ type: "aria_call_end", session_id: sessionId, operator_id: operatorId, ended_by_user: true });
      }
    };
  </script>
</body>
</html>''';
  }
}

// Note: This widget is web-only.
class AriaIframeView extends StatefulWidget {
  final String htmlSrcDoc;
  final String viewType;

  const AriaIframeView({
    required this.htmlSrcDoc,
    required this.viewType,
    super.key,
  });

  @override
  State<AriaIframeView> createState() => _AriaIframeViewState();
}

class _AriaIframeViewState extends State<AriaIframeView> {
  static final Set<String> _registeredViewTypes = <String>{};

  @override
  void initState() {
    super.initState();
    // Register a platform view factory exactly once per viewType.
    if (_registeredViewTypes.add(widget.viewType)) {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(widget.viewType, (int _) {
        // Use a blob: URL instead of srcdoc. about:srcdoc can yield an opaque origin
        // ("null"), which breaks Vapi/Daily.co (postMessage targetOrigin, WebRTC).
        final blob = html.Blob([widget.htmlSrcDoc], 'text/html');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final iframe = html.IFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow =
              'microphone; autoplay; clipboard-read; clipboard-write; display-capture'
          ..src = url;
        iframe.onLoad.listen((_) {
          html.Url.revokeObjectUrl(url);
        });
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.viewType);
  }
}

