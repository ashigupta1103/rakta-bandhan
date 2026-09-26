# Publishing Rakta Bandhan — release checklist

For the team shipping v1.0 to the App Store and Google Play. Related documents:
- `store-listing.md`: listing copy and every policy-form answer.
- `cost-estimate.md`: the Blaze budget.

Legend: ✅ done in the repo · ⬜ someone must do it (needs an account, a decision, or a Mac).

## Blockers — the stores will reject, or the app is unsafe, without these

- ⬜ **Real phone verification.** Today any 6-digit code signs in, and every account shares one hardcoded password (`Backend.verifyFakeOtp`). Anyone who knows a phone number can take over that account.
  - Plan: Truecaller one-tap (Android), then a WhatsApp OTP, then an SMS OTP as the fallback. "Verify on WhatsApp" (the user sends the code; free) can be switched on if the budget gets tight.
  - Runs as **Cloud Functions** in the same Firebase project, which mint a Firebase custom token. No separate server.
  - Do **not** use Firebase Phone Auth SMS at this volume (≈ ₹9.9 lakh a year). See `cost-estimate.md`.
- ⬜ **Firebase for iOS.** `lib/firebase_options.dart` has no iOS config, so the app crashes on launch on iPhone.
  - Run `flutterfire configure --project=<id> --platforms=android,ios,web`.
  - This regenerates `firebase_options.dart` and adds `ios/Runner/GoogleService-Info.plist`.
  - Register the iOS app with bundle ID **`com.raktabandhan.app`**.
- ⬜ **Legal contact details.** Set `kLegalContactEmail` and `kGrievanceOfficerName` in `lib/legal/legal_config.dart`.
  - Have counsel review `lib/legal/legal_documents.dart`, then set `kLegalApproved = true`.
  - Re-run `python tool/export_legal_html.py`.
  - The App Store requires a working support URL and contact.
- ⬜ **Map tiles and geocoding keys.** Both providers are set in one file, `lib/services/geo_config.dart`.
  - **Tiles:** create a free MapTiler key and paste the URL shown there. CARTO's keyless tiles were checked on 26 Sep 2026 and now return "API KEY REQUIRED".
  - **Geocoding:** create a free LocationIQ key and set `kLocationIqKey`. The public OpenStreetMap servers are fine for development only.
- ⬜ **Rotary mark.** The full logo includes the Rotary International wheel, a registered trademark. Confirm the club's use in a public app follows Rotary's brand guidelines (Apple guideline 5.2.1). The app icon deliberately uses only the droplet-and-heart mark.

## Done in this branch

- ✅ App icons generated from the approved logo mark, not the Flutter default: iOS, Android (legacy + adaptive), and web. Script: `tool/make_app_icons.py`.
- ✅ iOS bundle ID `com.raktabandhan.app`, matching Android. Display name "Rakta Bandhan" on both.
- ✅ iOS privacy manifest `ios/Runner/PrivacyInfo.xcprivacy`, registered in the Xcode project.
- ✅ iOS permission purpose strings: location, camera, photos, microphone. Background modes are audio (live calls) and remote-notification. `ITSAppUsesNonExemptEncryption = false`.
- ✅ Android permissions trimmed to what's used. No restricted permissions: no SMS, call log, full-screen intent or background location.
- ✅ Android release signing reads `android/key.properties`, which is git-ignored.
- ✅ In-app account deletion and data export. Report and block in chat.
- ✅ Privacy policy, terms and delete-account pages, in the app and as static web pages (`admin/frontend/public/legal/`).
- ✅ Firestore rules and indexes for chat, calls, reports, read markers, the private ID-proof document and the bounded donor search.

## Step by step

### 1. Firebase (Blaze)
1. Upgrade to Blaze and **create a budget with alerts immediately** (Cloud Console › Billing › Budgets).
2. `firebase deploy --only firestore:rules,firestore:indexes`
   - The index builds take a few minutes.
   - Chat, calls and the Find map fail until they're done.
3. Enable **App Check**:
   - Play Integrity on Android.
   - App Attest / DeviceCheck on iOS.
   - reCAPTCHA Enterprise on web.
4. Authentication › Settings › **SMS region policy: allow India only**.
5. Build the admin dashboard, then deploy: `cd admin/frontend && npm run build && cd ../.. && firebase deploy --only hosting`
6. Open `/legal/privacy.html`, `/legal/terms.html` and `/legal/delete-account.html` on the hosted domain. These are the store URLs.

### 2. Server-side jobs (Cloud Functions, same project)
Everything else stays client-side under Firestore rules. The functions use the built-in Admin SDK, so there is no key file to manage; the functions' service account needs the **Service Account Token Creator** role to mint sign-in tokens. All of this fits in the free 2M invocations a month. The jobs to add, in priority order:
1. **OTP send/verify** → custom token (replaces the fake OTP).
2. **Push on new message**: a Firestore trigger on `requests/{id}/messages/{mid}` sends FCM to the other participant.
3. **Push on incoming call**: same pattern, for `requests/{id}/calls/{cid}`.
   - Android: an FCM high-priority data message, shown as a calling notification (a genuine calling use case).
   - iOS: PushKit VoIP → CallKit. Add the `voip` background mode **only** together with CallKit.
4. **Urgent-alert fan-out**: a new request where urgency ∈ {urgent, critical}.
   - Query nearby opted-in donors (`urgent_alerts == true`, geohash range) and FCM them.
   - Donors' tokens are already saved at `donors/{uid}.fcm_token`.
5. Optional: a scheduled expiry of stale requests, which replaces the lazy client-side expiry.

### 3. Android → Google Play
1. Create the upload key once:
   ```
   keytool -genkey -v -keystore ~/rakta-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties`:
   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/absolute/path/to/rakta-upload.jks
   ```
3. Bump `version:` in `pubspec.yaml` for each upload. The build number (`+N`) must increase every time.
4. Build: `flutter build appbundle --release`
5. Play Console:
   1. Create the app.
   2. Fill **Data safety**, **Health apps declaration**, **Content rating**, **Target audience (18+)** and **Ads: none**, using `store-listing.md`.
   3. Upload to **Internal testing** first.
   4. New personal developer accounts must run a closed test with at least 12 testers for 14 days before production access.

### 4. iOS → App Store (needs a Mac or Codemagic)
1. In the Apple Developer account, create the App ID `com.raktabandhan.app` with the Push Notifications capability.
2. Run `flutterfire configure`; see Blockers.
3. `flutter build ipa --release` (or via Codemagic), then upload with Transporter or Xcode.
4. In App Store Connect:
   1. Fill **App Privacy** from `store-listing.md`, which matches `PrivacyInfo.xcprivacy`.
   2. Set the age rating.
   3. Add the privacy URL and support URL.
   4. Paste the **review notes**.
5. Before submitting, ship through TestFlight with two devices and walk the whole flow: register → request → accept → chat → call → delete account.

### 5. Before every release
- `flutter analyze` and `flutter test` are clean.
- `python tool/export_legal_html.py` has been re-run, and the Hosting deploy includes the output.
- If data handling changed: update `legal_documents.dart`, `PrivacyInfo.xcprivacy`, and both store forms together.
