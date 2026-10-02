# Publishing Rakta Bandhan — release checklist

For the team shipping v1.0 to the App Store and Google Play. Related documents:
- `store-listing.md`: listing copy and every policy-form answer.
- `cost-estimate.md`: the Blaze budget.
- [Current build and owner choices](../launch/BUILD_STATUS.md), [external connections](../launch/EXTERNAL_CONNECTIONS.md) and [owner deploy runbook](../launch/DEPLOY_RUNBOOK.md). Real email sign-in needs the owner to upgrade to Blaze and verify a sending domain; the app has no demo mode.

Legend: ✅ done in the repo · ⬜ someone must do it (needs an account, a decision, or a Mac).

## Blockers — the stores will reject, or the app is unsafe, without these

- ⬜ **Legal contact details.** Set `kLegalContactEmail` and `kGrievanceOfficerName` in `lib/legal/legal_config.dart`.
  - Have counsel review `lib/legal/legal_documents.dart`, then set `kLegalApproved = true` (removes the "draft" banner).
  - Re-run `python tool/export_legal_html.py`, then redeploy Hosting.
  - The App Store requires a working support URL and contact.
- ⬜ **Delete the old test accounts.** Accounts made with the old any-code test login (`p+91…@phone.raktabandhan.local`) share one password. Delete them in Firebase console › Authentication before launch; they can't create anything any more (rules require a verified email) but can still read.
- ⬜ **Team copy approval.** The About page bios for CSK and Adarsh Betala are role descriptions written from the roles given — have each person approve their paragraph, and send photographs if wanted.
- ⬜ **Firebase for iOS** (App Store phase). `lib/firebase_options.dart` has no iOS config yet.
  - Run `flutterfire configure --project=rakta-bandhan2026 --platforms=android,ios,web`, registering bundle ID **`com.raktabandhan.app`**.
  - Upload an APNs key in Firebase › Project settings › Cloud Messaging, so iOS gets push.
- ⬜ **Rotary mark.** The full logo includes the Rotary International wheel, a registered trademark. Confirm the club's use in a public app follows Rotary's brand guidelines (Apple guideline 5.2.1). The app icon deliberately uses only the droplet-and-heart mark.

## Done in this branch

- ✅ **Real sign-in.** Passwordless: a 6-digit code is emailed to the user and exchanged for a Firebase sign-in token (needs the Blaze functions and an email provider — see `docs/launch/AFTER_BLAZE_UPGRADE.md`). Account deletion needs no password. The old any-code test login is gone. Firestore and Storage rules only let **verified** accounts create anything.
- ✅ **Push notifications** (Cloud Functions in `functions/`): chat messages, missed calls, request accepted / released / cancelled / expired, two-sided donation confirmation prompts, nearby compatible donors on every new request (urgent alerts on a loud channel), and admin broadcasts to FCM topics.
- ✅ **Ringing calls when the app is closed** (Android): a high-priority data push opens the native incoming-call screen with ringtone (flutter_callkit_incoming). Answer goes straight into the call; Decline tells the caller at once. iOS gets a time-sensitive "Incoming call" alert until PushKit + CallKit are added.
- ✅ **Two-sided completion.** Donor taps "I donated" → their 90-day rest starts and history + certificate are written; the request becomes *completed* only when the requester also confirms (or an admin does). Enforced in the rules.
- ✅ **Cooldown.** Availability switches off for 90 days after a donation and can't be switched back on early — locked in the app and in the rules. It turns itself back on afterwards.
- ✅ **Certificates** open from Donation history; Save (photo gallery) and Share (WhatsApp, Instagram…).
- ✅ **Community photo posts** with an Instagram-style card and full-screen viewer; report / hide author / delete own post; photos on Cloudflare R2 through the Worker, compressed on the phone, deleted with the post; the existing editor also saves real post edits.
- ✅ **Area names, never coordinates**: neighbourhood ("Adyar, Chennai") on donor cards and posts; donors can re-pin their area.
- ✅ **Maps**: native Google Maps on phones once the key is added (free, unlimited mobile map loads); flutter_map stays as the fallback.
- ✅ **Admin**: verification checklist (5 steps) before Verify unlocks; real broadcasts; member testimonial submissions with an approval queue; reported posts in the inbox.
- ✅ **About** (mission, vision, story, team, belief), **community guidelines**, updated privacy policy and terms; public share page with a social preview card (`/app/`).
- ✅ **Cost**: the open-requests feeds read only nearby requests (geohash cells), not every open request in India.
- ✅ Play hygiene: Advertising ID permission removed, full-screen intent removed, camera foreground-service type removed.
- ✅ App icons, bundle IDs, iOS privacy manifest and purpose strings, Android release signing via `android/key.properties`, in-app account deletion and data export.

## Tests (all passing on this branch)

| Suite | Command | Result |
|---|---|---|
| Flutter analyzer | `flutter analyze` | no issues |
| Flutter tests | `flutter test` | all pass (see [verification](../launch/VERIFICATION.md)) |
| Security rules (Firestore + Storage, emulator) | `cd backend/rules-test && npm install && npm test` (needs Java 21) | 73 / 73 |
| Functions unit tests | `cd functions && npm test` | 27 / 27 |
| Functions smoke test (emulator) | `cd functions && FUNCTIONS_DISCOVERY_TIMEOUT=120 npm run smoke` | login, review seed, lifecycle/jobs, support and 410-record migration checks pass |
| Android build | `flutter build apk --release --dart-define=EDGE_URL=<worker url>` | APK builds; real-device acceptance is owner-run |
| Admin console | `cd admin/frontend && npm run build` | builds, type-checks |

Not testable here: real push delivery, real calls between two phones, and the Google map (need the live project, two devices and the Maps key) — see the two-phone checklist in step 3.

## Step by step

### 1. Firebase (Blaze)
1. **Billing account in the club's name**, linked to the project; upgrade to Blaze.
   - Budget: **₹3,000/month**, alerts at 50% / 90% / 100% (Cloud Console › Billing › Budgets & alerts). Blaze has no hard cap; the alerts are the guardrail.
   - The payment method can be changed any time (Billing › Payment method), and the project can be moved to a different billing account (Billing › Account management › Change billing) — no downtime.
2. **Authentication** › Sign-in method › enable **Email/Password**. Only the two admin consoles use it; users sign in with an emailed code, which needs the `SMTP_URL` secret (see `docs/launch/AFTER_BLAZE_UPGRADE.md`).
3. **Photos and call relay**: provision Cloudflare R2/TURN and deploy the Worker following `docs/launch/SPARK_NOW.md`. New app photos do not use Firebase Storage.
4. Check `REGION` in `functions/src/app.ts` equals the Firestore location (Firestore › the location shown at the top). Change it if needed.
5. Deploy everything:
   ```
   cd admin/frontend && npm run build && cd ../..
   python tool/export_legal_html.py && python tool/make_share_page.py
   firebase deploy --project rakta-bandhan2026 --only firestore:rules,firestore:indexes,functions,hosting
   ```
   - Accept the Artifact Registry cleanup policy when asked.
   - Index builds take a few minutes; the Find map and feeds fail until they show "Enabled".
6. Open `/legal/privacy.html`, `/legal/terms.html`, `/legal/community-guidelines.html`, `/legal/delete-account.html` and `/app/` on `rakta-bandhan2026.web.app` — these are the store URLs.

### 2. Google Maps key (recommended before launch)
1. Google Cloud console (same project) › APIs › enable **Maps SDK for Android** (and **for iOS** later).
2. Credentials › Create API key › restrict to *Android apps* with package `com.raktabandhan.app` + your upload and Play signing SHA-1s, and to the Maps SDK only.
3. Put `MAPS_API_KEY=…` in `android/local.properties` (git-ignored).
4. Build with `--dart-define=GOOGLE_MAPS=true`. Without the flag the app uses OpenStreetMap tiles (fine for testing, not for production load).
5. For address search, build with `--dart-define=LOCATIONIQ_KEY=<owner-key>` (`kLocationIqKey` reads this define).

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
4. Build: `flutter build appbundle --release --dart-define=GOOGLE_MAPS=true`
   - On the build machine, install **Android SDK Command-line Tools** (Android Studio › SDK Manager › SDK Tools) and run `flutter doctor --android-licenses`. Without them the bundle still builds but keeps native debug symbols (≈ 88 MB instead of ≈ 35 MB).
5. Play Console:
   1. Create the app.
   2. Fill **Data safety**, **Health apps declaration**, **Content rating**, **Target audience (18+)** and **Ads: none**, using `store-listing.md`.
   3. Upload to **Internal testing** first.
   4. New personal developer accounts must run a closed test with at least 12 testers for 14 days before production access.
   5. App content › **Foreground service** declaration: *Phone call* (see `store-listing.md`).
   6. App content › **App access**: choose "All or some functionality is restricted" and paste the sign-in instructions from the App Review notes in `store-listing.md` (the two review emails and the review code). Reviewers can't read an email, which is why those two addresses use a fixed code.
6. **Two-phone checklist** on the internal-testing build (one phone signed in as a requester, one as a donor):
   - [ ] Sign in with an email address → the 6-digit code arrives by email → entering it opens the app (a new account continues to registration).
   - [ ] A wrong code is refused, and a resent code arrives after the 30-second wait.
   - [ ] Donor registers (mobile number, area by GPS and by "Pin on map").
   - [ ] Requester raises an urgent request → donor's phone gets a notification **with the app closed** (and the loud urgent alert if urgent alerts are on).
   - [ ] Donor accepts → requester gets "A donor accepted your request".
   - [ ] Chat both ways; with the app closed, a message arrives as a notification and tapping it opens the chat.
   - [ ] Call with the receiving app **closed and the screen locked** → it rings; Answer connects audio both ways; Decline stops the caller ringing at once; no answer → "Missed call" notification.
   - [ ] Donor taps "Mark as donated" → requester is asked to confirm → after both confirm, the request shows *Completed*, the donor's availability switch is locked off for 90 days, and the certificate opens from Donation history (Save and Share both work).
   - [ ] Community: post with a photo, open it full-screen, report it from the other phone, see it in the admin inbox, delete it.
   - [ ] Admin: verification checklist → Verify; broadcast to "All donors" arrives on both phones.
   - [ ] Settings › Delete my account asks to confirm, then removes the account (the sign-in account too).

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
