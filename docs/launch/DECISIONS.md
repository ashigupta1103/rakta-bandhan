# Owner decisions, 2026-10-02

- No domain has been purchased. The owner reconfirmed leaving Resend and real email delivery pending; Cloudflare setup can proceed without a purchased domain.
- Demo mode is removed from the app (2026-10-02, owner request). The app is real wherever the free Firebase plan allows; only what needs an outside service is simulated, and labelled as such. Sign-in is email + password with Firebase's own verification email until Blaze; the emailed 6-digit code (Cloud Functions) takes over with `--dart-define=EMAIL_CODE_LIVE=true`. Do not provision or upload a Firebase service-account key to Cloudflare. Handoff steps 1 and 2 and key-dependent Worker admin/cron routes are deferred by this choice.
- Usernames are required, lowercase, start with a letter, 3–20 characters (`a-z`, digits, `_`), changeable once every 30 days, shown as `@name` on posts and chat.
- The phone-number check after registration is a labelled simulation (code `246810`, nothing is sent or verified) until an SMS / WhatsApp / Truecaller provider exists. Real phone ownership is unverified and the gate stays off.
- Push delivery remains pending Blaze. In-app Firestore notifications still work.
- Do not copy phone numbers onto requests. Private donor profiles remain accessible to the owner and administrators.
- Future PR base: `master`. Owner performs all deployments. Agent does not push or deploy.
- Exception, 2026-10-02: the owner told the agent to complete the Cloudflare setup itself, so the agent deployed the Worker and set its TURN secrets. This covers only that Cloudflare work. Firebase deployments, pushes and pull requests remain owner-run unless the owner says otherwise.
- Owner performs real-device and external-service testing. Local analysis, compile checks and small regression tests remain development checks.
