# Rakta Bandhan — Blaze upgrade build plan

> **For the Claude Code session that receives this file.**
> The Firebase project has just been moved from the free Spark plan to the
> pay-as-you-go **Blaze** plan. Your job is to replace every Spark-era
> workaround in this repo with the real implementation, phase by phase, until
> the checklist at the bottom passes. Read this whole file first, then read
> the files listed under "Read before you start". Work through the phases in
> order: P0 is a security hole and comes first.
>
> Written 2026-09-26 at the end of the Spark-era session. Everything below
> was true of the code at that point. Check `git log` for anything newer.
>
> **2026-09-29 update:** `feature/chat-calls-cost-plan` merged in since this
> was written. In-app chat, in-app voice calls (WebRTC, Firestore
> signalling), urgent alerts, chat/call block-and-report, real in-app
> account deletion, and ID-proof-off-the-profile-doc are now **built and
> merged**, all still client-side/Spark — see `backend/README.md` and
> `docs/specs/2026-09-26-chat-calls-alerts-compliance-design.md`. That
> moves the goalposts for two phases below: **P2 (push)** is now "add a
> push trigger to what already exists" rather than "build chat/calls",
> and **P0 (real OTP)** gained a real launch blocker of its own — Firebase
> Phone Auth SMS is priced at ≈₹9.9 lakh/year at this app's target scale;
> `docs/publishing/cost-estimate.md` (also new) has the real plan (Truecaller
> → WhatsApp OTP → SMS fallback, ≈₹13,300/year). Read that cost doc before
> touching P0's OTP implementation — it changes the approach, not just the
> price. The rest of this plan (admin custom claims, ban/delete at the Auth
> level, scheduled expiry/reactivation, Storage migration, SMS fallback,
> inbox replies) is still accurate and still not built.

---

## 1. Project facts

| | |
|---|---|
| Repo root | `X:\BloodBankkk` (Windows; the Bash tool is Git Bash, the PowerShell tool is Windows PowerShell 5.1) |
| App | Flutter (`lib/`), Dart SDK ^3.13, Android is the shipped target |
| Web admin console | React + Vite + Tailwind + shadcn-style components in `admin/frontend/`, built to `admin/frontend/build`, served by Firebase Hosting |
| Firebase project | `rakta-bandhan2026` (owner account `bloodbank216@gmail.com`) |
| Hosting URL | https://rakta-bandhan2026.web.app |
| Firebase config | `firebase.json` (rules → `backend/firestore.rules`, indexes → `backend/firestore.indexes.json`, hosting → `admin/frontend/build`), `.firebaserc` (default = `rakta-bandhan2026`) |
| Client Firebase config | `lib/firebase_options.dart`, `android/app/google-services.json`, `admin/frontend/src/lib/firebase.ts` |
| Git remotes | `origin` = `ashigupta1103/rakta-bandhan` (main repo, branch `master`). `fork` = `Yash13606/rakta-bandhan-app` is **broken** ("Repository not found"). Do not use it. |
| Admin auth | An admin is any Auth user with a doc at `admins/{uid}`. The first admin was created by hand in the console. Credentials are **not** in this file; ask the user if you need to sign in. |

Commands:

```bash
flutter analyze                     # must stay clean apart from the 5 known infos (see §3)
flutter test                        # 14 pass; test/widget_test.dart fails and always has (default counter template)
cd admin/frontend && npm run build && npx tsc --noEmit
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only hosting
firebase deploy --only functions    # once functions/ exists
```

If `firebase deploy` returns `401 invalid authentication credentials`, the
CLI token is stale. Ask the user to run `firebase login --reauth`. You can't do that for them.

---

## 2. Read before you start

1. `backend/README.md` covers the architecture, the collections table and the "requires Blaze" table.
2. `backend/firestore.rules` holds every invariant the Spark design pushes into rules. Read the comment on `donors_public` first (see §3.1).
3. `lib/services/backend.dart` contains all client-side business logic: registration, the request lifecycle, the admin actions and the content collections.
4. `lib/services/admin_service.dart` and `lib/screens/admin_dashboard_screen.dart` / `admin_content_tab.dart` make up the in-app admin console.
5. `admin/frontend/src/hooks/useFirebaseData.ts` holds the web console's reads and writes and mirrors the Flutter admin actions.
6. `lib/services/notifications_service.dart` builds the in-app notification feed from existing data. Nothing about it is stored.
7. `Rakta_Bandhan_Technical_HLD.md` and the two PDFs in the root describe the **original** Cloud Functions design. That design was never built. Treat it as the target, not as current state.

---

## 3. Hard-won gotchas (don't relearn these)

1. **Firestore rules + transactions.** Inside a transaction, `get()`/`exists()` in a rule sees the database *before* the transaction. It never sees a sibling write from the same transaction. A rule on `donors_public/{uid}` that did `get(donors/{uid})` made every new registration fail ("Registration failed. Please try again."). Rules must read only the document's own fields, or you move the logic into a Cloud Function.
2. **Rules are not filters.** A query must be provably allowed for every possible result. For example, `requests where status == 'fulfilled'` is rejected for normal users because they can read only `open` requests plus their own. This is why `public_stats/impact` exists.
3. **Known analyzer infos**, all pre-existing. Leave them or fix them, but don't add new ones:
   - `personal_information_screen.dart:74,79` has `use_build_context_synchronously`.
   - `backend.dart` `currentPosition()` has deprecated `timeLimit`.
   - `emergency_contact_service.dart:26,27` has `unintended_html_in_doc_comment`.
4. **Widget tests run without Firebase.** Any screen reachable from `test/more_menu_back_navigation_test.dart` must not touch `FirebaseFirestore.instance` when `Firebase.apps.isEmpty`. See how `testimonials_screen.dart` guards it.
5. **No secrets in the repo.** The repo is shared on GitHub. Pass API keys with `--dart-define` and read them with `String.fromEnvironment`. Server keys go in Functions secrets (`firebase functions:secrets:set`). Never hardcode either.
6. **India first.** Phone input is capped at 10 digits for India (`login_screen.dart`, `LengthLimitingTextInputFormatter`). Pakistan was removed from the country list on purpose. Keep India-specific pricing and region choices.
7. **Geocoding today** uses Nominatim (OpenStreetMap), not Mapbox, and there are no Mapbox references left. Nominatim's policy forbids autocomplete-as-you-type, which is one reason P4 exists.
8. **Two admin consoles** cover the same ground: Flutter (in-app) and web. Every admin capability you add must land in both, or you must say explicitly why it doesn't.
9. **The user reads terse replies** and wants work finished end to end: code, deploy and verify, not a plan. Confirm before anything irreversible or outward-facing: pushing to `origin`, opening a PR, deleting production data, or sending real SMS or push to real users.

---

## 4. What's simulated today, and what replaces it

### 4.1 Hard walls on Spark (these are why the plan was upgraded)

| # | Blocked on Spark | Current workaround (where) | Blaze replacement (phase) |
|---|---|---|---|
| 1 | **Real OTP login** | **Fake OTP.** Any 6-digit code is accepted. Every account is `p<phone>@phone.raktabandhan.local` with one shared hardcoded password (`backend.dart` `verifyFakeOtp`, `_fakeAuthPassword`). **Anyone who knows a phone number can sign in as that person.** | P0 |
| 2 | Cloud Functions of any kind | All logic runs client-side in transactions and is enforced by rules | P1 |
| 3 | Push notifications when the app is closed | In-app feed only, live while the app is open (`notifications_service.dart`). The "Notification permissions" button is a stub (`notifications_screen.dart:131`). | P2 |
| 4 | Scheduled jobs (expire requests, 90-day reactivation) | Lazy checks on read (`Backend.expireIfStale`, `Backend.maybeReactivate`). The rules let *any* signed-in user expire an overdue request. | P1 |
| 5 | Cloud Storage | ID proof is stored base64 inside `donors/{uid}.id_proof_base64` (~280 KB per doc). Story photos are disabled (`create_experience_screen.dart`). | P3 |
| 6 | Disabling or deleting another user's Auth account | Ban sets `is_banned` and rules enforce it, but the Auth account still exists. Admin "delete donor" removes Firestore docs only. | P1 |
| 7 | Custom-claims admin role | Existence of `admins/{uid}` is checked by an `exists()` read on every rule evaluation | P1 |
| 8 | Admin broadcast | Written to `audit_log` only. Nothing is delivered (`Backend.adminSendBroadcast`, web `broadcastNotification`). | P2 |
| 9 | SMS fallback (MSG91) | Not built | P5 |
| 10 | Replying to "Report an issue" / partnership inquiries | Admins can triage (status + internal note), but nothing reaches the submitter | P6 |
| 11 | Trustworthy aggregates | `public_stats/impact` is client-bumped (+1 capped by rules, so it can be spammed by +1s). Dashboard stats are computed in the browser from full-collection reads. | P1 |
| 12 | Server-side data export / full account erasure | Client-side JSON export. Account delete depends on `requires-recent-login`. | P7 |

### 4.2 Not a platform limit, still unfinished (do these too)

| Gap | Where | Fix (phase) |
|---|---|---|
| "Call" and "WhatsApp" buttons show "coming soon" | `match_contact_screen.dart:117,127`, `donor_found_screen.dart:95,105` | `url_launcher` with `tel:` and `https://wa.me/91…` (P8) |
| Leaderboard / Donor of the Year | `community_screen.dart` Impact tab (honest empty state) | Needs a public-handle model. Ask the user before building it (P8). |
| Likes and comments on stories | Not modelled | Subcollection plus a counter maintained by a Function (P8, optional) |
| Address search quality | Nominatim only | Google Places Autocomplete, India-biased (P4) |
| Admin egress | `AdminService.init()` streams the whole `donors` collection including base64 ID proofs. That was 62–92% of all egress in the cost model. | Storage migration (P3) plus paginated admin lists (P9) |
| Placeholder copy | About, Certificate, Help contact, "version placeholder" in `app_header.dart:185` | Needs real copy from the team (see `STAKEHOLDER_REQUIREMENTS_CHECKLIST.md`). Don't invent it. List it in the final report. |

---

## 5. Prerequisites the user does (verify each before the phase that needs it)

- [ ] Project is on **Blaze** (Console → Usage and billing).
- [ ] A **budget alert** exists (e.g. ₹1,000 and ₹5,000/month) in Google Cloud Billing. Do not start P1 without one.
- [ ] Firestore location is known (Console → Firestore → settings). Deploy Functions to the matching region, `asia-south1` (Mumbai) if Firestore is there.
- [ ] Phone Authentication is enabled (Console → Authentication → Sign-in method → Phone). Add test numbers for development.
- [ ] Android SHA-1 and SHA-256 fingerprints are added to the Android app in project settings. Phone auth (Play Integrity / reCAPTCHA) needs them. Re-download `google-services.json` afterwards.
- [ ] Cloud Storage bucket is created (Console → Storage → Get started, same region).
- [ ] **Google Maps Platform** key with Places API (New) and Geocoding API enabled, restricted to the Android app (package plus SHA-1) and to those two APIs. Needed for P4.
- [ ] **MSG91** (or another Indian DLT-registered SMS provider) account, auth key, sender ID and DLT template IDs. Needed for P5 only.
- [ ] Email for inbox replies: the Firebase "Trigger Email" extension plus SMTP credentials, or a SendGrid key. Needed for P6 only.

If a prerequisite is missing, build everything that doesn't depend on it, then
tell the user exactly which item is blocking which phase.

---

## 6. Phases

Every phase must leave `flutter analyze` and `npx tsc --noEmit` clean, keep
tests passing, update `backend/README.md` (remove the Spark workaround from
the tables and describe the real mechanism), and deploy whatever changed.

### P0 — Real phone OTP (security, do first)

**Goal:** a person can sign in only by proving they control the phone number.

1. Replace `verifyFakeOtp` with Firebase Phone Auth (`FirebaseAuth.verifyPhoneNumber` → `PhoneAuthProvider.credential` → `signInWithCredential`). Wire `otp_screen.dart` to the real `verificationId`, resend with a cooldown, auto-retrieval on Android, and real error states (`invalid-verification-code`, `too-many-requests`, `quota-exceeded`).
2. **Migration of existing fake accounts.** Existing users have uid X under the fake email and would get a new uid Y under phone auth. Write a callable Function `migrateLegacyAccount` that runs after a successful phone sign-in (uid Y). It finds the legacy Auth user by the email `p<phone>@phone.raktabandhan.local` and, if found, copies `donors/X` to `donors/Y` and `donors_public/X` to `donors_public/Y`. It re-points `requests.requester_uid`, `requests.matched_donor_id`, `donation_history.donor_id`, `community_stories.author_uid`, `issue_reports.reporter_uid` and `partnership_inquiries.requester_uid` from X to Y, deletes the legacy Auth user, and writes an `audit_log` entry. Make it idempotent.
3. Remove `_fakeAuthPassword` and `_fakeAuthEmailDomain` entirely once migration exists.
4. Enable **App Check** (Play Integrity on Android, reCAPTCHA Enterprise on the web admin). Enforce it on Firestore, Storage and Functions after verifying that the release build passes.
5. The admin console keeps email/password. Admins are separate accounts.

**Accept when:** a wrong OTP is rejected; a second phone can't sign in as the first; an existing test account signs in with a real OTP and still sees its profile, requests and history.

### P1 — Cloud Functions backbone

Create `functions/` in TypeScript (Node 20, firebase-functions v2, region from §5). Add `"functions"` to `firebase.json`. Use `defineSecret` for secrets.

Move trust-sensitive logic server-side:

1. **Admin custom claims.** Add a callable `setAdminRole({uid, admin})`, admin-only, that sets `{admin: true}` and keeps `admins/{uid}` in sync. Add a one-off script to backfill claims for existing `admins/*`. Switch rules `isAdmin()` to `request.auth.token.admin == true`. That removes an `exists()` read from every rule evaluation.
2. **Ban and delete at the Auth level.** Ban calls `auth.updateUser(uid, {disabled: true})` plus `revokeRefreshTokens`, and unban reverses it. Admin delete-donor deletes the Auth user too (Firestore cleanup plus `auth.deleteUser`). Update both consoles to call these callables instead of writing directly, and remove the "sign-in stays active" warnings.
3. **Request lifecycle.** Add callables `acceptRequest`, `markFulfilled`, `cancelRequest` and `adminConfirmDonation` that run the same transactions `backend.dart` runs today, server-side. Tighten `requests` rules so clients can create only; every transition goes through a Function. Keep the one-active-match rule (`donors.active_request_id`).
4. **Scheduled jobs.** `expireOpenRequests` runs every 15 minutes and flips `open` requests past `expires_at` to `expired`. `reactivateDonors` runs daily and sets `is_available = true` where `reactivation_scheduled_at <= now` and the donor isn't banned. Then remove the lazy client paths (`expireIfStale`, `maybeReactivate`) and the "any signed-in user may expire" rule clause.
5. **Aggregates.** An `onDocumentUpdated('requests/{id}')` trigger maintains `public_stats/impact` (monthly), with lifetime totals in `public_stats/totals`. Make `public_stats` read-only for clients (admin override stays, via a callable). Remove `_bumpImpactCounter` from the client.
6. **Contact reveal.** Phone numbers today are denormalised onto the request doc at accept time. Keep the denormalisation but write it only from the Function, so a client can never self-assign contact fields.

**Accept when:** the rules no longer contain a client-writable status transition; ban blocks sign-in outright; expiry and reactivation happen with no client open; the impact counter can't be moved by a normal user.

### P2 — Push notifications (FCM)

1. Add `firebase_messaging` (and `flutter_local_notifications` for foreground display). Request permission from the existing "Notification permissions" button (`notifications_screen.dart`) and on first match-relevant action. Store tokens in `users/{uid}/fcm_tokens/{token}` with `platform` and `updated_at`, and prune tokens that fail with `registration-token-not-registered`.
2. Triggers:
   - `onRequestCreated` finds compatible (blood-group compatibility table), available, verified, non-banned donors within radius using the existing geohash fields, and sends a push to each. Cap fan-out (e.g. nearest 50). Mark urgency in the payload.
   - Status changes (matched, cancelled, fulfilled, expired) notify the other party.
3. Tapping a notification deep-links to `RequestDetailScreen` (`AppNotification.requestId` already exists).
4. **Admin broadcast** does real delivery to an audience (all donors or one blood group, optional area), rate-limited, with the result count written to `audit_log`. Wire it in both consoles and remove the "logged only" copy.
5. Keep the existing in-app feed as the history view.

**Accept when:** with the app killed, phone B receives a push within seconds of phone A creating a compatible request; a broadcast arrives on a test device.

### P3 — Cloud Storage (ID proofs, story photos)

1. Add a `storage.rules` file to `firebase.json`. `id_proofs/{uid}/*` is writable by the owner, readable by the owner and admins, image only, ≤ 2 MB. `story_photos/{storyId}/*` is writable by the story author, readable by signed-in users, image only, ≤ 3 MB.
2. `Backend.uploadIdProof` uploads to Storage and saves `id_proof_path` on `donors/{uid}`. Remove `id_proof_base64`. Admin screens (Flutter `admin_donor_detail_screen.dart`, web DonorsPage) load it with a download URL.
3. **Migration Function** (callable, admin-only, batched, resumable): for each donor with `id_proof_base64`, decode it, upload it, set `id_proof_path` and delete the base64 field. Report counts.
4. Story photos: enable "Add photo" in `create_experience_screen.dart` (`image_picker` is already a dependency; compress with `maxWidth: 1280, imageQuality: 70`). Render photos in the Community feed and in admin moderation. Deleting a story deletes its photos (trigger).

**Accept when:** no donor doc contains base64; the admin console no longer downloads ID images as part of the list stream.

### P4 — Google Places address search (India)

1. Key via `--dart-define=MAPS_API_KEY=...`, read with `String.fromEnvironment('MAPS_API_KEY')`. With no key, fall back to the current Nominatim path unchanged.
2. Use a provider interface with two implementations: Google (Places Autocomplete (New) + Place Details / Geocoding) and OSM (existing). Set `includedRegionCodes: ['in']`, bias to the device location, and **use session tokens** so one address costs one session, not one call per keystroke. Keep the 400 ms debounce and set a minimum of 3 characters.
3. **Cost rule from the cost model:** at scale, type-ahead on Google costs the most in the whole app. Implement both modes behind a flag: `google` (autocomplete on Google) and `hybrid` (OSM for type-ahead, Google Geocoding only for the final pick). Default to `hybrid`.
4. Reverse geocoding for "use current location" (Uber/Rapido-style) goes through the same provider.

**Accept when:** typing a street name in an Indian city returns street-level suggestions that can be selected; a build with no key still works through OSM.

### P5 — SMS fallback (MSG91)

1. A Function sends an SMS to the top N compatible donors for **critical** requests when no one accepts within X minutes (a scheduled check or a Cloud Tasks delay). Use DLT-registered templates only. Store the auth key as a secret.
2. Per-request and per-day caps, logged in `audit_log`, with an admin toggle to disable it.
3. **Do not send real SMS during development.** Use a dry-run flag that logs instead of sending, and ask the user before the first real send.

### P6 — Inbox replies

1. Add a reply box on issue reports and partnership inquiries in both consoles. The Function sends email with Trigger Email or SendGrid (partnership inquiries have `work_email`), and an in-app notification for issue reports (the reporter's uid is known).
2. Store the thread as `issue_reports/{id}/replies/{replyId}`. Show the admin's replies to the reporter in the app (a "My reports" list under Help & support).
3. Remove the "no reply channel" copy from `InboxPage.tsx`, `admin_dashboard_screen.dart` and `backend/README.md`.

### P7 — Account lifecycle

1. `deleteMyAccount` becomes a callable that deletes the Auth user and all personal docs server-side (no `requires-recent-login` dead end). It keeps anonymised `donation_history` for recipients' records, as today.
2. Optional: a server-side export that writes JSON to Storage and returns a signed URL.

### P8 — Non-platform gaps

1. Call / WhatsApp: add `url_launcher`. `tel:+91XXXXXXXXXX` and `https://wa.me/91XXXXXXXXXX?text=...` use the revealed contact on the match screens.
2. Ask the user before building the Leaderboard / Donor of the Year and likes/comments (they need a public-handle and privacy decision). If approved, add a `display_handle` on `donors_public`, opt-in, with counters maintained by Functions.
3. Placeholder copy: collect every placeholder string into the final report for the team. Don't write copy yourself.

### P9 — Cost and scale hygiene

1. Paginate the admin donor and request lists in both consoles (`limit` plus `startAfter`, infinite scroll), with server-side search where it matters (e.g. by phone). Dashboard stats come from `public_stats/*` maintained by Functions, not from full-collection streams.
2. Add composite indexes for any new queries to `backend/firestore.indexes.json` and deploy them.
3. Keep Functions `minInstances: 0`, set `maxInstances` caps, and add a `concurrency` setting where it's safe.
4. Re-run the cost estimate at 1k / 3k / 7k / 12k users with India Maps pricing (70k free events per SKU per month) and confirm it stays within the budget alert.

---

## 7. End-to-end verification (all must pass before reporting done)

Use two real Android phones (A, B) plus the web console. Use test phone numbers for OTP where possible.

1. A signs in with a real OTP; a wrong code fails.
2. A registers (name, blood group, location picked through the new search) and appears as "Pending" in **both** admin consoles.
3. Admin verifies A. A's badge updates live.
4. B registers, marks available. A creates a compatible critical request. **B gets a push with the app killed.**
5. B accepts. A sees the match and B's contact. Call and WhatsApp open the dialer and WhatsApp. A third account can't read the matched request (test the rule).
6. B marks it fulfilled. `donation_history` is written, B's 90-day cooldown starts, and the Impact counter increments server-side.
7. A request left open past `expires_at` flips to `expired` with every client closed.
8. Admin bans B. B is signed out and can't sign back in. Unban restores B.
9. B uploads an ID proof. It's in Storage, not in the doc. Admin views it.
10. A posts a story with a photo. Admin hides it, unhides it, then deletes it, and the photo is gone from Storage.
11. A files "Report an issue". Admin replies. A sees the reply in the app.
12. Admin sends a broadcast to one blood group. Only matching test devices receive it.
13. Admin deletes a test donor. The Auth user is gone too.
14. `flutter analyze`, `flutter test`, `npx tsc --noEmit` and `npm run build` are clean. Rules, indexes, storage rules, functions and hosting are all deployed.

---

## 8. Final report to the user

Keep it short. Cover:

- What was built per phase, with deploy status.
- Anything skipped or blocked, and which prerequisite blocks it.
- The migration results (legacy accounts migrated, ID proofs moved).
- The list of placeholder copy the team still needs to supply.
- Updated monthly cost estimate.
- Remaining risks.

Don't push or open a PR unless the user asks. When they do: clean
commits, no build artefacts or secrets, and no adding anyone as a collaborator.
