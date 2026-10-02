# Spark now (free Firebase plan)

The app is built to run for real on the free plan. This page says what is real, what is simulated, what needs Blaze, and the few things only the owner can do.

Status: the Cloudflare Worker is deployed (2026-10-02), see [build status](BUILD_STATUS.md). Owner choice: no Firebase service-account key on Cloudflare. See [decisions](DECISIONS.md).

## What works for real

| Area | How |
|---|---|
| Sign-up and sign-in | Email + password. "Forgot password" sends Firebase's reset email (free). The email check after sign-up is simulated, see below. |
| Profiles and usernames | Firestore, with the atomic username claim (`usernames/{name}`) and the private/public donor pair. |
| Requests and matching | Open requests are found by geohash, a donor accepts in a transaction, one active match per donor, two-sided confirmation, 90-day rest. Expiry and reactivation run lazily in the app. |
| Chat and in-app calls | Firestore carries messages and the call handshake; the Cloudflare Worker supplies TURN relay credentials. |
| Photos | Cloudflare R2 through the Worker: profile photos, community posts, ID proofs. |
| Community, testimonials, support | Real Firestore collections; the admin console moderates them. Support replies arrive in-app. |
| Notifications | The in-app feed and, while the app is open, live call, alert and chat banners. |
| Data rights | JSON export and in-app deletion (asks the password again, then removes the data and the sign-in account). |
| Admin console | Email + password, reads and writes Firestore directly. |

## What is simulated

Both steps say "Simulation", send nothing, verify nothing, and have "Skip for now".

- **The email check** after sign-up (code `123456`). No email sender is connected, so an address is never proven. Until then the rules and the photo Worker accept unproven accounts. After Blaze, set `config/features.email_verified_required = true` to require proof again.
- **The phone-number check** after registration (code `246810`). No SMS, WhatsApp or Truecaller provider is connected; only a server can set `phone_verified_for`. The phone gate in the rules stays off (`phone_required=false`).

## What needs Blaze (or another outside service)

- The emailed 6-digit sign-in code (Cloud Functions + an email sender). Build with `--dart-define=EMAIL_CODE_LIVE=true` once it is deployed; see [after Blaze](AFTER_BLAZE_UPGRADE.md).
- Push notifications while the app is closed or in the background, and the native incoming-call screen. The app registers its token already; nothing can send until Functions exist.
- Server-side expiry and reactivation jobs, email replies to support, disabling or deleting another person's sign-in account.

## What only the owner can do

1. **Switch on Email/Password sign-in:** Firebase console → Authentication → Sign-in method → Email/Password → Enable. Without it the app shows "Email sign-in isn’t switched on for this project yet".
2. **Deploy the rules and indexes.** The app uses collections and queries the old rules and indexes do not have (usernames, support replies, geohash queries), so registration and requests fail until this is done:

   ```sh
   firebase deploy --project rakta-bandhan2026 --only firestore:rules,firestore:indexes
   ```

   Indexes take a few minutes to build; wait until they all show *Enabled* in the console.
3. **Create the first admin** (only needed for the admin console): create an email + password user in Authentication, then add a document `admins/<that user's uid>` in Firestore. See [backend/README.md](../../backend/README.md).
4. **Leave** `config/features` alone: `server_jobs` and `phone_required` default to false, which is what the free plan needs.

## Build

```sh
flutter build apk --release
```

`EDGE_URL` defaults to the deployed Worker (`https://rakta-bandhan-edge.rakta-bandhan-edge.workers.dev`, not a secret). Override it with `--dart-define=EDGE_URL=...` only to point a build somewhere else. The admin console needs `VITE_EDGE_URL` set to the same address at build time (already in the ignored `admin/frontend/.env.local`).

## Cloudflare Worker setup

Already run on 2026-10-02; kept for a fresh account. See the [Cloudflare walkthrough](CLOUDFLARE_SETUP.md).

```sh
cd edge
npm ci
npx wrangler login
npx wrangler deploy
npx wrangler secret put TURN_KEY_ID
npx wrangler secret put TURN_API_TOKEN
```

Set `ALLOWED_ORIGINS` to the exact admin/web origins before deploying. Do not set `AUTH_EMULATOR` or emulator host variables in production. No D1 database, Resend key or Firebase key is needed by this Worker.

## Notes

JPEG uploads are resized to at most 1440 pixels and quality 78, capped at 2 MB. Community and avatar links are public to anyone who has a link; ID-photo reads require an owner or admin bearer token. Legacy Firestore ID proofs remain a read fallback, with no bulk migration. Existing request phone fields need owner cleanup before using the new policy on historical data; new requests cannot contain them. `backend/storage.rules` remains for legacy tests; the app no longer uses Firebase Storage.

Continue with [after Blaze](AFTER_BLAZE_UPGRADE.md) and [external connections](EXTERNAL_CONNECTIONS.md).
