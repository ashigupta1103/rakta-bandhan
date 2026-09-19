# Rakta Bandhan backend (Firebase Spark / free plan)

No Cloud Functions, no custom server. The whole backend is Firestore +
Firebase Auth, driven directly from the Flutter client in
`lib/services/backend.dart`. Everything a Cloud Function would normally do
(matching, accept-locking, contact reveal, expiry, admin verification)
happens client-side inside Firestore transactions, with `firestore.rules`
enforcing the invariants a Cloud Function would otherwise guard.

See the root `PROJECT_HANDOFF.md` history and the two design PDFs
(`Rakta_Bandhan_Backend_Design.pdf`, `Rakta_Bandhan_Backend_Reference.pdf`)
for the original Cloud-Functions-based design those describe — that design
needs the Blaze plan to deploy at all and was never built. What's here is
the Spark-compatible replacement; see the "requires Blaze" table in the
plan this was built from for exactly what's simulated instead.

## vs. `Rakta_Bandhan_Technical_HLD.md`

That doc (root of repo) is the original, more ambitious architecture —
Cloud Functions, real FCM push, Geoflutterfire, MSG91, a separate web admin
dashboard. Decision: stay on Spark, keep what's built here. Three
different reasons an HLD item isn't built as literally specified —
worth keeping distinct, since only the first one is a hard wall:

**Genuinely Blaze-only — simulated instead, can't be done any other way on Spark:**
| HLD item | What we do instead |
|---|---|
| Cloud Functions (matching trigger, contact reveal, verification) | Client-side Firestore transactions + `firestore.rules` (this folder) |
| FCM push, backgrounded/closed app | In-app only, live while the app is open (`FirestoreNotificationsService`) |
| Scheduled functions (auto-expire, 90-day reactivation) | Lazy checks on read (`Backend.expireIfStale`, `Backend.maybeReactivate`) |
| MSG91 SMS fallback | Not built — no fallback channel if push/in-app is missed |

**Spark-compatible, just not built yet — no Blaze needed if you want these later:**
- Firebase Storage for donor ID proof / hospital verification docs (Storage has a free Spark tier)
- A real web admin dashboard via Firebase Hosting (Hosting is also free-tier; could be the same Flutter app built for web, since `firebase_options.dart` already has a `web` config)
- Firebase Analytics (not wired in at all)
- Real geohash *range* queries (Geoflutterfire-style `where(geohash, >=, ...)`) instead of the current full-scan-then-Haversine-filter — fine at demo scale, would matter at real scale

**Matches the HLD as-is, different mechanism, same result:**
- Data model (`donors`, `requests`, `hospitals`, `donation_history`) — same shape, `notifications` is derived instead of stored (see collections table below)
- OSM/Nominatim for geocoding — the HLD lists this as the fallback; it's what we use as the only method (no Google Maps Platform key)
- Admin verification gating (`is_verified`) and G-I-F-T flow (group → identify → fast accept → time/schedule) — same behavior, enforced by rules instead of a Function

## Deploy

```
firebase login
firebase use <project-id>
firebase deploy --only firestore:rules,firestore:indexes
```

## Migrating to a different Firebase account/project

Nothing app-specific is hardcoded outside the files FlutterFire's own
tooling manages — `firestore.rules`/`firestore.indexes.json` (this
folder) are project-agnostic and need zero edits. To point the whole app
at a new Firebase project (new account, new org, whatever):

1. `firebase login` as the new account.
2. From the repo root: `dart pub global activate flutterfire_cli` (once,
   if not already installed), then
   `flutterfire configure --project=<new-project-id>`.
   This regenerates `lib/firebase_options.dart`,
   `android/app/google-services.json` (and `ios/…/GoogleService-Info.plist`
   / `macos/…/GoogleService-Info.plist` if you configure those platforms
   too), and merges the new project/app IDs into the `flutter` key of
   `firebase.json` — it does not touch the `firestore` key pointing at
   this folder.
3. In the new project: enable Firestore (Native mode) and enable
   Authentication → Email/Password (used by the admin console) and
   whatever sign-in method you use for donors.
4. `firebase deploy --only firestore:rules,firestore:indexes` (same
   command as above, now targeting the new project).
5. Bootstrap the first admin again — it's account data, not code; see
   above. A fresh project has no `admins/{uid}` doc yet.
6. Existing donor/request data does **not** move automatically — it lives
   in the old project's Firestore. Export/import it yourself
   (`gcloud firestore export`/`import`, or the Console) if you need to
   carry it over; a fresh migration for a new deployment typically
   doesn't need to.

That's the whole migration — no code in `lib/` references a project ID,
API key, or app ID directly; everything reads through
`DefaultFirebaseOptions.currentPlatform` in `firebase_options.dart`.

## Bootstrap the first admin (one-time, manual)

Nothing in the app can create the first `admins/{uid}` doc on Spark — that
would normally be a Cloud Function (`setAdminRole`). Do it once by hand:

1. Firebase Console → Authentication → Add user (email + password, for
   yourself).
2. Copy that user's UID.
3. Firebase Console → Firestore → create a document at
   `admins/<uid>` with fields `{ email: "...", added_at: <timestamp> }`.
4. Sign in with that email/password on the Admin console screen in the
   app. Once signed in, that admin can add further admins the same way
   (or via a future "add admin" admin-only action).

## Collections

| Collection | Written by | Notes |
|---|---|---|
| `donors/{uid}` | owner (client), admin | private: name, phone, exact location, `is_verified`/`is_banned` are admin-only fields |
| `donors_public/{uid}` | owner (client) | map-safe mirror, no phone, ever |
| `requests/{id}` | owner creates; owner/matched-donor/admin transition it | denormalizes `requester_name`/`requester_phone` and `matched_donor_name`/`matched_donor_phone` at creation/accept time so contact reveal never needs a second cross-user read |
| `donation_history/{id}` | donor (self-report) or admin | immutable |
| `admins/{uid}` | admin only (first one: manual) | existence = admin, no custom claims |
| `hospitals/{id}` | admin only | reference data, readable by any signed-in user |
| `audit_log/{id}` | admin only | admin actions, admin-only read |
