/**
 * Vapi Web SDK bridge for Flutter web (same document as the app — no iframe).
 * Loaded as a module from index.html; exposes window.neyvoAria + window.neyvoAriaReady.
 */
let vapiInstance = null;

/**
 * Pass detail to Dart as a JSON string so DDC does not rely on [getProperty] on
 * anonymous JS object literals (often fails silently → empty transcript map).
 */
function emitToFlutter(onEvent, type, payload) {
  try {
    if (typeof onEvent !== "function") return;
    let s = "";
    if (payload == null || payload === undefined) {
      s = "";
    } else if (typeof payload === "string") {
      s = payload;
    } else if (typeof payload === "object") {
      s = JSON.stringify(payload);
    } else {
      s = JSON.stringify({ message: String(payload) });
    }
    onEvent(type, s);
  } catch (err) {
    console.error("[neyvo_vapi_bridge] emitToFlutter failed", type, err);
  }
}

/** Best-effort transcript extraction from Vapi / Daily `message` payloads. */
function transcriptFromVapiMessage(m) {
  try {
    if (!m || typeof m !== "object") return null;

    if (m.type === "transcript") {
      const text = String(m.transcript || m.text || "").trim();
      if (!text) return null;
      const role = String(m.role || "").toLowerCase();
      const who =
        role === "user" || role === "customer" || role === "caller"
          ? "You"
          : "ARIA";
      const finalSeg =
        m.transcriptType === "final" ||
        m.is_final === true ||
        m.final === true;
      return { who, text, final: finalSeg };
    }

    // Alternate shapes seen across SDK / transport versions
    if (m.transcript && typeof m.transcript === "string") {
      const text = String(m.transcript).trim();
      if (!text) return null;
      const role = String(m.role || "").toLowerCase();
      const who =
        role === "user" || role === "customer" || role === "caller"
          ? "You"
          : "ARIA";
      const finalSeg =
        m.transcriptType === "final" ||
        m.is_final === true ||
        m.final === true;
      return { who, text, final: finalSeg };
    }

    const nested = m.message || m.payload || m.data || m.content;
    if (nested && typeof nested === "object") {
      if (nested.type === "transcript" || nested.transcript || nested.text) {
        const text = String(
          nested.transcript || nested.text || nested.value || ""
        ).trim();
        if (!text) return null;
        const role = String(nested.role || m.role || "").toLowerCase();
        const who =
          role === "user" || role === "customer" || role === "caller"
            ? "You"
            : "ARIA";
        return { who, text };
      }
    }
  } catch (_) {}
  return null;
}

function serializeError(e) {
  try {
    if (e == null) return "null";
    if (typeof e === "string") return e;
    if (e instanceof Error) {
      return [e.name, e.message, e.stack && String(e.stack).slice(0, 600)].filter(Boolean).join(" | ");
    }
    if (typeof e === "object") {
      const parts = [];
      if (e.message) parts.push(String(e.message));
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
    "https://esm.sh/@vapi-ai/web@2.5.2",
  ];
  const failures = [];
  for (const url of urls) {
    try {
      const mod = await import(url);
      const Ctor = resolveVapiConstructor(mod);
      if (typeof Ctor === "function") return Ctor;
      const def = mod && mod.default;
      const tag = def == null ? "no default" : typeof def === "function" ? "fn" : typeof def;
      failures.push(url + ": not constructible (default: " + tag + ")");
    } catch (err) {
      failures.push(url + ": " + serializeError(err));
    }
  }
  throw new Error("Could not load Vapi web SDK. " + failures.join(" || "));
}

function wireVapiEvents(onEvent) {
  if (!vapiInstance) return;
  vapiInstance.on("message", (m) => {
    try {
      const payload = transcriptFromVapiMessage(m);
      if (payload) {
        emitToFlutter(onEvent, "transcript", payload);
      }
    } catch (_) {}
  });

  vapiInstance.on("call-start", () => emitToFlutter(onEvent, "call-start", {}));

  vapiInstance.on("speech-start", () =>
    emitToFlutter(onEvent, "speech-start", {})
  );
  vapiInstance.on("speech-end", () =>
    emitToFlutter(onEvent, "speech-end", {})
  );

  vapiInstance.on("transcript", (t) => {
    let text = "";
    let speaker = "aria";
    let finalSeg = false;
    if (typeof t === "string") {
      text = t;
    } else if (t && typeof t === "object") {
      text = t.text || t.transcript || t.value || "";
      if (t.speaker) speaker = t.speaker;
      finalSeg =
        t.is_final === true ||
        t.final === true ||
        t.transcriptType === "final";
    }
    const trimmed = String(text || "").trim();
    if (!trimmed) return;
    const low = String(speaker).toLowerCase();
    const who =
      low.includes("user") ||
      low.includes("customer") ||
      low.includes("caller")
        ? "You"
        : "ARIA";
    emitToFlutter(onEvent, "transcript", {
      who,
      text: trimmed,
      final: finalSeg,
    });
  });

  vapiInstance.on("call-end", () => emitToFlutter(onEvent, "call-end", {}));

  vapiInstance.on("error", (e) => {
    const msg = formatVapiSdkError(e);
    console.error("[neyvo_vapi_bridge] vapi error", e);
    emitToFlutter(onEvent, "error", { message: msg });
  });
}

window.neyvoAria = {
  /**
   * @param {string} publicKey
   * @param {string} assistantId
   * @param {{ session_id?: string, account_id?: string, operator_id?: string }} metadata
   * @param {(type: string, detail: object) => void} onEvent
   */
  async start(publicKey, assistantId, metadata, onEvent) {
    if (typeof onEvent !== "function") throw new Error("onEvent required");
    await window.neyvoAria.stop();
    const VapiCls = await loadVapiModule();
    const cleanKey = String(publicKey || "").trim();
    const hasOnlyValidChars = !/[^A-Za-z0-9._-]/.test(cleanKey);
    const validKey =
      hasOnlyValidChars &&
      cleanKey.length >= 20 &&
      cleanKey.length <= 200 &&
      !/\s/.test(cleanKey) &&
      !cleanKey.startsWith("sk_") &&
      !cleanKey.startsWith("vapi_sk_");
    if (!validKey) {
      emitToFlutter(onEvent, "error", {
        message:
          "Vapi public key is missing or malformed. Save the raw Vapi public web key in Firestore businesses/{account}/operators/aria_operator_creator or backend env VAPI_PUBLIC_KEY.",
      });
      return;
    }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      emitToFlutter(onEvent, "error", {
        message:
          "Microphone API is unavailable. Use HTTPS and a supported browser.",
      });
      return;
    }
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const tracks = stream && stream.getAudioTracks ? stream.getAudioTracks() : [];
    const hasLiveTrack = tracks.some((t) => t && t.readyState === "live" && t.enabled !== false);
    if (!hasLiveTrack) {
      try {
        tracks.forEach((t) => t.stop());
      } catch (_) {}
      emitToFlutter(onEvent, "error", {
        message: "Microphone permission was granted but no live audio track was detected.",
      });
      return;
    }
    try {
      tracks.forEach((t) => t.stop());
    } catch (_) {}

    const meta = metadata && typeof metadata === "object" ? metadata : {};
    vapiInstance = new VapiCls(cleanKey);
    wireVapiEvents(onEvent);
    await vapiInstance.start(assistantId, { metadata: meta });
  },

  stop() {
    try {
      if (vapiInstance) {
        vapiInstance.stop();
      }
    } catch (_) {}
    vapiInstance = null;
  },

  setMuted(muted) {
    try {
      if (vapiInstance && typeof vapiInstance.setMuted === "function") {
        vapiInstance.setMuted(!!muted);
      }
    } catch (_) {}
  },
};

window.neyvoAriaReady = true;
