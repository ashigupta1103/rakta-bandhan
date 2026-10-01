# Rakta Bandhan backend

> **Update (Oct 2026):** the project is moving to the **Blaze** plan. Push notifications, call ringing, request expiry and broadcasts now run as Cloud Functions in `../functions/`; photo posts use Cloud Storage (`storage.rules`). Sign-in is email + password with verification. The Spark-era notes below are kept for history — the rules in this folder are current. Run the rules tests with `cd rules-test && npm test`.

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
| FCM push, backgrounded/closed app | In-app only, live while the app is open — the derived notification feed (`FirestoreNotificationsService`), incoming calls (`CallService.incomingCalls`), new chat messages, and urgent alerts (`UrgentAlertService`) all watch Firestore listeners, not push. An FCM token is already saved to `donors/{uid}.fcm_token`, ready for a Blaze push trigger to use without a client rewrite. |
| Scheduled functions (auto-expire, 90-day reactivation) | Lazy checks on read (`Backend.expireIfStale`, `Backend.maybeReactivate`) |
| MSG91 SMS fallback | Not built — no fallback channel if push/in-app is missed |

**Spark-compatible, built:**
- Donor ID proof (`Backend.uploadIdProof`) — lives at `donors/{uid}/private/id_proof` (a Firestore *subcollection* doc, base64 inside it), not Cloud Storage — same free-tier trick as before, just moved off the profile doc itself so a bulk admin read of `donors` no longer downloads every photo. The profile only keeps `has_id_proof: true/false`. `AdminDonorDetailScreen`'s `_IdProofView` fetches it on demand, one donor at a time (`Backend.fetchIdProof`), and it's deleted once an admin verifies the donor (`Backend.adminVerifyDonor`) or the donor is rejected — the scan isn't kept longer than review needs. Caller-side resolution/quality caps (`maxWidth: 1280, imageQuality: 70`) keep it well under Firestore's 1MiB document limit.
- In-app chat and voice calls (`ChatService`/`ChatScreen`, `CallService`/`CallScreen`) — `requests/{id}/messages` and `requests/{id}/calls/{cid}` (+ ICE-candidate subcollections), open only between the requester and the matched donor while the request is `matched`. Calls are peer-to-peer WebRTC audio; Firestore carries only the signalling handshake, never the audio. Block/report writes to `reports/{id}` (admin-read, admin-can-triage-but-not-delete). See `docs/specs/2026-09-26-chat-calls-alerts-compliance-design.md`.
- Urgent alerts (`UrgentAlertService`/`UrgentAlertScreen`) — opt-in (`donors/{uid}.urgent_alerts`), full-screen takeover for a compatible nearby critical/urgent request, live only while the app is open (closed-app push needs Blaze — see below).
- Real in-app account deletion and data export (`AccountService`) — required by App Store 5.1.1(v) and Google Play's account-deletion policy; cancels/releases the user's open matches, scrubs their name/phone off shared request docs, deletes their own chat messages, then the two donor docs and the Auth user itself.
- A real web admin dashboard via Firebase Hosting (`admin/frontend`, reads Firestore directly)
- Firebase Analytics (`Backend._logEvent` — `donor_registered`, `request_created`, `request_matched`, `donation_fulfilled`)
- Admin-confirmed donations (`Backend.adminConfirmDonation`, triggered from `AdminRequestDetailScreen`) — the admin-side counterpart to a donor's own self-reported `markFulfilled`, for donations an admin/hospital confirms instead
- Real geohash range queries (`NearbyDonors`, a Geoflutterfire-style 3×3 cell grid memoised per ~5 km cell) for the Find Donors proximity search specifically, capped at 900 reads — `openRequestsStream`/`availableDonorsStream` (used by the main Requests tab and the matching-screen donor count) are deliberately left as full unbounded streams, since bounding *those* to a radius is a visibility decision (a distant compatible donor going unseen), not just a performance one. `donors_public` coordinates are coarsened to ~1 km (`Backend._coarse`) before they're ever written — exact lat/lng only lives on the private `donors/{uid}` doc.
- Admin cleanup deletes: a donor's Firestore profile (`Backend.adminDeleteDonor`) or a request (`Backend.adminDeleteRequest`) can be removed outright for spam/duplicates/test data, independent of the ban flag or the request-status transitions. Deleting a donor's profile doesn't touch their Auth account — see the Blaze table above.

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
| `donors/{uid}` | owner (client), admin | private: name, phone, exact location, `urgent_alerts`, `fcm_token`; `is_verified`/`is_banned` are admin-only fields. Owner delete = account deletion (unconditional, even if banned — see AccountService and the store-policy note in `firestore.rules`) |
| `donors/{uid}/private/id_proof` | owner (client), admin | the ID-proof image, split out of the profile doc so bulk admin reads don't download it; deleted once reviewed |
| `donors_public/{uid}` | owner (client) | map-safe mirror, no phone, ever; coordinates coarsened to ~1 km |
| `requests/{id}` | owner creates; owner/matched-donor/admin transition it; admin can delete outright | denormalizes `requester_name`/`requester_phone` and `matched_donor_name`/`matched_donor_phone` at creation/accept time so contact reveal never needs a second cross-user read |
| `requests/{id}/messages/{mid}` | the two matched participants | in-app chat, only while `matched` and not blocked; a sender may delete their own messages (account deletion) |
| `requests/{id}/calls/{cid}` (+ ICE-candidate subcollections) | the two matched participants | WebRTC signalling handshake only — audio is peer-to-peer and never stored |
| `reports/{id}` | any signed-in user (create); admin (read, update) | chat/call block-and-report; no delete — stays on record regardless of triage outcome |
| `donation_history/{id}` | donor (self-report) or admin | immutable |
| `admins/{uid}` | admin only (first one: manual) | existence = admin, no custom claims |
| `hospitals/{id}` | admin only | reference data, readable by any signed-in user |
| `audit_log/{id}` | admin only | admin actions, admin-only read |
| `community_stories/{id}` | author (client), admin | "Share an experience"; readable by any signed-in user, never edited by the author. Admin moderates: `is_hidden` (reversible — the feed filters it client-side) or delete |
| `issue_reports/{id}` | any signed-in user; admin triages | "Report an issue"; admin-only read. The author can't edit or withdraw one; an admin sets `status` (`new`/`in_progress`/`resolved`) and an admin-only `admin_note`, or deletes it |
| `partnership_inquiries/{id}` | any signed-in user; admin triages | "Partner with us"; same triage fields and rules as `issue_reports` |
| `announcements/{id}` | admin only | Community → What's New. `title`, `body`. No user-write path at all; readable by any signed-in user |
| `testimonials/{id}` | admin only | More → Testimonials. `quote`, `name`, `role`. Deliberately separate from `community_stories` — those are member posts, these are copy the team has permission to publish, so the admin-only write rule is what makes "curated and verified" structural |
| `public_stats/impact` | any signed-in user (+1 only), admin (any value) | Community Impact counter — a normal user can't query fulfilled `requests` (they carry phone numbers), so the aggregate lives here; rules cap a donor's write at +1, while an admin can set it outright (miscount, or donations confirmed offline) |

## Admin-controlled app content

Everything on the app's non-transactional screens is a real collection an
admin edits, not hardcoded copy. Both consoles cover the same ground:

| App screen | Collection | Flutter console | Web console |
|---|---|---|---|
| Community → What's New | `announcements` | Content tab | Content page |
| More → Testimonials | `testimonials` | Content tab | Content page |
| Community → Impact | `public_stats/impact` | Content tab ("Correct") | Content page ("Correct") |
| Community → Stories | `community_stories` | Content tab (hide/delete) | Content page (hide/delete) |
| Help & support → Report an issue | `issue_reports` | Inbox tab | Inbox page |
| Corporate partnerships → Start a conversation | `partnership_inquiries` | Inbox tab | Inbox page |
| Chat/call block-and-report | `reports` | Inbox tab | Inbox page |

Each screen falls back to its existing honest empty state when nothing is
published — the app never invents a placeholder announcement or testimonial.

**Still Blaze-only here:** there is no reply channel out of any Inbox
section, `reports` included. An `admin_note` is internal, and telling the
submitter anything would need outbound email/SMS from a server — see the
"requires Blaze" table above, which now also covers push for new messages
and incoming calls (today's `ChatScreen`/`CallScreen` only ring while the
app is open). Triage state is visible to admins only.
