# Neyvo Pulse – Next Steps to Full-Fledged Application

## Strategy & Competitive Context (Read First)

**See STRATEGIC_GAP_ANALYSIS.md** for the full competitive deep-scan (Dialpad, CloudTalk, Gia/Air, Talkdesk, Twilio) and how Neyvo wins.

- **Positioning:** We are building a **Voice Operating System (VOS)** / **Resolution System**, not a contact-center SaaS. Competitors sell tools or engines; we sell **outcome automation** and **self-optimizing infrastructure**.
- **Gaps we own:** (1) **Resolution, not completion** — “Resolution achieved” / payment attributed; (2) **Call memory** — assistant knows every past call with this student; (3) **School-trained assistant** — FAQ, policy, RAG; (4) **Calm Intelligence** — empathetic, institutional voice; (5) **Premium, outcome-dense UI** — Vercel/Linear-like, dark/minimal.
- **Implementation principles:** Outcome-first semantics (`success_metric`, `resolution_achieved`, `attributed_payment_*`); event-driven, single source of truth; module-ready Neyvo Core (Pulse today, other verticals later).

---

## Current State
- ✅ Dashboard, Students, Outbound Calls, Call History, Payments, Reminders, Reports, Settings
- ✅ Backend connected, Firebase ready, theme and API client in place

## Priority 1: Call Logs & AI Insights (This Phase)

### Call Logs (Enhanced)
- [x] Call history page with filters and transcripts
- [x] **Date range filter** (all time, last 7 days, last 30 days)
- [x] **Call outcome** filters (completed, failed, pending)
- [x] **Call Logs** title and link to AI Insights from app bar
- [x] **Duration** display and sort by duration (when backend provides)
- [x] **Export call logs** (CSV) for reporting
- [x] **Recording link** when backend provides `recording_url`

### AI Insights (New)
- [x] **AI Insights page** with:
  - Call outcome summary (total, completed, failed, success rate)
  - Common topics derived from call transcripts (payment plan, balance, due date, etc.)
  - Payment barriers mentioned (from transcripts)
  - Recommendations (review failed calls, add FAQ, payment plans)
  - Link to full call logs
- [x] API: `getInsights()` calling optional `/api/pulse/insights`; insights derived from `/api/pulse/calls` when backend has no insights endpoint yet
- [x] **AI Insights** in drawer nav and dashboard quick actions

---

## Priority 2: Authentication & Security
- [x] **Login / Sign-up** (Firebase Auth or backend JWT)
- [x] **Role-based access** (admin, staff, view-only) – backend members + X-User-Id; Settings → Team roles; first-admin bootstrap
- [ ] **Session timeout** and secure token refresh
- [x] **Audit log** (who viewed/edited what) – backend audit_log + GET /api/pulse/audit-log; Audit log page in nav

---

## Priority 3: Data & Export
- [x] **Export reports** to CSV (dashboard, reports, payments)
- [x] **Export call logs** with filters applied
- [x] **Bulk actions** (e.g., select students → schedule reminders, export list)
- [x] **Data import** (CSV upload for students if needed)


---

## Priority 4: Assistant Training & Call Memory (Mandatory)

See **TRAINING_AND_MEMORY_DESIGN.md** for full architecture and implementation plan.

### Call memory (assistant knows past calls)
- [x] **Persist**: VAPI end-of-call webhook updates Pulse call with transcript, summary, outcome; pass `school_id` + `student_id` in create-call metadata
- [x] **Inject**: Before each outbound call, backend loads last N calls for that student, builds `past_calls_summary`, passes to VAPI as `variableValues.past_calls_summary`

### Flexible training (schools train their assistant)
- [x] **FAQ + policy**: Backend storage for FAQ and policy fields; inject into assistant context at call start
- [ ] **RAG**: Chunk + embed school knowledge (FAQ, docs); vector store; at call start retrieve top-k and pass as `school_knowledge` (optional; currently FAQ+policy text only)
- [x] **Training UI**: Flutter – FAQ CRUD, policy form; dedicated “Training” screen in nav

### Implementation order (see design doc)
1. Call memory persist (webhook + metadata)  
2. Call memory inject (query past calls, add variable)  
3. FAQ + policy storage and injection  
4. RAG ingest (chunk, embed, store)  
5. RAG retrieve at call start  
6. Training UI in app  

---

## Priority 5: Call Success Tracking (Mandatory)

See **CALL_SUCCESS_TRACKING_DESIGN.md** for full design and attribution rules.

**Goal:** Track when a call leads to payment (and other success dimensions) so you can report “payment received after reminder call” and success rates.

### Payment-after-call attribution
- [x] **On payment created**: When a payment is recorded, find the most recent outbound call to that student within last 14 days; mark that call as `success_metric: "payment_received"` and set `attributed_payment_id`, `attributed_payment_at`, `attributed_payment_amount`
- [x] **Call document fields**: Add `success_metric`, `attributed_payment_id`, `attributed_payment_at`, `attributed_payment_amount`; expose in `GET /api/pulse/calls`

### Conversation outcome (optional but recommended)
- [x] **In VAPI webhook**: When saving call, set `outcome_type` (e.g. promised_to_pay, no_answer, engaged) from transcript/summary (keyword-based) for soft success and funnel reports

### Reporting
- [x] **Dashboard**: Payment success rate (% of calls that led to payment), revenue attributed to calls; Resolution rate and Revenue from calls cards
- [x] **API**: Include success fields in call list/detail; `GET /api/pulse/calls/success-summary` for aggregates

---

## Backend Additions (Recommendations)
- `GET /api/pulse/insights` – aggregated AI insights (top questions, barriers, call stats)
- `GET /api/pulse/calls/export?from=&to=&format=csv`
- Store per-call: `transcript`, `summary`, `topics[]`, `payment_barrier`, `recording_url`, `duration_seconds`, `outcome_type`, `success_metric`, `attributed_payment_*`
- Webhook from VAPI to save transcript and run lightweight “insight” extraction (e.g., keywords → topics)

---

## Implementation Order (Strategy-Aligned)

Aligned with **STRATEGIC_GAP_ANALYSIS.md** so we ship differentiation (resolution + memory + training) in a high-velocity, correct order.

**Phase A – Resolution backbone**
1. VAPI webhook: persist call with transcript, summary, outcome_type; link to `school_id`/`student_id`.
2. Payment attribution: on payment created, attribute to last call; expose `success_metric`, `attributed_payment_*` in `GET /api/pulse/calls`.
3. UI: show “Resolution achieved” / “Payment received” and success metrics in Call Logs and dashboard.

**Phase B – Call memory**
4. Before each outbound call: load last N calls for student, build `past_calls_summary`, pass to VAPI (see TRAINING_AND_MEMORY_DESIGN.md).

**Phase C – Training & RAG**
5. FAQ + policy storage; inject at call start.
6. RAG: chunk, embed, retrieve; pass `school_knowledge` (see TRAINING_AND_MEMORY_DESIGN.md).
7. Training UI: FAQ CRUD, document upload, policy form (Settings or dedicated screen).

**Phase D – Polish and scale**
8. Resolution/success summary API; dashboard cards; role-based access; audit log.
9. Optional: latency/correctness monitoring; “Resolution Rate” and “Revenue attributed to calls” as first-class metrics.

This document will be updated as items are completed.
