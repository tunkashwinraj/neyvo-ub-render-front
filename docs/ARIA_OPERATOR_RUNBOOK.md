# ARIA operator (Vapi web) — runbook

## What runs where

- **Flutter web — Create operator (creator) flow:** After `POST /api/operators/initiate-aria-call`, the app loads **`web/neyvo_vapi_bridge.js`** (see `web/index.html`) in the **same page** as Flutter. That script dynamically imports **`@vapi-ai/web@2.5.2`** (jsDelivr, then esm.sh) and exposes `window.neyvoAria`. Dart calls `start` / `stop` after the user taps **Connect microphone & start ARIA** (clear gesture in the main document).
- **Flutter web — Operator test call** (detail screen dialog): may still use the **HTML iframe** path (`AriaIframeView` + `operatorCallHtml`) for the embedded test UI.
- **Non-web** (Windows/macOS/iOS/Android): create-operator live voice shows a **“use Flutter web”** message; the HTTP backend is unchanged.

## Firestore (per account)

- **Path:** `businesses/{account_id}/operators/aria_operator_creator`
- **Fields:**
  - `vapi_public_key` — Vapi **public (browser)** key only (same project as the assistant). Not `sk_` / `vapi_sk_`. No quotes/newlines.
  - `aria_operator_creator_assistant_id` — Assistant ID for the **creator** voice interview.

## Environment fallbacks (backend)

- `VAPI_PUBLIC_KEY` — if Firestore `vapi_public_key` is empty.
- `ARIA_OPERATOR_CREATOR_ASSISTANT_ID` — if Firestore `aria_operator_creator_assistant_id` is empty.

## Client requirements

- **HTTPS** in production.
- **Microphone** permission for the app origin.
- **Network:** allow `cdn.jsdelivr.net` and `esm.sh` (or the second CDN is used if the first fails). Calls go to `api.vapi.ai`.

## Verify in DevTools (Network)

1. `POST .../api/operators/initiate-aria-call` → **200**, body includes non-empty `vapi_public_key`, `aria_operator_creator_assistant_id`, `operator_id`.
2. After clicking **Connect** on the creator screen: requests to **`cdn.jsdelivr.net`** and/or **`esm.sh`** for the SDK → **200** (same for the bridge script’s `import()`).
3. **`https://api.vapi.ai/...`** (e.g. web call creation) → not **401** (401 usually means key/assistant mismatch or wrong key type).

## Manual smoke checklist

- [ ] Firestore doc exists for the same `account_id` the app sends on API calls.
- [ ] Public key and assistant ID are from the **same** Vapi project.
- [ ] Open **Create Operator with ARIA** on **web** → start session → click **Connect microphone & start ARIA** → hear assistant, see transcripts in the live transcript panel.
- [ ] If SDK fails to load: UI shows which CDN attempts failed; check corporate firewall/ad block.

## Unrelated logs

- Pulse shell messages like **“Real-time wallet … unavailable”** come from Firestore wallet listeners, not Vapi.
