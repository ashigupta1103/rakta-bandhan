# Running cost — Firebase Blaze, first 6 months

**Load assumed:** 5,000 new signups/month, 2,000 monthly active users (MAU), India.
**Architecture assumed:** client-side first (as today). Server-side only for what can't be done safely on the client:
- push notifications (new match, message, incoming call, urgent alert);
- OTP sending.

Prices were checked in September 2026 (sources at the end). USD, with INR at about ₹88/$. Re-check the pricing pages before committing a budget.

## Bottom line

| | Firebase phone OTP ($0.07/SMS) | Own OTP via an Indian SMS/WhatsApp provider |
|---|---|---|
| **Per month** | **≈ $410–470** (₹36k–41k) | **≈ $30–95** (₹2.6k–8.4k) |
| **6 months** | ≈ $2,500–2,800 | ≈ $200–600 |

**OTP is ~85–95% of the bill.** Everything else — database, functions, push, hosting, calls — comes to $5–60/month at this size. The single biggest saving is sending OTPs through an Indian DLT-registered provider (or WhatsApp authentication messages) from one small Cloud Function, instead of Firebase Phone Auth.

## Line by line (per month)

### 1. OTP — the dominant cost
- **SMS sent:** about 5,950 a month.
  - 5,000 signups × 1.15 (resends and failed attempts) = 5,750.
  - Plus re-logins: 10% of MAU = 200.
- **Firebase Phone Auth:** 10 SMS a day are free (≈300 a month).
  - Billable: 5,650 × $0.07 = **≈ $396**.
- **Own OTP function:** a DLT-registered SMS provider costs about ₹0.13–0.25 per SMS (WhatsApp authentication templates are about ₹0.12).
  - 5,950 × ≈ ₹0.2 = **≈ ₹1,200 (≈ $14)**.
  - The function mints a Firebase custom token, so the rest of the app is unchanged.
  - One-time TRAI DLT entity and template registration applies.
- Either way, turn on **App Check** and restrict SMS to +91 before launch. OTP endpoints are the classic target of SMS-pumping fraud, which can cost far more than real usage.

### 2. Firestore — about $5–13
DAU is taken as about 25% of MAU, so 500 a day. Registered donors grow by 5,000 a month, reaching about 30,000 by month 6.

**Reads per day**
- **Find map:** 750 opens × ~300–900 donors (bounded query, see note) = 225k–675k.
- **Home and Request lists** (open requests, typically under 50): about 45k.
- **Profile, inbox, chat and calls:** about 20k.
- **Total:** about 290k–740k a day, against 50k a day free.
- **Billable:** about 7–21M a month × $0.06 per 100k = **$4–13**.

**Other operations**
- **Writes:** registration, messages (plus the inbox preview), call setup and read markers come to about 5–8k a day. That's under the 20k a day free, so **$0**.
- **Storage:** donors plus ID images reach about 2 GB by month 6. At about $0.18/GiB beyond the free 1 GiB, that's **under $1**.

> **Fixed in this branch:** before, the Find map and matching screen read *every* available donor on each open. At 30,000 donors that's about 15M reads a day, or **$270+/month and rising every month**. They now query only the ~15 km around the search point, capped at 900 donors per open (`lib/services/nearby_donors.dart`). The ID-proof image also moved out of the profile document, so the ~10 profile reads per user per day no longer download ~200 KB each (`Backend.uploadIdProof`).

### 3. Cloud Functions — $0
Expected triggers:
- new request → urgent-alert fan-out to nearby opted-in donors via FCM;
- new message → push;
- new call → VoIP/FCM push;
- request matched → push;
- OTP send/verify.

That's about 80k invocations a month against 2M free, and about 10k GB-seconds against 400k free. Keep `minInstances: 0`. Container images in Artifact Registry are free up to 0.5 GB.

### 4. Push (FCM), Analytics, Hosting — $0
- **FCM and Google Analytics** are free on every plan.
- **Hosting** (admin dashboard and the legal pages) is well inside the free 10 GB of storage and 360 MB a day of transfer.

### 5. Calls — about $0–1
Call audio is peer-to-peer, so Firebase only carries the handshake (a few writes per call).
- Some mobile networks need a TURN relay. Cloudflare TURN is $0.05 per GB.
- Usage: about 1,200 calls a month × 3 min, with 20% relayed at about 0.6 MB/min, comes to about 0.4 GB, so **about $0.02**.
- The TURN slot is `callIceServers` in `lib/services/call_service.dart`.

### 6. Maps and address search — about $0–50 (verify)
- The app uses OpenStreetMap's public tile and Nominatim servers. Their usage policies are not meant for production apps: no heavy tile use, and no search-as-you-type on Nominatim.
- At about 750 map opens a day (about 20k tile loads), move to a hosted provider before launch, such as MapTiler, Stadia or Carto for tiles, and LocationIQ for geocoding (it has a free daily quota).
- Budget **$0–50 a month** depending on the provider and plan.

### 7. Fixed costs
- **Apple Developer Program:** $99 a year (≈ $8 a month).
- **Google Play:** $25 one-time.
- **iOS builds:** Codemagic's free tier covers occasional builds; a Mac is the alternative.

## Guardrails to set on day one of Blaze
1. **Google Cloud budget** with alerts at 50%, 90% and 100% of what you expect to spend. Blaze has no hard cap; alerts are the safety net.
2. **App Check** on Firestore, Functions and Auth.
3. **Phone Auth SMS region policy:** allow India only.
4. Check the **Firestore usage dashboard** weekly for the first month. Read spikes almost always mean a listener re-subscribing in a loop.

## Sources
- [Firebase pricing](https://firebase.google.com/pricing)
- [Identity Platform (phone auth SMS) pricing](https://cloud.google.com/identity-platform/pricing)
- [Firestore pricing](https://firebase.google.com/docs/firestore/pricing)
- [Cloudflare TURN](https://developers.cloudflare.com/realtime/turn/)
- [India OTP SMS pricing overview](https://www.mtalkz.com/blog/otp-sms-pricing-guide-india)
