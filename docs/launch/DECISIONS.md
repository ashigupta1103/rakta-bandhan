# Owner decisions, 2026-10-02

- No domain has been purchased. Real email delivery remains pending a verified domain.
- Use demo sign-in until Blaze. Real sign-in stays in Cloud Functions; do not provision or upload a Firebase service-account key to Cloudflare. Handoff steps 1 and 2 and key-dependent Worker admin/cron routes are deferred by this choice.
- Usernames are required, lowercase, start with a letter, 3–20 characters (`a-z`, digits, `_`), changeable once every 30 days, shown as `@name` on posts and chat.
- Phone checking remains simulated in demo builds. Real phone ownership is unverified and the gate stays off.
- Push delivery remains pending Blaze. In-app Firestore notifications still work; demo notifications are simulated.
- Do not copy phone numbers onto requests. Private donor profiles remain accessible to the owner and administrators.
- Future PR base: `master`. Owner performs all deployments. Agent does not push or deploy.
- Owner performs real-device and external-service testing. Local analysis, compile checks and small regression tests remain development checks.
