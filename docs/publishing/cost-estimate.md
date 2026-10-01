# Running cost: year-1 plan (₹40,000 budget)

**Load assumed:** 1,00,000 signups in year 1 (about 50,000 in the launch month, then about 4,500 a month). About 2–4% of registered users open the app on a given day; up to 10,000 a day in the launch weeks.
**Exchange rate:** ₹96/$ (Sep 2026). **Google Cloud and Meta bills from India carry 18% GST**, which is included below.
**Architecture:** almost everything runs on the phone against Firestore, protected by security rules. The few server jobs run as **Cloud Functions in the same Firebase project**, with no separate server to maintain:
1. phone verification (Truecaller check, OTP send/verify, Firebase sign-in token);
2. push notifications for messages, calls and urgent requests;
3. call-relay (TURN) credentials;
4. a job every 15 minutes that expires old requests.

## Year 1

| Item | Choice | Year 1 (incl. GST) |
|---|---|---|
| Apple Developer Program | Organisation account in the club's name, $99/year | ₹9,500 |
| Google Play | Organisation account, $25 **one-time** | ₹2,500 |
| Login verification | Truecaller → WhatsApp OTP → SMS OTP (see below) | ₹13,300 |
| Firestore | Blaze, after the two read fixes below | ₹8,000 |
| Cloud Functions | 2M invocations/month free; we use about 0.3M. Container storage is the only charge | ₹500 |
| Push notifications | FCM | ₹0 |
| Maps on screen | Google Maps SDK for Android/iOS: mobile map loads are free and unlimited | ₹0 |
| Address lookup | LocationIQ free tier (5,000/day); OpenStreetMap Nominatim only in development | ₹0 |
| Call relay (TURN) | Cloudflare Realtime: 1,000 GB/month free, about 0.6 MB per relayed call minute | ₹0 |
| Hosting (admin panel, legal pages) | Firebase Hosting free tier, on the `.web.app` address | ₹0 |
| iOS builds without a Mac | Codemagic free tier (500 build minutes/month) | ₹0 |
| WhatsApp sender number | The club's existing landline or number, not already on WhatsApp | ₹0 (a new SIM kept active ≈ ₹2,000) |
| **Subtotal** | | **≈ ₹33,800** |
| Reserve | Launch spike, SMS abuse, card forex fees | ₹6,200 |
| **Total** | | **₹40,000** |

**Year 2 onwards** (about 36,000 signups a year): **≈ ₹23,000**.
- Apple: ₹9,500.
- OTP: ₹4,800.
- Firestore: ₹8,300, because the user base is larger.
- Functions: ₹500.
- Google Play is not charged again.

## Login verification

About **1,25,000 verifications** in year 1: 1,00,000 signups plus about 25% extra for resends, reinstalls and phone changes.

| Method | Price per verification | Share of logins | Year 1 |
|---|---|---|---|
| **Truecaller one-tap** (Android, if installed) | ₹0 | ≈ 35% (43,750) | ₹0 |
| **WhatsApp OTP**: Meta authentication template, Cloud API direct | ₹0.1357 (₹0.115 + GST) | ≈ 58% (73,000) | ₹9,900 |
| **SMS OTP** without DLT (Fast2SMS / 2Factor), fallback only | ≈ ₹0.41 | ≈ 7% (8,000) | ₹3,300 |
| **Total** | | | **≈ ₹13,300** |

For comparison, over the same year:

| Other approach | Year 1 |
|---|---|
| WhatsApp + SMS, without Truecaller | ≈ ₹20,400 |
| SMS through a DLT provider only (₹5,900/year registration + ≈ ₹0.24 each) | ≈ ₹36,000 |
| Firebase Phone Auth SMS ($0.07 + GST each) | ❌ ≈ ₹9,90,000 |

**Budget lever:** **"Verify on WhatsApp" (reverse verification)** makes the WhatsApp share free:
- The user taps a button, WhatsApp opens with a code pre-filled, and they tap send.
- Messages a user sends *to* a business are free, and are not subject to messaging limits.
- It saves about ₹9,900 a year. The app can switch to it with one server setting if the budget gets tight.

**Launch-day limit.** A new WhatsApp business number may message only 250 people a day. Completing **Meta Business Verification** lifts this to **100,000 a day** immediately, so finish it before launch.

**Protection against SMS abuse** (the usual way OTP bills blow up):
- Only the real app can call the OTP function: App Check with Play Integrity or App Attest.
- +91 numbers only.
- 30 seconds between resends; at most 5 codes per number, and per device, each day.
- A code expires after 5 minutes; 5 wrong attempts lock it. Codes are stored hashed.
- A daily cap on SMS spend inside the function.

## Firestore: the two fixes the budget depends on

Firestore bills per document read: $0.06 per 100,000 reads, after 50,000 free reads a day. The earlier fixes bounded the donor map and the counts. Two more places still read data **nationwide**, which is fine now and expensive at 1 lakh users.

| Where | Today | Fix | Reads per app open |
|---|---|---|---|
| `Backend.openRequestsStream()`, used by home, Requests and urgent alerts | Every open request in India, live | Only requests within the alert area (geohash cells), newest first, capped | hundreds → ≤ 60 |
| `community_screen.dart` "this month" figure | Downloads every fulfilled request ever | Count query for this month only | thousands → ≈ 1 |

| Scenario | Reads per active user per day | Firestore, year 1 incl. GST |
|---|---|---|
| With both fixes (target) | ≈ 100–120 | **≈ ₹7,000–9,000** |
| Without them | ≈ 300–600 | ≈ ₹20,000–35,000 (breaks the budget) |

Storage isn't the cost:
- 1 lakh donor profiles plus requests come to well under 1 GB, which is free.
- The ID photo has already moved out of the profile and is deleted after verification.

## Community posts with photos (built)

- **Compress on the phone before upload:** a feed image at ~1080 px WebP (≈150 KB) plus a thumbnail at ~320 px (≈20 KB). That keeps storage and downloads inside the free tiers: Firebase Storage's 5 GB, or Cloudflare R2's 10 GB with free downloads.
- **Keep it to photos.** Video is where the cost would jump.

## Setup, step by step

1. **Accounts in the club's name.** Apple (and Google, as good practice) expect a legal entity, not an individual, to publish a health-related app (Apple guideline 5.1.1(ix)).
   - Get a free **D-U-N-S number** for the club; it takes 1–4 weeks, so start now.
   - Then open the Apple Developer (organisation) and Google Play (organisation) accounts.
   - Organisation Play accounts also skip the "12 testers for 14 days" rule that applies to new personal accounts.
   - Apply for Apple's nonprofit fee waiver; if it's approved, that saves ₹9,500 a year.
2. **Blaze.** Create the Google Cloud billing account in the club's name, link it and upgrade.
   - **Budget:** ₹3,000/month, with alerts at 50%, 90% and 100%. Blaze has no hard cap.
3. **Don't enable "Identity Platform"** in Authentication. The app doesn't need it, and plain Firebase Auth has no per-user charge for custom sign-in.
4. **Deploy the rules and indexes:** `firebase deploy --only firestore:rules,firestore:indexes`.
5. **Cloud Functions.**
   - Deploy in the same region as Firestore.
   - Accept the **Artifact Registry cleanup policy** when the CLI asks, so old builds don't accumulate storage.
   - Give the functions' service account the **Service Account Token Creator** role; creating sign-in tokens needs it.
6. **App Check:** Play Integrity (Android) and App Attest (iOS), enforced on Firestore and the functions.
   - Play Integrity allows 10,000 checks a day by default. **Request the free quota increase a week before launch.**
7. **Meta.**
   - Set up the Business Manager and WhatsApp Cloud API number, and complete **Business Verification**.
   - Create an authentication template with a copy-code button, and add a payment method.
8. **Truecaller.** Create a developer account and register the Android package name plus the release SHA-1.
9. **SMS fallback.** Open a Fast2SMS or 2Factor account and top up ₹1,000.
10. **Cloudflare.** On a free account, create a Realtime TURN key; the function turns it into short-lived call credentials.
11. **Google Maps.** Create one Android key and one iOS key, each restricted to the app's package or bundle ID and to the Maps SDK only.
12. **First month:** check Billing and Firestore usage twice a week. A sudden jump in reads almost always means a screen re-downloading in a loop.

## Your numbers

| | Amount |
|---|---|
| Year 1 quote | ₹1,00,000 |
| Interns (2 × ₹5,000) | −₹10,000 |
| Year-1 running costs (this plan, with reserve) | −₹40,000 |
| **You keep, year 1** | **≈ ₹50,000** (≈ ₹56,000 if the reserve isn't used) |
| AMC from year 2 | ₹35,000–40,000 |
| Year-2 running costs, if you pay them | ≈ −₹23,000 |
| **You keep, year 2+** | **≈ ₹12,000–17,000** |

**Recommendation:** from year 2, the club pays Google Cloud, Apple and Meta directly (the accounts are already in its name). Your AMC then stays service income: ≈ ₹35–40k instead of ≈ ₹12–17k.

## Sources
- [Firebase pricing](https://firebase.google.com/pricing)
- [Cloud Run functions pricing](https://cloud.google.com/functions/pricing-1stgen)
- [Maps SDK for Android usage and billing](https://developers.google.com/maps/documentation/android-sdk/usage-and-billing)
- [Google Maps Platform pricing list](https://developers.google.com/maps/billing-and-pricing/pricing)
- [Cloudflare TURN service](https://developers.cloudflare.com/realtime/turn/)
- [Identity Platform pricing](https://cloud.google.com/identity-platform/pricing)
- [Google Cloud taxes in India](https://docs.cloud.google.com/billing/docs/resources/vat-overview)
- [WhatsApp messaging limits](https://developers.facebook.com/docs/whatsapp/messaging-limits/)
- [WhatsApp authentication pricing, India 2026](https://richautomate.in/blog/meta-whatsapp-per-template-pricing-2026-india-explained)
- [Fast2SMS OTP without DLT](https://www.fast2sms.com/OTP-SMS-via-API-without-DLT-Registration)
- [Play Integrity API overview](https://developer.android.com/google/play/integrity/overview)
- [Apple Developer Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/)
- [Truecaller Flutter SDK](https://pub.dev/packages/truecaller_sdk)
