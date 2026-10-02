# Local build status, 2026-10-02

Branch: `feat/prelaunch`. Upstream `origin/master` at `0e19c5d` was merged, preserving the updated UI. The owner approved connecting missing actions while retaining that design. No push, deployment or production Firebase mutation was performed.

## Implemented

- Demo sign-in accepts any valid email, with simulated email code `123456` and phone code `246810`.
- Functions account ban/unban/removal, bounded reactivation, request expiry, two-person completion and switchable server impact counting.
- Cloudflare R2 client uploads/downloads/deletions, JPEG compression, private ID-proof access and legacy read fallback; TURN credentials with caching and STUN fallback. Both admin clients use authenticated ID-photo access.
- Atomic username claims, signup/existing-account prompt, 30-day changes, profile/post/chat display, release on deletion and protection against late cleanup deleting a reused name.
- Community story editing saves text/topic/replacement photos through the real backend without replacing the upstream editor design.
- New request documents contain no phone numbers. The optional phone gate is enforced by rules, and clients cannot grant themselves verification.
- Both admin consoles use server search and 50-record cursor pages for donors/requests, pending verification queries and aggregate totals. Web hospital/history lists also have cursor pages. Charts based on loaded samples are labelled.
- Private support submissions/replies, My reports, reply actions in both consoles, status mirrors, export/deletion, and a disabled-by-default Functions email/push trigger.
- Nonblocking App Check activation; configurable web site keys. Server enforcement remains off until owner registration and verification.
- Owner-run, paged search backfill and optional historical request-phone cleanup; dry run by default and an explicit live-project guard.
- Local preflight and CI cover analysis, tests, emulator smoke, Worker bundle and admin checks. Hosted legal pages and privacy/store disclosures match these data changes.

## Deferred by owner choice

Worker service-account helper, D1 email sign-in, privileged Worker admin routes/cron, and Worker push delivery are deferred. Use demo until Blaze; no Firebase service-account private key belongs on Cloudflare. Truecaller/SMS/WhatsApp phone ownership verification remains pending. `phone_required=false` and `server_jobs=false` until the relevant owner rollout.

The real production acceptance in the original handoff remains pending owner provisioning/deployment and device testing. Code compilation and emulator results do not verify a live third-party connection.

## Local validation

- Flutter: analyzer clean; 65 tests pass, with the demo-only test skipped in the normal run. The defined demo test passes separately.
- Functions: 27 unit tests. Emulator smoke covers login/review accounts, lifecycle, jobs, username release/reuse, support delivery off and migration/search/cursor behaviour across 410 records.
- Edge: 23 tests and dry-run Worker bundle.
- Rules: 73 tests, including username atomicity/cooldown, phone protection, contact privacy and private support access.
- Admin: TypeScript, production build and lint pass. Seven pre-existing lint warnings remain in shared UI components; the build also reports its existing chunk-size warning.

Final check logs and APKs are local, ignored artifacts in `build/checks/` and `build/`. Re-run `bash tool/preflight.sh` for reproducible checks. In Windows use Git Bash, not an unconfigured WSL installation.

## Owner next steps

1. Install `build/RaktaBandhan-demo.apk` and do the device testing you requested.
2. Purchase a domain and create Cloudflare/Resend accounts. Follow [external connections](EXTERNAL_CONNECTIONS.md).
3. Provision/deploy R2 and TURN as described in [Spark now](SPARK_NOW.md).
4. When ready, upgrade Firebase to Blaze and follow [after Blaze](AFTER_BLAZE_UPGRADE.md) and [the deploy runbook](DEPLOY_RUNBOOK.md).
5. Configure signing, App Check, legal contacts and store accounts. Enable real delivery only after owner verification.

Publishing edits for owner review: Cloudflare photo/call transport, phone privacy, username/User ID disclosure, support submissions/replies, App Check and configured address provider; updated test/build evidence. `kLegalApproved` remains false. Existing local stash/backup safety copies were retained.
