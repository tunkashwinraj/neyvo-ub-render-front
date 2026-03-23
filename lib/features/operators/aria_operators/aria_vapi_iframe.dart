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
    // Match neyvo-website: @vapi-ai/web ^2.5.2 (pinned for stable ESM in iframe)
    import Vapi from "https://esm.sh/@vapi-ai/web@2.5.2";

    const vapi = new Vapi("'''+pKey+'''");
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
      try {
        window.parent.postMessage(payload, "*");
      } catch (e) {}
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

    async function startAriaCall() {
      try {
        // In embedded iframe mode, explicitly requesting mic access first makes
        // browser permission behavior far more reliable.
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
          try {
            stream.getTracks().forEach((t) => t.stop());
          } catch (_) {}
        }
        await vapi.start(assistantId, { metadata: { account_id: accountId, operator_id: operatorId, session_id: sessionId } });
      } catch (err) {
        let msg = (err && err.message)
          ? err.message
          : "Could not start ARIA call (check Vapi public key / assistant id)";
        // Browser shows 401 on api.vapi.ai/call/web when key/assistant mismatch
        if (/401|unauthor/i.test(String(msg))) {
          msg += " — Use the Vapi public (web) key from the dashboard (same value as NEXT_PUBLIC_VAPI_KEY on the website) and aria_operator_creator_assistant_id from the same Vapi project. Set both in Firestore businesses/{account}/operators/aria_operator_creator or env VAPI_PUBLIC_KEY / ARIA_OPERATOR_CREATOR_ASSISTANT_ID.";
        }
        postToFlutter({ type: "aria_call_error", session_id: sessionId, message: msg });
      }
    }

    startAriaCall();

    // Same pattern as neyvo-website VapiDemo: final transcripts often arrive on `message`
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
      const msg = e && e.message ? e.message : "Connection failed";
      postToFlutter({ type: "aria_call_error", session_id: sessionId, message: msg });
    });

    const muteBtn = document.getElementById("muteBtn");
    muteBtn.onclick = () => {
      muted = !muted;
      try { vapi.setMuted(muted); } catch (e) {}
      muteBtn.textContent = muted ? "Unmute" : "Mute";
    };

    document.getElementById("endBtn").onclick = () => {
      if (confirm("Are you sure? Your operator won't be created.")) {
        try { vapi.stop(); } catch (e) {}
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
    <div class="log" id="log"></div>
    <div class="note">This is a direct test call to your operator assistant.</div>
  </div>

  <script type="module">
    import Vapi from "https://esm.sh/@vapi-ai/web@2.5.2";
    const vapi = new Vapi("'''+pKey+'''");
    const assistantId = "'''+aId+'''";
    const sessionId = "'''+sId+'''";
    const accountId = "'''+accId+'''";
    const operatorId = "'''+opId+'''";
    const logEl = document.getElementById("log");

    function postToFlutter(payload) {
      try { window.parent.postMessage(payload, "*"); } catch (e) {}
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

    let muted = false;
    const muteBtn = document.getElementById("muteBtn");
    muteBtn.onclick = () => {
      muted = !muted;
      try { vapi.setMuted(muted); } catch (e) {}
      muteBtn.textContent = muted ? "Unmute" : "Mute";
    };

    document.getElementById("endBtn").onclick = () => {
      if (confirm("End this test call?")) {
        try { vapi.stop(); } catch (e) {}
        postToFlutter({ type: "aria_call_end", session_id: sessionId, operator_id: operatorId, ended_by_user: true });
      }
    };

    async function startOpCall() {
      try {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
          try { stream.getTracks().forEach((t) => t.stop()); } catch (_) {}
        }
        await vapi.start(assistantId, { metadata: { account_id: accountId, operator_id: operatorId, session_id: sessionId } });
      } catch (err) {
        const msg = (err && err.message) ? err.message : "Could not start call";
        postToFlutter({ type: "aria_call_error", session_id: sessionId, operator_id: operatorId, message: msg });
      }
    }
    startOpCall();

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
      const msg = e && e.message ? e.message : "Connection failed";
      postToFlutter({ type: "aria_call_error", session_id: sessionId, operator_id: operatorId, message: msg });
    });
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
        final iframe = html.IFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'microphone *; autoplay *'
          ..srcdoc = widget.htmlSrcDoc;
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.viewType);
  }
}

