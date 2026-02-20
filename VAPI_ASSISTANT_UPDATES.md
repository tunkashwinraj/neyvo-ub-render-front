# VAPI Assistant Updates (Neyvo Pulse Billing Agent)

Use these updates so the assistant matches the backend and avoids small inconsistencies.

---

## 1. Fix `endCallMessage` (wrong school name)

**Current:**  
`"End the call politely once conversation is complete."` and the stored `endCallMessage` is:  
`"Thank you for choosing TechSolutions. I'm glad I could help you today. Have a great day!"`

**Issue:** "TechSolutions" is hardcoded; it should use the school name.

**Update in VAPI dashboard:**  
Set **endCallMessage** to use the same variable as the rest of the script:

```text
Thank you for choosing {{school_name}}. I'm glad I could help you today. Have a great day!
```

---

## 2. Optional: Use `past_calls_summary` and `school_knowledge` in the prompt

The backend already injects these into each outbound call:

- **`past_calls_summary`** – Text summary of recent calls with this student (date, summary, outcome).
- **`school_knowledge`** – FAQ + policy text from Training (Settings / Training screen).

Your assistant can use them by referencing the variables in the **system message**. Add one short block so the model knows they exist and when to use them:

**Add to the system message (after the Compliance Guardrails block):**

```text
Context (use when relevant):
- past_calls_summary: {{past_calls_summary}} — Use this to avoid repeating yourself and to reference prior conversations.
- school_knowledge: {{school_knowledge}} — Use this to answer policy and FAQ questions accurately. Do not make up policy details.
```

No code change is required: the backend sends these in `variableValues` when creating the VAPI call; you only need to mention them in the prompt so the model uses them.

---

## 3. Optional: Voicemail message variable

You already use `{{student_name}}`, `{{school_name}}`, `{{balance}}` in **voicemailMessage**. No change needed unless you want to add due date or late fee there, e.g.:

```text
Hello {{student_name}}, this is Alex calling on behalf of {{school_name}} regarding your account balance of {{balance}}, due {{due_date}}. Please contact the billing office at your earliest convenience. Thank you.
```

---

## Summary

| Item | Action |
|------|--------|
| **endCallMessage** | Replace "TechSolutions" with `{{school_name}}`. |
| **System message** | Optionally add a "Context" block that references `{{past_calls_summary}}` and `{{school_knowledge}}`. |
| **Voicemail** | Optional: add `{{due_date}}` if you want it in the voicemail. |

After updating, redeploy or save the assistant in the VAPI dashboard so new outbound calls use the new copy and variables.
