# VAPI: Set X-Vapi-Secret for webhook (prompt for Composer / manual steps)

Use this to configure your VAPI assistant and phone so webhooks are accepted by the backend at `https://neyvo-pulse.onrender.com`.

---

## Copy-paste prompt: Twilio number → server + assistant

Use this to point your **Twilio-imported number +1 (229) 600 6675** at your server and assistant:

```
I have a Twilio-imported phone number in VAPI: +1 (229) 600 6675 (E.164: +12296006675).

I need to:

1. **Point this phone number to my server**
   - **Server URL (webhook):** https://neyvo-pulse.onrender.com/webhooks/vapi/events
   - **Custom header:** X-Vapi-Secret = j5cMzCB>=D=1pPVnE_RA (exactly, including special characters)
   So all inbound and outbound call events for this number are sent to that URL with that header.

2. **Use my assistant for this number**
   - **Assistant ID:** 93f2fcf8-a0e8-422c-be36-2d7c20fb4904
   This number should use this assistant for inbound calls and for outbound campaigns (so the AI and webhooks are the same).

Please give me:
- Exact VAPI dashboard steps to find the phone number +1 229 600 6675, set its Server URL and X-Vapi-Secret header, and assign/link the assistant above.
- If using the VAPI API instead: the PATCH request(s) to update this phone number with serverUrl, custom headers, and assistantId (or equivalent).
- The **VAPI Phone Number ID** for +1 229 600 6675 so I can set VAPI_PULSE_PHONE_NUMBER_ID in my backend for outbound campaigns.
```

---

## Copy-paste prompt for Composer AI (generic)

```
I need to configure VAPI so that webhooks are sent to my server with the X-Vapi-Secret header.

**Goal:** When VAPI sends events (call started, ended, transcript, etc.) to my server, the request must include the header:
- **Header name:** X-Vapi-Secret
- **Header value:** j5cMzCB>=D=1pPVnE_RA

**Server URL (webhook endpoint):**  
https://neyvo-pulse.onrender.com/webhooks/vapi/events

**Resources to update in VAPI (dashboard or API):**

1. **Assistant**  
   - Assistant ID: 93f2fcf8-a0e8-422c-be36-2d7c20fb4904  
   - Set the assistant’s server URL to: https://neyvo-pulse.onrender.com/webhooks/vapi/events  
   - Add a custom header for the webhook: name = X-Vapi-Secret, value = j5cMzCB>=D=1pPVnE_RA  

2. **Phone number**  
   - Phone number ID: 3007da9c-6d2c-4c38-85bd-6cfa7900f8f2  
   - Set this phone’s server URL to: https://neyvo-pulse.onrender.com/webhooks/vapi/events  
   - Add the same custom header: name = X-Vapi-Secret, value = j5cMzCB>=D=1pPVnE_RA  

Please give me exact steps for the VAPI dashboard (where to click, which fields to fill), or if using the VAPI API, the exact request body/fields to PATCH the assistant and the phone number with this server URL and custom header. The header value must be sent exactly as: j5cMzCB>=D=1pPVnE_RA (including the special characters).
```

---

## Manual steps (VAPI dashboard)

If you prefer to do it yourself:

1. **Assistant**
   - Go to [VAPI dashboard](https://dashboard.vapi.ai) → **Assistants**.
   - Open the assistant with ID `93f2fcf8-a0e8-422c-be36-2d7c20fb4904`.
   - Find **Server** / **Server URL** / **Webhook** (or similar).
   - Set **Server URL** to: `https://neyvo-pulse.onrender.com/webhooks/vapi/events`
   - Add **custom header**: name `X-Vapi-Secret`, value `j5cMzCB>=D=1pPVnE_RA`.
   - Save.

2. **Phone number**
   - Go to **Phone Numbers** (or **Numbers**).
   - Open the phone with ID `3007da9c-6d2c-4c38-85bd-6cfa7900f8f2`.
   - Set **Server URL** to: `https://neyvo-pulse.onrender.com/webhooks/vapi/events`
   - Add **custom header**: name `X-Vapi-Secret`, value `j5cMzCB>=D=1pPVnE_RA`.
   - Save.

**Backend:** You said you already set the variable in Render. Ensure it is exactly:
- **Key:** `VAPI_WEBHOOK_SECRET`
- **Value:** `j5cMzCB>=D=1pPVnE_RA`

(No quotes in the value in Render.)

---

## Test webhook with curl (ping your server)

To check that the webhook endpoint accepts the `X-Vapi-Secret` header without placing a real call:

**Valid JSON:** The body must be a single JSON object (starts with `{`). On Windows, add `--ssl-no-revoke` to avoid `CRYPT_E_NO_REVOCATION_CHECK`.

**Git Bash / MINGW64 (Windows):**

```bash
curl -X POST "https://neyvo-pulse.onrender.com/webhooks/vapi/events" \
  -H "Content-Type: application/json" \
  -H "X-Vapi-Secret: j5cMzCB>=D=1pPVnE_RA" \
  --ssl-no-revoke \
  -d '{"type":"status-update","status":"test","call":{"id":"test_call_123"}}'
```

**PowerShell:**

```powershell
$headers = @{
  "Content-Type"   = "application/json"
  "X-Vapi-Secret"  = "j5cMzCB>=D=1pPVnE_RA"
}
$body = '{"type":"status-update","status":"test","call":{"id":"test_call_123"}}'
Invoke-RestMethod -Method Post -Uri "https://neyvo-pulse.onrender.com/webhooks/vapi/events" -Headers $headers -Body $body
```

You should get a 200 response. In Render logs you should see the webhook received (e.g. `[VAPI WEBHOOK] Auth OK` and the event type).

---

## Trigger a test call (confirm webhook receives header)

Use one of the commands below to place a test call to **+12038128759**. Replace `YOUR_VAPI_PRIVATE_KEY` with your actual VAPI private API key (same as `VAPI_PULSE_PRIVATE_KEY` in Render, or from [VAPI dashboard](https://dashboard.vapi.ai) → API Keys).

### Bash (Linux / macOS / Git Bash on Windows)

**If you get a Windows SSL revocation error** (`CRYPT_E_NO_REVOCATION_CHECK`), add `--ssl-no-revoke` to the curl command.

```bash
curl -X POST "https://api.vapi.ai/call" \
  -H "Authorization: Bearer YOUR_VAPI_PRIVATE_KEY" \
  -H "Content-Type: application/json" \
  --ssl-no-revoke \
  -d '{"assistantId":"93f2fcf8-a0e8-422c-be36-2d7c20fb4904","phoneNumberId":"3007da9c-6d2c-4c38-85bd-6cfa7900f8f2","customer":{"number":"+12038128759"}}'
```

**Important:** The `-d` value must be valid JSON: it needs an opening `{` right after the quote (e.g. `'{"assistantId":...'`).

### PowerShell (Windows)

```powershell
$headers = @{
  "Authorization" = "Bearer YOUR_VAPI_PRIVATE_KEY"
  "Content-Type"  = "application/json"
}
$body = @{
  assistantId   = "93f2fcf8-a0e8-422c-be36-2d7c20fb4904"
  phoneNumberId = "3007da9c-6d2c-4c38-85bd-6cfa7900f8f2"
  customer      = @{ number = "+12038128759" }
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri "https://api.vapi.ai/call" -Headers $headers -Body $body
```

### What happens

1. VAPI creates the call and rings **+12038128759**.
2. VAPI sends webhook events to `https://neyvo-pulse.onrender.com/webhooks/vapi/events` with header `X-Vapi-Secret: j5cMzCB>=D=1pPVnE_RA`.
3. Your backend (Render) validates the header and, if it matches `VAPI_WEBHOOK_SECRET`, returns 200 and processes the event.

### How to confirm on your server

- In **Render** → your service → **Logs**, look for:
  - `[VAPI WEBHOOK] Auth OK (X-Vapi-Secret valid, ...)` → secret accepted.
  - `[VAPI WEBHOOK] Received: status-update` (or `end-of-call-report`, etc.) → event handled.
- You should **not** see `Rejected: Missing X-Vapi-Secret` or `Invalid X-Vapi-Secret` anymore.

No code change is needed on the server; it already checks the header and logs the result.

---

## Verify (summary)

After saving in VAPI and triggering a test call:

- Server logs show: `[VAPI WEBHOOK] Auth OK (X-Vapi-Secret valid, ...)`  
- No more: `Rejected: Missing X-Vapi-Secret` or `Invalid X-Vapi-Secret`

---

## Campaign outbound: VAPI limits (concurrency & plan)

**Recommendation:** Use **your own Twilio number** (imported in VAPI) for outbound campaigns instead of a VAPI-bought number. You avoid VAPI number limits and scale via Twilio; VAPI still provides the AI/assistant.

If starting a campaign shows a message like **"Couldn't Start Call. Numbers Bought On Vapi Have A Daily Outbound Call Limit"** (or similar), limits depend on:

- **Concurrency** – e.g. how many simultaneous calls your plan allows (e.g. 10). Check **VAPI dashboard → Settings → Subscription**.
- **Usage / billing** – trial plans, spending caps, or carrier (Twilio/VAPI number) rate limits.
- **VAPI-bought numbers** – may have softer limits; **Twilio-imported numbers** use your Twilio account limits.

**Check your limits:** VAPI dashboard → **Settings → Subscription / Billing** and **Analytics → Usage**.

**To scale outbound (e.g. 100+ concurrent):**

1. In **VAPI dashboard** → **Phone Numbers** → **Add** → choose **Twilio** (import your own).
2. Connect Twilio, select or buy a number, save. Copy the **VAPI Phone Number ID**.
3. In your **backend** (e.g. Render env), set **`VAPI_PULSE_PHONE_NUMBER_ID`** to that number’s ID and redeploy.

Your effective daily volume is roughly: **(concurrency × 24h) / average call duration** (e.g. 10 concurrent × 24h with ~2 min calls → 7,200+ calls/day possible).
