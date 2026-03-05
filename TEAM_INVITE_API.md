# Team invite API – backend contract

The **Team** section in the app adds members by email and expects the backend to **send an invite email** to that address. If users don’t receive the email, the backend implementation of this endpoint is the place to fix.

## Endpoint

- **Method:** `POST`
- **Path:** `/api/pulse/members/invite`
- **Auth:** Same as other Pulse APIs (e.g. `Authorization: Bearer <token>`, `X-User-Id`). `account_id` is sent in the body by the frontend.

## Request body (from frontend)

| Field               | Type     | Required | Description |
|---------------------|----------|----------|-------------|
| `email`              | string   | Yes      | Email address to invite. |
| `role`              | string   | Yes      | `"admin"` or `"staff"`. |
| `permissions`        | string[] | No       | Only for `role: "staff"`. e.g. `["students","call_logs","campaigns"]`. |
| `send_invite_email` | boolean  | Yes      | Frontend sends `true`; backend **must send an invite email** when this is true. |
| `account_id`         | string   | Yes*     | Injected by frontend; org/account to add the member to. |

## What the backend must do

1. **Validate** the request (email, role, permissions, auth).
2. **Create/link the member** in your store (e.g. Firestore) with the given role and permissions.
3. **When `send_invite_email === true`**, send an **invite email** to `email` containing:
   - A link to join/sign in (e.g. app URL or magic link), and/or
   - Instructions to sign up/log in and join the org.

If no email is sent when `send_invite_email` is true, users will report “I never got the invite.”

## Typical causes of “no email received”

- **Endpoint not implemented** – 404 or stub that doesn’t send email.
- **Email service not configured** – No SMTP, SendGrid, SES, etc., or missing env vars.
- **Email sent but filtered** – Spam/junk; use a proper sender domain and consider a transactional email provider.
- **Wrong address** – Bug using a different field than `email` for the recipient.

## Response

- **Success:** e.g. `200` or `201` with a body such as `{ "ok": true, "message": "Invite sent" }`.
- **Error:** 4xx with a clear message; frontend shows it in a SnackBar.

Frontend shows: *“Invite sent to &lt;email&gt;. If they don’t receive it, ask them to check spam.”*
