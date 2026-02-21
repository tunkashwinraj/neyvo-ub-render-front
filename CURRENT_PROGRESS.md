# Neyvo Pulse – Current Progress

**Last updated:** February 2025  
**Purpose:** Single snapshot of where the project stands: done, in progress, and pending.

---

## 1. Vision & Positioning

- **Product:** Voice Operating System (VOS) / **Resolution System** for schools—AI outbound calls about balances, due dates, payment plans; real-time answers; payment barriers captured; outcome tracking (e.g. “payment received after call”).
- **Differentiation (vs Dialpad, CloudTalk, Gia/Air, Talkdesk, Twilio):** Resolution (not just completion), call memory, school-trained assistant (FAQ/policy/RAG), calm institutional voice, outcome-dense UI. See **STRATEGIC_GAP_ANALYSIS.md**.
- **Backend:** Python/FastAPI at `https://neyvo-pulse.onrender.com`.  
- **Frontend:** Flutter app (web target; theme, API client, Firebase in place).

---

## 2. Completed Work

### 2.1 Core foundation
- [x] Backend API connected; health check
- [x] Firebase (client + service account) integrated
- [x] Flutter app structure, Spearia theme, NeyvoPulseApi client
- [x] Auth: login/sign-up (Firebase Auth or backend JWT); role-based access (admin, staff, view-only); first-admin bootstrap
- [x] Audit log (backend + GET `/api/pulse/audit-log`; Audit log page in nav)

### 2.2 Pages & features (frontend)
- [x] **Dashboard** – summary, quick actions
- [x] **Students** – list, detail, add/edit/delete; balance, due date, payment history; quick actions (call, add payment, schedule reminder)
- [x] **Outbound calls** – initiate call with context (student, balance, etc.)
- [x] **Call history** – list with date range (all time, 7d, 30d), outcome filters (completed/failed/pending), duration, export CSV, recording link when provided
- [x] **AI Insights** – outcome summary, common topics, payment barriers, recommendations; link to call logs; nav + dashboard quick action
- [x] **Payments** – list, add payment; export
- [x] **Reminders** – list, create/edit
- [x] **Reports** – reports page; export CSV
- [x] **Settings** – school/VAPI config, team roles
- [x] **Training** – FAQ CRUD, policy form (assistant training UI)
- [x] **Campaigns** – campaigns page
- [x] **Integrations** – integration page
- [x] **Template scripts** – template scripts page
- [x] **Data import** – CSV upload for students
- [x] **Bulk actions** – e.g. select students → schedule reminders, export

### 2.3 Backend & integrations
- [x] Pulse API: students, payments, calls, reminders, settings, reports/summary, outbound call initiation
- [x] **VAPI webhook** – endpoint for call events; persist transcript, summary, outcome; link to `school_id` / `student_id` (metadata)
- [x] **Call memory – persist:** End-of-call webhook updates Pulse call with transcript, summary, outcome
- [x] **Call memory – inject:** Before outbound call, backend loads last N calls for student, builds `past_calls_summary`, passes to VAPI as `variableValues.past_calls_summary`
- [x] **FAQ + policy:** Backend storage; inject into assistant context at call start
- [x] **Payment-after-call attribution:** On payment created, attribute to last outbound call within 14 days; set `success_metric`, `attributed_payment_*` on call; expose in GET `/api/pulse/calls` and success-summary
- [x] **Conversation outcome:** In webhook, set `outcome_type` (e.g. promised_to_pay, no_answer, engaged) from transcript/summary
- [x] **Dashboard success metrics:** Resolution rate, revenue attributed to calls (payment success rate, attributed revenue)

### 2.4 Design & docs
- [x] **STRATEGIC_GAP_ANALYSIS.md** – competitive scan, positioning
- [x] **EXECUTION_PLAN.md** – phases, architecture, UI principles
- [x] **NEXT_STEPS.md** – priorities, checklist, implementation order
- [x] **TRAINING_AND_MEMORY_DESIGN.md** – call memory + FAQ/policy + RAG architecture
- [x] **CALL_SUCCESS_TRACKING_DESIGN.md** – payment attribution, success metrics
- [x] **SCHOOL_DATABASE_INTEGRATION_AND_RAG.md** – school data sources, integration options, RAG context
- [x] **VAPI_SETUP_X_VAPI_SECRET.md** – webhook URL, `X-Vapi-Secret`, Twilio number → server + assistant (prompts and manual steps)

---

## 3. In Progress / To Verify

- [ ] **Session timeout & secure token refresh** (auth hardening)
- [ ] **VAPI dashboard config:** Ensure Twilio-imported number (+1 229 600 6675) has Server URL `https://neyvo-pulse.onrender.com/webhooks/vapi/events` and header `X-Vapi-Secret` set (see **VAPI_SETUP_X_VAPI_SECRET.md**); confirm assistant ID and Phone Number ID in backend env (e.g. `VAPI_PULSE_PHONE_NUMBER_ID`) for outbound campaigns
- [ ] **RAG (optional):** Chunk + embed school knowledge; vector store; at call start retrieve top-k and pass as `school_knowledge` (FAQ+policy text injection is already done; RAG is next step per TRAINING_AND_MEMORY_DESIGN)

---

## 4. Pending / Later

- [ ] **Backend:** Dedicated `GET /api/pulse/insights` if desired (currently insights can be derived from `/api/pulse/calls`)
- [ ] **Backend:** `GET /api/pulse/calls/export?from=&to=&format=csv` for server-side export
- [ ] **Real-time:** Firestore listeners for live updates (optional)
- [ ] **Phase 4–7 enhancements** from EXECUTION_PLAN (e.g. scheduled calls, call templates, real-time call status, deeper analytics charts)

---

## 5. Quick Reference

| Area           | Status   | Notes |
|----------------|----------|--------|
| Frontend app   | Done     | Dashboard, Students, Calls, Call History, AI Insights, Payments, Reminders, Reports, Settings, Training, Campaigns, Integrations, Auth, Audit |
| Backend API    | Done     | Render; Pulse endpoints; VAPI webhook; attribution; call memory inject |
| VAPI + Twilio  | Configure| Number in VAPI; webhook URL + `X-Vapi-Secret`; assistant linked (see VAPI_SETUP_X_VAPI_SECRET.md) |
| Call memory    | Done     | Persist via webhook; inject `past_calls_summary` before outbound |
| FAQ / policy   | Done     | Stored and injected at call start |
| RAG            | Optional | Not yet implemented; design in TRAINING_AND_MEMORY_DESIGN.md |
| Success tracking| Done     | Attribution + dashboard cards + success-summary API |

---

## 6. Services & Infrastructure Cost (What You’re Using)

**Voice (per call – you already have this):**  
VAPI platform, Twilio outbound US, ElevenLabs (Flash/Turbo v2.5), optional OpenAI TTS, Deepgram Nova-2 STT, GPT-4o / GPT-4o Mini (LLM) — **all during the call are via VAPI**; you don’t pay Deepgram or OpenAI directly for the live call. Your per‑minute tiers (Neutral/Natural/Ultra) are correct.

**Add these (often missed):**

| Service | Use | Cost note |
|--------|-----|-----------|
| **Render** | Backend hosting (`neyvo-pulse.onrender.com`) | Paid plan (e.g. ~$7/mo or usage-based). Free tier sleeps after inactivity. |
| **OpenAI (backend)** | Post-call summary (VAPI webhook, 1 completion per call) + optional dashboard insight (`/api/reports/insight`) | **GPT-4o-mini** only; very cheap (short prompts, ~80–few hundred tokens per call + per insight load). |
| **Firebase** | Auth + Firestore (students, calls, payments, etc.) | Free tier usually enough; beyond that: Firestore reads/writes, Auth (e.g. phone) can add small cost. |

**Clarifications:**

- **Pulse “AI Insights” page** (`GET /api/pulse/insights`): **No OpenAI** — keyword-based on transcript/summary. No extra AI cost.
- **OpenAI for “insights”:** Only used for (1) post-call summary in webhook (gpt-4o-mini), (2) optional `/api/reports/insight` one-liner (gpt-4o-mini). So yes, **GPT-4o-mini only**, negligible per call.
- **Deepgram:** Not used in your backend for VAPI calls; VAPI does STT. Your backend has Deepgram code for a different path (Twilio Media Stream). So no separate Deepgram line for **your** infra; if VAPI uses Deepgram, it’s already inside VAPI’s per‑minute.

**Summary:** Add **Render** and **OpenAI (backend, gpt-4o-mini)** to your infra list. **Firebase** if you want full picture. Nothing else critical missing for normal usage.

---

*Update this file as major items are completed or priorities change.*
