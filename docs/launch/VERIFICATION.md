# Verification record, 2026-10-02

Source: branch `feat/prelaunch`. Upstream `origin/master` at `0e19c5d` is included. New UI layouts/assets were preserved; the owner approved wiring missing actions.

## Local checks

| Check | Result |
|---|---|
| Full `bash tool/preflight.sh` | Passed |
| Flutter analyzer | No issues |
| Flutter tests | 62 pass; the login tests also pass with `--dart-define=EMAIL_CODE_LIVE=true` (12 pass) |
| Real app on an Android emulator (Firebase auth + Firestore emulators, this repo's rules) | Donor journey passes: sign up → simulated email check → register → phone-check simulation → accept a request → in-app call → both confirm → rest period + record → certificate → Find → Community. The requester, account and community/support journeys in `integration_test/` were not completed (unverified). |
| Functions unit tests | 27 pass |
| Functions emulator smoke | Login/review, accounts, jobs, support and 410-record migration/search/cursor checks pass |
| Edge tests and dry-run bundle | 23 pass; bundle succeeds |
| Firestore/legacy Storage rules | 73 pass |
| Admin types/build/lint | Pass, including follow-up document-ID mapping check |
| Release APK | Built and signature-verified; see the section below |

Smoke tests used `demo-rakta-bandhan` emulators. No real email, SMS or push was sent. Production Firebase was not mutated. The existing admin lint/chunk-size and local SDK/Kotlin migration warnings remain; all listed checks exit zero.

## APK for owner testing

Local path: `X:\BloodBankkk\build\RaktaBandhan.apk` (a copy of `build\app\outputs\flutter-apk\app-release.apk`; the older `build/RaktaBandhan-demo.apk` is obsolete: it contained the demo layer, now removed).

- Build: `flutter build apk --release` (`EDGE_URL` defaults to the live Worker)
- Package: `com.raktabandhan.app`, version `1.0.0` (code 1).
- Minimum Android API: 24. Target API: 36.
- Size: 111,956,510 bytes (106.8 MiB).
- Signature: APK v2 verification passes.
- SHA-256: `32c4deac019dbe697602f89e88a552d6997d52bad8efd3c1b93ae2430ef8a2b3`.
- Permissions audited: no `AD_ID`, `USE_FULL_SCREEN_INTENT`, `CALL_PHONE`, call-log or camera foreground-service permission. The compiled app contains no demo or sample strings; its one simulation is labelled "Simulation".
- Sign-in is email + password (free plan); the email check after sign-up is a labelled simulation (code `123456`). It needs Email/Password switched on in the Firebase console, and the rules and indexes in this repo deployed to the live project: see [Spark now](SPARK_NOW.md). The phone-number check after registration is a labelled simulation (code `246810`).

Use the normal Flutter release command after tests. On this SDK, skipping package setup with `--no-pub` left a generated integration-test plugin entry and failed Android compilation; the normal command regenerated the release plugin setup and built successfully. Generated registrant noise was restored before committing.

The artifact and logs in `build/checks/` are ignored local outputs. Code/docs are committed, and the working tree was clean before this verification record. No push or deployment was performed; stash/backup snapshots were retained.

## Remaining owner work

Device testing, domain/account provisioning and deployment remain owner tasks. Follow [external connections](EXTERNAL_CONNECTIONS.md) and [the deploy runbook](DEPLOY_RUNBOOK.md). The emailed sign-in code and push delivery remain pending Blaze and a verified sender, per [accepted decisions](DECISIONS.md); until then sign-in is email + password. Production acceptance follows the owner's Firebase deployment. Legal approval/signing/store setup also remains owner-provided.
