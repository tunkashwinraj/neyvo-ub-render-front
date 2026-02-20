# VAPI: Set X-Vapi-Secret for webhook (prompt for Composer / manual steps)

Use this to configure your VAPI assistant and phone so webhooks are accepted by the backend at `https://neyvo-pulse.onrender.com`.

---

## Copy-paste prompt for Composer AI

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
