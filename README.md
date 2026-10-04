# Rakta Bandhan

A Flutter blood-donation app for India. A requester raises a request, compatible nearby donors are notified, one donor accepts, both talk through in-app chat or call, and both sides confirm the donation. A service project of Madras Cosmos Charitable Trust and Chennai Capital Trust (the Rotary Clubs of Madras Cosmos and Chennai Capital). Android first, then iOS; it also builds for web.

## Repository layout

| Path | What is in it |
|---|---|
| `lib/`, `test/`, `integration_test/`, `assets/` | The Flutter app, its tests and assets |
| `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` | Flutter platform projects |
| `backend/` | Firestore and Storage security rules, indexes, emulator rule tests |
| `functions/` | Cloud Functions: push, call ringing, nearby-donor fan-out, expiry, login codes (needs the Blaze plan; not deployed yet) |
| `edge/` | Cloudflare Worker: R2 photo storage and TURN credentials for calls |
| `admin/` | React admin dashboard, deployed to Firebase Hosting |
| `docs/` | `architecture/`, `handoff/`, `planning/`, `launch/`, `publishing/`, `specs/`, and `AUDIT.md` |
| `design/` | Design artifacts: `v1_original/`, `v2_new/`, `v3_updated/` (the approved final) |
| `tool/` | Scripts: legal pages, share page, app icons, preflight checks, emulator end-to-end run |
| `releases/` | Old release APKs |

## Run it

```bash
flutter pub get
flutter run -d chrome     # or an Android device
flutter analyze
flutter test
```

Architecture notes, the data model, design-system rules and the full command list are in [CLAUDE.md](CLAUDE.md). Launch status and runbooks are in [docs/launch/](docs/launch/); the store listing and release checklist are in [docs/publishing/](docs/publishing/).
