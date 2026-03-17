# Secrets snapshots (encrypted)

This folder is for **encrypted** snapshots of production configuration so a rollback can restore runtime behavior.

## Rules

- **Never commit plaintext secrets** to git.
- Commit only **encrypted** files (recommended extension: `.enc`).

## Typical needs for Flutter web

Most Flutter web deployments do not have “secrets” at runtime (Firebase Hosting serves static files).
However, if you use any sensitive build-time config (rare), store it encrypted here.

## Recommended files (optional)

- `frontend-build-defines.json.enc` — encrypted record of build-time `--dart-define` values (if needed)

