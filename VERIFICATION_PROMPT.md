# Neyvo Pulse – Full Stack Verification Prompt

**Use this prompt with VAPI Composer AI (or any testing/evaluation agent) to run a detailed verification of the Neyvo Pulse application.** Copy the entire "Instructions for the evaluator" section below and paste it into the composer. The evaluator should perform each check and report pass/fail plus any errors or potential issues.

---

## Instructions for the evaluator

You are performing a **detailed evaluation and verification** of the Neyvo Pulse application stack. Your goal is to confirm that all endpoints, the connection between frontend and backend, the Render deployment, and Sentry (if used) are working correctly, and to identify any errors or potential issues.

### Context

- **Application:** Neyvo Pulse – voice/student-management app (Flutter web frontend, Flask backend on Render).
- **Backend base URL:** `https://neyvo-pulse.onrender.com`
- **API prefix:** All Pulse APIs are under `/api/pulse/`. The frontend sends `school_id=default-school` (query or body) and may send `X-User-Id` (Firebase UID) for RBAC.
- **CORS:** Backend must allow the frontend origin (e.g. `http://localhost:PORT` for local dev, or the deployed Flutter URL) and must allow headers: `Content-Type`, `Authorization`, `X-Admin-Token`, `X-User-Id`, `Accept`, `Accept-Language`, `X-Requested-With`, `ngrok-skip-browser-warning`.

### 1. Backend availability and health

- **1.1** Request `GET https://neyvo-pulse.onrender.com/api/pulse/health` (no auth required).
  - **Pass:** Status 200, JSON with `"ok": true` and `"service": "neyvo_pulse"`.
  - **Fail:** Non-200, timeout, connection refused, or missing/incorrect JSON. Note the exact status and body.
- **1.2** If the backend is on Render with cold starts, the first request may be slow (30–60 s). Retry once after a short wait if the first attempt times out, and note whether the second attempt succeeds.

### 2. Pulse API endpoints (smoke test)

For each endpoint, call with the base URL above. Use query param `school_id=default-school` where applicable. Report status code and whether the response is valid JSON with an `ok` field (or 2xx for OPTIONS).

| # | Method | Path | Purpose | Expected |
|---|--------|------|---------|----------|
| 2.1 | GET | `/api/pulse/health` | Health check | 200, `ok: true` |
| 2.2 | GET | `/api/pulse/students?school_id=default-school` | List students | 200, `ok: true`, `students` array |
| 2.3 | GET | `/api/pulse/payments?school_id=default-school` | List payments | 200, `ok: true`, `payments` array |
| 2.4 | GET | `/api/pulse/calls?school_id=default-school` | List calls | 200, `ok: true`, `calls` array |
| 2.5 | GET | `/api/pulse/calls/success-summary?school_id=default-school` | Success metrics | 200, `ok: true`, `success_summary` object |
| 2.6 | GET | `/api/pulse/reminders?school_id=default-school` | List reminders | 200, `ok: true`, `reminders` array |
| 2.7 | GET | `/api/pulse/settings?school_id=default-school` | Get settings | 200, `ok: true`, `settings` object |
| 2.8 | GET | `/api/pulse/reports/summary?school_id=default-school` | Reports summary | 200, `ok: true` |
| 2.9 | GET | `/api/pulse/knowledge/policy?school_id=default-school` | Get policy | 200, `ok: true`, `policy` object |
| 2.10 | GET | `/api/pulse/knowledge/faq?school_id=default-school` | List FAQ | 200, `ok: true`, `faq` array |
| 2.11 | GET | `/api/pulse/audit-log?school_id=default-school&limit=10` | Audit log | 200, `ok: true`, `entries` array |
| 2.12 | GET | `/api/pulse/members?school_id=default-school` | List members (RBAC) | 200, `ok: true`, `members` array |
| 2.13 | GET | `/api/pulse/members/me?school_id=default-school` | Current user role | 200, `ok: true`, `role` string |

**Mutation checks (optional but recommended):**  
- **2.14** `POST /api/pulse/students` with body `{"school_id":"default-school","name":"Verification Student","phone":"+15550001111"}`. Expect 201 and `student` object; note the returned `id` for cleanup if needed.  
- **2.15** `GET /api/pulse/insights` (optional backend). If 404 or 5xx, note it; frontend can derive insights from calls when this is missing.

### 3. CORS and frontend–backend connection

- **3.1** From a browser context (or with origin header), send `OPTIONS https://neyvo-pulse.onrender.com/api/pulse/students?school_id=default-school` with headers: `Origin: http://localhost:61426`, `Access-Control-Request-Method: GET`, `Access-Control-Request-Headers: Content-Type, X-User-Id`.
  - **Pass:** 204 or 200, and response headers include `Access-Control-Allow-Origin` (e.g. `*` or the requested origin) and `Access-Control-Allow-Headers` including `X-User-Id` and `Content-Type`.
  - **Fail:** Missing CORS headers, 4xx/5xx on OPTIONS, or browser would block the subsequent GET. Note which header is missing or wrong.
- **3.2** Perform a real `GET /api/pulse/students?school_id=default-school` from the same origin (or with the same Origin header). **Pass:** 200 and valid JSON. **Fail:** Blocked by CORS, network error, or non-2xx.

### 4. Render deployment

- **4.1** Confirm the backend URL responds (already covered in 1.1). If the service is on Render free tier, note that cold starts can cause the first request to take 30–60 seconds; report whether retries succeed.
- **4.2** Check that responses are not truncated and that JSON is well-formed. Report any 502/503 or HTML error pages.
- **4.3** If you have access to Render dashboard or logs: note whether env vars are set (e.g. `SENTRY_DSN`, `SENTRY_DISABLE`, `CORS_ALLOW_ORIGIN`, Firebase/DB vars). Do not log secret values; only report “set” or “missing” for critical names.

### 5. Sentry

- **5.1** Backend may log “Sentry initialized” or “Sentry disabled by SENTRY_DISABLE”. If Sentry is enabled and the deployment blocks outbound connections to Sentry ingest, the app may log “Remote end closed connection” or “Internal error in sentry_sdk”. Report whether you see any Sentry-related errors in logs (if logs are available).
- **5.2** Recommendation: If Sentry ingest is unreachable from Render, set `SENTRY_DISABLE=1` so the app does not attempt to send events. Note this as a potential configuration fix if you observe Sentry transport errors.

### 6. Frontend assumptions (no direct code execution required)

- **6.1** The Flutter app is configured with `SpeariaApi.setBaseUrl('https://neyvo-pulse.onrender.com')`. If the user runs the app against a different backend (e.g. localhost), the base URL must match that backend; otherwise every request will fail or hit the wrong host. Report: “Frontend base URL should match the backend being tested (currently documented as https://neyvo-pulse.onrender.com).”
- **6.2** The app sends `X-User-Id` when the user is signed in (Firebase Auth). Backend CORS must allow this header (checked in 3.1). Report any mismatch.
- **6.3** Auth: Login/sign-up use Firebase Auth; the backend does not issue JWTs. Report if there is any expectation of backend-issued tokens that would be incorrect.

### 7. Summary report

Produce a short report with:

1. **Overall status:** PASS / FAIL / PARTIAL (with one-line reason).
2. **Backend health:** Result of 1.1 and 1.2 (and 4.1).
3. **Endpoint table:** For each of 2.1–2.13 (and 2.14–2.15 if run), list: endpoint, status code, pass/fail, and one line for any error or anomaly.
4. **CORS / connectivity:** Result of 3.1 and 3.2; any “failed to fetch” or CORS errors the frontend might see.
5. **Render:** Cold start note, 502/503, or other deployment issues (4.1–4.3).
6. **Sentry:** Any Sentry-related errors or recommendation (5.1–5.2).
7. **Risks or follow-ups:** List any potential issues (e.g. missing env, wrong base URL, rate limits, or endpoints that failed only under specific conditions).

Perform the checks in order where possible; if the health check (1.1) fails, note that and still attempt CORS (3) if you can reach the server at all. Be concise but precise: include status codes, header names, and exact error messages where relevant.

---

## Quick reference – Pulse API base and key routes

- **Base:** `https://neyvo-pulse.onrender.com`
- **Pulse prefix:** `/api/pulse/`
- **Query param:** `school_id=default-school` for multi-tenant (default).
- **Optional header:** `X-User-Id: <firebase-uid>` for RBAC (backend allows request if header absent).

| Area | Key routes |
|------|------------|
| Health | `GET /api/pulse/health` |
| Students | `GET/POST /api/pulse/students`, `GET/PATCH/DELETE /api/pulse/students/<id>` |
| Payments | `GET/POST /api/pulse/payments` |
| Calls | `GET /api/pulse/calls`, `GET /api/pulse/calls/success-summary` |
| Reminders | `GET/POST /api/pulse/reminders` |
| Settings | `GET/PATCH /api/pulse/settings` |
| Reports | `GET /api/pulse/reports/summary` |
| Knowledge | `GET/PATCH /api/pulse/knowledge/policy`, `GET/POST/PATCH/DELETE /api/pulse/knowledge/faq` |
| Outbound call | `POST /api/pulse/outbound/call` (body: student_phone, student_name, etc.) |
| Audit | `GET /api/pulse/audit-log` |
| RBAC | `GET /api/pulse/members`, `GET /api/pulse/members/me`, `PATCH /api/pulse/members/<user_id>` |

Use this document as the single source of verification steps and report format for the evaluator.
