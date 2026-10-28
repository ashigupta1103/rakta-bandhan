# Store launch TODO: Google Play first, then the App Store

**Give this file to a new session with:**
> Read `docs/launch/STORE_LAUNCH_TODO.md`. Use the skills in `.claude/skills/` as it says. Work top to bottom. Stop at every **CONFIRM** and wait for me.

Tags: **[Claude]** the session does it in this repo. **[You]** needs your account, device, money or a decision. **[Both]** Claude prepares, you click. **CONFIRM** = never do it without asking first (a credential, an external account, spending money, publishing, or anything that cannot be undone).

## 0. What is blocked on you right now

Full table with reasons: [`PLAY_READINESS_FINDINGS.md`](PLAY_READINESS_FINDINGS.md) section A. In the order that gates the launch:

1. **D-U-N-S number, then the Play organisation account.** Nothing can be uploaded without it.
2. **Create the upload keystore and `android/key.properties`**, and back them up. Today the AAB is debug-signed and Play will reject it.
3. **Give me the privacy contact email and the Grievance Officer's name** (`lib/legal/legal_config.dart` is empty), then **have counsel approve the legal text** so the "Draft" banner can be removed.
4. **Create the two review accounts** (requester, and an admin-verified donor) in the build you upload.
5. **Install Android SDK Command-line Tools** (Android Studio › SDK Manager › SDK Tools) and run `flutter doctor --android-licenses`. Without them the AAB is 86.7 MB instead of about 35 MB because native debug symbols are not stripped.
6. **Upgrade to Blaze** and deploy the functions, or ship Internal testing only: push, ringing calls and urgent alerts do not work without them.
7. Real phones: the two-phone test, the incoming-call screen recording Play asks for, and fictional-data screenshots.

## 1. Facts

| | |
|---|---|
| App | Rakta Bandhan (Flutter). Package / bundle ID `com.raktabandhan.app` |
| Version | `1.0.0+1` in `pubspec.yaml`. The `+N` must rise on every upload |
| Firebase project | `rakta-bandhan-india` (Spark today; Blaze pending). The owner runs Firebase deploys |
| Live Worker | `https://rakta-bandhan-edge.raktabandhan.workers.dev` |
| Release signing | `android/key.properties` (git-ignored) with an upload keystore. If it is missing, the build falls back to debug signing and Play will reject it |
| Build | `flutter build appbundle --release --dart-define=GOOGLE_MAPS=true` (add `--dart-define=EMAIL_CODE_LIVE=true` only after Blaze + email sender) |
| Test APK | `build/RaktaBandhan.apk` (built with `SHOW_ERRORS=true`; never upload that build to a store) |
| Existing docs | `docs/publishing/README.md` (checklist), `docs/publishing/store-listing.md` (every form answer), `docs/publishing/cost-estimate.md`, `docs/launch/*`, `docs/RAKTA_BANDHAN_COMPLETE_GUIDE.md` |
| Git | Local branch `feat/prelaunch`; remotes `origin` (owner) and `fork` (Yash13606). Do not commit or push unless asked |

## 2. Installed skills (project folder `.claude/skills/`, git-ignored)

| Skill | Use it for | Careful |
|---|---|---|
| `playstore-review` | Check the repo against Google Play's Developer Program Policies before submitting. Supports Flutter | Read-only analysis; run first |
| `android-playstore-scan` | Scan the project, produce a Play Console setup checklist | Analysis only |
| `mobile-platform-operations` | Play and App Store review readiness, signing, staged release, rollback. Includes the Play review checklist at `references/google-play-store-review/review-checklist.md` | Reference |
| `app-store-optimization-alirezarezvani`, `app-store-optimization-davila7` | Title, short and long description, keywords, A/B test ideas | Two overlapping ASO skills; use the first, consult the second if needed |
| `app-store-screenshots` | Screenshot sizes, order, device frames, preview video | Its `allowed-tools` is `Bash(belt *)`, a command-line tool I have not vetted. Do not install `belt` without asking |
| `android-playstore-setup` | Play Console setup flow: privacy policy, versioning, Fastlane, workflows | **Written for native Kotlin/Gradle.** Do NOT run its generators over this Flutter project's Gradle setup or signing. Use it as a checklist. It also contains `git push origin main` steps: never run those |
| `android-playstore-publishing` | Generates 4 GitHub Actions workflows for Play deployment | Same warning. Needs GitHub secrets (Play service-account JSON, keystore). **CONFIRM** before creating any workflow or secret |
| `app-store-deployment` | iOS App Store and Google Play deployment with signing and CI | Use for the Apple phase; it has an `xcodebuild -license accept` step: **CONFIRM** |

Not installed, with reasons: `expo-deployment` does not exist in `expo/skills` (this is not an Expo app anyway); `google-play-store-review` is a reference inside `mobile-platform-operations`, not a standalone skill; the LobeHub copy of `android-playstore-publishing` needs a LobeHub account, so the GitHub copy was installed instead. `app-store-deployment` (via `skillfish`) also left copies in `~/.claude`, `~/.cursor`, `~/.codex`, `~/.gemini` and other agents' global folders; harmless, remove them if you want.

## 3. Phase 0: accounts and decisions (you, start today, in parallel with everything)

- [ ] **[You]** Get a free **D-U-N-S number** for the club or trust (1 to 4 weeks). Organisation accounts need it.
- [ ] **[You]** **Google Play organisation account**, $25 once. Organisation accounts skip the "12 testers for 14 days" rule that personal accounts must pass.
- [ ] **[You]** **Apple Developer organisation account**, $99 a year; apply for the nonprofit fee waiver.
- [ ] **[You]** Decide the launch route. **Recommended:** internal-testing build on today's free-plan app; production only after Blaze, because push (urgent alerts, calls, chat) is the product's core and does not work until the functions are deployed.
- [ ] **[You]** Blaze in the club's name with a budget alert; a sending domain for the emailed code; legal contact name and email. Costs: `docs/publishing/cost-estimate.md`.
- [ ] **[You]** Rotary mark: confirm the club may show the Rotary wheel in a public app (Apple guideline 5.2.1). Team bios: each person approves their paragraph.

## 4. Phase 1: make the app store-ready (Claude, in this repo)

- [x] **[Claude]** Findings list written: [`PLAY_READINESS_FINDINGS.md`](PLAY_READINESS_FINDINGS.md). `flutter analyze` clean, 97 tests pass, target API 36, no restricted permissions.
- [x] **[Claude]** Version `1.0.0+1` is right for a first upload. R8 is on. `flutter build appbundle --release --dart-define=GOOGLE_MAPS=true` builds (86.7 MB, debug-signed because `key.properties` is missing; see section 0 items 2 and 5). Removed geolocator's unused location foreground service from the manifest.
- [x] **[Claude]** `store-listing.md` and `docs/publishing/README.md` now cover the free-plan email + password build (Play "App access" block added). Fill the `<REVIEW_*>` placeholders once the accounts exist.
- [x] **[Claude]** Listing text checked: the short description is 76 characters (limit 80), the long description and keywords are in `store-listing.md`, no invented stats or partners. Optional: ask the ASO skills for A/B variants after the first release.
- [ ] **[Both]** Assets: 512×512 icon, 1024×500 feature graphic, phone screenshots. Re-shoot screenshots with fictional demo data; the current ones show a real hospital name and "Priya (test)". Use `app-store-screenshots`.
- [ ] **[Claude]** Fix code-level blockers found by the review. `lib/legal/legal_config.dart` still names Chennai Capital Trust as a legal entity; changing it needs counsel (**CONFIRM**).
- [ ] **[Claude]** `flutter analyze` and `flutter test` clean before every build.

## 5. Phase 2: backend go-live (you run the commands; Claude prepares them)

- [ ] **[You]** Upgrade to Blaze. Then deploy: `cd admin/frontend && npm run build && cd ../.. && python tool/export_legal_html.py && python tool/make_share_page.py && firebase deploy --project rakta-bandhan-india --only firestore:rules,firestore:indexes,functions,hosting`. Wait until every index shows Enabled. **CONFIRM** (spends money, changes the live project).
- [x] **[You]** Old test accounts in Firebase Authentication: already removed per `BUILD_STATUS.md` (2026-10-02). Recheck the console before launch.
- [ ] **[Claude]** Check the four legal URLs and `/app/` on `rakta-bandhan-india.web.app` load; these are the store links.
- [ ] **[You]** Google Maps key restricted to the package and the Maps SDK; LocationIQ key.

## 6. Phase 3: Google Play Console

- [ ] **[Both]** Create the app. Fill Data safety, health-apps declaration, content rating, target audience 18+, ads none, foreground-service declaration (phone call), App access. Every answer is in `docs/publishing/store-listing.md`.
- [ ] **[Both]** Upload the AAB to **Internal testing**. **CONFIRM** before any upload.
- [ ] **[You]** Run the two-phone checklist in `docs/publishing/README.md` (step 3.6). It is the only way to test push, ringing calls and the map.
- [ ] **[You]** If the account is personal: closed test with 12 testers for 14 days. Then **Production** with a staged rollout. **CONFIRM** before production.

## 7. Phase 4: Apple App Store (after Play is live)

- [ ] **[You]** A Mac or Codemagic. **[Both]** `flutterfire configure --project=rakta-bandhan-india --platforms=android,ios,web` for bundle ID `com.raktabandhan.app`; upload an APNs key; `flutter build ipa --release`; TestFlight with two devices.
- [ ] **[Both]** App Store Connect: App Privacy (matches `ios/Runner/PrivacyInfo.xcprivacy`), age rating, privacy and support URLs, review notes. The review notes must say the email and phone checks are labelled simulations until real providers exist.

## 8. After launch

- [ ] Watch Billing twice a week for the first month; staged-rollout percentage; crash and ANR vitals; reply to reviews.
- [ ] Turn on the email and phone verification switches (admin site, Settings) only when real providers exist; turning them on early locks everyone out.

## 9. Known risks

- Push, ringing calls, photos and the map have not been tested on real devices.
- Phone and email checks are simulations in the free-plan build. Say so in the review notes.
- The admin site pages were never opened against live data.
- Nothing has been deployed to the live project since Blaze is pending.
