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

## Step 4: Deploy web to goodwin-neyvo (Firebase Hosting)

```bash
cd GU_Neyvo_Front
flutter build web
firebase deploy --only hosting
```

If you use **Firebase App Check** for the web app, enable and configure it in the Console (**App Check** → your Web app). The Flutter app no longer ships a separate reCAPTCHA widget or build-time key injection.

## Step 5: Verify

- Open https://goodwin-neyvo.web.app and confirm the **Goodwin** theme (not UB) and that sign-in works without App Check 403.

## Troubleshooting

- **App Check 403 / throttled**  
  Confirm App Check settings in Firebase Console for the web app and allowed domains. After repeated 403s, Firebase may throttle for ~24 hours; temporarily set App Check to **Monitoring** in the Console while debugging, then re-enforce enforcement.

- **Android 409 / “already exists”**  
  The Android app is already registered in goodwin-neyvo; use the **download** link for that app to get `google-services.json`. You don’t need to create it again.

- **Same package in another project**  
  If Firebase says the package/bundle ID is already used in another project (e.g. ub-neyvo), you can either remove the app from the other project in Console or use this setup only for goodwin-neyvo and keep ub-neyvo for other environments.
