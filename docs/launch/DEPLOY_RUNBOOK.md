# Owner deploy runbook

The agent does not push, deploy or mutate production. PR base is `master`.

## Local build checks

```sh
bash tool/preflight.sh
cd functions
npm run build
npm run smoke
```

Smoke tests use `demo-rakta-bandhan` emulators. Local emulator secrets are dummy values in ignored `functions/.secret.local`; never reuse them in production. Long build/check commands should run in the background.

## Deploy order

1. Review the branch and secrets/configuration. Keep existing UI changes. Read [external connections](EXTERNAL_CONNECTIONS.md).
2. Complete Cloudflare setup from [Spark now](SPARK_NOW.md), deploy the Worker, and record its HTTPS URL. Verify its CORS origins and private ID-photo access before using it.
3. Build the admin with `VITE_EDGE_URL` (and optional `VITE_RECAPTCHA_SITE_KEY`) in an ignored `.env.local`. Run `npm ci`, `npx tsc --noEmit`, `npm run build`, `npm run lint` in `admin/frontend`.
4. Deploy Firestore rules/indexes and Hosting with an explicit project:

   ```sh
   firebase deploy --project rakta-bandhan2026 --only firestore:rules,firestore:indexes,hosting
   ```

   Wait for indexes to finish building. Existing donors need a `name_lower` backfill before name-prefix search can find them. Review the migration script and run it as owner after a backup; never invent usernames for existing users. From `functions/`:

   ```sh
   node scripts/backfill-search.mjs --project rakta-bandhan2026 --yes-live
   node scripts/backfill-search.mjs --project rakta-bandhan2026 --yes-live --apply
   ```

   The script uses the Admin SDK and needs owner Application Default Credentials with Firestore access; Firebase CLI login alone does not provide these. The owner can configure local ADC with `gcloud auth application-default login` following [Google's Firestore authentication guide](https://docs.cloud.google.com/firestore/native/docs/authentication). The agent does not run that login or the live migration.

   The first command is a dry run. Review historical phone removal separately: add `--cleanup-request-phones` to a dry run, then `--apply` only after owner approval/backup. The agent runs this script only against emulators. New requests never include phone fields.
5. On Spark, leave `server_jobs=false`, `phone_required=false`, real sign-in and delivery pending.
6. After Blaze, follow [the upgrade checklist](AFTER_BLAZE_UPGRADE.md) and deploy Functions explicitly:

   ```sh
   firebase deploy --project rakta-bandhan2026 --only functions
   ```

   Turn on `server_jobs` only after server jobs are verified. Enable App Check enforcement last.
7. Build artifacts:

   ```sh
   flutter build apk --release --dart-define=EDGE_URL=https://rakta-bandhan-edge.rakta-bandhan-edge.workers.dev
   ```

   This produces the real app and requires the owner-deployed services. Verify signing and legal approval before store release.

## Owner acceptance

Use two real devices/accounts for sign-in, username uniqueness/cooldown, photo upload and ID privacy, raise/accept, chat, call relay across networks, completion/rest period, admin actions, support replies and account deletion. Check an old donor can choose a username once. Check private phone numbers are absent from new request documents and review historical phone-field cleanup before publishing the new privacy policy.

Admin donor search: name prefix, exact email, exact Indian mobile number, or `@username` prefix. A live change to the newest page resets loaded older pages; use Load more again. Totals use aggregate queries; sampled charts identify the sample. My reports shows the newest 50 submissions and 100 replies; older private inbox entries get an author copy when an admin first replies.

`ENABLE_SUPPORT_DELIVERY=false` is the default. Switching it on affects new replies only. Delivery claims prevent automatic duplicate sends; a failed or interrupted delivery remains available in-app and is not automatically retried. Inspect delivery state before sending a new reply.

Rollback: keep the prior APK/admin build and reviewed rules. Restore the previous app/hosting build if needed; do not weaken privacy rules to make an old app's phone-copying writes succeed. Disable `server_jobs` only together with a compatible client impact path. No rollback command here deletes owner data.
