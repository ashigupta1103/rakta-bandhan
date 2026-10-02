# Inputs for real-service activation

Checked locally on 2026-10-02, branch `feat/prelaunch`. Application/backend code and local validation are recorded in [verification](VERIFICATION.md). Real-service activation is still separate from those checks. The owner reconfirmed demo until Blaze and asked to leave Resend pending; only the Cloudflare inputs are needed now. Follow the [Cloudflare walkthrough](CLOUDFLARE_SETUP.md).

## What was checked

- Firebase CLI has a signed-in account. This does not confirm project permissions, the billing plan, the Firestore region or deployed resources; production was not queried or changed.
- Wrangler reports no authenticated Cloudflare account on this machine.
- No local Worker credentials, admin `.env.local`, Functions `.env.rakta-bandhan2026` or Android `key.properties` were present.
- Local Functions discovery exports the expected login, account, notification, expiry/reactivation and support handlers, all in `asia-south1`. Login binds `SMTP_URL` and `REVIEW_CODE`; support binds `SMTP_URL`.
- The current APK is a demo build. It cannot verify live Firebase, email, R2 or TURN connections.

## Information the owner supplies

| Input | Where it belongs | Needed for |
|---|---|---|
| Firebase Blaze status and actual Firestore region | Owner confirmation; project stays `rakta-bandhan2026` | Functions rollout; app/server regions must agree |
| Cloudflare account ID `361246d2529c9324af1bacc33d2adfb8` | Already set in `edge/wrangler.toml`; select this account for Wrangler login | Worker deployment |
| TURN Server's key ID and API token (**set 2026-10-02**; rotate them, see [build status](BUILD_STATUS.md)) | Cloudflare Worker secrets `TURN_KEY_ID` and `TURN_API_TOKEN`; see [the dashboard walkthrough](CLOUDFLARE_SETUP.md) | Authenticated short-lived relay credentials; the SFU token shared in chat does not work here and should be revoked |
| Verified Resend domain and sender address | `MAIL_FROM` in ignored `functions/.env.rakta-bandhan2026` | Email codes for real users |
| Resend API key | Firebase `SMTP_URL` secret, formatted as below | Functions email delivery |
| Production review code | Firebase `REVIEW_CODE` secret | Required secret binding for first deployment, even with review access off |
| Deployed Worker HTTPS URL | **Done 2026-10-02:** `https://rakta-bandhan-edge.rakta-bandhan-edge.workers.dev`. Flutter `EDGE_URL`; admin `VITE_EDGE_URL` (already set in the ignored `admin/frontend/.env.local`) | Photo uploads/reads/deletion and calls |
| LocationIQ key | Flutter `LOCATIONIQ_KEY` build define | Production address search; public Nominatim fallback is for development |
| Owner signing configuration and certificate fingerprints | Ignored `android/key.properties`, private keystore; Firebase App Check | Signed real APK and later enforcement |
| Google Maps key, if native maps are wanted | Ignored `android/local.properties`; package/SHA-1 restrictions | Native Android maps with `GOOGLE_MAPS=true` |
| Web reCAPTCHA site key, when registered | Admin `.env.local` as `VITE_RECAPTCHA_SITE_KEY` | Web App Check |

Share public account IDs, domain names, sender addresses and service URLs in chat. For server keys, share only an ignored local file path, or set them directly in the provider's secret store. Never share account passwords, private keys or tokens in chat. No Firebase service-account key, R2 S3 key or D1 database is needed under the accepted plan.

Resend SMTP secret format: `smtps://resend:<RESEND_API_KEY>@smtp.resend.com:465`. Provision it interactively using `npx -y firebase-tools@latest functions:secrets:set SMTP_URL --project rakta-bandhan2026`. Provision a privately generated six-digit `REVIEW_CODE` the same way. Leave `REVIEW_EMAILS` empty: having the secret bound does not enable review access for any address. Emulator/demo codes are not production credentials.

Use a project-specific ignored params file rather than editing tracked defaults:

```dotenv
# functions/.env.rakta-bandhan2026 -- replace the sender with the verified address
MAIL_FROM="Rakta Bandhan <no-reply@YOUR_VERIFIED_DOMAIN>"
REVIEW_EMAILS=
ENFORCE_APP_CHECK=false
ENABLE_SUPPORT_DELIVERY=false
```

Cloudflare requires an [R2 subscription](https://developers.cloudflare.com/r2/get-started/) before creating the bucket. Functions deployment requires [Blaze](https://firebase.google.com/docs/functions/get-started). Resend requires a [verified sending domain for other recipients](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain); its [SMTP settings](https://resend.com/docs/send-with-smtp) use the API key as password. The TURN route already matches Cloudflare's [credential API](https://developers.cloudflare.com/realtime/turn/generate-credentials/).

## Activation order

1. **Done 2026-10-02.** Wrangler is signed into the existing Cloudflare account and the TURN Server key exists. The existing private R2 bucket is `bloodbank`. The owner told the agent to complete this Cloudflare step itself; see [decisions](DECISIONS.md).
2. **Done 2026-10-02** (see [build status](BUILD_STATUS.md)): the R2/TURN Worker is deployed with both TURN secrets and the exact browser origins, and its URL is recorded above. Health, the sign-in gates and the R2 binding were checked live; private ID-photo access and relay responses for a real signed-in user still need real sign-in.
3. Configure/build the admin with the Worker URL, then deploy reviewed Firestore rules/indexes and Hosting. Wait for indexes. Review search backfill and historical phone cleanup separately; do not apply them implicitly.
4. Once Blaze and the sender are ready, provision both Functions secrets, verify region and runtime token-signing IAM permissions, then deploy Functions. Verify sign-in, bans/deletion, jobs and push on the owner's devices.
5. Set `server_jobs=true` only after server jobs are verified. Keep `phone_required=false`; real phone ownership verification is still deferred. Turn on support delivery and App Check enforcement only after their verification.
6. Build a distinct real APK without `DEMO_SIGNIN`, with `EDGE_URL` and the selected map/search configuration. Keep the existing demo APK available.

Commands and acceptance checks are in [the deploy runbook](DEPLOY_RUNBOOK.md) and [after Blaze](AFTER_BLAZE_UPGRADE.md). No external resource has been provisioned, no key uploaded and no deployment performed by this readiness check.
