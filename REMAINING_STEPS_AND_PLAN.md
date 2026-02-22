# Neyvo Pulse – Remaining Steps & Plan to Achieve the Goal

**Goal:** Launch-ready **Voice Resolution System** for schools: outbound AI calls, payment attribution, call memory, school-trained assistant, revenue (Stripe + subscriptions), and a polished, working product.

---

## 1. Where Things Stand

| Area | Status | Notes |
|------|--------|--------|
| **Core app** | Done | Dashboard, Students, Calls, Call History, AI Insights, Payments, Reminders, Reports, Settings, Training, Campaigns, Integrations, Auth, Audit |
| **Backend API** | Done | Pulse endpoints, VAPI webhook, call memory inject, payment attribution, success-summary |
| **Revenue & billing** | Done | Stripe Checkout for wallet top-up, webhook applies credits, SendGrid for day-60/low-balance emails, Developer Console (all tabs, admin top-up), explicit routes so no 404s |
| **Demo & account** | Done | Settings: Account (email/phone), Load demo data (seed students, payments, school name, VAPI placeholders) |
| **Backend test page** | Done | Health, Pulse, Billing, Stripe create-checkout-session, Admin endpoints |

---

## 2. Remaining Steps (Ordered by Impact)

### Must-do before launch

1. **Stripe production**
   - [ ] In Stripe Dashboard: add webhook endpoint `https://neyvo-pulse.onrender.com/api/billing/stripe-webhook`, event `checkout.session.completed`.
   - [ ] Set `STRIPE_WEBHOOK_SECRET` (and keep `STRIPE_SECRET_KEY`) in Render environment.
   - [ ] Test: Wallet → buy credits → complete payment → confirm credits applied.

2. **VAPI + Twilio config**
   - [ ] In VAPI: Twilio number has **Server URL** = `https://neyvo-pulse.onrender.com/...` (your actual VAPI webhook path; see **VAPI_SETUP_X_VAPI_SECRET.md**).
   - [ ] Set **X-Vapi-Secret** header; ensure backend has same secret.
   - [ ] Confirm **Assistant ID** and **Phone Number ID** in backend env (e.g. `VAPI_PULSE_ASSISTANT_ID`, `VAPI_PULSE_PHONE_NUMBER_ID`) and in app Settings so outbound calls use the right assistant/number.

3. **Auth hardening (recommended)**
   - [ ] **Session timeout** and **secure token refresh** (e.g. Firebase ID token refresh before expiry, or backend session TTL).
   - Keeps long-lived sessions safe without forcing re-login too often.

### Nice-to-have (post–launch or parallel)

4. **Optional RAG**
   - [ ] Chunk + embed school knowledge (FAQ, docs); vector store; at call start retrieve top-k and pass as `school_knowledge` (see **TRAINING_AND_MEMORY_DESIGN.md**).  
   - FAQ + policy text injection is already done; RAG adds document-level context.

5. **Optional backend endpoints**
   - [ ] `GET /api/pulse/insights` – aggregated insights (if you want server-side insight logic).
   - [ ] `GET /api/pulse/calls/export?from=&to=&format=csv` – server-side CSV export.

6. **Email env (if using crons)**
   - [ ] Set `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`, `NEYVO_SUCCESS_SESSION_BOOK_URL`, `NEYVO_APP_WALLET_URL` on Render if you want day-60 and low-balance emails to send and contain correct links.

---

## 3. Plan of Approach

### Phase 1 – Production readiness (1–2 days)

1. **Stripe**
   - Add webhook in Stripe Dashboard; copy signing secret.
   - Set `STRIPE_WEBHOOK_SECRET` (and `STRIPE_SECRET_KEY`) on Render; redeploy.
   - Test wallet top-up end-to-end (browser → Checkout → success → credits in app).

2. **VAPI**
   - Follow **VAPI_SETUP_X_VAPI_SECRET.md**: webhook URL, `X-Vapi-Secret`, number and assistant linked.
   - Test one outbound call from the app; confirm webhook receives events and call appears in Call History with transcript/outcome if available.

3. **Smoke test**
   - Run Flutter Backend Test page: all green for Health, Billing (wallet, subscription, create-checkout-session), Admin (billing-overview, system-health, organizations, pricing-config).
   - In app: log in → Load demo data → open Students, Payments, Wallet, Settings; confirm data and no crashes.

### Phase 2 – Auth & polish (0.5–1 day)

4. **Session / token**
   - Implement session timeout (e.g. 24h or 7d) and refresh of Firebase ID token before expiry; send refreshed token to backend if you use custom auth there.
   - Optional: “Remember me” vs “Session only” so schools can choose.

5. **Quick UX pass**
   - Confirm Settings shows Account (email/phone) and Load demo data.
   - Confirm Developer Console: all tabs load; admin can open org detail and “Top up” (Stripe link) for any org.

### Phase 3 – Optional enhancements

6. **RAG** (if you want document-level knowledge)
   - Implement per **TRAINING_AND_MEMORY_DESIGN.md**: ingest docs → chunk → embed → store; at call start query vector store and pass `school_knowledge` into assistant.

7. **Insights / export**
   - Add `GET /api/pulse/insights` and/or `GET /api/pulse/calls/export` if you want server-side aggregation or large CSV exports.

---

## 4. Checklist Summary

- [ ] Stripe webhook created and `STRIPE_WEBHOOK_SECRET` set on Render.
- [ ] Stripe wallet top-up tested end-to-end.
- [ ] VAPI webhook URL and `X-Vapi-Secret` set; number and assistant IDs in backend/env and Settings.
- [ ] At least one successful outbound call and webhook event received.
- [ ] Session timeout / token refresh (recommended).
- [ ] Backend Test page green for all critical endpoints.
- [ ] Demo data loaded once; Students, Payments, Settings show expected data.
- [ ] (Optional) RAG; (optional) insights/export endpoints; (optional) email env for crons.

---

## 5. Reference Docs

| Doc | Use |
|-----|-----|
| **STRIPE_SETUP.md** (backend) | Stripe keys, webhook URL, event `checkout.session.completed` |
| **VAPI_SETUP_X_VAPI_SECRET.md** | VAPI webhook URL, secret, number and assistant setup |
| **NEXT_STEPS.md** | Full priority list and implementation order |
| **CURRENT_PROGRESS.md** | Snapshot of done / in progress / pending |
| **STRATEGIC_GAP_ANALYSIS.md** | Positioning and differentiation |

Once Phase 1 and 2 are done, you have a **launch-ready** Neyvo Pulse: real payments, working voice pipeline, and a single clear path to go live. Phase 3 can follow after launch or in parallel.
