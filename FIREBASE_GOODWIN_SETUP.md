# Fix: FlutterFire "Failed to create Android app" (409)

## What’s going on

- **Error:** `Failed to create Android app for project goodwin-neyvo` with HTTP **409**.
- **Meaning:** An Android app with package `com.neyvo.pulse.neyvo_pulse_front` **already exists** in the Firebase project **goodwin-neyvo**. FlutterFire tries to create it again and the API returns “already exists”.

## What’s already done

- **Web** is already configured for **goodwin-neyvo** (project, app ID, API key, etc.).
- **Android / iOS / macOS / Windows** in `lib/firebase_options.dart` still point to **ub-neyvo** until you complete one of the options below.

---

## Option A – Let FlutterFire create the Android app (recommended if the existing app is unused)

If the existing Android app in **goodwin-neyvo** was created by mistake or isn’t used yet:

1. Open [Firebase Console](https://console.firebase.google.com/) → project **goodwin-neyvo**.
2. Go to **Project settings** (gear) → **Your apps**.
3. Find the **Android** app with package name `com.neyvo.pulse.neyvo_pulse_front`.
4. Remove that app (e.g. “Remove app” or delete).
5. In your project folder run:
   ```bash
   flutterfire configure --project=goodwin-neyvo --yes
   ```
   FlutterFire will create the Android app (and others if needed) and update `lib/firebase_options.dart` and `android/app/google-services.json` for **goodwin-neyvo**.

---

## Option B – Keep the existing Android app and use its config

If you want to **keep** the existing Android app in **goodwin-neyvo**:

1. Open [Firebase Console](https://console.firebase.google.com/) → project **goodwin-neyvo**.
2. Go to **Project settings** (gear) → **Your apps**.
3. Open the **Android** app with package `com.neyvo.pulse.neyvo_pulse_front`.
4. Download **google-services.json** and **replace** the file at:
   ```
   GU_Neyvo_Front/android/app/google-services.json
   ```
5. Then update `lib/firebase_options.dart`: in the `android` section, set:
   - `projectId` → `goodwin-neyvo`
   - `apiKey` → from the new `google-services.json` (under `client[0].api_key[0].current_key`)
   - `appId` → from the new file (`client[0].client_info.mobilesdk_app_id`)
   - `messagingSenderId` → from the new file (`project_info.project_number`)
   - `storageBucket` → `goodwin-neyvo.firebasestorage.app`

After that, Android will use **goodwin-neyvo** and you won’t get the 409 from FlutterFire because you’re no longer asking it to create that app.

---

## Summary

| Platform  | Current project   | Action |
|----------|-------------------|--------|
| Web      | goodwin-neyvo     | Done   |
| Android  | ub-neyvo          | Use Option A or B above |
| iOS / macOS / Windows | ub-neyvo | After fixing Android, run `flutterfire configure --project=goodwin-neyvo --yes` again to add these for goodwin-neyvo, or add them in Firebase Console and update `firebase_options.dart` manually. |

The underlying issue is: **the Android app already exists in goodwin-neyvo**, so “create” fails with 409. Either remove it and let FlutterFire create it (Option A), or keep it and use its config (Option B).
