# Neyvo Pulse – Assistant Training & Call Memory Design

This document describes how to implement **two mandatory features**:

1. **Call memory** – The assistant must have full knowledge of past calls with each student (e.g. “we’ve called you 6 times about reminders”; reasons, outcomes, what was discussed).
2. **Flexible training** – Schools must be able to train their assistant so it can answer many types of student questions, with full knowledge of the school’s model, policies, and how they’ve trained it.

It also covers **RAG** (retrieval-augmented generation) and **semantic analysis** as the most efficient way to support both.

---

## 1. Goals (Mandatory)

| Requirement | Description |
|-------------|-------------|
| **Past call knowledge** | Before/during every call, the assistant must “know” the full history of calls with that student: count, reasons (e.g. reminder #3, balance due), outcomes (promised to pay, asked for extension), and summaries/transcripts so it can say things like “Last time we discussed a payment plan” or “This is our 6th reminder call.” |
| **School-trained assistant** | Schools can add FAQs, policies, documents. The assistant must use this knowledge to answer diverse student questions (payment plans, deadlines, who to contact, late fees, etc.) in a flexible way. |
| **RAG + semantic** | Use retrieval over school knowledge and (optionally) over past call content, with semantic similarity so the right context is injected into the prompt. |

---

## 2. Current State (Brief)

- **Outbound flow**: Frontend → `POST /api/pulse/outbound/call` → backend sends to VAPI with `variableValues`: `student_name`, `balance`, `due_date`, `late_fee`, `school_name`, `message_type`. No past-call context and no school-specific knowledge beyond what’s in the VAPI assistant template.
- **Call storage**:  
  - Pulse: `schools/{school_id}/outbound_calls` – only “initiated” with student_id, student_phone, etc. No transcript/summary stored today.  
  - VAPI webhooks: end-of-call report stored in `vapi_calls/{call_id}` and `businesses/{biz_id}/calls/{call_id}` with transcript, analysis, etc., but not linked to Pulse `school_id`/`student_id` in a way the Pulse backend uses.
- **Training**: No school-specific knowledge base or FAQ in the Pulse path; the assistant is whatever is configured in the VAPI dashboard.

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         NEYVO PULSE (School)                              │
├─────────────────────────────────────────────────────────────────────────┤
│  Flutter App                                                              │
│  • Training UI: FAQ, documents upload, policy fields                      │
│  • Call memory view: past calls per student (already in Call Logs)        │
│  • Start outbound call (unchanged from user POV)                           │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Backend (Pulse API + services)                                           │
│                                                                           │
│  When starting outbound call:                                             │
│    1. Load student profile (balance, due_date, etc.)                       │
│    2. Load PAST CALL MEMORY for this student (last N calls: summary +     │
│       reason, outcome, key points)                                         │
│    3. (Optional) RAG: retrieve school knowledge chunks relevant to        │
│       “billing + payment policy + this student”                            │
│    4. Build context string(s); pass to VAPI as variableValues             │
│       (e.g. past_calls_summary, school_knowledge)                          │
│                                                                           │
│  After each call (VAPI webhook):                                          │
│    1. Receive end-of-call-report with transcript, analysis                │
│    2. Identify school_id + student_id (from call metadata)                 │
│    3. Generate short summary + topics + outcome                            │
│    4. Persist in Pulse call storage (per student) for future memory      │
│                                                                           │
│  Training / RAG:                                                          │
│    • Ingest: FAQ entries, uploaded docs → chunk → embed → vector store    │
│    • At call start (or on demand): semantic search → top-k chunks          │
│    • Inject into assistant context                                       │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  VAPI                                                                     │
│  • Assistant uses {{past_calls_summary}}, {{school_knowledge}}, and       │
│    existing {{student_name}}, {{balance}}, etc. in prompt / firstMessage  │
│  • No change to VAPI product; we only pass richer variableValues         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Call Memory (Past Calls) – Design

### 4.1 Persist full call outcome in Pulse

- **When**: On VAPI `end-of-call-report` webhook.
- **How**:  
  - When creating an outbound call, backend must pass **metadata** to VAPI: `account_id`, `student_id`. VAPI includes this in the end-of-call payload.  
  - Backend has a **Pulse-specific** handler (or branch in the existing webhook) that:  
    - Reads `metadata.school_id`, `metadata.student_id`.  
    - Gets transcript and analysis from the event.  
    - Generates a **short summary** (e.g. 2–4 sentences) and **outcome** (e.g. “promised to pay by Friday”, “asked for extension”, “no answer”).  
    - Writes/updates a call record **keyed by student** so we can query “all calls for this student”.

- **Where to store** (choose one and keep it consistent):

  - **Option A – Same collection, update by call_id**:  
    When we start a call we already create a doc in `schools/{school_id}/outbound_calls` with `vapi_call_id`. When the webhook fires, we **update that doc** by `vapi_call_id` (or by a mapping call_id → doc id) with:  
    `transcript`, `summary`, `outcome`, `topics[]`, `duration_seconds`, `recording_url`, `ended_at`.  
    Then “past calls for student” = query `outbound_calls` where `student_id == X`, ordered by `created_at` desc.

  - **Option B – Separate “call history” subcollection**:  
    `schools/{school_id}/students/{student_id}/calls/{call_id}`.  
    Webhook creates/updates a doc here with the same fields. “Past calls for student” = read this subcollection.  
    Pro: clear per-student history. Con: two places to write (outbound_calls for “initiated”, student’s calls for “completed”).

Recommendation: **Option A** – single collection `outbound_calls`, with webhook updating the same document we create at call start (match by `vapi_call_id` or by storing `vapi_call_id` in the doc when we create the call). Add fields: `transcript`, `summary`, `outcome`, `topics`, `duration_seconds`, `recording_url`, `ended_at`, `status: "completed"`.

### 4.2 Build “past call summary” for the next call

- **When**: In the backend, **right before** calling VAPI `create-call` (same place you now build `variableValues`).
- **Input**: `school_id`, `student_id`.
- **Steps**:  
  1. Query `schools/{school_id}/outbound_calls` where `student_id == student_id`, order by `created_at` desc, limit N (e.g. 10 or 20).  
  2. For each call, take `summary` (or if missing, first 200 chars of `transcript`), `outcome`, `created_at`, and optionally “reason” (e.g. reminder #K, balance reminder) if you store it.  
  3. Format a single text block, e.g.:

```text
Past calls with this student:
- 2026-02-18 (reminder #6): Student said they would pay by Friday. Outcome: promised to pay.
- 2026-02-10 (balance reminder): Asked about payment plan. Outcome: discussed plan.
- ...
```

  4. Pass this as a new **variable** to VAPI, e.g. `past_calls_summary`, and ensure the VAPI assistant’s system prompt (or firstMessage) says something like: “You have the following context about past calls with this student. Use it to personalize and avoid repeating yourself: {{past_calls_summary}}.”

- **Token budget**: Keep this block bounded (e.g. last 5–10 calls, or cap total characters). If you have many calls, summarize the oldest as “N earlier calls about balance/reminders” to avoid blowing the context window.

### 4.3 Optional: RAG over past transcripts

- If you want the assistant to “recall” specific sentences from past calls (e.g. “You mentioned last time you’d pay on the 15th”), you can:
  - Store per-call chunks (e.g. by sentence or paragraph) with embeddings in a vector store, keyed by `school_id` + `student_id`.
  - At call start, run a semantic query like “payment promise, due date, extension” and inject the top chunks into `past_calls_summary` or a second variable.
- For many schools, the **structured summary per call** (4.2) is enough and simpler; add RAG over transcripts only if you need finer-grained recall.

---

## 5. Flexible Training (School Knowledge) – Design

### 5.1 What schools can train

- **Structured fields** (already partly there): school name, payment policy, contact info, late fee, due date rules. These can stay as simple key–value or short text and be injected into the prompt.
- **FAQ list**: Pairs of (question, answer). Schools add/edit/delete. Used for both direct Q&A and RAG.
- **Documents**: PDFs, DOCX, or plain text (e.g. “Payment policy 2026”, “FAQ for parents”). Uploaded, chunked, embedded, and retrieved via RAG.

### 5.2 Data model (backend)

- **Stored in Firestore** (or your primary DB), e.g.:
  - `schools/{school_id}/knowledge/faq` – document or subcollection: `{ id, question, answer, order }`.
  - `schools/{school_id}/knowledge/documents` – metadata: `{ id, name, type, uploaded_at }`. File content can be in Storage or in a “chunks” subcollection after processing.
  - `schools/{school_id}/knowledge/policy` – optional doc with fields: `payment_policy`, `late_fee_policy`, `contact_info`, `default_due_days`, etc.
- **Vector store** (for RAG): Either:
  - **Same DB**: e.g. Postgres + pgvector, collection “knowledge_chunks” with (school_id, chunk_text, embedding, source_type, source_id).  
  - **Managed**: Pinecone, Weaviate, or Firebase Vector Search if available.  
  Chunks have metadata: `school_id`, `source` (faq_id or document_id), so retrieval is always scoped to the school.

### 5.3 RAG pipeline

- **Ingest (when school adds/edits FAQ or uploads a doc)**:
  1. **FAQ**: One “chunk” per Q&A (e.g. “Q: … A: …”).  
  2. **Documents**: Split into chunks (e.g. 300–500 tokens with overlap).  
  3. Generate **embeddings** (e.g. OpenAI `text-embedding-3-small`, or open-source like `sentence-transformers`).  
  4. Store in vector store with `school_id` and `source` metadata.

- **At call start (or when assistant needs knowledge)**:
  1. Optional: build a short “query” from current context, e.g. “payment policy due date late fee contact” + “student balance reminder”.  
  2. Embed the query with the same model.  
  3. Vector search **filtered by school_id**, top-k (e.g. 5–10 chunks).  
  4. Format chunks into a single string `school_knowledge` and pass as **variableValues.school_knowledge** (or similar) to VAPI.  
  5. System prompt: “Use the following school-specific knowledge when answering: {{school_knowledge}}.”

- **Semantic analysis**: Same embedding model can be used to:
  - **Match student utterance** to the closest FAQ (embed student message, find nearest FAQ chunk) and optionally return that answer or reinforce it in the prompt.
  - **Intent/topic**: Classify “payment question”, “due date”, “complaint”, “extension request” for routing or logging (optional).

### 5.4 Training UI (Flutter)

- **Settings / Training** section (or new “Assistant training” screen):
  - **FAQ**: List of Q&A; add/edit/delete; optional reorder.  
  - **Documents**: Upload file (PDF/DOCX/TXT); show list with “Processing”/“Ready”; delete.  
  - **Policy fields**: Form with payment policy, late fee, contact info, etc.  
- **API**: Backend exposes e.g.:
  - `GET/POST/PATCH/DELETE /api/pulse/knowledge/faq`
  - `GET/POST/DELETE /api/pulse/knowledge/documents` (upload = multipart or base64)
  - `GET/PATCH /api/pulse/knowledge/policy`
  - Optional: `POST /api/pulse/knowledge/documents/{id}/reprocess` to re-chunk/re-embed.

---

## 6. VAPI Integration Details

- **Pass metadata when creating the call** so the webhook can attribute the call to a student:

```json
{
  "assistantId": "...",
  "phoneNumberId": "...",
  "customer": { "number": "+1..." },
  "assistantOverrides": {
    "variableValues": {
      "student_name": "...",
      "balance": "...",
      "due_date": "...",
      "late_fee": "...",
      "school_name": "...",
      "past_calls_summary": "...",   // NEW
      "school_knowledge": "..."      // NEW
    }
  },
  "metadata": {
    "school_id": "default-school",
    "student_id": "abc123"
  }
}
```

- Check VAPI docs for the exact field name for custom metadata (e.g. `metadata` or `customData`). The end-of-call report must return this so the backend can update the correct Pulse call record and student history.

- **Assistant prompt (in VAPI dashboard)** should include instructions like:
  - “You have context about past calls with this student. Use it to be personal and avoid repeating yourself.”
  - “Use the following school knowledge to answer policy and FAQ questions: {{school_knowledge}}.”

---

## 7. Implementation Order (Efficient Path)

| Phase | What | Backend | Frontend |
|-------|------|---------|----------|
| **1. Call memory – persist** | Webhook updates Pulse call with transcript/summary/outcome; pass school_id + student_id in create-call metadata | VAPI webhook branch: resolve Pulse call by vapi_call_id or metadata, write summary + transcript; ensure outbound call creation sends metadata | No change |
| **2. Call memory – inject** | Before create-call, load last N calls for student, build `past_calls_summary`, add to variableValues | In `create_outbound_call`, query outbound_calls by student_id, format text, add to variableValues; extend VAPI payload with metadata | No change |
| **3. Training – FAQ + policy** | Schools can add FAQ and policy fields; inject into prompt | Firestore: faq + policy; endpoint to get “all knowledge text” for a school; at call start, build school_knowledge from FAQ + policy (no vector yet), add to variableValues | Training UI: FAQ list CRUD, policy form |
| **4. RAG – ingest** | Chunk + embed FAQ and docs; store in vector DB | Chunking + embedding job (on FAQ/doc add/update); vector DB write; API for ingest | Document upload UI; “Processing” state |
| **5. RAG – retrieve** | At call start, semantic search, inject top-k into school_knowledge | On create_outbound_call, query vector store by school_id, merge with FAQ/policy if needed, set variableValues.school_knowledge | No change |
| **6. Optional** | Semantic intent/FAQ match during call | Backend tool or post-turn: embed user message, return closest FAQ or intent; can be used for analytics or dynamic prompt | Optional: show “matched FAQ” in Call Logs |

---

## 8. Tech Choices (Short)

- **Embeddings**: OpenAI `text-embedding-3-small` (good quality, low cost) or open-source (e.g. `sentence-transformers`) if you want to avoid external API.
- **Vector DB**: pgvector (if you already use Postgres), or Pinecone/Weaviate for managed; Firebase Vector Search if you stay on Firebase and it supports your scale.
- **Summary generation**: Use the same LLM you use for insights (e.g. one short paragraph per call) in the webhook when persisting the call.

---

## 9. Success Criteria

- **Call memory**: For any outbound call, the assistant “knows” the last N calls with that student (reason, outcome, short summary). No need for the student to repeat history.
- **Training**: Schools can add FAQs and documents; the assistant’s answers align with this content and with policy fields; behavior is flexible and under the school’s control.
- **RAG**: Relevant chunks from the school’s knowledge base are retrieved by semantic similarity and included in the context for every call (or for specific intents).

This gives you a clear path to implement **past-call memory** and **flexible, school-driven training** with **RAG and semantic search** in an efficient way, with minimal change to the existing VAPI flow (metadata + two new variables and webhook persistence).
