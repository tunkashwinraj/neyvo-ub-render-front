# What to Do in VAPI + Prompt for VAPI Composer AI

---

## Part A: What you should do in VAPI (manual)

Do this in the **VAPI Dashboard** (dashboard.vapi.ai or your VAPI project):

1. **Open your assistant**  
   - Go to **Assistants** → open **"Neyvo Pulse Billing Agent"** (or the one with ID `93f2fcf8-a0e8-422c-be36-2d7c20fb4904`).

2. **Fix the end-call message**  
   - Find the field **"End Call Message"** (or `endCallMessage`).  
   - **Current value:**  
     `Thank you for choosing TechSolutions. I'm glad I could help you today. Have a great day!`  
   - **Replace with:**  
     `Thank you for choosing {{school_name}}. I'm glad I could help you today. Have a great day!`  
   - So: remove "TechSolutions" and use the variable `{{school_name}}` instead.

3. **Update the system message (so the AI uses past calls and school knowledge)**  
   - Find the **system message** (the main prompt for the assistant).  
   - At the **end** of that prompt (after "End the call politely once conversation is complete."), **add** this block exactly:

   ```
   Context (use when relevant):
   - past_calls_summary: {{past_calls_summary}} — Use this to avoid repeating yourself and to reference prior conversations.
   - school_knowledge: {{school_knowledge}} — Use this to answer policy and FAQ questions accurately. Do not make up policy details.
   ```

   - Save.  
   - Our backend already sends `past_calls_summary` and `school_knowledge` on each outbound call; this tells the model to use them.

4. **Optional: Voicemail**  
   - If you want the due date in the voicemail, set **Voicemail Message** to something like:  
     `Hello {{student_name}}, this is Alex calling on behalf of {{school_name}} regarding your account balance of {{balance}}, due {{due_date}}. Please contact the billing office at your earliest convenience. Thank you.`

5. **Save the assistant**  
   - Click Save/Update so new outbound calls use these changes.

---

## Part B: Prompt to paste into VAPI Composer AI

Copy everything below the line and paste it into VAPI Composer (or any AI that can help with VAPI). The AI can then apply these via the VAPI API or tell you exactly what to change in the dashboard.

---

**START OF PROMPT — copy from here**

You are helping me update a VAPI assistant for **Neyvo Pulse**, a billing/reminder voice agent. The assistant is named **Neyvo Pulse Billing Agent**. I need the following changes applied (via VAPI API if you have access, or by giving me exact dashboard instructions).

**Assistant context:**
- Assistant name: Neyvo Pulse Billing Agent.
- It uses variables: `{{school_name}}`, `{{student_name}}`, `{{balance}}`, `{{due_date}}`, `{{late_fee}}`.
- Our backend also injects `{{past_calls_summary}}` and `{{school_knowledge}}` on every outbound call. The assistant prompt does not yet reference them.

**Required changes:**

1. **End Call Message (`endCallMessage`)**  
   - Current text includes: "Thank you for choosing TechSolutions. I'm glad I could help you today. Have a great day!"  
   - **Change to:** Use the school name variable instead of "TechSolutions".  
   - New value: `Thank you for choosing {{school_name}}. I'm glad I could help you today. Have a great day!`

2. **System message (main prompt)**  
   - Keep the existing system message exactly as is (Alex, billing assistant for {{school_name}}, purpose, style, objectives, compliance guardrails, "End the call politely once conversation is complete.").  
   - **Append** the following block at the very end of the system message:

   ```
   Context (use when relevant):
   - past_calls_summary: {{past_calls_summary}} — Use this to avoid repeating yourself and to reference prior conversations.
   - school_knowledge: {{school_knowledge}} — Use this to answer policy and FAQ questions accurately. Do not make up policy details.
   ```

3. **Optional:** If the assistant has a voicemail message, add `{{due_date}}` to it so the voicemail mentions the due date (e.g. "...balance of {{balance}}, due {{due_date}}. Please contact...").

**Deliverable:**  
- If you can call the VAPI API: apply these changes to the assistant and confirm.  
- If you cannot: output step-by-step instructions I can follow in the VAPI dashboard (which field to open, what to paste where, and what the final text should be).

**END OF PROMPT — copy until here**

---

Use **Part A** if you prefer to do it yourself in the dashboard; use **Part B** if you want to hand the work to VAPI Composer AI and get either API updates or precise dashboard steps.
