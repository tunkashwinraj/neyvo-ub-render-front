# Production configuration inventory (frontend)

This document lists **what configuration exists in production**, and therefore what must be captured to reproduce production behavior during a rollback.

## Where production config lives

- **Firebase Hosting**: serves the built `build/web` bundle.
- **Build-time defines**: Flutter web uses `--dart-define` values baked into the compiled bundle at build time.
- **Firebase web config**: in `lib/firebase_options.dart` (generated) and related Firebase setup.

## Build-time (compile-time) defines used by this app

From `lib/main.dart`:

- **`SPEARIA_BASE_URL`**: backend base URL (defaults to `https://goodwin-neyvo-back.onrender.com`)
- **`SPEARIA_BASE_URL_STAGING`**: backend base URL for staging host (defaults to prod URL)
- **`NEYVO_TENANT`**: local override (defaults to empty; Goodwin is forced in code)
- **`FORCE_STAGING`**: treat localhost as staging (defaults to false)
- **`NEYVO_ACCOUNT_ID`**: optional fallback account id (defaults to empty; Goodwin host fallback is `757763`)

These are **not runtime environment variables** in Firebase Hosting; they must be captured as part of the **backup snapshot notes** (or encoded into a `dart-define-from-file` that is versioned/encrypted).

## Backup scope for “code-only + secrets”

For the backup system we will maintain:

- **Code snapshot**: git tag + release.
- **Build artifact snapshot**: zip of `build/web` attached to the release (so redeploy is fast).
- **Secrets/config snapshot** (encrypted): only if you use any sensitive build-time config (rare for Flutter web; most config is non-secret).

## Exclusions (not covered by this plan)

- Firestore data backups (documents/collections)
- Firebase Auth user backups
- Firebase Storage backups

