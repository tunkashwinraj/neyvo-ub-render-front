# Prompt for ChatGPT: Generate Demo Data for Neyvo Pulse Integration

Copy everything below the line and paste it into ChatGPT. It will generate demo data in the exact formats our integration layer accepts (webhook JSON, CSV, and API pull response).

---

**START OF PROMPT — copy from here**

You are helping me create **demo data** for testing a school billing integration. The system accepts student and payment data in three formats. Generate realistic but fake data for a single school (e.g. "Riverside Academy") with **around 8–12 students** and **around 15–25 payments** (some students have multiple payments). Use US-style names, phone numbers (e.g. +1 555-XXX-XXXX), and dollar amounts. Include a mix of current balances, due dates, and late fees.

Output your response in **three parts** as described below. Use the same students and payments across all three parts so the data is consistent (same `external_id` and `external_payment_id` values where applicable).

---

## Part 1: Webhook-style JSON (single events and one batch)

Generate these **exact JSON payloads** (I will POST them to an endpoint that expects this shape):

**1a) Single payment received event**
```json
{
  "school_id": "demo-school",
  "event": "payment_received",
  "external_id": "<use same student external_id from your roster>",
  "student_id": "<same>",
  "amount": "<amount as string e.g. \"50.00\">",
  "external_payment_id": "<unique id e.g. pay-demo-001>",
  "method": "card",
  "note": "Online payment"
}
```
Give me 2 different examples (two different students, two different payments) with real-looking values.

**1b) Balance updated event**
```json
{
  "school_id": "demo-school",
  "event": "balance_updated",
  "external_id": "<student external_id>",
  "name": "<student name>",
  "phone": "<student phone>",
  "email": "<student email or null>",
  "balance": "<new balance as string e.g. \"125.00\">",
  "due_date": "2025-03-15",
  "late_fee": "25.00"
}
```
Give me 1 example.

**1c) Batch payload (students + payments in one request)**
One JSON object with this structure (use your full list of 8–12 students and 15–25 payments):
```json
{
  "school_id": "demo-school",
  "students": [
    {
      "external_id": "stu-001",
      "name": "...",
      "phone": "...",
      "email": "...",
      "balance": "...",
      "due_date": "YYYY-MM-DD",
      "late_fee": "...",
      "notes": null
    }
  ],
  "payments": [
    {
      "external_payment_id": "pay-001",
      "student_id": "stu-001",
      "amount": "50.00",
      "method": "card",
      "note": null
    }
  ]
}
```
Fill in all students and payments with consistent IDs (each payment’s `student_id` must match a student’s `external_id`).

---

## Part 2: CSV for file ingest

Generate one CSV string (with header row) that represents the **same students** as in Part 1. Each row = one student. Columns must be:

`external_id,name,phone,email,balance,due_date,late_fee,notes`

Use the same student data (external_id, name, phone, email, balance, due_date, late_fee) as in Part 1. Quote any field that contains a comma. Provide the raw CSV text in a code block so I can copy it.

Optional second CSV: same students but with one extra column `amount` and `external_payment_id` for payments (so each row can be student + one payment). Columns: `external_id,name,phone,email,balance,due_date,late_fee,notes,amount,external_payment_id,method`. Include 2–3 sample rows for payments.

---

## Part 3: API pull response JSON

Generate one JSON object that mimics what an external school API would return when we call GET on their “students and payments” endpoint. Structure:

```json
{
  "students": [
    {
      "external_id": "stu-001",
      "name": "...",
      "phone": "...",
      "email": "...",
      "balance": "...",
      "due_date": "YYYY-MM-DD",
      "late_fee": "...",
      "notes": null
    }
  ],
  "payments": [
    {
      "external_payment_id": "pay-001",
      "student_id": "stu-001",
      "amount": "50.00",
      "method": "card",
      "note": null
    }
  ]
}
```

Use the **same** 8–12 students and 15–25 payments as in Part 1, with the same IDs. So Part 1c, Part 2, and Part 3 all describe the same roster and transactions.

---

## Summary to include

At the end, list:
- School identifier used: `demo-school`
- Number of students
- Number of payments
- Any `external_id` / `external_payment_id` values you used (so I can test idempotency by re-sending the same payload).

**END OF PROMPT — copy until here**

---

## How to use the generated data

1. **Webhook (Part 1)**  
   - POST each JSON to: `https://your-backend.onrender.com/api/pulse/integration/webhook?school_id=demo-school`  
   - Or put `"school_id": "demo-school"` in the body.  
   - Enable webhook mode for `demo-school` in integration config first.

2. **CSV (Part 2)**  
   - POST to: `POST /api/pulse/integration/ingest/csv`  
   - Body: `{ "school_id": "demo-school", "csv": "<paste the CSV string>" }`  
   - Or send the CSV as a multipart file with field name `file`.

3. **API pull (Part 3)**  
   - Save the Part 3 JSON. Either:  
     - Mock their API: serve that JSON from a URL and set `api_pull_url` in integration config to that URL, then call `POST /api/pulse/integration/sync` with `school_id=demo-school`, or  
     - Call your backend with the same JSON shape and run the sync logic (e.g. via a small script that POSTs to a test endpoint if you add one).

Using the same IDs in all three parts lets you test idempotency (e.g. sending the same webhook or CSV twice should not create duplicate payments).
