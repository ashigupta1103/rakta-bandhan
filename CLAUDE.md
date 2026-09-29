# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Rakta Bandhan — a Flutter blood-donation app (requester raises a request → compatible nearby donors see it → one donor accepts → contact is revealed → donor marks it donated). An initiative of the Rotary Club of Madras Cosmos, targeting India. Must run on Android, iOS, Web and Windows from one codebase.

Three deployable parts live in this repo:
- `lib/` — the Flutter app (the main product).
- `backend/` — Firestore security rules + indexes only. There is **no server**; see "Backend model" below.
- `admin/frontend/` — React 19 + Vite + Tailwind + shadcn admin dashboard, reads Firestore directly, deployed to Firebase Hosting (`firebase.json` → `admin/frontend/build`). `admin/backend/functions/` holds Cloud Functions that require the Blaze plan and are **not deployed**.

`design/`, `design_new/`, `design_updated/` are design artifacts and a separate reference Flutter snapshot (`design_new/flutter`, excluded from analysis) — not app source.

## Commands

```bash
flutter pub get
flutter analyze                                   # lint (flutter_lints)
flutter test                                      # all widget tests
flutter test test/logout_confirmation_test.dart   # single file
flutter test --plain-name "substring of test name"
flutter run -d chrome        # or -d windows / an Android device
flutter build apk --dart-define=ENABLE_PREVIEW_UI=true   # client demo build with sample content

firebase deploy --only firestore:rules,firestore:indexes  # after editing backend/*
python tool/export_legal_html.py   # after editing lib/legal/* — regenerates the hosted privacy/terms/delete-account pages
python tool/make_app_icons.py      # regenerate launcher icons from assets/branding (needs Pillow)

cd admin/frontend && npm run dev | npm run build | npm run lint   # oxlint
```

## Backend model (read before touching data code)

Firebase **Spark (free) plan** — no Cloud Functions, no Cloud Storage, no server-sent FCM push. Everything a function would do runs client-side in `lib/services/backend.dart` (`Backend.instance` singleton) inside Firestore transactions, with `backend/firestore.rules` enforcing the invariants. Consequences:
- **Auth is fake OTP**: any 6-digit code is accepted; the phone number maps to a synthetic email + a shared hardcoded password (`verifyFakeOtp`). Not production-safe.
- **Two donor docs**: `donors/{uid}` (private — phone, ID proof as base64, owner/admin only) and `donors_public/{uid}` (name, group, coarse location, availability). Writes that touch both must stay in one transaction because the rules cross-check them.
- **Request lifecycle** on `requests/{id}.status`: `open → matched → fulfilled`, or `cancelled` / `expired`. Accept is a transaction that locks via `donors/{uid}.active_request_id`. Expiry (`requestExpiryHours = 6`) and 90-day donor reactivation are **lazy** — `expireIfStale` / `maybeReactivate` are called wherever docs are read, not on a schedule.
- **Contact reveal**: requester name/phone are denormalized onto the request at creation; matched donor name/phone are written on accept. Screens read contact info off the request doc, never off the other party's `donors/` doc.
- **Notifications are derived, not stored**: `FirestoreNotificationsService` synthesizes the feed from the user's own request streams. They are in-app only and live only while the app is open.
- Location/geocoding is OpenStreetMap Nominatim (no API key); donor search is a full scan + Haversine filter (demo scale). Map is `flutter_map`.
- Blood compatibility table (`bloodCompatibility`) is keyed **recipient → donor groups**.
- `donors_public` coordinates are coarsened to ~1 km (`Backend._coarse`); exact lat/lng only live on private `donors/{uid}`.
- **Location:** anything *stored* (registration area, request location, chat location) must come from `Backend.preciseLocation()` (nullable — real GPS or nothing), a search result, or `LocationPickerScreen` (Rapido-style fixed-centre pin). `currentPosition()` falls back to a demo city and is for centring a map only; check `Backend.isFallback`. Map tiles and geocoding providers/keys live in `lib/services/geo_config.dart`; all maps use `appMapBase()` from `widgets/map_tiles.dart`.
- Counting donors: use `NearbyDonors.countCompatible` (Firestore `count()` aggregation), not a document listener.
- **Never scan `donors_public`** from user-facing screens — use `NearbyDonors` (geohash precision-5 cell + 8 neighbours, `limit(100)` per cell; needs the `(is_available, geohash)` index). `Backend.availableDonorsStream()` is a whole-collection scan kept only for admin paths.
- The ID-proof image lives at `donors/{uid}/private/id_proof` (owner/admin); the profile only has `has_id_proof`. Don't put large blobs on docs that are read often.

## Chat, calls, urgent alerts (see `docs/specs/2026-09-26-chat-calls-alerts-compliance-design.md`)

- **Chat** (`ChatService`, `ChatScreen`): `requests/{id}/messages` (kinds `text`/`call`/`location`), only between the requester and the matched donor, writable only while the request is `matched` and `chat_closed_by` is unset (block). Each send is a batch that also writes `last_message` + the sender's `requester_read_at`/`donor_read_at` on the request — that powers the **Messages inbox** (`ConversationsScreen`, `ChatService.watchConversations`), unread badges, "Seen", and the in-app `MessageBanner`. Reports go to `reports/` (admin-read).
- **In-app calls** (`CallService`, `CallScreen`/`IncomingCallScreen`): audio-only WebRTC (`flutter_webrtc`), Firestore carries only the handshake at `requests/{id}/calls/{cid}` + candidate subcollections. Incoming calls use a collection-group query (index in `backend/firestore.indexes.json`). STUN only — `callIceServers` has a TURN slot that must be filled before launch.
- **Urgent alerts** (`UrgentAlertService`, `UrgentAlertScreen`, `UrgentAlertToggle`): opt-in via `donors/{uid}.urgent_alerts`. Full-screen takeover + looping `AlertSound` (in-house WAVs in `assets/sounds/`).
- `LiveEventsHost` (mounted in `MainNavigationScreen`) pushes incoming-call / urgent-alert routes over any screen. Everything live is a Firestore listener, so it only works while the app is open; the Blaze migration adds push (FCM token already saved to `donors/{uid}.fcm_token`) without changing these classes.
- Store-policy constraints baked in: no `USE_FULL_SCREEN_INTENT`, no `CALL_PHONE`/call-log permissions (phone fallback is a `tel:` intent), no iOS `voip` background mode until CallKit is added.
- **Account data**: `AccountService` does JSON export and in-app deletion (required by App Store 5.1.1(v) / Google Play). Deletion order matters — see its doc comment. `Backend.releaseMatch` lets a matched donor back out (request reopens).
- **Legal**: text in `lib/legal/legal_documents.dart` must match real behaviour — update it in the same change when data handling changes. `legal_config.dart` holds contact/grievance fields and `kLegalApproved` (draft banner until true).

## App structure

- `main.dart` → `SplashScreen`; on web the whole app is constrained to a 430px centered column in `MaterialApp.builder` (do it there, not per screen).
- `MainNavigationScreen` is an `IndexedStack` tab shell. Flow screens (find donors, donor details, matching, tracking, contact) are pushed on top so the nav bar hides — don't turn them into tabs.
- State is plain `StatefulWidget` + `StreamBuilder` over Firestore; no state-management library.
- `lib/preview_mode.dart` `kEnablePreviewUi`: true in debug/profile, false in release unless `--dart-define=ENABLE_PREVIEW_UI=true`. Gates all sample/fictional content (preview gallery reachable from Login, sample About/Community copy). Release builds must never show invented people, stats or partners.

## Design system rules

`PROJECT_HANDOFF.md` documents the original redesign; its palette section is **outdated** — the live tokens are in `lib/theme/`:
- Colors only via `AppColors` (logo-derived warm system: `brandRed` ramp, vermilion/orange, gold, warm neutrals, `emberField*` gradient reserved for emotional-peak screens — consent, matching, match, certificate). Many legacy aliases (`primary`, `textPrimaryWarm`, …) point at the same tokens; don't add new duplicates.
- Two type voices: Barlow (theme default, all UI chrome) and Newsreader via `AppTextStyles.display()` for names, headlines, counts only.
- Icons: `lucide_icons_flutter` only. No emoji or Unicode glyphs as icons, no Material `Icons.*`. Icon-on-tint mounts use `BrandGlyph` (droplet), not a tinted circle.
- Sentence case everywhere — no tracked ALL-CAPS eyebrow labels.
- Text/icons on the ember gradient use the `AppColors.onEmber*` tokens, never inline hex.
- Custom tappables use `Pressable` (0.97 press scale); motion stays under ~300ms, ease-out, and respects `MediaQuery.disableAnimations`.
- Any request cancel goes through `ConfirmSheet`.
- No native OS date/time pickers — custom in-app components.
- Radii: `AppTheme.controlRadius` (12) for controls/tiles, 20 for raised cards/sheets.
- Keep the existing logo (`assets/branding/`) unchanged.
- Widget tests in `test/` are regression guards (double-bordered search field, logout confirm, back navigation, legal reader, blood compatibility table) — keep them passing when restyling. Tests must not touch `Backend.instance` (it eagerly creates Firebase singletons).

## Publishing

Release checklist, store-form answers and the Blaze cost model live in `docs/publishing/`; the prioritised audit is `docs/AUDIT.md`. Keep `lib/legal/legal_documents.dart`, `ios/Runner/PrivacyInfo.xcprivacy` and `docs/publishing/store-listing.md` consistent whenever data handling changes.
