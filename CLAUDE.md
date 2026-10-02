# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Rakta Bandhan — a Flutter blood-donation app (requester raises a request → compatible nearby donors are notified → one donor accepts → chat/call in app → both sides confirm the donation). A service project of Madras Cosmos Charitable Trust and Chennai Capital Trust (Rotary Clubs of Madras Cosmos and Chennai Capital), targeting India. Android first, then iOS; also builds for Web.

Deployable parts in this repo:
- `lib/` — the Flutter app (the main product).
- `backend/` — Firestore + Storage security rules, indexes, and `rules-test/` (emulator tests).
- `functions/` — Cloud Functions (TypeScript, Blaze): push notifications, call ringing, nearby-donor fan-out, broadcasts, request expiry. They only *notify*; all data invariants stay in the rules.
- `admin/frontend/` — React 19 + Vite + Tailwind + shadcn admin dashboard, reads Firestore directly, deployed to Firebase Hosting (`firebase.json` → `admin/frontend/build`), with static legal pages (`public/legal/`) and the share page (`public/app/`). `admin/backend/functions/` is an old, undeployed draft — the live functions are in `functions/`.

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

firebase deploy --only firestore:rules,firestore:indexes,storage,functions  # after editing backend/* or functions/
cd backend/rules-test && npm test     # rules tests on the emulator (Java 21)
cd functions && npm test              # functions unit tests;  npm run smoke  = emulator smoke test
flutter build appbundle --release --dart-define=GOOGLE_MAPS=true   # store build with native Google Maps
python tool/export_legal_html.py   # after editing lib/legal/* — regenerates the hosted privacy/terms/guidelines/delete-account pages
python tool/make_share_page.py     # share page + social preview image (admin/frontend/public/app/)
python tool/make_app_icons.py      # regenerate launcher icons from assets/branding (needs Pillow)

cd admin/frontend && npm run dev | npm run build | npm run lint   # oxlint
```

## Backend model (read before touching data code)

Firebase **Spark** until the owner upgrades to Blaze. Data logic runs client-side in `lib/services/backend.dart` inside Firestore transactions, with `backend/firestore.rules` enforcing every invariant. Cloud Functions are built but pending deployment after Blaze; demo sign-in remains the current test path. Cloudflare Workers provide R2 photos and TURN relay without a Firebase service-account key. Consequences:
- **Auth is passwordless**: email → a 6-digit code emailed by the `requestLoginCode` function, traded by `verifyLoginCode` for a Firebase custom token carrying the claim `login: email_otp` (`functions/src/login.ts`; app side `LoginScreen` → `LoginCodeScreen` → `Backend.requestLoginCode` / `verifyLoginCode`). Rules let a verified account create anything (`isVerifiedUser()`: the `login` claim, a verified email, or a `phone_number` claim). Account deletion needs no password: `deleteMyAuthAccount` removes the Auth user server-side. The phone number is collected on registration, unverified. The two admin consoles still sign in with email + password.
- **Two donor docs**: `donors/{uid}` (private — phone, ID proof as base64, owner/admin only) and `donors_public/{uid}` (name, group, coarse location, availability). Writes that touch both must stay in one transaction because the rules cross-check them.
- **Request lifecycle** on `requests/{id}.status`: `open → matched → fulfilled`, or `cancelled` / `expired`. Accept is a transaction that locks via `donors/{uid}.active_request_id` and refuses donors on cooldown. **Completion is two-sided**: `donorConfirmDonation` (starts the donor's 90-day cooldown, writes `donation_history` with hospital + group) and `requesterConfirmDonation`; whichever is second sets `fulfilled` — the rules enforce this. Expiry runs every 15 min in `expireOldRequests` (plus lazy `expireIfStale`); reactivation is lazy (`maybeReactivate`). The rules (`cooldownRespected`) stop a donor going available or shortening the rest period.
- **Contact**: requester and donor names appear on the request. Phone numbers stay in private donor profiles for their owner and administrators; new requests never copy them. Matched people use in-app chat and calls.
- **Notifications**: the in-app feed is derived (`FirestoreNotificationsService`); push comes from the functions to `donors/{uid}.fcm_token` and to FCM topics (`all`, `bg_<group>` e.g. `bg_Apos` — keep `PushService.bloodGroupTopic` and `functions/src/geo.ts` in sync). Android channels (`messages`, `requests`, `urgent_alerts`, `general`) are created in `MainActivity.kt`. `PushService` handles token/topics, notification taps, and the native incoming-call screen (`flutter_callkit_incoming`) when the app is closed; `LiveEventsHost` routes taps and avoids double-ringing.
- **Maps**: native Google Maps on phones when built with `--dart-define=GOOGLE_MAPS=true` (`useGoogleMaps` in `widgets/map_tiles.dart`, key via `MAPS_API_KEY`), else `flutter_map` + OSM tiles. Geocoding is Nominatim/LocationIQ (`geo_config.dart`).
- **Never show coordinates**: use `Backend.shortPlace(label)` for addresses and the `donors_public.area` neighbourhood name (`reverseGeocodeArea`) for people.
- **Open requests**: user screens use `openRequestsNearStream(lat, lng)` (geohash cells, `(status, geohash)` index), never the nationwide `openRequestsStream()`.
- **Community posts** can carry one JPEG on Cloudflare R2 at `community/{uid}/{random}.jpg`. The service prepares JPEG <=1440 px, q78, <=2 MB. The app and admin consoles delete the R2 photo before deleting its post; community and avatar links are readable by anyone who has the link.
- Blood compatibility table (`bloodCompatibility`) is keyed **recipient → donor groups**.
- `donors_public` coordinates are coarsened to ~1 km (`Backend._coarse`); exact lat/lng only live on private `donors/{uid}`.
- **Location:** anything *stored* (registration area, request location, chat location) must come from `Backend.preciseLocation()` (nullable — real GPS or nothing), a search result, or `LocationPickerScreen` (Rapido-style fixed-centre pin). `currentPosition()` falls back to a demo city and is for centring a map only; check `Backend.isFallback`. Map tiles and geocoding providers/keys live in `lib/services/geo_config.dart`; all maps use `appMapBase()` from `widgets/map_tiles.dart`.
- Counting donors: use `NearbyDonors.countCompatible` (Firestore `count()` aggregation), not a document listener.
- **Never scan `donors_public`** from user-facing screens — use `NearbyDonors` (geohash precision-5 cell + 8 neighbours, `limit(30)` per cell; needs the `(is_available, geohash)` index). `Backend.availableDonorsStream()` is a whole-collection scan kept only for admin paths.
- ID proofs use authenticated Worker reads at `id_proofs/{uid}/proof.jpg`; legacy `donors/{uid}/private/id_proof` remains a read fallback. The profile only has `has_id_proof`. `backend/storage.rules` is retained for legacy tests; the app no longer uses Firebase Storage.

## Chat, calls, urgent alerts (see `docs/specs/2026-09-26-chat-calls-alerts-compliance-design.md`)

- **Chat** (`ChatService`, `ChatScreen`): `requests/{id}/messages` (kinds `text`/`call`/`location`), only between the requester and the matched donor, writable only while the request is `matched` and `chat_closed_by` is unset (block). Each send is a batch that also writes `last_message` + the sender's `requester_read_at`/`donor_read_at` on the request — that powers the **Messages inbox** (`ConversationsScreen`, `ChatService.watchConversations`), unread badges, "Seen", and the in-app `MessageBanner`. Reports go to `reports/` (admin-read).
- **In-app calls**: audio-only WebRTC; Firestore carries the handshake. `CallService` fetches `/ice` from `EDGE_URL` with a 3-second timeout, caches TURN credentials per uid until expiry minus 5 minutes, and retains built-in STUN as fallback.
- **Urgent alerts** (`UrgentAlertService`, `UrgentAlertScreen`, `UrgentAlertToggle`): opt-in via `donors/{uid}.urgent_alerts`. Full-screen takeover + looping `AlertSound` (in-house WAVs in `assets/sounds/`).
- `LiveEventsHost` (mounted in `MainNavigationScreen`) pushes incoming-call / urgent-alert routes over any screen while the app is open; with the app in the background the push + native call screen take over.
- Store-policy constraints baked in: `USE_FULL_SCREEN_INTENT`, the camera foreground-service type and the Advertising ID permissions are removed in the manifest (`tools:node="remove"`); no `CALL_PHONE`/call-log permissions (phone fallback is a `tel:` intent); no iOS `voip` background mode until PushKit + CallKit are added.
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
