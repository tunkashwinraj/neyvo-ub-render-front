# Neyvo Pulse – Call Success Tracking Design

This document describes **how to track success based on calls** in a highly efficient way: e.g. “payment received after a reminder call” counts as call success, plus other measurable dimensions.

---

## 1. What “Call Success” Means (Multiple Dimensions)

| Dimension | What we measure | Why it matters |
|-----------|------------------|----------------|
| **Payment attribution** | Payment recorded for the same student within X days **after** the call | Direct business outcome: “This call led to payment.” |
| **Outcome from conversation** | What happened in the call: promised to pay, asked for extension, disputed, no commitment, no answer | Soft success; predicts future payment and guides follow-up. |
| **Engagement** | Call answered, duration, follow-up actions | Proxy for “reach” and “attention”; no-answer vs 2 min conversation. |
| **Conversion funnel** | Call → promise → payment (within window) | End-to-end success rate. |

**Most important for you:** *If a call happens and payment is received from that student after the call (within a defined window), attribute that payment to the call and mark the call as “payment success.”*

---

## 2. Best Ways to Track (Efficient Implementation)

### 2.1 Payment-after-call attribution (primary, high value)

**Rule:** When a **payment** is recorded for a student, look back for the **most recent outbound call** to that student within the last **N days** (e.g. 7 or 14). If found, **attribute the payment to that call** and mark the call as “success = payment received.”

**Why efficient:**
- Single place to run logic: **when payment is created** (e.g. in `POST /api/pulse/payments` or in the `add_payment` service).
- No polling, no heavy jobs. One query: “last call to this student before this payment, within last 14 days.”
- Writes only one update: set on that call document `attributed_payment_id`, `attributed_payment_at`, and a success flag.

**Data to add on the call document** (e.g. in `schools/{school_id}/outbound_calls/{call_id}`):

| Field | Type | Meaning |
|-------|------|--------|
| `attributed_payment_id` | string \| null | Payment doc ID that we attribute to this call (set when payment is created and falls in window after this call). |
| `attributed_payment_at` | timestamp \| null | When that payment was recorded. |
| `attributed_payment_amount` | string \| null | Amount (for reporting). |
| `success_metric` | string | e.g. `"payment_received"` \| `"promised_to_pay"` \| `"engaged"` \| `"no_answer"` \| `"unknown"`. |

**Attribution window:** e.g. **14 days**. So: payment at T → consider calls with `created_at` in [T − 14 days, T]. Pick the **most recent** call in that interval (closest to T) and attribute the payment to it.

**Edge cases:**
- Multiple calls before one payment: attribute to the **most recent** call (the one closest in time to the payment).
- One call, multiple payments later: attribute only the **first** payment in the window to that call (so each call gets at most one “payment success”). Alternatively you can attribute all payments in the window to the same call for “revenue per call”; the doc below assumes “first payment only” for a clear success flag.

**Implementation sketch (backend, in `add_payment` after writing the payment):**
1. Get `school_id`, `student_id`, payment `created_at`, payment `id`, `amount`.
2. Query `outbound_calls` where `school_id` = X, `student_id` = Y, `created_at` ≤ payment_at, `created_at` ≥ payment_at − 14 days; order by `created_at` desc; limit 1.
3. If a call doc is found, update that call doc: set `attributed_payment_id`, `attributed_payment_at`, `attributed_payment_amount`, `success_metric = "payment_received"`.
4. (Optional) If you want only one payment per call: only run attribution if that call does not already have `attributed_payment_id`.

---

### 2.2 Outcome from the call (transcript / summary)

**When:** In the VAPI **end-of-call webhook**, when you persist the call (transcript, summary, etc.).

**What:** Classify the call into an **outcome type** and store it on the call document so you can report “% promised to pay”, “% no answer”, etc., and later correlate with payments.

**Suggested outcome types:**

| Value | Meaning |
|-------|--------|
| `payment_received` | Set when attribution runs (payment after call); overrides or sits alongside conversation outcome. |
| `promised_to_pay` | Student committed to pay (by date or “will pay”). |
| `asked_extension` | Asked for more time / payment plan. |
| `payment_planned` | Agreed on a plan (e.g. installments). |
| `engaged` | Answered, had a real conversation, no clear commitment. |
| `no_commitment` | Talked but no promise. |
| `disputed` | Disputed balance or charges. |
| `no_answer` | Not answered / voicemail only. |
| `unknown` | Could not determine. |

**How to set:**  
- **Lightweight:** Rule-based on keywords in transcript/summary (e.g. “will pay”, “by Friday”, “payment plan”) → set `outcome_type`.  
- **Stronger:** One short LLM call in the webhook: “Given this transcript/summary, classify outcome into: promised_to_pay, asked_extension, …” and store the result in the call doc.

**Data to add on the call document:**

| Field | Type | Meaning |
|-------|------|--------|
| `outcome_type` | string | One of the values above (from transcript/summary). |
| `outcome_confidence` | string \| number | Optional: "high" / "low" or 0–1. |

**Efficiency:** One extra write at webhook time; no extra reads. Enables dashboards like “X% of calls were promised_to_pay; of those, Y% had payment_received within 14 days.”

---

### 2.3 Engagement (answered, duration)

**Source:** VAPI end-of-call report: `duration`, `ended_reason`, etc.

**Data to add on the call document (if not already there):**

| Field | Type | Meaning |
|-------|------|--------|
| `duration_seconds` | int | From VAPI. |
| `answered` | bool | e.g. true if duration > 0 or ended_reason ≠ no_answer. |
| `ended_reason` | string | VAPI value (e.g. customer-ended-call, no-answer). |

**Use:** Filter “success” reports to answered calls only; show “avg duration” and “no-answer rate” per school or per campaign.

---

## 3. Single Source of Truth: Call Document Shape

Recommended fields on each call in `schools/{school_id}/outbound_calls` (or equivalent):

```text
# Already or from webhook
vapi_call_id, student_id, student_phone, student_name,
balance, due_date, late_fee, status, created_at,
transcript, summary, recording_url, ended_at

# Success tracking
success_metric          # "payment_received" | "promised_to_pay" | "engaged" | "no_answer" | "unknown"
outcome_type           # same set (from conversation)
attributed_payment_id  # set when payment is created in window
attributed_payment_at
attributed_payment_amount
duration_seconds
answered
ended_reason
```

- **success_metric:** Your main “success” label. Set to `payment_received` when attribution runs; otherwise set from `outcome_type` when the call is saved (e.g. promised_to_pay, no_answer, unknown).
- **outcome_type:** Purely from the conversation (and optional LLM/keyword logic).
- **attributed_*:** Filled only when a payment is recorded after the call (attribution logic).

---

## 4. Attribution Logic (Detailed)

**When:** Immediately after creating a payment (in `add_payment` or in the route that calls it).

**Input:** `school_id`, `student_id`, payment `id`, payment `created_at`, payment `amount`.

**Steps:**
1. Let `payment_at` = payment `created_at` (or now if not stored).
2. Query calls: same `school_id`, same `student_id`, `created_at` ≤ `payment_at`, `created_at` ≥ `payment_at` − 14 days. Order by `created_at` desc. Limit 1.
3. If no call found, return (no attribution).
4. If call already has `attributed_payment_id`, optional: skip (so each call gets at most one payment), or allow overwrite with “latest payment” depending on product choice.
5. Update the call document:
   - `attributed_payment_id` = payment id  
   - `attributed_payment_at` = payment_at  
   - `attributed_payment_amount` = amount  
   - `success_metric` = `"payment_received"`  
6. (Optional) Emit an event or update an aggregate (e.g. school-level “calls that led to payment” count) for dashboards.

**Firestore query shape (conceptual):**
- Collection: `schools/{school_id}/outbound_calls`
- Where: `student_id` == student_id, `created_at` <= payment_at, `created_at` >= payment_at - 14d
- Order by: `created_at` desc
- Limit: 1

Then update that document with the attribution fields.

---

## 5. Reporting (What You Can Show)

With the above in place you can efficiently support:

| Report | How |
|--------|-----|
| **Payment success rate (calls)** | Count calls where `success_metric == "payment_received"` / total completed calls (or total answered calls). |
| **Revenue attributed to calls** | Sum `attributed_payment_amount` (or join to payments by `attributed_payment_id`) for calls in a date range. |
| **Conversion funnel** | % of calls with outcome_type “promised_to_pay” that later have `success_metric == "payment_received"`. |
| **Per-student** | “3 calls, 1 led to payment” = count calls for student where one has `attributed_payment_id` set. |
| **Per campaign / time** | Same metrics filtered by date or by a campaign tag if you add it later. |

All of this uses the same call documents; no extra tables. Dashboards can read from existing list-calls API if the response includes the new fields, or from a dedicated “call success summary” endpoint that aggregates by school and date.

---

## 6. Implementation Order (Efficient Path)

| Step | What | Effort |
|------|------|--------|
| 1 | Add fields to call model (in code/docs): `success_metric`, `attributed_payment_id`, `attributed_payment_at`, `attributed_payment_amount`. Ensure webhook (or existing flow) writes `duration_seconds`, `answered`/`ended_reason` when available. | Small |
| 2 | In `add_payment`: after creating the payment, run attribution (query last call in 14-day window, update that call). | Small |
| 3 | Expose new fields in `GET /api/pulse/calls` (and in any call-detail response) so the app can show “Payment received after this call” and success badges. | Small |
| 4 | (Optional) In end-of-call webhook: set `outcome_type` (and default `success_metric` from it) using keywords or a small LLM call. | Medium |
| 5 | Add dashboard or “Call success” section: payment success rate, revenue attributed, outcome breakdown (if you have outcome_type). | Medium |

Steps 1–3 give you **payment-based call success** with minimal code and no background jobs. Steps 4–5 add conversation-level nuance and visibility.

---

## 7. Summary

- **Best single way to track “call success” for payments:** When a payment is recorded, attribute it to the most recent call to that student within the last 14 days and mark that call as “payment received.”
- **Efficient:** One query + one write at payment-creation time; no cron, no duplicate state.
- **Extra value:** Store conversation outcome (promised_to_pay, no_answer, etc.) in the webhook and use it for soft success and funnel analytics.
- **Result:** You can report “this call led to payment,” “X% of calls resulted in payment,” and “revenue attributed to calls” with a small, well-defined change set.
