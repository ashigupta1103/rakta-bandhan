# Running cost: cheapest setup

**Load assumed:** about 50,000 signups at launch, then 2,000–3,000 new signups a month. About 3,000–5,000 monthly active users (MAU) after the launch spike.
**Exchange rate:** ₹96/$ (25 Sep 2026).
**Architecture:** almost everything runs on the phone against Firestore, protected by security rules. The few server jobs run on **your existing server**, so no Firebase Cloud Functions are needed:
1. phone verification;
2. push notifications;
3. optionally, a nightly expiry job.

## Year 1 (you cover it)

| Item | Cheapest option | Year 1 |
|---|---|---|
| Login verification | Truecaller one-tap (Android) + "reverse WhatsApp" (everyone else) + paid OTP only as a rare fallback | **₹0–1,500** |
| Firestore: reads, writes, storage | Blaze plan, pay only above the free tier (after the optimisations below) | **₹1,500–6,000** |
| Push notifications | FCM, sent from your server with the Firebase Admin SDK | ₹0 |
| Server jobs | Your existing server (Railway ≈ $5/month ≈ ₹5,800/year if you ever need a separate one) | ₹0 |
| In-app calls | Peer-to-peer; TURN relay from Metered's free 500 MB/month, or coturn on your server | ₹0 |
| Maps | MapTiler free tier (100k tile loads/month, key needed) or OSM during development | ₹0 |
| Address search | LocationIQ free tier (5,000 requests/day) | ₹0 |
| Community photos | Cloudflare R2 (10 GB free, free downloads) | ₹0 (≈ ₹1,000/yr on Firebase Storage) |
| Apple Developer | $99/year (fee waiver possible for nonprofits) | ₹9,500 |
| Google Play | $25 **one-time** | ₹2,400 |
| **Total** | | **≈ ₹13,500–19,500** |

**Year 2 onwards** (about 30,000 signups a year): **≈ ₹11,000–15,000**. That's Apple ₹9,500 plus Firestore ₹1,500–5,000 plus a small OTP fallback; Google Play isn't charged again.

## Login verification: from ₹6.5 lakh to about ₹0

| Method | Cost per login | Year 1 (~97,000 logins) | Notes |
|---|---|---|---|
| Firebase Phone Auth (SMS) | $0.07 = ₹6.7 | **≈ ₹6,50,000** | Never use at this volume |
| SMS OTP via an Indian DLT provider | ₹0.12–0.20 | ₹12,000–19,000 | Needs DLT registration (one-time fee) |
| WhatsApp authentication template | ₹0.136 incl. GST | ≈ ₹13,000 | Needs a Meta Business account |
| **Truecaller one-tap** | **₹0** | ₹0 | Android only; about half of Indian Android users have Truecaller |
| **Reverse WhatsApp** (user *sends* a code to you) | **₹0** | ₹0 | Messages users send *to* a business are free on Meta's Cloud API; works on iPhone too |

**How reverse WhatsApp works:**
1. The app shows "Verify with WhatsApp".
2. WhatsApp opens with a pre-filled message such as `Verify my Rakta Bandhan number: RB-482913`, addressed to your business number. The user taps send.
3. Meta forwards the incoming message to your server. Your server checks the code and reads the sender's number; WhatsApp verified that SIM when the user set WhatsApp up.
4. Your server creates a Firebase login token, and the app signs in. Nothing is sent *to* the user, so nothing is billed.

**Recommended order in the app:**
1. Truecaller, if it's installed.
2. Reverse WhatsApp.
3. SMS OTP, only for the rare user without either. It stays within Firebase's 10 free SMS a day, or costs ₹0.12–0.20 through a DLT provider.

## Why the database used to cost so much (it wasn't storage)

**Storage is cheap.** 80,000 donor profiles are about 80 MB. Firestore gives 1 GB free, and beyond that it's about ₹17 per GB per month.

**Firestore bills per document read.** Every time a screen downloads a record, that's one read. It costs $0.06 per 100,000 reads, after 50,000 free reads a day. Three things in the code were downloading far more than needed:

| Problem | Reads | Fix (now in the code) | Reads after |
|---|---|---|---|
| Find map and searching screen downloaded **every** available donor on each open | 30,000–80,000 per open | Only donors within about 15 km, at most 30 per area (270 per open) | ≤ 270 |
| Searching screen kept a live download of donors just to show "N donors nearby" | Thousands, plus every change | Firestore **count** query, refreshed once a minute (1 read per 1,000 donors counted) | ≈ 9 a minute |
| Admin dashboards loaded **every** donor and request (plus their ID photos) on open | 80,000+ per admin visit | Newest 200 donors and 300 requests, and counts instead of downloads | ≤ 500 |
| The ID photo (~200 KB) sat inside the donor profile, downloaded on nearly every screen | ~10 downloads/user/day × 200 KB | Moved to its own record, and **deleted once an admin has verified it** | ~0 |

With these fixes, a busy launch day with 5,000 active users comes to about 700k–1.2M reads. That's about ₹40–70 for the day, and ordinary days are far less.

## Community posts with photos

The media cost above now covers this. The community feature is currently a design preview with no backend.

**Assumed usage:** about 5% of active users post one photo a month (≈150–250 posts), and each active user views about 50 posts a month.

**Required to keep this near ₹0**

Compress on the phone before upload:
- a feed image at ~1080 px WebP, about 120–180 KB;
- a thumbnail at ~320 px, about 20 KB.

Uncompressed phone photos are 3–6 MB each, 25–40× more data.

**Storage and downloads**
- **Cloudflare R2:** 10 GB of storage and downloads are free, so this is **₹0**.
- **Firebase Storage:** about 9 GB of downloads a month × $0.12, so about **₹1,000 a year**.

**Firestore for the feed:** about 150k–250k reads a month, which is inside the free tier.

**Video is where the cost would jump.** Keep v1 to photos only.

## Blaze, step by step

1. **Create the billing account in the Rotary club's name**, not yours, and link it to the Firebase project. Then upgrade to Blaze.
2. **Budget alerts** (Cloud Console › Billing › Budgets): monthly budget ₹1,500, with alerts at 50%, 90% and 100%. Blaze has no hard cap, so the alerts are the guardrail.
3. `firebase deploy --only firestore:rules,firestore:indexes`, then wait for all indexes to show "Enabled".
4. **App Check** on Firestore and Auth, so only the real app can use your quota.
5. Auth › Settings › **SMS region policy: India only**, if the SMS fallback is used at all.
6. **Service account** for your server: Project settings › Service accounts › Generate key. Store it as a secret on your server; never put it in the app or the repo.
7. For the first month, check the **Firestore usage page** twice a week. A sudden jump in reads almost always means a screen is re-downloading in a loop.

## Your numbers

| | Amount |
|---|---|
| Year 1 quote | ₹1,00,000 |
| Interns (2 × ₹5,000) | −₹10,000 |
| Year-1 running costs (cheapest setup) | −₹13,500 to −₹19,500 |
| **You keep, year 1** | **≈ ₹70,000–76,500** |
| AMC from year 2 | ₹35,000–40,000 |
| Year-2 running costs, if you pay them | −₹11,000 to −₹15,000 |
| **You keep, year 2+** | **≈ ₹20,000–29,000** |

**Recommendation:** have the club pay Google Cloud, Apple and Meta directly, on accounts in their name. Your AMC then stays pure service income, and the club legally owns its users' data, which DPDP expects of it as data fiduciary.

## Sources
- [Firebase pricing](https://firebase.google.com/pricing)
- [Identity Platform SMS pricing](https://cloud.google.com/identity-platform/pricing)
- [Cloud Storage for Firebase: billing changes](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)
- [WhatsApp authentication pricing, India 2026](https://richautomate.in/blog/meta-whatsapp-per-template-pricing-2026-india-explained)
- [SMS OTP pricing, India 2026](https://www.messagecentral.com/en-in/blog/sms-otp-pricing-india)
- [Truecaller Flutter SDK](https://pub.dev/packages/truecaller_sdk)
- [Firebase Phone Number Verification](https://firebase.google.com/docs/phone-number-verification)
- [USD/INR](https://tradingeconomics.com/india/currency)
