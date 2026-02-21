# Prompt for Vapi Composer AI: Verify Every Neyvo Pulse Endpoint

**Important:** Vapi Composer **cannot make external HTTP requests** (no outbound network). It cannot call your backend directly. Use the **local verification script** below instead; then paste the script output back into Composer for analysis (it can interpret results and suggest fixes).

---

## Option 1: Run the verification script locally (recommended)

From the **Neyvo Pulse Backend** folder:

```bash
node verify-neyvo-pulse.js
```

Optional env vars:

- `BASE_URL` – default `https://neyvo-pulse.onrender.com`
- `BUSINESS_ID` – default `default-school`

Example:

```bash
BASE_URL=https://neyvo-pulse.onrender.com BUSINESS_ID=default-school node verify-neyvo-pulse.js
```

Then **paste the full output** into Vapi Composer. It can:

- Interpret which endpoints failed and why
- Suggest fixes (auth, CORS, missing fields)
- Detect schema or config issues

The script lives at: **`Neyvo Pulse Backend/verify-neyvo-pulse.js`**.

---

## Option 2: Copy-paste prompt for Vapi Composer (manual checklist)

If you prefer to have Composer reason about the API without running the script, use the prompt below. Composer will **not** call your backend; it can only give you a checklist or a Postman/script to run yourself.

```
You are verifying the Neyvo Pulse backend API. Base URL: BASE_URL (e.g. https://neyvo-pulse.onrender.com).
Auth: pass business_id for all requests that need it — either query ?business_id=default-school or JSON body {"business_id": "default-school"}. If the app uses Bearer or API key, add the appropriate header (e.g. Authorization: Bearer <token>).

For each endpoint below, perform one request and check:
1. HTTP status is 2xx (200, 201, etc.) where expected; 4xx/5xx only if the spec says so.
2. Response is valid JSON.
3. Required fields mentioned below are present when applicable.

Endpoints to verify:

— Health —
GET BASE_URL/api/pulse/health
  → Expect 200, JSON with ok: true, service: "neyvo_pulse"

— Students (use business_id) —
GET BASE_URL/api/pulse/students?business_id=default-school
  → Expect 200, JSON with "students" array
POST BASE_URL/api/pulse/students
  Body: {"business_id": "default-school", "name": "Test Student", "phone": "+15551234567"}
  → Expect 201, JSON with "student" object (id, name, phone, etc.)

— Payments (use business_id) —
GET BASE_URL/api/pulse/payments?business_id=default-school
  → Expect 200, JSON with "payments" or list
POST BASE_URL/api/pulse/payments
  Body: {"business_id": "default-school", "student_id": "<id>", "amount": "10.00", "method": "other"}
  → Expect 201 or 200, JSON with payment info

— Reminders (use business_id) —
GET BASE_URL/api/pulse/reminders?business_id=default-school
  → Expect 200, JSON with "reminders" or list

— Calls (use business_id) —
GET BASE_URL/api/pulse/calls?business_id=default-school
  → Expect 200, JSON with "calls" or list
GET BASE_URL/api/pulse/calls/success-summary?business_id=default-school
  → Expect 200, JSON

— Insights (use business_id) —
GET BASE_URL/api/pulse/insights?business_id=default-school
  → Expect 200, JSON

— Knowledge (use business_id) —
GET BASE_URL/api/pulse/knowledge/policy?business_id=default-school
  → Expect 200, JSON with policy fields
GET BASE_URL/api/pulse/knowledge/faq?business_id=default-school
  → Expect 200, JSON with "faq" or items

— Settings (use business_id) —
GET BASE_URL/api/pulse/settings?business_id=default-school
  → Expect 200, JSON with school_name, currency, etc.

— Outbound / phone numbers (use business_id) —
GET BASE_URL/api/pulse/outbound/phone-numbers?business_id=default-school
  → Expect 200, JSON with "numbers" or list
GET BASE_URL/api/pulse/outbound/capacity?business_id=default-school
  → Expect 200, JSON

— Billing (use business_id) —
GET BASE_URL/api/billing/wallet?business_id=default-school
  → Expect 200, JSON (balance, tier, etc.)
GET BASE_URL/api/billing/usage?business_id=default-school
  → Expect 200, JSON (usage data)
GET BASE_URL/api/billing/tier?business_id=default-school
  → Expect 200, JSON (tier info)
GET BASE_URL/api/billing/transactions?business_id=default-school
  → Expect 200, JSON (transactions list)

— Numbers API (use business_id) —
GET BASE_URL/api/numbers?business_id=default-school
  → Expect 200, JSON with numbers list
GET BASE_URL/api/numbers/search?area_code=585&country=US
  → Expect 200, JSON with "available" array (may be empty)

— Admin (if you have admin auth) —
GET BASE_URL/api/admin/billing-overview
  → Expect 200, JSON (overview)
GET BASE_URL/api/admin/tier-configs
  → Expect 200, JSON with "tier_configs"
GET BASE_URL/api/admin/numbers/stats
  → Expect 200, JSON (platform stats)

Report for each: method, path, status received, and whether required fields were present. If any request fails (non-2xx or missing required fields), list the failure and suggested fix.
```

---

## Before you run

1. **Set BASE_URL** in the prompt to your real backend (e.g. `https://neyvo-pulse.onrender.com` or your staging URL).
2. **Auth:** If your backend requires Bearer token or API key, add one line at the top of the prompt, e.g. “Use header: Authorization: Bearer MY_TOKEN” so the assistant includes it in every request.
3. **business_id:** The prompt uses `default-school`; if your test org has a different ID, replace it in the prompt.
4. **POST bodies:** For POST endpoints that need a real `student_id`, the assistant may need to use an ID returned from the students list or from a prior create-student call.

This gives Vapi Composer a single, self-contained checklist to verify every Neyvo Pulse endpoint.
