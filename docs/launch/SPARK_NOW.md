# Spark now

Current owner choice: **demo sign-in until Blaze**, no Firebase service-account key on Cloudflare. See [decisions](DECISIONS.md).

The Worker handles photos and TURN only. It does not provide real sign-in, push delivery, privileged admin Auth actions or cron jobs. Firebase rules and client transactions enforce data invariants; lazy expiry/reactivation remains available.

See the [complete Windows Cloudflare walkthrough](CLOUDFLARE_SETUP.md) for account creation, R2 subscription/bucket, TURN keys, login prompts and Worker verification. Resend remains pending. Owner-only setup (the agent does not run these commands):

```sh
cd edge
npm ci
npx wrangler login
npx wrangler deploy
npx wrangler secret put TURN_KEY_ID
npx wrangler secret put TURN_API_TOKEN
npx wrangler deploy
```

Create the TURN key in Cloudflare Realtime. Set `ALLOWED_ORIGINS` to the exact admin/web origins before deploying. Do not set `AUTH_EMULATOR` or emulator host variables in production. No D1 database, Resend key or Firebase key is needed by this Worker.

Owner deploys Spark-safe Firebase pieces separately:

```sh
firebase deploy --project rakta-bandhan2026 --only firestore:rules,firestore:indexes,hosting
```

Keep `config/features.server_jobs=false` and `phone_required=false`. Do not deploy Cloud Functions on Spark. `backend/storage.rules` remains for legacy tests; new app uploads use R2, and `firebase_storage` is removed.

Build the current demo APK:

```sh
flutter build apk --release --dart-define=DEMO_SIGNIN=true
```

After upgrading to Blaze and deploying Functions, build with `--dart-define=EDGE_URL=https://<worker-host>` and **without** `DEMO_SIGNIN`. The admin console needs `VITE_EDGE_URL=https://<worker-host>` at build time. Neither value is a secret. Until then a non-demo build cannot perform real email sign-in.

JPEG uploads are resized to at most 1440 pixels and quality 78, capped at 2 MB. Community/avatar links are public to anyone who has a link; ID-photo reads require an owner/admin bearer token. Legacy Firestore ID proofs remain a read fallback, with no bulk migration. Existing request phone fields require owner cleanup before using a new policy on historical data; new requests cannot contain them.

Continue with [after Blaze](AFTER_BLAZE_UPGRADE.md) and [external connections](EXTERNAL_CONNECTIONS.md).
