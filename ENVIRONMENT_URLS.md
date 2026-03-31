# Backend URL (Flutter)

**Edit one constant** in [`lib/config/backend_urls.dart`](lib/config/backend_urls.dart):

- `kNeyvoBackendUrl` — paste your backend base URL (staging, production, or `http://127.0.0.1:8000`). No trailing slash.

All API calls and integration fallbacks use `resolveNeyvoApiBaseUrl()`, which reads that default unless you override at build time:

```text
flutter run -d chrome --dart-define=API_BASE_URL=https://goodwin-neyvo-back.onrender.com
```

## Backend (Render, separate repo)

Each Render service sets **`PUBLIC_BASE_URL`** to its own public URL (see `GU_Neyvo_Back/.env.example`).

## Regenerating `vapi_configs` (backend repo)

```text
cd GU_Neyvo_Back
python scripts/generate_vapi_configs.py
```

Set `PRODUCTION_URL` / `PUBLIC_BASE_URL` before running so generated JSON matches that host.
