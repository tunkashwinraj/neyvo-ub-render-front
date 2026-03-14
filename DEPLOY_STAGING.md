# Frontend testing (staging) environment

This project supports a **staging** frontend that talks to your **testing backend** (e.g. Render service on the Testing branch), while production keeps using the main backend.

---

## Team: Deploy to staging only (step-by-step)

Use this when you want to deploy to **staging** (ub-neyvo-staging.web.app) and **not** to production (ub.neyvo.ai / ub-neyvo.web.app).

### 1. Get latest config (required)

```bash
cd "C:\Ashwin Project\UB Neyvo\UB_Neyvo_Front"
git pull
```

Your repo **must** have:

- **firebase.json** with a `"target": "staging"` entry in the `hosting` array.
- **.firebaserc** with `"staging": "ub-neyvo-staging"` under `targets.ub-neyvo.hosting`.

If you see `Error: Hosting site or target staging not detected in firebase.json`, your copy is missing this. Pull the latest from the repo (or copy `firebase.json` and `.firebaserc` from a teammate who has it).

### 2. Select Firebase project and link staging (one-time per machine)

```bash
firebase use ub-neyvo
firebase target:apply hosting staging ub-neyvo-staging
```

You should see: `Applied hosting target staging to ub-neyvo-staging`.

### 3. Build for staging (with testing backend URL)

```bash
flutter clean
flutter pub get
flutter build web --dart-define=SPEARIA_BASE_URL_STAGING=https://ub-neyvo-back-testing.onrender.com
```

### 4. Deploy only to staging

```bash
firebase deploy --only hosting:staging
```

- **Correct:** Deploy completes and shows `Hosting URL: https://ub-neyvo-staging.web.app`.
- **Wrong:** If you run `firebase deploy --only hosting` (no target) or `firebase deploy --only hosting:default`, you will deploy to **production**. Always use `hosting:staging` for staging.

### 5. Deploy Goodwin staging (optional)

Same build works for both. After step 4:

```bash
firebase deploy --only hosting:goodwin-staging
```

---

## How it works

- **Production**: Firebase default site (e.g. `ub-neyvo.web.app`) → backend from `SPEARIA_BASE_URL` (prod Render or main branch).
- **Staging**: Firebase staging site (e.g. `ub-neyvo-staging.web.app`) → backend from **hostname detection**: when the app runs on a URL that contains `staging`, it uses the staging backend URL (same as prod by default, or set via `SPEARIA_BASE_URL_STAGING`).

So you can deploy the **same build** to both sites; the app chooses the backend at runtime based on the hostname.

## 1. Create the staging site in Firebase (one-time)

1. Open [Firebase Console](https://console.firebase.google.com) → your project **ub-neyvo**.
2. Go to **Hosting**.
3. If you only have one site, click **Add another site** (or the three-dots menu → **Add new site**).
4. Choose a site ID, e.g. **ub-neyvo-staging**. Firebase will give you a URL like `ub-neyvo-staging.web.app`.
5. Note the **exact site ID** (e.g. `ub-neyvo-staging`). You’ll use it in step 3 below.

## 2. Point staging to your testing backend (optional)

If your **testing backend** is a different URL (e.g. a second Render service for the Testing branch):

- Build with:
  ```bash
  flutter build web --dart-define=SPEARIA_BASE_URL_STAGING=https://YOUR-STAGING-BACKEND.onrender.com
  ```
- If you use the **same** Render service for both (you just switch the branch between main and Testing), you can skip this: staging will use the same URL as prod, and you control “prod vs test” by which branch is deployed on Render.

## 3. Wire the staging site in this repo (one-time)

Edit **`.firebaserc`** and set the staging site ID to the one you created:

```json
"targets": {
  "ub-neyvo": {
    "hosting": {
      "default": "ub-neyvo",
      "staging": "ub-neyvo-staging"
    }
  }
}
```

Replace `ub-neyvo-staging` with your actual staging site ID if different.

## 4. Deploy to staging

From the frontend repo:

```bash
# Build (optionally with staging backend URL; see step 2)
flutter build web

# Deploy only to the staging site
firebase deploy --only hosting:staging
```

Your staging app will be at the staging URL (e.g. `https://ub-neyvo-staging.web.app`). It will automatically use the staging backend when opened from that hostname.

## 5. Deploy to production

```bash
flutter build web
firebase deploy --only hosting:default
```

(Or `firebase deploy --only hosting` to deploy both default and staging.)

## Summary: connection to backend

| Frontend URL              | Backend used                          |
|---------------------------|----------------------------------------|
| `ub-neyvo.web.app` (prod) | `SPEARIA_BASE_URL` (prod Render)       |
| `ub-neyvo-staging.web.app` | `SPEARIA_BASE_URL_STAGING` or same as prod |

- **Render on Testing branch**: Use that same Render URL for staging (default behavior), and deploy the frontend to the Firebase staging site. Staging frontend + Testing backend = full testing environment.
- **Two Render services** (prod + staging): Set `SPEARIA_BASE_URL_STAGING` when building for staging so the staging site talks to the staging Render service.
