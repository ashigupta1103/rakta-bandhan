# Verification record, 2026-10-02

Source: `feat/prelaunch` at `fda233cfc6b427b383f93f3044bb5198a513dd3e`. Upstream `origin/master` at `0e19c5d` is included. New UI layouts/assets were preserved; the owner approved wiring missing actions.

## Local checks

| Check | Result |
|---|---|
| Full `bash tool/preflight.sh` | Passed |
| Flutter analyzer | No issues |
| Flutter tests | 67 pass; 1 demo-only skip |
| Demo sign-in test with `DEMO_SIGNIN=true` | 1 pass |
| Functions unit tests | 27 pass |
| Functions emulator smoke | Login/review, accounts, jobs, support and 410-record migration/search/cursor checks pass |
| Edge tests and dry-run bundle | 23 pass; bundle succeeds |
| Firestore/legacy Storage rules | 73 pass |
| Admin types/build/lint | Pass, including follow-up document-ID mapping check |
| Release demo APK | Builds; package and APK signature verified |

Smoke tests used `demo-rakta-bandhan` emulators. No real email, SMS or push was sent. Production Firebase was not mutated. The existing admin lint/chunk-size and local SDK/Kotlin migration warnings remain; all listed checks exit zero.

## APK for owner testing

Local path: `X:\BloodBankkk\build\RaktaBandhan-demo.apk`

- Build: `flutter build apk --release --dart-define=DEMO_SIGNIN=true`
- Package: `com.raktabandhan.app`, version `1.0.0` (code 1).
- Minimum Android API: 24. Target API: 36.
- Size: 112,562,718 bytes (107.3 MiB).
- Signature: APK v2 verification passes.
- SHA-256: `58eeb0e06e4663e6df4952662782c580b5d633d989d583fd07241669b80a924a`.
- Any valid email works in demo; email code `123456`, phone code `246810`. Demo checks do not prove real phone ownership.

Use the normal Flutter release command after tests. On this SDK, skipping package setup with `--no-pub` left a generated integration-test plugin entry and failed Android compilation; the normal command regenerated the release plugin setup and built successfully. Generated registrant noise was restored before committing.

The artifact and logs in `build/checks/` are ignored local outputs. Code/docs are committed, and the working tree was clean before this verification record. No push or deployment was performed; stash/backup snapshots were retained.

## Remaining owner work

Device testing, domain/account provisioning and deployment remain owner tasks. Follow [external connections](EXTERNAL_CONNECTIONS.md) and [the deploy runbook](DEPLOY_RUNBOOK.md). Real sign-in and push activation remain pending Blaze and a verified sender, per [accepted decisions](DECISIONS.md). Production acceptance and a configured real APK follow that rollout. Legal approval/signing/store setup also remains owner-provided.
