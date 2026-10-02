# External connections

The agent builds the clients and server code locally. The owner creates accounts, provides credentials privately, deploys and tests the connections. Nothing in this checklist confirms a live connection. See [activation inputs](ACTIVATION_INPUTS.md) for the exact information and secret destinations, including the first-deploy secret bindings.

| Connection | Owner setup | Configuration | Current activation |
|---|---|---|---|
| Firebase | Keep the existing project; create an Auth admin plus `admins/<uid>`; deploy rules/indexes | Existing client config; no secret key in the app | Demo until Blaze for donor email sign-in |
| Cloudflare photos | Create account and `rakta-bandhan-media` R2 bucket; deploy `edge/` | `EDGE_URL` in Flutter, `VITE_EDGE_URL` in admin; exact `ALLOWED_ORIGINS` | Owner deployment pending |
| Cloudflare TURN | Create TURN key in Realtime; put `TURN_KEY_ID` and `TURN_API_TOKEN` into Worker secrets | Never place the TURN API token in an app or `.env` committed to Git | Owner setup pending; STUN fallback remains |
| Resend | Buy and verify a domain, create API key and SMTP sender | Functions `SMTP_URL` secret and verified `MAIL_FROM` | Domain absent; Blaze pending |
| App Check | Register Play Integrity/release SHA-256, Apple provider and web reCAPTCHA | Web public site key; console debug tokens; enforcement stays off until verified | Owner registration pending |
| Push | Enable Cloud Functions on Blaze and verify Android/iOS configuration and device permissions | Firebase Messaging configuration and per-user private device tokens | Deferred until Blaze |
| Phone ownership | Choose and provision Truecaller or paid provider later | `phone_required=false` | Demo simulation only |
| LocationIQ | Create key; restrict it as supported by provider | `--dart-define=LOCATIONIQ_KEY=<key>` (see `geo_config.dart`) | Optional address search; owner key pending |
| Google Maps | Restrict Android key by package and release SHA-1; enable native Maps SDK | `MAPS_API_KEY` in ignored `android/local.properties`; `--dart-define=GOOGLE_MAPS=true` | Optional; OSM fallback available |
| Store publication | Owner Play Console/Apple accounts, signing material, legal approval/contact details | Private signing config; `docs/publishing/` | Owner pending |

The owner reconfirmed demo until Blaze and asked to leave Resend pending. Start with the [complete Cloudflare walkthrough](CLOUDFLARE_SETUP.md); it does not require a purchased domain. Follow [Spark now](SPARK_NOW.md), then [after Blaze](AFTER_BLAZE_UPGRADE.md) when real sign-in is wanted. No D1 database or Firebase key on Cloudflare is needed under the accepted plan.

Public client configuration identifies the project; server keys grant privileges and must stay in secret stores. Native app defines are recoverable from binaries: never put Resend, TURN API or service-account credentials there.
