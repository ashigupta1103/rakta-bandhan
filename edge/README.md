# edge: the Cloudflare Worker

Photo storage on R2 and call-relay credentials, on Cloudflare's **free plan**, so both work while Firebase is still on Spark (no Cloud Functions, no Firebase Storage).

| Route | What it does |
|---|---|
| `GET /health` | liveness check |
| `PUT` / `GET` / `DELETE /media/{kind}/{uid}/{name}` | photos in R2. `kind` is `community`, `avatars` or `id_proofs`. Only the owner uploads; ID photos are readable only by their owner or an admin |
| `POST /ice` `{requestId}` | short-lived TURN credentials for the two people on a matched request (Cloudflare Realtime TURN); STUN-only when no key is set |

**No service account.** The Worker verifies the caller's Firebase ID token against Google's public keys, and to ask "may this person do that?" it reads Firestore *with the caller's own token*, so the security rules decide. It holds no secret that could impersonate a user; the only secrets are the TURN key and token.

```bash
npm install
npm test        # unit tests against an in-memory R2 and stubbed Firebase/Cloudflare
npm run check   # bundles the Worker exactly as a deploy would, without logging in
npm run dev     # local Worker with a local R2 (add --var AUTH_EMULATOR:true to use the Auth emulator's tokens)
npm run deploy  # needs `npx wrangler login`; see docs/launch/SPARK_NOW.md for the first-time setup
```

The app finds the Worker through the `EDGE_URL` build define (`--dart-define=EDGE_URL=https://rakta-bandhan-edge.<account>.workers.dev`).
