# Neyvo Pulse – Frontend module

Dedicated folder for Neyvo Pulse (schools): screens, routes, and API client. Same colors and fonts as the main app (Spearia theme), different structure and layout.

## Layout

- **`pulse_route_names.dart`** – Route path constants.
- **`pulse_routes.dart`** – `PulseRouter.generateRoute` for Pulse screens.
- **`neyvo_pulse_api.dart`** – API client (outbound call, health). Uses `SpeariaApi.baseUrl`; no auth for Pulse endpoints.
- **`screens/`**
  - **`pulse_auth_page.dart`** – Sign in / Sign up (Firebase), new layout.
  - **`pulse_dashboard_page.dart`** – School dashboard: Outbound calls, Students, Reminders.
  - **`outbound_calls_page.dart`** – Form to start an outbound call (student phone, name, balance, due date, late fee, VAPI phone number ID).
  - **`students_page.dart`** – Placeholder; connect student roster (Firestore/CSV) later.

## Running as Neyvo Pulse

Run with:

```bash
flutter run --dart-define=NEYVO_PULSE=true
```

For web:

```bash
flutter run -d chrome --dart-define=NEYVO_PULSE=true --dart-define=BACKEND_BASE=http://127.0.0.1:8000
```

Without `NEYVO_PULSE=true`, the app uses the default Spearia Admin flow (AuthGate, onboarding, business dashboard).

## API key usage

- **Outbound calls** are started from the **backend** (private key only). The frontend calls `POST /api/pulse/outbound/call`; the backend uses `VAPI_PULSE_PRIVATE_KEY` to create the VAPI call.
- **Public API key** is for client-side use only if you add a VAPI widget or client-side feature later; do not use it for outbound calls.
