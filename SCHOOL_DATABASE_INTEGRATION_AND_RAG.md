# School Database Integration & RAG – Education & Architecture

**Purpose:** Educate on how schools manage student/finance data, which integration options exist, and how Neyvo Pulse can accept data from many different school systems in a flexible, secure way—with real-time sync into Firebase and correct behavior for the voice assistant (RAG, balance, payments).

**Audience:** Product, engineering, and school onboarding.

---

## Part 1: How Schools Manage Their Data (Current Systems)

### 1.1 What Schools Actually Use

Schools (K–12, higher ed, vocational) typically use a mix of:

| System type | What it does | Common products | Typical backend |
|-------------|--------------|-----------------|-----------------|
| **SIS (Student Information System)** | Enrollment, demographics, schedules, grades, attendance | PowerSchool, Infinite Campus, Skyward, Synergy, eSchoolPLUS, FACTS SIS, iSAMS, OpenSIS | SQL Server, PostgreSQL, Oracle, MySQL (varies by vendor) |
| **ERP / Finance** | General ledger, fees, billing, receivables | Ellucian (Banner, Colleague), KEV Group, district ERPs | Often SQL Server, Oracle |
| **Payment / fee platforms** | Collect payments, link to student accounts | MySchoolBucks, InTouch, school-specific portals | APIs + their own DB; often sync back to SIS/ERP |
| **Custom / in-house** | Built by district or local vendor | Custom apps, spreadsheets, Access, FileMaker | Anything: Excel, SQLite, MySQL, SQL Server |

So when you say “their database,” it might be:

- A **vendor SIS** (e.g. PowerSchool) with a known API or export.
- An **ERP** that owns “student financial” records.
- A **payment gateway** that sends webhooks when a payment is received.
- A **custom DB** (SQL Server, PostgreSQL, MySQL, etc.) with their own schema.
- **Files** (CSV/Excel) exported on a schedule.

You cannot assume one database or one format. The only safe assumption is: **we will see many different ways of providing data.**

### 1.2 How Finance / Payments Are Usually Handled

- **Transactions are sensitive:** Student balances, payments, and due dates are financial records. Schools need audit trails, correct numbers, and often FERPA/PCI considerations.
- **Where the “truth” lives:** Often the **SIS or ERP** is the source of truth for “current balance” and “amount due.” Payment systems may:
  - Push **payments** into the SIS (via API or batch), or
  - Send **webhooks/events** (“payment received”) so another system can update balance.
- **Real-time expectations:** Many modern systems support:
  - **Webhooks:** “When a payment is received, POST to this URL.”
  - **API polling:** “Give me payments since last sync.”
  - **Batch files:** Nightly CSV/Excel of updated balances and payments.

So “real-time” can mean:

1. **True real-time:** Webhook/event within seconds of payment.
2. **Near real-time:** Sync every 5–15 minutes via API or change-data-capture.
3. **Scheduled:** Hourly/daily batch file or API pull.

Your system should support all three and let each school choose what they can provide.

### 1.3 Standards (Worth Knowing, Not Required)

- **Ed-Fi** is a K–12 (and growing) data standard and API model. Many SIS/state systems support or are moving toward Ed-Fi. It uses a **push** model: the school (or their SIS) pushes data to an Ed-Fi API. Ed-Fi has a **Finance** domain (e.g. in Data Standard 4.x). Supporting Ed-Fi is a strong option for schools that already have it.
- **OneRoster** is used for roster/course data in K–12.
- **Custom APIs** and **CSV/Excel** are still the most common “integration” for many schools.

So: support **multiple modes** (webhook, API pull, file, and optionally Ed-Fi) so you can say “we accept your data however you can give it.”

---

## Part 2: The Core Problem You’re Solving

- **Their data** lives in their SIS/ERP/payment system (unknown DB, unknown schema).
- **Your system** (Neyvo Pulse) uses **Firebase (Firestore)** for schools, students, payments, and knowledge.
- **Requirements:**
  - When a **payment** happens in their world, Firebase should reflect it (so balance/assistant are correct).
  - **Real-time or near real-time** so the voice assistant doesn’t quote stale balances.
  - **Multi-tenant:** Many schools, each with different data sources and formats.
  - **Safe:** No wrong numbers, no duplicate payments, audit-friendly.

So you need an **integration layer** that:

1. Accepts data in **multiple ways** (webhook, API, file, scheduled job).
2. **Normalizes** their format into your **canonical schema** (student, balance, payment, etc.).
3. **Writes** into Firestore (and optionally updates caches/indexes for RAG).
4. Handles **idempotency**, **ordering**, and **errors** so finance data stays correct.

---

## Part 3: Flexible Integration Architecture (Multi-Mode)

### 3.1 Single “Contract” (Canonical Model), Many Inputs

- **Your system’s contract:** What Pulse needs per school is fixed:
  - **Students:** identity (e.g. id, name, phone, email), **balance**, **due_date**, **late_fee**, notes, etc.
  - **Payments:** student_id, amount, method, date, optional reference_id (for idempotency).
  - **Optional:** fee schedules, payment plans (if you add them later).

- **Each school** may send data in a different shape. So you define:
  - A **canonical schema** in your backend (and in Firestore).
  - **Adapters/connectors** per “mode” and optionally per “product” (e.g. “PowerSchool CSV”, “Generic webhook”, “Ed-Fi API”).

Conceptually:

```
School A (webhook)     →  Adapter A  →  Canonical model  →  Firestore (+ RAG index)
School B (CSV daily)   →  Adapter B  →  Canonical model  →  Firestore (+ RAG index)
School C (Ed-Fi API)   →  Adapter C  →  Canonical model  →  Firestore (+ RAG index)
```

Every path ends in the **same** Firestore collections (`schools/{id}/students`, `schools/{id}/payments`, etc.) and the same RAG/knowledge sources so the assistant is never confused.

### 3.2 Modes of Data Acceptance (What You Should Support)

| Mode | How school sends data | Best for | Real-time? |
|------|------------------------|----------|------------|
| **Webhook** | Their system POSTs to your URL when an event occurs (e.g. payment received, balance updated) | Schools with modern SIS/payment systems | Yes |
| **API pull** | Your backend calls their API (or read-only DB) on a schedule (e.g. every 15 min) | Schools that give you API or DB read access | Near real-time |
| **File upload** | They upload CSV/Excel (or you pull from SFTP/S3) on a schedule | Schools with no API, only exports | Batch (e.g. hourly/daily) |
| **Ed-Fi** | They push to your Ed-Fi-compatible API | Schools already on Ed-Fi | Yes (push) |
| **Manual / admin** | Staff enter payments or corrections in Pulse UI | Fallback, one-off | N/A |

You don’t need to implement all on day one, but the **design** should allow adding new adapters without changing how Firestore or the assistant works.

### 3.3 Per-School Configuration (Tenant Settings)

For each school (tenant), you store:

- **Which mode(s)** they use (e.g. webhook + nightly file for full refresh).
- **Credentials / URLs** (e.g. webhook secret, API key, SFTP path)—encrypted, per tenant.
- **Field mapping:** “Their column `STU_BAL` = our `balance`; their `PaymentId` = our idempotency key.”
- **Sync state:** Last successful sync time, last processed id/cursor (for incremental pull).

This can live in Firestore, e.g. `schools/{school_id}/integration_config` (and optionally in your backend DB if you have one).

### 3.4 Real-Time and Correctness (Payments Especially)

- **Idempotency:** For payments, use a **unique key** from their system (e.g. `external_payment_id`). Before writing, check if that id already exists; if yes, skip or update instead of duplicating.
- **Ordering:** If they send “balance update” and “payment” in quick succession, process in order (e.g. by timestamp or sequence id) or reconcile balance from their “current balance” if they send it.
- **Balance:** Prefer **them sending the new balance** after a payment when possible, so you don’t have to recompute (avoids rounding/race issues). If they only send “payment amount,” you can update balance as `current_balance - amount` with care (and optional reconciliation job).
- **Webhook reliability:** Have them retry on 5xx; your endpoint should be idempotent (same webhook twice = same result).

This way, “several payments every hour” is safe: each payment is applied once, and the assistant always reads the latest from Firestore.

---

## Part 4: How This Connects to Firebase (Your Current Stack)

Your codebase already has:

- **Firestore:** `schools/{school_id}/students`, `schools/{school_id}/payments`
- **Students:** name, phone, email, balance, due_date, late_fee, notes, created_at, updated_at
- **Payments:** student_id, amount, method, note, created_at

The integration layer should:

1. **Only write** into these collections (and any new ones you add for integration, e.g. `integration_log` or `sync_state`).
2. **Match students** by a stable key: either their `student_id` from the school’s system (stored as `external_id` on the student doc) or by phone/email if that’s what they send.
3. **Create or update** students when you receive roster/balance updates; **append** payments with idempotency.

So:

- **Webhook:** “Payment received” → adapter normalizes → `add_payment()` + optional `update_student(school_id, student_id, balance=...)`.
- **File/API pull:** Parse rows → for each student, upsert by `external_id`; for each payment, insert if `external_payment_id` not seen.

Firebase becomes the **single source of truth for Pulse**: voice backend, frontend, and RAG all read from Firestore. No need for the assistant to “call the school’s database”; it only needs to read from Firestore (and RAG index built from it).

---

## Part 5: RAG and the Assistant (No Stale Data, No Wrong Numbers)

### 5.1 What the Assistant Needs

From your docs and code:

- **Per outbound call:** Backend injects `{{student_name}}`, `{{balance}}`, `{{due_date}}`, `{{past_calls_summary}}`, `{{school_knowledge}}`.
- **school_knowledge:** FAQ, policy, and other “knowledge” so the assistant answers accurately (this is your RAG-like content).

So there are two “data” inputs to the assistant:

1. **Structured live data:** student name, balance, due date (from Firestore at call time).
2. **RAG / knowledge:** `school_knowledge` (and optionally past calls).

### 5.2 Keeping It Correct

- **Structured data:** The backend already loads the student from Firestore when placing the call. So as long as the **integration layer** keeps Firestore students and payments up to date, the assistant **automatically** gets the latest balance and due date. No extra “connection” needed—just ensure every path (webhook, API, file) writes through the same Firestore API.
- **RAG / school_knowledge:** If you store school-specific docs/FAQ in Firestore (or a vector store fed from Firestore), then:
  - When you add “integration” content (e.g. “Payment policies”), that content should be written to the same place `school_knowledge` is built from.
  - Optionally, a **dynamic** RAG step at call time: “fetch this student’s balance and last payment from Firestore” and inject into the prompt. You’re already doing the former (injecting balance/due_date); the key is that Firestore is updated by the integration layer so that data is fresh.

So:

- **Their DB** → (webhook/API/file) → **Your adapter** → **Firestore** (students, payments).
- **Backend** (Render) → reads Firestore when creating a call → sends **balance, due_date, school_knowledge** to VAPI.
- **VAPI** → uses that in the prompt → assistant speaks correct numbers.

RAG “connection” is: **Firestore is the single source; integration keeps Firestore updated; assistant reads from Firestore (via your backend).** No direct link from assistant to their database required.

### 5.3 Optional: RAG Over Student/Finance Facts

If you want the assistant to answer “When did I last pay?” or “What was my previous balance?” you can:

- Store **payment history** and **balance history** in Firestore (you already have payments).
- Either:
  - Pre-compute a short “student summary” (last payment date, current balance) and put it in `school_knowledge` or in the per-call context, or
  - Add a **tool/function** from VAPI to your backend: “get_student_financial_summary(school_id, student_id)” that reads Firestore and returns a few lines of text for the prompt.

In both cases, the data still comes from Firestore; the integration layer’s job is only to keep Firestore correct.

---

## Part 6: End-to-End Flow (Summary)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCHOOL SIDE                                                                 │
│  SIS / ERP / Payment system (any DB, any vendor)                             │
│  - Sends: webhook on payment, or API we poll, or CSV we pull                 │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  NEYVO PULSE – INTEGRATION LAYER (to build)                                  │
│  - Ingest: Webhook endpoint, API pull job, file ingest job, Ed-Fi endpoint   │
│  - Adapters: map their format → canonical (student, payment, balance)        │
│  - Idempotency: external_id, external_payment_id                             │
│  - Per-school config: mode, mapping, credentials                             │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FIREBASE (FIRESTORE) – Single source of truth for Pulse                     │
│  schools/{id}/students   schools/{id}/payments   school_knowledge / RAG      │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────────────────┐
│  Backend        │   │  Frontend       │   │  RAG / school_knowledge       │
│  (Render)       │   │  (Flutter)      │   │  (built from Firestore +     │
│  - Outbound     │   │  - Lists        │   │   school docs/FAQ)           │
│  - VAPI tools   │   │  - Dashboards    │   │  → Injected into VAPI prompt │
│  - Reads       │   │  - Reads         │   │  → Assistant answers         │
│    Firestore    │   │    Firestore    │   │    with correct policy/FAQ   │
└────────┬────────┘   └─────────────────┘   └─────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  VAPI           │  Gets: student_name, balance, due_date, school_knowledge,
│  Voice assistant│  past_calls_summary → Speaks correct numbers & policy
└─────────────────┘
```

---

## Part 7: Security and Care (Sensitive Numbers)

- **Never log** full payment amounts or student PII in plain text in production logs; redact or hash where needed.
- **HTTPS only** for webhooks and APIs; verify webhook signatures (e.g. HMAC) so only their system can POST.
- **Per-tenant credentials:** Stored encrypted; never reused across schools.
- **Read-only where possible:** If you poll their API or DB, use a read-only account so you can’t accidentally change their data.
- **Audit trail:** Keep an integration log (e.g. “payment X received at T, written to Firestore”) for dispute and compliance.
- **FERPA / local rules:** Treat student financial data as sensitive; restrict access in Firestore rules and in your backend by `school_id` (and role).

---

## Part 8: How to Proceed (Phased)

1. **Define canonical schema** (already mostly done: students, payments). Add fields if needed: `external_id`, `external_payment_id`, `last_sync_at`.
2. **Add per-school integration config** in Firestore (or backend): mode, mapping, secrets.
3. **Implement one mode first:** e.g. **Webhook** – single endpoint, verify signature, parse body, map to canonical, write to Firestore (idempotent). Test with a mock or one friendly school.
4. **Then add:** Scheduled **file ingest** (CSV) and/or **API pull** (generic “GET students”, “GET payments since”) with a generic adapter and configurable mapping.
5. **Optional:** Ed-Fi adapter for schools that already have Ed-Fi.
6. **RAG:** Keep building `school_knowledge` from Firestore (and any docs you add). Ensure integration doesn’t overwrite human-edited content unless intended; use separate collections or fields for “integration-sourced” vs “school-edited” if needed.

This gives you a **flexible, multi-tenant integration** that accepts many modes and keeps Firebase (and thus the assistant) in sync with their data, so the assistant won’t have issues fetching or “storing” data—it just reads what’s already in Firestore, which your integration layer keeps up to date.

---

## References (Further Reading)

- Ed-Fi Alliance – API integration, data standard, Finance domain: https://docs.ed-fi.org
- Multi-tenant integration patterns (e.g. adapter, tenant config): Microsoft Azure multitenant guide, Endgrate multi-tenant SaaS integration
- Webhook vs API, idempotency: Twilio webhook docs, WebhookDB HTTP Sync
- School payment/SIS platforms: KEV Group, MySchoolBucks (APIs), PowerSchool, Ellucian
