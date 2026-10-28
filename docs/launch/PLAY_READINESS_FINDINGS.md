# Google Play readiness: findings (2026-10-10)

Audit of the repo at `feat/prelaunch` against Google Play policy, using the `playstore-review`, `android-playstore-scan` and `mobile-platform-operations` checklists as reference. Code checks were done by reading the manifest, Gradle files and the merged release manifest.

## A. Stops you: only you can unblock these

| # | Blocker | Why it stops the launch | What you do |
|---|---|---|---|
| 1 | **No Play developer account** | Nothing can be uploaded | Get a D-U-N-S number for the trust (1 to 4 weeks), then open the organisation account ($25). Organisation accounts skip the 12-testers-for-14-days rule |
| 2 | **No upload keystore (`android/key.properties` is missing)** | The build is debug-signed; Play rejects it | Run the `keytool` command in `docs/publishing/README.md` step 3.1, create `android/key.properties`. **Back the `.jks` file and both passwords up outside this PC.** Never commit them |
| 3 | **`kLegalContactEmail` and `kGrievanceOfficerName` are empty** (`lib/legal/legal_config.dart`) | Play and the DPDP Act need a working privacy contact; the live privacy page has none | Tell me the email and the Grievance Officer's name; I set them and regenerate the pages |
| 4 | **Legal pages show a "Draft awaiting legal review" banner** (`kLegalApproved = false`) | A reviewer opening the privacy URL sees a draft policy | Have counsel review `lib/legal/legal_documents.dart`, then tell me to flip `kLegalApproved` |
| 5 | **Review accounts do not exist** | Play's "App access" needs a working login | Create two accounts in the build you upload (requester, and an available, admin-verified O+ donor near the requester). Send me the emails and passwords to paste into the form, or paste them yourself. Use throw-away passwords |
| 6 | **Hosting must be redeployed after any legal change** | The privacy URL must show the final text | After #3 and #4: `python tool/export_legal_html.py`, `cd admin/frontend && npm run build`, `firebase deploy --project rakta-bandhan2026 --only hosting`. The pages are live today (HTTP 200) |
| 7 | **Blaze not upgraded** | Push, ringing calls and urgent alerts do not work. Reviewers and testers will see a half-working core | Upgrade with a budget alert, deploy functions. Until then ship **Internal testing only** |
| 8 | **Screenshots with fictional data** | The current ones show a real hospital and "Priya (test)" | Needs a seeded demo account and a phone or emulator. I prepare the shot list; you (or we together) capture them |
| 9 | **Foreground-service declaration needs a screen recording** | Play requires a video of the phone-call feature | Record an incoming call on a real phone once the functions are live |
| 10 | **Real-device test never done** | Push, calls, photos and the map are untested outside emulators | Run the two-phone checklist (`docs/publishing/README.md` step 3.6) on the internal-testing build |
| 11 | **Rotary wheel in the full logo** | Trademark (also Apple 5.2.1) | Get written OK from the club; the app icon already uses only the droplet-and-heart mark |
| 12 | **Team bios** | The About page bios were written from roles | Each person approves their paragraph |
| 13 | **Google Maps key and LocationIQ key** | Without them the app falls back to OpenStreetMap tiles (fine for testing, not for production load) | Create restricted keys (`docs/publishing/README.md` step 2) |

Already done by you (per `docs/launch/BUILD_STATUS.md`): the old Firebase Auth test accounts are removed and the Worker is deployed.

## B. Checked in the repo: passing

- **Target API 36**, min 24 (Flutter 3.x defaults). Meets Play's current target requirement.
- **Application ID** `com.raktabandhan.app`, version `1.0.0+1`. Good for a first upload; raise `+N` for every later upload.
- **Release shrinking**: an R8 `mapping` folder exists in `build/app/outputs`, so code shrinking is on in release.
- **Restricted permissions**: no SMS, call log, background location, `QUERY_ALL_PACKAGES`, all-files access or accessibility. `USE_FULL_SCREEN_INTENT`, camera foreground-service type and Advertising ID permissions are removed and absent from the merged manifest.
- **Account deletion**: in the app (Settings › Delete my account) and on `https://rakta-bandhan2026.web.app/legal/delete-account.html`. Both return HTTP 200.
- **Privacy policy**: linked in the app (login, consent, settings, about) and live at the URL above.
- **User-generated content**: report, block and hide exist for chat and community posts; admins review reports.
- **Analytics**: Firebase Analytics only; ad-ID collection off. No crash-reporting SDK, so no crash-log row is needed in Data safety.
- `flutter analyze`: no issues. `flutter test`: 97 passed.

## C. Fixed in this pass

- **Removed geolocator's unused location foreground service** from the manifest (`tools:node="remove"`). The merged manifest declared a `location` service type; without it, the only foreground-service declaration is **Phone call**.
- **Review instructions now match the build.** `store-listing.md` had only the emailed-code review instructions; it now has a Play "App access" block for the free-plan email + password build, and the Apple notes name the two labelled simulations. `docs/publishing/README.md` (App access step and the two-phone checklist) is mode-aware.

## D. Remaining risks to know about

- **Permissions merged from plugins** you will be asked about in Play Console: `FOREGROUND_SERVICE_PHONE_CALL`, `FOREGROUND_SERVICE_MICROPHONE` (declared as the calling feature), `MANAGE_OWN_CALLS`, `DISABLE_KEYGUARD`, `TURN_SCREEN_ON`, `ACCESS_NOTIFICATION_POLICY` (all from `flutter_callkit_incoming`), `RECORD_AUDIO`, `BLUETOOTH_CONNECT`. Without `USE_FULL_SCREEN_INTENT` the incoming call shows as a heads-up notification, not a full-screen takeover. This is intentional (store policy) but is a behaviour difference from iOS-style calling.
- **Health apps declaration** is required (category: blood and organ donation). Answers are in `store-listing.md`.
- **Simulated email and phone checks** in the free-plan build. The review text says so. Do not describe the phone check as "verified" anywhere in the listing.
- **Chennai Capital Trust as a legal entity** in `legal_config.dart`: leave as is unless counsel says otherwise.
- **Store-listing text** says "Donors are verified by the Rakta Bandhan team." That is true only if the admin actually verifies donors; keep that practice, or soften the sentence.
- **Short description** is 76 characters (limit 80).
