# Connect All Apps to Firebase Project **goodwin-neyvo**

The FlutterFire CLI fails to **create** the Android app in goodwin-neyvo because an app with that package name already exists (Firebase returns 409). You need to get the config files from the Firebase Console and then run the generator script.

## Step 1: Get Android config from Firebase Console

1. Open: **https://console.firebase.google.com/project/goodwin-neyvo/settings/general**
2. Under **"Your apps"**, find the **Android** app (package: `com.neyvo.pulse.neyvo_pulse_front`).
   - If you don’t see an Android app, click **"Add app"** → Android → enter package name `com.neyvo.pulse.neyvo_pulse_front` → register the app.
3. Download **google-services.json** (click the download icon for the Android app).
4. Replace the existing file in your project:
   - Save it as: `GU_Neyvo_Front/android/app/google-services.json`

## Step 2: Get iOS (and macOS) config from Firebase Console

1. In the same **goodwin-neyvo** project settings page, under **"Your apps"**:
   - If there is no **iOS** app, click **"Add app"** → iOS → enter bundle ID: `com.neyvo.pulse.neyvoPulseFront` → register and download **GoogleService-Info.plist**.
   - If an iOS app already exists, open it and download **GoogleService-Info.plist**.
2. Save the file as: `GU_Neyvo_Front/ios/Runner/GoogleService-Info.plist`

## Step 3: Generate `firebase_options.dart`

From the project root (`GU_Neyvo_Front`), run:

```bash
node scripts/generate_firebase_options.js
```

This reads `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` (if present) and writes `lib/firebase_options.dart` so **all platforms use goodwin-neyvo**.

## Step 4: Deploy web to goodwin-neyvo (Firebase Hosting + App Check)

To avoid App Check 403 on goodwin-neyvo.web.app, use the **same** reCAPTCHA v3 site key in the app as in Firebase App Check:

1. In Firebase Console: **goodwin-neyvo** → **App Check** → select your **Web** app → reCAPTCHA v3 provider. Note the **reCAPTCHA v3 site key** (or register one and add `goodwin-neyvo.web.app` to the reCAPTCHA admin allowed domains).
2. Build and inject the key, then deploy:

```bash
cd GU_Neyvo_Front
set RECAPTCHA_V3_SITE_KEY=your_site_key_here
flutter build web --dart-define=RECAPTCHA_V3_SITE_KEY=your_site_key_here
node scripts/inject_recaptcha_key.js
firebase deploy --only hosting
```

On macOS/Linux use `export RECAPTCHA_V3_SITE_KEY=your_site_key_here` instead of `set`. The inject script updates `build/web/index.html` so the reCAPTCHA script tag uses the same key as the Dart build.

## Step 5: Verify

- Open https://goodwin-neyvo.web.app and confirm the **Goodwin** theme (not UB) and that sign-in works without App Check 403.

## Troubleshooting

- **App Check 403 / throttled**  
  Use the same reCAPTCHA v3 site key in Firebase App Check (goodwin-neyvo) and in the build (Step 4). After a 403, Firebase may throttle for ~24 hours; fix the key and redeploy, or temporarily set App Check to Monitoring in the Console.

- **Android 409 / “already exists”**  
  The Android app is already registered in goodwin-neyvo; use the **download** link for that app to get `google-services.json`. You don’t need to create it again.

- **Same package in another project**  
  If Firebase says the package/bundle ID is already used in another project (e.g. ub-neyvo), you can either remove the app from the other project in Console or use this setup only for goodwin-neyvo and keep ub-neyvo for other environments.
