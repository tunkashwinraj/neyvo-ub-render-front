# Restore / rollback runbook (frontend)

Goal: **restore production in ~15 minutes** to the last known-good backup snapshot.

Production hosting:

- Firebase project: `goodwin-neyvo`
- Hosting site (default): `goodwin-neyvo`
- URL: `https://goodwin-neyvo.web.app`

## Fast rollback (preferred): Firebase Hosting version rollback

If a bad deploy went out, the fastest way back is a Firebase Hosting rollback:

```bash
firebase use goodwin-neyvo
firebase hosting:rollback goodwin-neyvo
```

Pick the version that matches the desired backup timestamp.

## Re-deploy a backup build artifact (no rebuild)

Each scheduled backup release attaches `frontend-build-web.zip` (a zipped `build/web`).

Steps:

1. Download `frontend-build-web.zip` from the GitHub Release `backup-YYYYMMDD-HHMMZ`.
2. Unzip so you get `build/web` locally.
3. Deploy:

```bash
firebase use goodwin-neyvo
firebase deploy --only hosting:default
```

## Rebuild + deploy (if you can’t use the artifact)

```bash
flutter pub get
flutter build web --release -O 4
firebase use goodwin-neyvo
firebase deploy --only hosting:default
```

## Post-restore verification checklist

- `https://goodwin-neyvo.web.app` loads and renders the login screen
- Basic API connectivity:
  - app loads without “pending preflight” storms
  - calls page loads after login

