# Cloudflare setup on this Windows machine

Owner walkthrough, checked against Cloudflare's documentation on 2026-10-02. Keep Firebase on Spark and keep the demo APK. Resend, real email sign-in, push and real phone verification remain pending. This setup prepares photos and call relay for the later real app.

## 1. Create or open the account

1. Open [Cloudflare sign-up](https://dash.cloudflare.com/sign-up), or [log in](https://dash.cloudflare.com/login) if you already have an account.
2. Verify your email and select the account that will own Rakta Bandhan's resources.
3. Use the Workers Free plan. A purchased domain is not needed: the Worker can use a Cloudflare-provided `workers.dev` address. [Worker deployment documentation](https://developers.cloudflare.com/workers/get-started/guide/).
4. Copy your account ID: press **Ctrl+K** in the dashboard, search **Copy account ID**, and select it. Alternatively, find Account Details under Workers & Pages. The account ID can be shared with Codex; it is not an API token. [Official account-ID instructions](https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/).

## 2. Enable R2 and create the photo bucket

1. In the account dashboard, open **Storage & databases > R2 > Overview**. If R2 is not activated, complete its subscription checkout yourself. Cloudflare requires an R2 subscription; included free usage does not make all usage unlimited. [R2 setup](https://developers.cloudflare.com/r2/get-started/).
2. Select **Create bucket**.
3. Enter exactly **`rakta-bandhan-media`** as the bucket name.
4. Select **Standard** storage; leave the location selection at its default unless the owner has a specific data-location requirement.
5. Finish creating the bucket. Keep direct public access, `r2.dev` access and bucket custom domains disabled. The Worker serves public community/avatar links and checks authentication for ID proofs.
6. No R2 API token or S3 access key is needed. The repo already binds this bucket to the Worker as `MEDIA` in `edge/wrangler.toml`.

R2 Standard includes **10 GB-month of storage, 1 million Class A operations and 10 million Class B operations per month**. Usage beyond the allowance is billed; monitor R2 usage and billing. [R2 pricing](https://developers.cloudflare.com/r2/pricing/).

## 3. Create the TURN key for call relay

1. Open Cloudflare's [Realtime dashboard shortcut](https://dash.cloudflare.com/?to=/:account/calls) and select the same account. In the dashboard navigation this may appear under **Media > Realtime**; choose the **TURN** / **TURN Server** section.
2. Create a TURN key and give it a recognisable project label, for example `rakta-bandhan`.
3. Save the returned **key ID** and its **API token** privately. If the token is shown only once, save it before leaving the page.
4. The app's Worker secret names are **`TURN_KEY_ID`** and **`TURN_API_TOKEN`**. Use the API token belonging to the TURN key, rather than a general Cloudflare account API token.

These credentials stay on the Worker. The existing `/ice` route checks that the signed-in caller is one of the two people on a matched request, then requests credentials lasting one hour. The long-lived TURN key never belongs in the APK. [Cloudflare TURN credentials](https://developers.cloudflare.com/realtime/turn/generate-credentials/).

Cloudflare's TURN service has a **1,000 GB monthly free tier**, shared with Realtime SFU; additional eligible egress is **$0.05/GB**. Check the account's current terms and usage before enabling it. [Realtime pricing](https://developers.cloudflare.com/realtime/sfu/platform/pricing/), [TURN FAQ](https://developers.cloudflare.com/realtime/turn/faq/).

## 4. Sign Wrangler in

On this PC, open **PowerShell**. Run each command separately and wait for it to finish:

```powershell
Set-Location -LiteralPath 'X:\BloodBankkk\edge'
npx wrangler login
npx wrangler whoami
```

The login command opens your browser. Sign in to the account above and approve Wrangler's access. Return to PowerShell; `whoami` should show that account. If there are several accounts, select the correct one with the account ID in this PowerShell session:

```powershell
$env:CLOUDFLARE_ACCOUNT_ID = 'YOUR_ACCOUNT_ID'
```

Replace only `YOUR_ACCOUNT_ID` with the actual ID. Do not run the commands under another folder, create a new Worker project, or run a temporary/anonymous deployment. Dependencies are already installed in this workspace; on a fresh checkout use `npm ci` first. Wrangler is the repo's existing deployment tool. [Cloudflare CLI guide](https://developers.cloudflare.com/workers/get-started/guide/).

## 5. Deploy the existing Worker and set its secrets

The owner runs these deployment commands. They change Cloudflare resources; Codex has not run them.

First deploy the checked-in code:

```powershell
npx wrangler deploy
```

On a new account Wrangler may ask you to choose a `workers.dev` subdomain. Choose an available account subdomain and finish that prompt. The Worker name is already `rakta-bandhan-edge`.

Then add each secret separately:

```powershell
npx wrangler secret put TURN_KEY_ID
npx wrangler secret put TURN_API_TOKEN
```

For each command, paste the corresponding value **at its interactive prompt**, then press Enter. Do not append the value to the command, put it into tracked code or paste it into chat. The first command takes the key ID; the second takes the key's API token. Afterwards deploy once more so the final code and bindings are in place:

```powershell
npx wrangler deploy
npx wrangler secret list
```

The secret list shows names, not values. Both names should be present. You do not need D1, a Firebase service-account key, a Resend key or scheduled Worker jobs for this plan.

The checked-in browser origins already include:

```text
https://rakta-bandhan2026.web.app
https://rakta-bandhan2026.firebaseapp.com
```

Use the Worker dashboard's bindings/settings to confirm `MEDIA` refers to `rakta-bandhan-media`, `FIREBASE_PROJECT_ID` is `rakta-bandhan2026`, and both secrets exist. Do not enable `AUTH_EMULATOR` or `FIRESTORE_EMULATOR_HOST` on a deployed Worker. If another admin/web domain is used later, add its exact origin to `ALLOWED_ORIGINS` in `edge/wrangler.toml` before deploying.

## 6. Copy and check the Worker address

Wrangler prints the actual deployed HTTPS address, shaped like:

```text
https://rakta-bandhan-edge.YOUR_SUBDOMAIN.workers.dev
```

Do not use the example literally. Copy your real address and open it with **`/health`** appended in a browser. Expected response:

```json
{"ok":true}
```

This proves the Worker responds. It does not prove uploads, private-photo authorization or TURN credentials. Those require real Firebase authentication and the later device acceptance tests. `/ice` is an authenticated POST endpoint, so opening it as a browser page will not generate call credentials.

Send Codex only the **account ID**, confirmation that the bucket/secrets are set, and the **Worker URL**. No server token needs to be shared in chat. The URL will be used as Flutter `EDGE_URL` and admin `VITE_EDGE_URL`.

## 7. What happens after this setup

- Continue using `build/RaktaBandhan-demo.apk`. Its simulated login/content does not use the live Worker, even if Cloudflare is deployed.
- Firebase production deployment remains reserved for the owner. Rules/indexes/Hosting and later Functions have a separate rollout in [the deploy runbook](DEPLOY_RUNBOOK.md); this guide does not change Firebase.
- After Blaze and email delivery are ready, build the real APK with `EDGE_URL` and without `DEMO_SIGNIN`. Check R2 uploads, private ID-photo access and calls across two phone networks.
- In Cloudflare, monitor Worker requests, R2 storage/operations and TURN usage. Workers Free currently allows **100,000 requests/day**. [Workers limits](https://developers.cloudflare.com/workers/platform/limits/).

If an account/billing/login prompt differs, finish only the step you understand and provide its wording. No screenshots containing API tokens are needed.

## Common setup errors

| Error | Next action |
|---|---|
| Wrangler says not authenticated | Run `npx wrangler login`, approve in the browser, then `whoami` |
| R2 subscription required | Complete the account's R2 checkout; Workers Free alone does not activate R2 |
| Bucket not found | Check the bucket name and selected account match `edge/wrangler.toml` |
| Worker URL not available | Finish the `workers.dev` subdomain prompt and use the printed URL |
| Calls return STUN only | Verify both TURN secrets; real matched-call authentication and provider verification are still needed |
| Admin photos fail with a browser-origin error | Use the intended Hosting origin, confirm `ALLOWED_ORIGINS`, and build the admin with `VITE_EDGE_URL` |

Start with steps 1-3. Once the account, bucket and TURN key exist, proceed to Wrangler login and owner deployment.
