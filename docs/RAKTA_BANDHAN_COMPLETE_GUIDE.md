# Rakta Bandhan: the complete guide

*A bond of humanity, tied by blood.*

**Verified against:** `master` at `6e8edf7` (pull request #7 merged), 2026-10-05.
**Read this first if you are new:** sections 1 to 6 explain what the product is and how it works. Everything after that is reference.

---

## Contents

1. [The idea in one page](#1-the-idea-in-one-page)
2. [Status at a glance](#2-status-at-a-glance)
3. [Quick answers](#3-quick-answers)
4. [Who uses it](#4-who-uses-it)
5. [The main journey, end to end](#5-the-main-journey-end-to-end)
6. [The life of a request](#6-the-life-of-a-request)
7. [Matching: blood groups, "nearby" and location](#7-matching-blood-groups-nearby-and-location)
8. [Talking and being notified](#8-talking-and-being-notified)
9. [The app, screen by screen](#9-the-app-screen-by-screen)
10. [Privacy, safety and trust](#10-privacy-safety-and-trust)
11. [The admin website](#11-the-admin-website)
12. [Architecture](#12-architecture)
13. [Data model](#13-data-model)
14. [Security rules in plain words](#14-security-rules-in-plain-words)
15. [Cloud Functions and the Cloudflare Worker](#15-cloud-functions-and-the-cloudflare-worker)
16. [Free plan today versus after Blaze](#16-free-plan-today-versus-after-blaze)
17. [Design system](#17-design-system)
18. [Codebase map](#18-codebase-map)
19. [Build, test, deploy](#19-build-test-deploy)
20. [Money](#20-money)
21. [Launch checklist and open decisions](#21-launch-checklist-and-open-decisions)
22. [Known gaps and quirks](#22-known-gaps-and-quirks)
23. [History and decisions](#23-history-and-decisions)
24. [Glossary](#24-glossary)

**Status words used throughout.** *Real* means it works today on the free Firebase plan. *Simulated* means the screen exists, says "Simulation" on it, and verifies nothing. *Needs Blaze* means it is built and tested but cannot run until Firebase is upgraded and the Cloud Functions are deployed. *Not built* means it does not exist. *Not verified* means the code exists but nobody has tried it on real phones.

---

## 1. The idea in one page

**The problem.** In India you can get food and groceries in ten minutes, but finding a blood donor in time is painfully hard. The founding pitch (May 2025 deck) puts the irony as: "to get our needs met faster than we can save a life." Today a request often travels as a forwarded message in group chats. The app puts it in front of compatible donors nearby instead.

**The product.** Rakta Bandhan ("Rakta" is blood, "Bandhan" is a bond) is a phone app, modelled on cab-booking apps:

1. Someone who needs blood raises a **request**: blood group, units, how urgent, which hospital.
2. **Compatible, available donors nearby** see it right away.
3. **One donor accepts.** The request is now matched and nobody else can take it.
4. The two **talk inside the app** (messages and voice calls). Phone numbers are never shown.
5. After the donation, **both confirm**. The donor then rests for **90 days** and is switched back on automatically.
6. The donor gets a **certificate**, and the community "impact" counter goes up by one.

**Who is behind it.** A service project of Madras Cosmos Charitable Trust and Chennai Capital Trust, run by the Rotary Clubs of Madras Cosmos and Chennai Capital (Chennai, Tamil Nadu), with support from Rotary International District 3233. It targets India. Android first, then iOS. It also builds for the web.

**The original mechanism: G-I-F-T** (from the founding deck):

| Letter | Step | In the app |
|---|---|---|
| **G** | Group selection: the patient or hospital picks the blood group and location | Create-request screen |
| **I** | Identify donors: GPS finds verified, available donors nearby, only those whose rest period is over | Near-you feed, urgent alerts, Find map |
| **F** | Fast acceptance: one tap, then they are connected | Accept button, then chat and call |
| **T** | Track and schedule: the donor schedules the donation, the requester tracks it | Tracking screen and chat. There is no scheduling or ETA feature (see section 22) |

**What it is not.** It is not a blood bank and not a medical service. It connects people. Blood is never bought or sold; anyone who asks for money is reported and removed. In an emergency the user is told to call 108 or 112 and contact the hospital directly.

**Principles that shape every decision:**

- **Real, not demo.** Every screen shows real data or an honest empty state. No invented people, numbers or partners.
- **Free plan first.** Everything that can run on Firebase's free plan does. Only what truly needs an outside service is simulated, and says so on screen.
- **Privacy by design.** Phone numbers never leave a person's private profile. Locations are approximate to other users. Coordinates are never shown as numbers.
- **The rules are the law.** The phone app writes to the database directly, so the database security rules enforce every invariant. Cloud Functions only notify.

---

## 2. Status at a glance

| Area | Status | Notes |
|---|---|---|
| Sign-up and sign-in with email and password | Real | Min 8 characters, "Forgot password" email |
| Email check after sign-up | **Simulated** | Code `123456`, can be skipped, nothing is sent |
| Phone number check after registration | **Simulated** | Code `246810`, can be skipped, verifies nothing |
| Registration, usernames, profiles | Real | Username claimed atomically, 30-day change limit |
| Raising, finding, accepting, cancelling requests | Real | |
| Two-sided donation confirmation, 90-day rest, certificate | Real | |
| Nearby search by geohash | Real | |
| In-app chat | Real | Live while the app is open |
| In-app voice calls | Real code, **not verified** | TURN relay is live. Not yet tried between two real phones on different networks |
| Urgent alerts (full-screen ring) | Real, foreground only | Opt-in. Only while the app is open |
| Push notifications, ringing when the app is closed | **Needs Blaze** | The app registers its token. Nothing can send yet |
| Photos (profile, posts, ID proof) | Real | Cloudflare R2 through the Worker. Not verified end to end with a real signed-in user by the developer |
| Community: stories, What's new, Impact | Real | |
| Testimonials | Real | Member submits, admin approves, then it appears |
| Help and support, reports, partnership inquiries | Real | Replies appear inside the app |
| Data export and in-app account deletion | Real | Required by both app stores |
| Admin website | Real | Built and tested. Needs a Hosting deploy after each change |
| Maps | Real, fallback | OpenStreetMap by default. Native Google Maps needs a key and a build flag |
| Address search | Real, development grade | Public Nominatim by default. A LocationIQ key is needed for production |
| Emailed 6-digit sign-in code | **Needs Blaze** | Plus an email sender and a domain |
| Server jobs: request expiry, donor reactivation | **Needs Blaze** | Done lazily inside the app until then |
| Real phone verification | **Not built** | Needs an SMS, WhatsApp or Truecaller provider |
| iOS | **Not built** | No Firebase iOS config, no push keys, no CallKit or PushKit |
| Languages other than English | **Not built** | Tamil, Malayalam and Hindi are suggested |
| Emergency contact | Device-only | Stored on the phone, not synced (the screen says so) |
| Startup ad | Empty placeholder | A labelled empty slot for up to 3 seconds at every launch. No ad provider connected |
| Legal pages | **Draft** | A "draft" banner shows until counsel approves and contact details are filled in |

**Live resources** (public identifiers, no secrets):

| Thing | Value |
|---|---|
| Firebase project | `rakta-bandhan-india` |
| Functions region (when deployed) | `asia-south1` (the Firestore location must match; the owner confirms this) |
| Hosting | `https://rakta-bandhan-india.web.app` (admin site, legal pages, share page) |
| Cloudflare Worker | `https://rakta-bandhan-edge.raktabandhan.workers.dev` |
| R2 bucket | `bloodbank` (private) |
| Android package and iOS bundle id | `com.raktabandhan.app` |
| App version | `1.0.0+1` |

---

## 3. Quick answers

| Question | Answer |
|---|---|
| Do notifications arrive when the app is closed? | **No, not yet.** That needs Blaze plus the Cloud Functions, which are written and tested but not deployed. While the app is open, the in-app notification feed, call rings, chat banners and urgent alerts all work. |
| Does the "ring me for urgent requests" alert work? | Yes, **only while the app is open**, and only for donors who switched it on. With the app closed it needs push (Blaze). |
| Does calling work? | The in-app voice call works between two phones with the app open. Ringing a closed or locked phone needs Blaze. It has not been verified on two real phones. |
| Is an email address really verified? | **No.** The post-sign-up email check is a simulation, so any well-formed address is accepted. Real proof needs Blaze and an email sender. |
| Is a phone number verified? | **No.** It is collected and kept private, never checked. |
| Can others see my phone number? | No. It stays on your private profile. Matched people use in-app chat and calls. Even you see it masked (last 3 digits) in the app. |
| Can others see where I live? | Only an area name ("Adyar, Chennai") and a position rounded to about 1 km. Never coordinates as numbers. |
| Does "verified donor" change what a donor can do? | **No.** It is only a badge. An unverified donor can still accept requests. |
| Is the blood-group logic right? | Yes. O-negative is the universal donor and AB-positive the universal recipient. Rh-negative recipients never get Rh-positive donors. Covered by a test. |
| How many people can a request match? | Exactly one donor, enforced inside a database transaction and by the rules. |
| What if the donor cannot go after accepting? | They tap "I can't make it". The request reopens for others with a fresh 6 hours. |
| How long is a request live? | 6 hours. Then it expires. |
| How long does a donor rest? | 90 days after a completed donation. The app and the rules both stop them switching back on early. |
| Where do photos live? | Cloudflare R2, through a small Worker, not Firebase Storage. |
| Who runs the servers? | There are none to maintain. Firebase (database and sign-in), Cloudflare (photos and call relay), and, after Blaze, Firebase Cloud Functions. |
| What does it cost to run? | Today it runs on free tiers (Firebase Spark, and Cloudflare's free plan with R2's free allowance). The store accounts cost money. The year-1 plan with Blaze, verification and a reserve is about ₹40,000 (section 20). |
| How do I get the latest app? | `flutter build apk --release` (section 19). |

---

## 4. Who uses it

There is **one kind of account**. Everyone registers once with a blood group and an area, so everyone is a potential donor. A person acts as a **requester** on the requests they raise and as a **donor** on the ones they accept.

| Actor | What they do | How the system knows |
|---|---|---|
| **Requester** | Raises a request, watches it, chats or calls the donor, confirms the donation | `requester_uid` on the request |
| **Donor** | Registers, stays "available", gets notified, accepts one request, donates, rests 90 days | `matched_donor_id` on the request, plus the profile flags |
| **Admin** (volunteer or staff) | Verifies donors, moderates, answers support, publishes content | A document at `admins/{uid}` on an ordinary email-and-password account |
| **Owner** (Rotary and the developer) | Deploys, holds the Firebase and Cloudflare accounts, flips the feature switches | Console access, plus the admin site |
| **The Worker** | Stores photos, hands out call-relay credentials | A Cloudflare Worker that checks each caller's Firebase token |
| **Cloud Functions** | Send push, expire and reactivate, carry bans to sign-in, email sign-in codes | Not deployed yet (Blaze) |

---

## 5. The main journey, end to end

```
 NEW PERSON                REQUESTER                         DONOR
 ----------                ---------                         -----
 install app
 sign up / sign in
 register (name, @username,
   mobile, blood group, area)
 phone check (simulated)
 consent -> location ask
 main app opens
                           raise request
                             group, units, urgency, place
                           "Matching..." radar screen
                                                             sees it in "Near you"
                                                             (or an urgent alert rings)
                                                             opens it, taps Accept
                           "A donor accepted"                "You're connected"
                           <------- chat and voice calls ------->
                                                             goes to the hospital, donates
                                                             taps "I've donated"
                           taps "Donation received"
                           request = FULFILLED               rest 90 days, certificate,
                                                             impact counter +1
```

### Step 0. Opening the app

`main.dart` starts Firebase, activates App Check without blocking, starts the push service and runs the app. The **splash** shows the logo ("Every drop connects a life") while the destination is decided, then a **startup ad slot** appears for up to 3 seconds (currently an empty, labelled slot), then:

| Situation | Goes to |
|---|---|
| Signed out | Login screen |
| Signed in, no profile yet | Registration |
| Profile exists but no username (older accounts) | Choose a username |
| Profile and username exist | The four-tab app |
| Offline and the profile cannot be read | The app, rather than strand the user |

### Step 1. Signing in

Two modes, picked **when the app is built** by `--dart-define=EMAIL_CODE_LIVE=true`:

| | Free plan (default) | After Blaze |
|---|---|---|
| Sign in | Email and password. Min 8 characters. "Forgot password" sends Firebase's reset email | No password. Enter your email, receive a 6-digit code, type it |
| After sign-up | A labelled simulation of "check your email" (code `123456`, skippable) | The code itself is the proof |
| Code rules | n/a | 10-minute life, 5 wrong tries, 30-second gap between sends, 8 per day per address, 20 per hour per network. Stored only as a salted hash |
| Account deletion | Asks for the password again, then the app deletes the sign-in account | A server function deletes the sign-in account |
| Result | A Firebase user | A custom-token user carrying `login: email_otp`, which the rules treat as "verified" |

The same address always lands on the same account, so existing password users keep their data when the app later switches to emailed codes. Admin consoles always use email and password.

### Step 2. Registering

One screen collects the **name**, an **@username**, a **10-digit Indian mobile number** (starts with 6 to 9), the **blood group**, and the **area**. The area is pre-filled from real GPS where available. It can be changed by search or by dropping a pin on a map. If there is no GPS fix and no chosen place, the app asks for a pin, because the area decides which requests reach the donor and a guessed city would break matching.

When submitted, one **database transaction** writes three things together:

1. the username claim `usernames/{name}`;
2. the private profile `donors/{uid}` (name, phone, email, exact location, flags);
3. the public mirror `donors_public/{uid}` (name, username, group, a position rounded to about 1 km, a neighbourhood name).

If the username is already taken, or a profile already exists, the whole thing fails and nothing is written.

A new donor starts **available, not verified, not banned**.

**Username rules:** starts with a letter, 3 to 20 characters of lowercase letters, digits and underscores, not on a reserved list (admin, support, rotary, official and so on), changeable once every 30 days. The name is released when the account is deleted.

### Step 3. The rest of onboarding

Registration, then the **phone check** (a labelled simulation), then the **consent** screen ("your phone number is never public", "your location is shown approximately", "you can delete your account anytime"), then a **location permission** ask if it has not been granted (it never blocks), then a short "verifying" screen, then the app.

### Step 4. Raising a request

A single guided screen asks three things one at a time, each collapsing to a green-check summary that can be reopened:

1. **Blood group** and **units** (1 to 10). It does not default to the requester's own group, because the blood may be for someone else.
2. **Urgency**: *Normal* (within a day or two), *Urgent* (needed within hours) or *Critical* (life-threatening, notify fastest).
3. **Hospital or place**: current location, search, or a Rapido-style map picker where the pin stays fixed and the map moves under it.

The request is saved with the requester's name and @username (never a phone number), a geohash, coordinates, `status: open`, and an expiry **6 hours** later. Two other places raise the same kind of request: the **Find** map and a donor's profile page both have a "Request O+ blood" button. That creates an **ordinary open request** for that blood group at your location (urgent, 1 unit). It is *not* addressed privately to that one donor (see section 22).

### Step 5. The matching screen

The requester lands on a dark "ember" screen with a radar animation. It is live:

- It watches the request document. When a donor accepts it moves on by itself.
- Every minute it counts how many **compatible, available donors** are within about 15 km, using a cheap Firestore count query, and shows that number.
- After 15 seconds it says no match is confirmed yet. The screen keeps updating.
- At the request's expiry it moves to a calm "no donor found" screen.
- "Keep waiting in background" returns to the app. The live status is always under Request, then Yours, then Track status.
- Cancelling goes through a confirmation sheet.

### Step 6. A donor finds the request

Three ways, strongest to gentlest:

| Channel | How it works | When |
|---|---|---|
| **Urgent alert** | Full-screen "ride request" style takeover, looping chime and vibration, one obvious action, gone after 45 seconds | Opt-in. Only for urgent or critical requests, within 25 km, raised in the last 20 minutes, compatible with the donor, available, not matched, not resting. Only while the app is open |
| **Push notification** | A system notification, loud channel for opted-in donors on urgent requests | Needs Blaze |
| **Near you feed** | The Request tab lists compatible open requests within 50 km, most urgent first, then nearest | Always, while the donor looks |

### Step 7. Accepting

Opening a request shows who, what and where, with an Accept button. Accept runs a **transaction** that checks, in order:

1. the donor's profile exists;
2. they are **not resting** (else "You donated recently…");
3. they have **no other active match** (their `active_request_id` lock points at nothing live);
4. the request is **still open** (else "Someone else already accepted this request");

then it sets the request to `matched`, writes the donor's name and username onto it, stamps `matched_at`, and sets the donor's `active_request_id` to this request. The security rules **re-check the same conditions**, so a modified client cannot cheat. If two donors tap at once, only one write wins.

### Step 8. Connected

Both people now see each other's name and @username, and can **message** and **voice call** (section 8). The donor sees **"I've donated"** and **"I can't make it"**. The requester sees **"Donation received"** and **Cancel**.

### Step 9. Completing the donation (two-sided)

Completion needs **both** people. The first to confirm only stamps their own timestamp. The second one closes the request. The rules enforce who may write what.

```
donor taps "I've donated"            requester taps "Donation received"
  -> donor_confirmed_at                -> requester_confirmed_at
        \                                  /
         +---- whichever is SECOND  -------+
                       |
                status = FULFILLED, fulfilled_at
                       |
   donor-side effects, applied exactly once:
     last_donation_date, is_available = false, reactivation in 90 days,
     active_request_id cleared, a donation_history record (id = request id),
     the Impact counter +1
```

The donor-side effects can be applied by any of three paths. The "applied once" guard is the donor's own `active_request_id` lock, cleared in the same write:

| Path | When |
|---|---|
| The donor's own confirmation, if it is the second | Immediately |
| The `onRequestUpdated` Cloud Function | When the requester's confirmation is the second (needs Blaze) |
| `completeMyDonationIfConfirmed()` in the donor's app | Fallback when the donor next opens or acts in the app |

An **admin** can also close a matched request on a hospital's word (`confirmed_by: admin`).

### Step 10. Afterwards

- **Thank-you screen** with the donor's real donation count.
- **Rest period**: the availability switch is locked off for 90 days, with a countdown screen, an optional word-riddle game and community stories to read.
- **Reactivation**: when the 90 days are over the app switches the donor back on when they open it. After Blaze a daily job does it too and sends "You can donate again".
- **Donation history and certificate**: one record per donation. A certificate (name, hospital, date, blood group, donation number) can be saved to the gallery or shared.

---

## 6. The life of a request

```
                       create
          (nothing) ------------> OPEN ----------------------------> EXPIRED
                                  |  ^        6 hours, no donor
                                  |  |
                       accept     |  |  release ("I can't make it")
                                  v  |
                                MATCHED ----------------------------> FULFILLED
                                  |            both confirm
                                  |
                       cancel     v
              (from OPEN or MATCHED) ---------------------------------> CANCELLED
```

| Transition | Who may do it | Conditions the rules check |
|---|---|---|
| create (`open`) | A verified, unbanned member | The request carries no phone number. Requester id is the caller |
| open to matched | A donor | Transaction plus rules: not resting, no other live match, request still open |
| matched to open ("release") | The matched donor | New expiry at most 7 hours ahead |
| open or matched to cancelled | The requester | |
| open to expired | **Any signed-in user** | Only once the expiry time has genuinely passed |
| matched to fulfilled | Needs both confirmations | Each side stamps only its own timestamp |
| delete | An admin | For spam, duplicates, test requests |

**Clocks and limits:**

| Thing | Value |
|---|---|
| Request lives | 6 hours (a released request gets a fresh 6) |
| Donor rest after a donation | 90 days |
| Unanswered call rings | 45 seconds, then "missed" |
| Urgent alert on screen | 45 seconds |
| Urgent alert freshness | Raised in the last 20 minutes |
| Matching screen donor count refresh | Every minute |
| Units per request | 1 to 10 |
| Chat message | Up to 1000 characters |
| Community post | Up to 2000 characters, topic up to 80 |
| Testimonial | 1 to 600 characters |
| Photo | JPEG, longest side 1440 px, quality 78, at most 2 MB, camera and GPS metadata removed |

---

## 7. Matching: blood groups, "nearby" and location

### Blood compatibility

The table maps a **recipient** to the **donor groups that can give to them**. It exists identically in the app (`bloodCompatibility` in `lib/services/backend.dart`) and the server (`BLOOD_COMPATIBILITY` in `functions/src/geo.ts`).

| Recipient | Can receive from |
|---|---|
| A+ | A+, A-, O+, O- |
| A- | A-, O- |
| B+ | B+, B-, O+, O- |
| B- | B-, O- |
| AB+ | **All eight groups** (universal recipient) |
| AB- | A-, B-, AB-, O- |
| O+ | O+, O- |
| O- | O- |

**O-negative appears in every row**, so an O- donor sees every request (universal donor). Rh-negative recipients never receive Rh-positive donors. There is no "emergency override" mode. `test/blood_compatibility_test.dart` asserts these rules.

A donor's feed uses the **inverse**: "which recipient groups can I give to?" (`compatibleRecipientGroups`).

### How "nearby" works (geohash)

Firestore cannot ask "everything within X km" directly. The app stores a **geohash** (a short text code for a map cell) on every donor and request, then queries cell by cell:

1. Pick a cell size at least as wide as the search radius.
2. Take the cell that contains the point **plus its 8 neighbours** (a 3 by 3 block).
3. Ask Firestore for documents whose geohash starts with each cell (up to 9 small queries, merged and de-duplicated).
4. Apply the real distance (haversine) cut-off on the phone, because the block over-covers its corners.

Costs are bounded: **at most 60 requests per cell** in the feed and **30 donors per cell** on the map. Donor counts use Firestore's `count()` aggregation, about 9 reads however many donors exist.

**The radius differs by screen** (this is real, see section 22):

| Where | Radius |
|---|---|
| Near-you request feed | 50 km |
| Find tab (map and list) | The 3 by 3 block of precision-5 cells, about 15 km square, then filtered to 50 km |
| Matching screen donor count | About 15 km (same block) |
| In-app urgent alert | 25 km |
| Server push (when deployed) | 25 km for urgent or critical, 15 km otherwise |
| Founding deck | "5 km radius and so on" |

### Location rules

- **Private, exact**: only on `donors/{uid}` (owner and admins can read).
- **Public, rounded**: `donors_public` keeps a position rounded to 0.01 degrees (about 1.1 km) and a neighbourhood name.
- **Anything stored** (registration area, a request's location, a shared location in chat) must come from real GPS, a search result, or the map picker. `currentPosition()` falls back to Chennai Central **only to centre a map**, never to store. The app says when a map is centred on that fallback.
- **Coordinates are never displayed.** Addresses use `shortPlace()`, people use the area name. The only place numbers travel is inside a "open in Google Maps" link.
- **Providers** live in `lib/services/geo_config.dart`: map tiles (OpenStreetMap by default, native Google Maps with `--dart-define=GOOGLE_MAPS=true` and a key), geocoding (public Nominatim by default, LocationIQ with `--dart-define=LOCATIONIQ_KEY=...`), restricted to India.

---

## 8. Talking and being notified

### Chat

- Exists **only between the requester and the matched donor**, under `requests/{id}/messages`. No open DMs.
- Writable only while the request is `matched` and nobody has blocked.
- Kinds written to the database: `text`, `location` (opens in a maps app) and `call` (a call-log row).
- Every send is **one batch**: the message, plus `last_message` and the sender's own read time on the request. That is what powers the **Messages inbox** (one listener for all conversations), unread badges, the dot on the Request tab, "Seen", and the in-app banner.
- Quick replies are written for the one thing these two need to do: meet at a blood bank.
- A pinned safety line: "Blood is never bought or sold. If anyone asks for or offers money, report them."
- **Report** reasons: asked for or offered money, harassment, fake request, spam, something else. **Block** closes the conversation for both.
- Admins can read any thread (disclosed in the privacy policy) to review reports.

### Voice calls

```
   Caller app                        Firestore                       Callee app
   ----------                        ---------                       ----------
   fetch relay credentials from the Worker (3 s limit, cached; falls back to STUN)
   open mic, create WebRTC offer
   write requests/{id}/calls/{cid}   status: ringing, offer ----->  incoming-call listener rings
        ICE candidates  ----------->  caller_candidates  -------->  callee answers, writes answer
        <-------------  callee_candidates  <----------------------   status: accepted
   ================= audio flows phone to phone (or through the relay) =================
   hang up -> status ended; the caller writes one call-log row into the chat
```

- **Audio only.** Nothing is recorded or stored. Firestore carries only the handshake.
- **STUN** (Google's public servers) connects most calls. Mobile-carrier NAT pairs, common in India, need a **TURN relay**. The Worker hands the two people on a matched request short-lived Cloudflare TURN credentials (1 hour, cached by the app until 5 minutes before expiry).
- No answer for 45 seconds logs a missed call. After about 15 seconds the caller is offered "call their phone instead" (a `tel:` link, no permission needed).
- Any call entry point (chat header, contact sheet, inbox, tracking) opens the call screen immediately and lets it place the call, so every failure state looks the same everywhere.

### Notifications: three layers

| Layer | What it is | Works when |
|---|---|---|
| **Notification feed** (bell) | Derived from the user's own requests and matches. No notifications collection exists. Shows: donor accepted, donor says they donated, completed, expired (for requesters), and cancelled (for donors) | Always, when the user opens it |
| **Live in-app events** (`LiveEventsHost`) | While the app is open: ringing call takes the whole screen, urgent alert takes the whole screen, a chat or push arrives as a top banner. Calls win over alerts and banners | App open |
| **Push** (FCM) | System notifications and the native incoming-call screen | **Needs Blaze** |

**What the app already does for push.** On sign-in it asks permission, saves the device token to `donors/{uid}.fcm_token`, and subscribes to the topics `all` and `bg_<group>` (for example `bg_Apos`). Four Android channels exist: `messages`, `requests`, `urgent_alerts` (alarm sound), `general`. A high-priority data message on Android opens the native incoming-call screen (with Accept and Decline) even when the app is closed. **Nothing sends these yet.**

**What the functions send once deployed:**

| Event | Who is told |
|---|---|
| A new chat message | The other person |
| A missed call | The callee |
| A new request | Compatible, available donors nearby with a token (loud channel for opted-in donors on urgent requests) |
| A donor accepts | The requester |
| A donor backs out | The requester |
| The requester cancels a matched request | The donor |
| One side says they donated | The other side, asking them to confirm |
| Donation completed | Both |
| A request expires unmatched | The requester |
| An admin broadcast | Everyone, or one blood group |
| Rest period over | The donor |
| A support reply | The member |

---

## 9. The app, screen by screen

The signed-in app has **four tabs**, kept alive in an `IndexedStack`, so switching tabs does not rebuild them. Flow screens (matching, tracking, contact, donor details) are pushed on top so the tab bar hides.

### Tab 1: Request

- **Near you**: compatible open requests within 50 km, most urgent first, then nearest, with a small "You've accepted" section for the donor's own active match. Each card shows urgency and group, the place (tap to open Google Maps), distance, age and units, with one dominant action.
- **Yours**: the requests this user raised, cancelled ones hidden, with a "Need blood yourself?" shortcut.
- A chat icon opens the **Messages inbox** (badged with unread); the bell opens notifications.

### Tab 2: Find

A real map with every donor pin at its rounded public position, plus a draggable list sheet ("Available now, nearest first"). Filter by blood group. Tapping a donor opens a **trust page** built from public data only: group, availability, "Verified donor" or "Not yet verified", neighbourhood. It deliberately has no call or message button, because contact only becomes real after a match. A "Request X blood" button raises an ordinary open request (section 5, step 4).

### Tab 3: Community

| Sub-tab | What it is |
|---|---|
| **Stories** | Posts members share ("Share an experience"), optionally with one photo. Shown under the poster's **@username** only. Report, hide-this-author, or delete your own |
| **What's new** | Announcements an admin publishes. Empty state until then |
| **Impact** | "Donations this month", the one public counter |

### Tab 4: My Page

Photo (camera or gallery, with a preview step), name, blood group, verification state, approximate area, the **availability switch** (locked while resting) and the **urgent-alert toggle**. Then:

| Row | Goes to |
|---|---|
| Donation history and certificates | Timeline, impact trail, certificate |
| Personal information | Verification, ID proof upload, edit name and mobile (the number is masked even here) |
| @username | The username editor |
| Emergency contact | Device-only note (not synced) |
| Settings, your data and account | See below |
| Privacy policy, Terms of use | The reader |
| Log out | |

### Everything else

| Screen | What it does |
|---|---|
| **Settings and privacy** | The urgent-ring toggle, a link to the phone's notification settings, a plain statement of what others can and cannot see, **export my data** (JSON), and **delete my account** |
| **Help and support** | FAQs, "Report an issue", and **My reports and replies** (the member's own submissions with admin replies) |
| **Corporate partnerships** | An enquiry form ("Start a conversation"). The commercial terms (sponsors, tiers, prices) are deliberately empty and awaiting the Rotary team |
| **Testimonials** | Approved quotes, shown under @username. Members can submit their own with consent to publish |
| **About** | Mission, vision, story and team, as supplied by the Rotary team. Team bios still need each person's approval |
| **Cooldown** | The 90-day arc, "days to go", word riddles ("six short stages about blood and community, nothing to win") |
| **Legal reader** | Privacy policy, Terms of use, Community guidelines. "In short" summary, contents list, full text |
| **Donation journey and certificate** | The real count and a shareable certificate |

`word_riddle_screen.dart` and `home_screen.dart` exist. The riddles are reachable from the cooldown screen. `home_screen.dart` and the in-app admin screens (`admin_*.dart`) are leftovers that no navigation reaches (section 22).

---

## 10. Privacy, safety and trust

**What is private and what is not:**

| Data | Who can see it |
|---|---|
| Phone number | Only the owner and admins. Never copied onto requests. Masked to the last 3 digits everywhere it is displayed |
| Exact location | Owner and admins |
| Rounded location and area name | Any signed-in user (the public listing) |
| Name | On a request, the requester's and donor's names appear to each other and to anyone who can read the request |
| @username | Public. Used on posts, testimonials and chat |
| Email | Owner and admins |
| ID proof photo | Owner and admins only, every time, with a fresh sign-in. **Deleted after an admin verifies it** |
| Profile photo | The link is held only on the owner's private profile. The image itself can be opened by anyone who has the link |
| Chat and calls | Only the two people. Admins can read chat for abuse review |
| Community photos | Anyone who has the link (unguessable names) |

**Safety features:** report and block in every chat, report or hide or delete on every post, community guidelines, admin verification with a five-point checklist, a ban switch, an audit log of every admin action, and "blood is never bought or sold" repeated in the chat and the policy.

**Data rights:** *export* everything as JSON (Digital Personal Data Protection Act, right of access) and *delete* the account inside the app. Deletion order matters and is documented in `AccountService`: cancel own open or matched requests and scrub the name and phone off them; release any match the user accepted back to open; delete the user's own chat messages; delete push token, ID proof, profile photo, support records, the username claim and both profile documents; finally delete the sign-in account. Every step is safe to retry. Donation history rows stay, holding only an orphaned id.

**Legal documents** live in `lib/legal/legal_documents.dart` (version 1.1, effective 1 October 2026): Privacy policy, Terms of use, Community guidelines. They must always match real behaviour, so any change to data handling updates them in the same change, plus `ios/Runner/PrivacyInfo.xcprivacy` and `docs/publishing/store-listing.md`. Hosted copies are regenerated with `python tool/export_legal_html.py`. They show a **draft banner** until `kLegalApproved` is set after counsel review. `kLegalContactEmail` and `kGrievanceOfficerName` are **still blank** and are store blockers.

**Store-policy choices baked in:** no advertising ID, no full-screen-intent permission, no camera foreground-service type, no call or SMS permissions (the phone fallback is a `tel:` link), no iOS background `voip` mode, in-app account deletion, report and block on user content, an 18+ target audience on Google Play, category Medical.

**Android permissions actually requested:** fine and coarse location, internet and network state, record audio and audio settings (calls), Bluetooth connect (headsets), post notifications, vibrate. One foreground service type is declared: `phoneCall|microphone`, used only while a call is ringing or live.

---

## 11. The admin website

A React site (`admin/frontend`: React 19, Vite, Tailwind, shadcn components). It reads and writes **Firestore directly**; the security rules, not a server, decide what an admin may do. Sign-in is email and password; **a person is an admin if and only if a document exists at `admins/{uid}`**. The first admin is created by hand in the Firebase console (a one-time step), after which an admin can add more.

| Page | What it does |
|---|---|
| **Dashboard** | Live cards: donors (and how many verified), available donors, open requests (and total), hospitals, total donations, fulfilment rate, average response time, banned users, plus recent activity |
| **Map** | Donors, open requests and hospitals on a free basemap |
| **Donors** | Search by name, @username, phone or email. Filter by group or "pending verification". Paged. Actions: view ID photo (fetched with the admin's own token), **Verify** (behind a five-point checklist, then the ID photo is deleted and only the check date is kept), activate or deactivate, **ban or unban**, delete profile |
| **Requests** | Filter by status. **Confirm donation** on a matched request (closes it as fulfilled, starts the donor's rest, records it, bumps the Impact counter). Delete spam |
| **Hospitals** | A reference list: add, edit, verify, delete. The app's users do not read it today |
| **Inbox** | Three sections: Help and support, Partnerships, Chat and call reports (including reported community posts). Each item shows who sent it. Status *New, In progress, Resolved*, an internal note, a **reply** the member sees in My reports, an Email button on partnership inquiries, "view conversation" on chat reports, and Hide or Delete on reported posts |
| **Content** | **What's new** announcements; **Testimonials** (a review queue for member submissions with *Approve*, *Edit first*, *Reject*, plus manual entries); the **Impact** counter correction; community story **moderation** (hide is reversible, delete removes the photo too) |
| **Donations** | Fulfilled requests, read-only |
| **Analytics** | Charts computed in the browser from live data |
| **Broadcast** | Compose a push to all donors or one blood group. Writing the document is the whole API; delivery needs the deployed function |
| **Audit log** | The last 100 admin actions, written by the site itself, never editable |
| **Settings** | The feature switches in `config/features` (section 12), each with a warning and a confirmation |

The sidebar shows badges for waiting inbox items and pending testimonials.

**The five-point verification checklist** an admin confirms before **Verify** unlocks: a clear readable ID photo (Aadhaar, PAN, driving licence, voter ID or passport); the name on the ID matches the profile; the donor is 18 or older; the admin called or messaged the number and the donor confirmed they registered; the blood group was confirmed with the donor.

There is also an older in-app admin console (`lib/screens/admin_*.dart`, `lib/services/admin_service.dart`). No menu reaches it any more. The website is the live console.

---

## 12. Architecture

```
                       +--------------------------------------+
                       |   Flutter app  (Android now, iOS     |
                       |   later, web build too)              |
                       +-----+----------------+---------------+
                             |                |
         Firebase Auth +     |                | HTTPS with the user's Firebase token
         Firestore (direct)  |                v
                             |      +-------------------------------+
                             |      |  Cloudflare Worker  (free)    |
                             |      |   /media/...  -> R2 bucket    |
                             |      |   /ice        -> TURN creds   |
                             |      +-------------------------------+
                             v                       |
        +------------------------------+             | reads Firestore *as the caller*
        |  Firestore + security rules  |<------------+ so the rules decide access
        |  (rules enforce everything)  |
        +---------------+--------------+
                        ^
                        |  Admin SDK (bypasses rules)  -- NOT DEPLOYED YET (Blaze)
        +---------------+--------------+
        |  Cloud Functions (asia-south1)|-----> FCM push, scheduled jobs,
        |  notify, expire, reactivate,  |       custom sign-in tokens, email
        |  sign-in codes, ban to Auth   |
        +------------------------------+

        +------------------------------+
        |  Admin website (React)       |  Firebase Hosting, same Firestore,
        |  email + password sign-in    |  fetches ID photos through the Worker
        +------------------------------+
```

### The key idea: Spark-first

The project runs on Firebase's **free (Spark) plan**, which cannot run Cloud Functions. So matching, accept-locking, completion, the 90-day cooldown and the rest all run **inside the phone app as Firestore transactions** (`lib/services/backend.dart`), and the **security rules** (`backend/firestore.rules`) enforce every invariant, so a modified app cannot cheat. Cloud Functions are written for the things a phone cannot do (push, scheduled jobs, carrying a ban to the sign-in account, emailing codes). They never hold a data invariant on their own: the rules remain the authority, and the functions only notify or apply effects the rules already allow.

### Components

| Folder | What | Deployed to | Status |
|---|---|---|---|
| `lib/` | The Flutter app | Play Store, App Store later, web | Built |
| `backend/` | Firestore rules, 42 indexes, rules tests, legacy Storage rules | Firebase | Rules and indexes deployed by the owner |
| `functions/` | Cloud Functions (TypeScript) | Firebase (Blaze) | Built and tested, **not deployed** |
| `edge/` | Cloudflare Worker (TypeScript) | Cloudflare (free) | **Deployed** |
| `admin/frontend/` | Admin website, legal pages, share page | Firebase Hosting | Built; deploy after each change |
| `admin/backend/` | An old draft | Nowhere | Superseded by `functions/` |
| `design/` | Design artifacts and a reference Flutter snapshot | Nowhere | Reference |
| `docs/` | Documentation | Nowhere | |
| `tool/` | Scripts for legal pages, share page, icons, preflight, emulator end-to-end | Local | |

### Feature switches (`config/features`)

A single document the owner (or an admin, from the Settings page) flips. A missing flag means **off**.

| Flag | Off (today) | On |
|---|---|---|
| `email_verified_required` | Any signed-in, non-anonymous account may create data (because email proof cannot exist yet) | Only accounts that proved their email (emailed code or a verified address) may. **Turn on only after the emailed code is live, or every member is locked out** |
| `phone_required` | No phone check anywhere | A verified phone is needed to raise or accept a request. **Do not turn on yet:** phone verification does not exist |
| `server_jobs` | The app bumps the Impact counter itself | Cloud Functions own the counter and the rules stop the app touching it. Turn on only after Functions are deployed and verified |

The edge Worker reads `email_verified_required` too.

### How the Worker is secure without a service account

It never holds a key that could impersonate a user. It **verifies the caller's Firebase token** against Google's public signing keys, and to ask "may this person do that?" it reads Firestore **with the caller's own token**, so the rules answer. Its only secrets are the TURN key id and token. Routes: `GET /health`; `PUT, GET, DELETE /media/{community|avatars|id_proofs}/{uid}/{name}`; `POST /ice`. CORS allows only the app's web origins, except public photo reads.

---

## 13. Data model

### Collections

| Collection | Key fields | Read | Write |
|---|---|---|---|
| `donors/{uid}` | name, name_lower, username, phone, email, blood_group, location_label, geohash, lat, lng, is_available, is_verified, is_banned, active_request_id, urgent_alerts, fcm_token, photo_url, photo_path, has_id_proof, last_donation_date, reactivation_scheduled_at, created_at | Owner, admin | Owner (cannot change the verified or banned flags, cannot shorten the rest period), admin |
| `donors/{uid}/private/id_proof` | Legacy base64 ID photo. New photos go to R2 | Owner, admin | Owner, admin |
| `donors_public/{uid}` | name, username, blood_group, geohash (precision 6 of the rounded point), lat, lng (rounded), area, is_available, is_verified, updated_at | Any signed-in user. **No phone field is allowed** | Owner, admin |
| `usernames/{name}` | uid, created_at | Single get only, never a list | Owner (create, delete), tied to the profile with `getAfter` |
| `requests/{id}` | requester_uid, requester_name, requester_username, blood_group, units_needed, urgency, location_label, geohash, lat, lng, status, created_at, expires_at; on accept matched_donor_id, matched_donor_name, matched_donor_username, matched_at; donor_confirmed_at, requester_confirmed_at, fulfilled_at, cancelled_at, expired_at, released_at; last_message, requester_read_at, donor_read_at, chat_closed_by | Open: any signed-in user. Otherwise the two people and admins | The transitions in section 6 |
| `requests/{id}/messages/{mid}` | sender_uid, kind, text, sent_at, lat, lng, call_seconds | The two participants, admins | Participants, while matched and not blocked. Sender may delete own |
| `requests/{id}/calls/{cid}` (+ `caller_candidates`, `callee_candidates`) | caller_uid, callee_uid, caller_name, status, offer, answer, timestamps, ICE candidates | The two parties | Create: participants. Update: the two parties. Never deleted |
| `donation_history/{requestId}` | donor_id, request_id, donation_date, confirmed_by (`self`, `both` or `admin`), hospital, blood_group | The donor, admins | The donor only for a request truly fulfilled with them. Immutable after |
| `community_stories/{id}` | author_uid, author_name, author_username, topic, body, blood_group, location_label, image_url, image_path, image_aspect, created_at, edited_at, is_hidden | Any signed-in user | Author (text, topic, photo), admin (hide, delete) |
| `testimonial_submissions/{id}` | author_uid, name, username, quote, role, consent_to_publish | Admin only | Any member, with consent (quote 1 to 600). No updates |
| `testimonials/{id}` | quote, name, username, role, author_uid, submitted_by_member | Any signed-in user | Admin only |
| `announcements/{id}` | title, body, created_at | Any signed-in user | Admin only |
| `public_stats/impact` | month_key, donations_this_month | Any signed-in user | Anyone: only +1 (or reset to 1 in a new month), unless `server_jobs` is on. Admin: any value |
| `reports/{id}` | reporter_uid, reported_uid, request_id or story_id, reason, details, status | Admin | Any verified member (create). Admin (update). Never deleted |
| `issue_reports/{id}`, `partnership_inquiries/{id}` | reporter_uid or requester_uid, reason or org_name and contact details, status, admin_note | Admin | Member creates. Admin triages and deletes |
| `support_submissions/{id}` | A safe copy for the author: title, body, status | Author, admin | Author creates the copy. Admin updates status |
| `support_replies/{id}` | source_collection, source_id, to_uid, body, created_by | The addressed member, admin | Admin only. No updates |
| `hospitals/{id}` | name, address, city, state, contact_phone, lat, lng, verified | Any signed-in user | Admin |
| `audit_log/{id}` | actor, action, target, time | Admin | Admin create. Never edited or deleted |
| `broadcasts/{id}` | title (80), body (300), blood_group, status | Admin | Admin create. The function stamps the result |
| `admins/{uid}` | email, added_at | Owner (own doc), admin | Admin |
| `config/features` | The three switches | Any signed-in user | Admin |
| `login_codes`, `login_ip` | Hashed codes and counters | Nobody (server only) | Cloud Functions |

### Indexes

**42 composite indexes** in `backend/firestore.indexes.json`: requests by status and geohash, by status and created time, by requester, by matched donor, by status and expiry; donors by availability and geohash, and by availability, blood group and geohash; donors by `is_verified`, `is_banned`, group, name, username, phone and email for the admin search and paging (27 of the 42; two more serve matching and reactivation); donation history by donor; calls by callee and status; support submissions and replies. The Find map and request feeds fail until these show **Enabled** in the console after a deploy.

### Analytics events

`sign_up`, `login`, `login_code_requested`, `donor_registered`, `request_created`, `request_matched`, `request_released`, `donation_confirmed`, `donation_fulfilled`, `story_posted`. The advertising id is not collected.

---

## 14. Security rules in plain words

`backend/firestore.rules` is the contract. In plain language:

- **Who is "verified":** a person with an emailed-code sign-in, a verified email, or a phone number; or, while `email_verified_required` is off, any non-anonymous account. Anonymous accounts can never create anything.
- **Who is an admin:** a document exists at `admins/{uid}`. Only an admin can write that document.
- **Who is banned:** `donors/{uid}.is_banned`. A banned donor's own profile writes, new requests, accepts, usernames, stories and testimonials are all refused. (Their sign-in still works on the free plan; the Cloud Function disables it after Blaze.)
- **Rest period:** while `reactivation_scheduled_at` is in the future, a donor cannot mark themselves available, and the date can only move later, never earlier.
- **`is_verified` and `is_banned`:** an owner's own update cannot change either. Only an admin can.
- **No phone on public docs, ever:** `donors_public` and new requests reject a phone field.
- **One active match per donor:** to accept, the donor's own lock must be set to this request in the same write, and any existing lock must point at nothing live.
- **Completion needs both sides** and each side may stamp only its own confirmation. A donation record can be written by a donor only for a request that is truly fulfilled with them as the donor, with the same hospital and blood group, stamped with the server time.
- **Lazy expiry:** any signed-in user can expire an open request, but only once its expiry time has genuinely passed.
- **Release:** the matched donor may reopen a request, with a new expiry at most 7 hours out.
- **Chat and calls:** only the two participants, only while matched and not blocked.
- **Usernames:** a valid unclaimed name, bound to both profile copies in the same transaction, and a 30-day gap between changes.
- **Impact counter:** exactly +1 per write (or reset to 1 in a new month) unless server jobs are on; admins may set any value.
- **Everything not listed is denied** by a final catch-all.

**Tests:** 82 rules tests run on the Firebase emulator and cover these areas, including cross-user attacks (a member forging an admin-confirmed record, a client bumping stats, a double lock).

---

## 15. Cloud Functions and the Cloudflare Worker

### Cloud Functions (`functions/`, TypeScript, region `asia-south1`)

**Written and tested (27 unit tests plus an emulator smoke test), not deployed.**

| Function | Trigger | What it does |
|---|---|---|
| `requestLoginCode`, `verifyLoginCode` | Callable | Email a 6-digit code, trade it for a Firebase custom token with the `login: email_otp` claim. Hashed, rate-limited, optional fixed code for two app-store review addresses |
| `deleteMyAuthAccount` | Callable | Removes the caller's sign-in account |
| `onChatMessage` | New message | Push to the other person |
| `onCallCreated`, `onCallUpdated` | Call created or changed | Ring the callee (Android native call screen), then stop the ring, plus a missed-call notification |
| `onRequestCreated` | New open request | Find compatible, available, nearby donors with tokens, push (loud channel for opted-in donors on urgent) |
| `onRequestUpdated` | Request changed | Push on accept, release, cancel, confirmations, completion, expiry. On completion, applies the donor's rest and history record and bumps the Impact counter if `server_jobs` is on |
| `expireOldRequests` | Every 15 minutes (Asia/Kolkata) | Closes open requests past their expiry |
| `reactivateDonors` | Daily 06:00 (Asia/Kolkata) | Switches donors back on after rest, sends "You can donate again" |
| `onBroadcast` | New broadcast | Sends to the `all` or `bg_<group>` topic and records the result |
| `onDonorUpdated`, `onDonorDeleted` | Donor changed or removed | A ban disables the sign-in account and revokes sessions; an unban re-enables it; a removal deletes the Auth user, subcollections and username claim |
| `onReplyCreated` | New support reply | Optional email and push, **off by default** (`ENABLE_SUPPORT_DELIVERY`) |

Secrets and parameters: `SMTP_URL` (email), `REVIEW_CODE`, `REVIEW_EMAILS`, `ENFORCE_APP_CHECK` (off), `ENABLE_SUPPORT_DELIVERY` (off), `MAIL_FROM`.

### The Worker (`edge/`, 26 tests)

Detailed in section 12. It stores photos in a private R2 bucket (`community`, `avatars`, `id_proofs`), checks the real image bytes (JPEG, PNG or WebP) rather than the claimed type, caps uploads at 2 MB, and issues TURN credentials only to the two people on a matched request, falling back to STUN-only when no TURN key is set or Cloudflare is unreachable. Community and avatar links are readable by anyone with the link (unguessable names). ID photos are never public.

---

## 16. Free plan today versus after Blaze

| Capability | Free plan (today) | After Blaze and Functions |
|---|---|---|
| Sign-in | Email and password. Email check simulated | Emailed 6-digit code, real proof |
| Chat | Live while both apps are open | Plus a push when the app is closed |
| Urgent alert ring | Only with the app open and opted in | Plus a loud push when closed |
| Incoming call ring | Full-screen only with the app open | Plus the native call screen when closed (Android) |
| Request expiry | Lazy, when someone views the request | A job every 15 minutes |
| Donor reactivation | When the donor opens the app | Daily job plus a push |
| Impact counter | The app adds one | Functions own it |
| A ban | Writes are refused. The person can still sign in | The sign-in account is disabled and sessions revoked |
| Admin broadcast | The document is saved. Nothing delivers it | Delivered as a topic push |
| Support replies | Inside the app only | Optional email and push |
| Phone verification | Simulated | Still needs a provider (SMS, WhatsApp, Truecaller) |

**The push decision (open).** Three options were put to the owner: (1) upgrade to Blaze and deploy the functions that already exist; (2) have the Cloudflare Worker send FCM pushes using a tightly scoped service account (about a day of work; the owner previously declined putting a Firebase key on Cloudflare); (3) leave push off. As of this guide no choice is recorded.

---

## 17. Design system

The approved design source is `design/v3_updated/Rakta Bandhan Redesign.dc.html` (30 screens plus a handoff section) and its audit. The live code tokens are in `lib/theme/`. `docs/handoff/PROJECT_HANDOFF.md` documents the original redesign and its palette section is **out of date**.

**Colour** comes only from `AppColors`, a warm system sampled from the logo:

| Family | Role | Anchor values |
|---|---|---|
| Red ramp | Action, urgency, the blood itself | `brandRed` `#B81E14`, ember `#6E1109` |
| Vermilion and orange | Warmth, progress | `#C9481E`, `#D9631F` |
| Gold | Community, recognition, Rotary | `#E0A030` |
| Warm neutrals | Paper, ink, edges | ground `#FCF8F2`, ink `#241413`, sand `#F5EDE1` |
| GPS blue | The one deliberate non-brand hue: "you are here" | `#2F6FED` |

The **ember gradient** (red to near-black) is reserved for the emotional-peak screens: consent, matching, the matched moment and the certificate. Text on it uses the `onEmber*` tokens.

**Type:** two voices. **Barlow** for all UI. **Newsreader** (serif) through `AppTextStyles.display()` for names, headlines and counts only.

**Rules the code follows:** Lucide icons only (no Material `Icons`, no emoji as icons); sentence case, no tracked all-caps labels; custom tappables use `Pressable` (0.97 press scale); motion under about 300 ms, ease-out, respecting "reduce motion"; every request cancel goes through a `ConfirmSheet`; no native date or time pickers; radii 12 for controls and 20 for raised cards and sheets; the logo in `assets/branding/` is never altered; on the web the whole app is a 430 px centred column (set once in `MaterialApp.builder`).

---

## 18. Codebase map

```
BloodBankkk/
  lib/
    main.dart, app_info.dart, firebase_options.dart
    screens/    55 files (onboarding, the four tabs, request flow, chat, call,
                legal reader, plus some admin leftovers)
    services/   backend.dart (all data logic), chat_service, call_service,
                push_service, urgent_alert_service, notifications_service,
                nearby_donors, live_merge, account_service, support_service,
                photos, edge (Worker client), usernames, geo_config, features
    widgets/    shared UI (rb_ui, app_header, confirm_sheet, live_events_host, maps, ...)
    theme/      app_colors, app_text_styles, app_theme
    legal/      legal_documents, legal_config
  test/                 widget and unit tests (96 tests across 25 files)
  integration_test/     end-to-end journeys on an Android emulator
  backend/              firestore.rules, firestore.indexes.json, rules-test/, storage.rules (legacy)
  functions/            Cloud Functions + tests + emulator smoke test
  edge/                 Cloudflare Worker + tests
  admin/frontend/       React admin site, public/legal/*.html, public/app/ (share page)
  design/               design artifacts: v1_original, v2_new, v3_updated (the approved final)
  docs/
    architecture/       original HLD and the two backend design PDFs (the ambitious design)
    handoff/            the original redesign handoff
    planning/           the Blaze upgrade plan
    launch/             free plan, Blaze upgrade, Cloudflare setup, runbook, status snapshots
    publishing/         release checklist, store listing, cost estimate
    specs/              the chat, calls, alerts and compliance design
    AUDIT.md            prioritised audit
  tool/                 preflight.sh, e2e_screenshots.sh, export_legal_html.py,
                        make_share_page.py, make_app_icons.py
  .github/workflows/    CI
  CLAUDE.md             rules for AI assistants working in the repo
  EDGE_CASES.md         a 20-section QA checklist (nothing in it has been run yet)
  releases/             an old Aug-16 APK (outdated)
```

**State management** is plain `StatefulWidget` plus `StreamBuilder` over Firestore. No state library. Tests must not touch `Backend.instance` (it eagerly creates Firebase singletons).

**Notable packages:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_app_check`, `firebase_analytics`, `cloud_functions`, `flutter_webrtc`, `flutter_callkit_incoming`, `geolocator`, `google_maps_flutter` and `flutter_map` with `latlong2`, `image_picker` and `image`, `audioplayers`, `share_plus`, `gal`, `url_launcher`, `google_fonts`, `lucide_icons_flutter`, `shared_preferences`.

---

## 19. Build, test, deploy

### Everyday commands

```bash
flutter pub get
flutter analyze                        # lint
flutter test                           # all widget and unit tests
flutter run -d chrome                  # or an Android device
flutter build apk --release            # the real app
flutter build apk --release --dart-define=SHOW_ERRORS=true   # test build that prints the exception on a broken screen
flutter build appbundle --release --dart-define=GOOGLE_MAPS=true   # Play Store build

cd backend/rules-test && npm test      # rules tests on the emulator (needs Java 21)
cd functions && npm test               # function unit tests; "npm run smoke" for the emulator smoke test
cd edge && npm test                    # Worker tests
cd admin/frontend && npm run dev | build | lint
bash tool/preflight.sh                 # every check CI runs, in one command
bash tool/e2e_screenshots.sh build/e2e_donor integration_test/app_flow_test.dart   # real app on an emulator
```

### Build-time switches (`--dart-define=NAME=value`)

| Define | Effect |
|---|---|
| `EMAIL_CODE_LIVE=true` | Switch to the passwordless emailed code (after Blaze) |
| `EDGE_URL=...` | Point at a different Worker (defaults to the live one) |
| `GOOGLE_MAPS=true` | Native Google Maps (needs `MAPS_API_KEY` in `android/local.properties`) |
| `LOCATIONIQ_KEY=...` | Production address search |
| `RECAPTCHA_SITE_KEY=...` | Web App Check |
| `SHOW_ERRORS=true` | Test builds only: show the exception text instead of a generic message |
| `USE_EMULATORS=true` | Debug only: talk to the local Firebase emulators |

### Test counts (as of this guide)

| Suite | Result |
|---|---|
| Flutter analyze | No issues |
| Flutter tests | 96 pass |
| Firestore rules (emulator) | 82 of 82 |
| Cloud Functions unit tests | 27 of 27, plus an emulator smoke test |
| Worker tests | 26 of 26 |
| Admin site | `tsc`, production build and lint pass |
| CI on PR #7 | All six jobs passed (flutter, functions, functions-smoke, rules, admin, edge) |

### Deploy order (owner-run)

1. **Cloudflare Worker** (done once): `cd edge`, `npx wrangler login`, `npx wrangler deploy`, then set `TURN_KEY_ID` and `TURN_API_TOKEN` as secrets.
2. **Firebase rules and indexes:** `firebase deploy --only firestore:rules,firestore:indexes`. Wait until every index shows *Enabled*.
3. **First admin:** create an email and password user in Authentication, then create `admins/<that uid>` in Firestore.
4. **Admin site and legal pages:** `cd admin/frontend && npm run build`, `python tool/export_legal_html.py`, `python tool/make_share_page.py`, then `firebase deploy --only hosting`. **Repeat after every admin change.**
5. **After Blaze:** set the `SMTP_URL` and `REVIEW_CODE` secrets, deploy Functions, then switch on `server_jobs`, and later `email_verified_required`, in Settings. Build the app with `EMAIL_CODE_LIVE=true`.

### Working agreements

The owner performs every Firebase deployment and all real-device and external-service testing. Pull requests go to `master` of `ashigupta1103/rakta-bandhan` from a branch on the developer's fork. Local analysis, compile checks and small regression tests are development checks. CI mirrors `tool/preflight.sh`.

---

## 20. Money

From `docs/publishing/cost-estimate.md`. Assumes 1,00,000 signups in year 1, ₹96 to the dollar, 18% GST on Google Cloud and Meta bills.

| Item | Year 1 |
|---|---|
| Apple Developer Program (organisation, $99) | ₹9,500 (a non-profit waiver could save this) |
| Google Play (organisation, $25 once) | ₹2,500 |
| Login verification (Truecaller, then WhatsApp, then SMS fallback) | ₹13,300 |
| Firestore (Blaze, after two read fixes that are done) | ₹8,000 |
| Cloud Functions | ₹500 |
| Push, maps on screen, address lookup, TURN relay, hosting, iOS builds | ₹0 (free tiers) |
| **Subtotal** | **about ₹33,800** |
| Reserve | ₹6,200 |
| **Year 1 total** | **₹40,000** |
| Year 2 onwards | about ₹23,000 |

Firebase Phone Auth SMS was rejected: about ₹9,90,000 a year at this volume. Blaze has no hard spending cap, so the plan is a ₹3,000 per month budget with alerts at 50, 90 and 100 percent. The founding deck's budget was ₹5,00,000 for development plus ₹1,00,000 for outreach.

---

## 21. Launch checklist and open decisions

### The owner (Firebase, Cloudflare, accounts)

- [ ] Deploy the admin site to Hosting after PR #7 (`firebase deploy --only hosting`).
- [ ] Confirm every index shows *Enabled*, and that the Firestore location matches `asia-south1`.
- [ ] Delete leftover Auth test accounts (keep the admin).
- [ ] Decide the push route (section 16), then upgrade to Blaze if option 1.
- [ ] After Blaze: SMTP sender and domain, deploy Functions, switch the build to `EMAIL_CODE_LIVE=true`, then `server_jobs`, then `email_verified_required`.
- [ ] Register App Check (Play Integrity, release SHA-256, web reCAPTCHA). Keep enforcement off until verified.
- [ ] Add the Google Maps key and a LocationIQ key for production.
- [ ] Android upload key and `android/key.properties`.

### The Rotary team (content and legal)

- [ ] A monitored contact email and a named grievance officer (store blockers).
- [ ] Counsel review of the legal text, then set `kLegalApproved = true`.
- [ ] Each team member approves their About bio, and photos if wanted.
- [ ] Confirm the club's use of the Rotary wheel in the full logo (Apple guideline 5.2.1). The app icon deliberately uses only the droplet-and-heart mark.
- [ ] Decide the corporate-partnership terms (sponsors, tiers, prices). The screen is deliberately empty until then.
- [ ] A D-U-N-S number and organisation accounts for Apple and Google.
- [ ] See `docs/launch/STAKEHOLDER_REQUIREMENTS_CHECKLIST.md` for the full list.

### Testing nobody has done

- [ ] The **two-phone checklist** in `docs/publishing/README.md` (a requester and a donor, with the app closed and the screen locked).
- [ ] Photo upload and private ID-photo access with real accounts.
- [ ] A call between two phones on different networks (the TURN path).
- [ ] The 20-section QA list in `EDGE_CASES.md`. Every case is still "Not tested".

### Store and release

- [ ] Fill Data safety, Health apps declaration, content rating, foreground-service declaration (type Phone call, with a screen recording) and App access using `docs/publishing/store-listing.md`.
- [ ] A closed test (12 testers for 14 days on a personal Play account; organisation accounts skip it).
- [ ] iOS: `flutterfire configure`, an APNs key, PushKit and CallKit, TestFlight.

---

## 22. Known gaps and quirks

These were found by reading the code, not guessed. Each is a real behaviour today.

| # | Finding | Why it matters |
|---|---|---|
| 1 | **"Verified donor" is only a badge.** Nothing blocks an unverified donor from accepting, and they appear in Find as "Not yet verified". | The store copy says donors are "verified by the team". The verification checklist exists, but the system does not require it. A decision for the Rotary team |
| 2 | **A startup ad slot shows a labelled, empty "Advertisement" card for 3 seconds at every launch.** No ad provider is connected. | It adds 3 seconds to each launch, and the store forms say "Ads: none". If an ad network is ever added, the Play ads declaration, Data safety form and privacy policy all change |
| 3 | **The search radius differs per screen** (5 km in the deck, 15, 25 and 50 km in different places). | A donor can see a request on the feed that a push would not reach. Worth one agreed number |
| 4 | **"Request O+ blood" on a donor card raises an ordinary open request**, not a message to that donor. | Users may expect a private request. The snackbar says "visible to nearby donors" |
| 5 | **The registered name is still stored on community posts** (`author_name`) and testimonials (`name`), although the app now shows only the @username. Signed-in users can read those documents. | The UI keeps the promise, but the data does not. If the promise must hold at the data level, stop writing the field or restrict reads |
| 6 | **Names appear on requests by design.** The requester's and donor's names are on the request, readable by any signed-in user while it is open. | Phone numbers never are. This is a deliberate trade-off |
| 7 | **The notification bell has an unread-dot capability that nothing turns on.** And when a request completes, the requester's feed says "Thanks for donating!", which reads oddly for the person who received blood. | Minor. Both are small fixes |
| 8 | **Emergency contact is stored only on the phone.** The screen says so. | Lost on reinstall, never available to anyone else |
| 9 | **No scheduling or ETA tracking.** The founding deck's "T: track and schedule" is only chat plus status. | A feature gap against the original concept |
| 10 | **Ban does not cancel the person's open requests**, and on the free plan a banned person can still sign in (writes are refused). | A recorded decision. Full effect needs Blaze |
| 11 | **English only.** All copy is hard-coded. | Tamil, Malayalam and Hindi are suggested |
| 12 | **The `hospitals` list is admin-only data.** The app never reads it. A request's place is free text or a map pin. | Verified hospitals are not yet used for anything user-facing |
| 13 | **Leftover code:** the old in-app admin screens, `home_screen.dart`, and a few small widgets are never reached. | Safe to delete later. Removing them was held back |
| 14 | **Unproven emails are accepted** until `email_verified_required` is on. Anyone can create accounts with fake emails through the public sign-up API and then write data. | Fine for a pre-launch test project. Must be switched on before real users |
| 15 | **Documentation drift:** `backend/README.md` says sign-in uses emailed codes (the default build uses a password) and "no Cloud Functions"; `docs/publishing/README.md` lists 73 rules tests (now 82); a comment in `request_detail_screen.dart` says the single-active-match rule is not in the backend (it is); `docs/launch/*` status files are dated snapshots from 2026-10-02. | Trust the code and this guide over these |

---

## 23. History and decisions

| When | What |
|---|---|
| May 2025 | The founding deck by Rotary Club of Madras Cosmos and Madras Cosmos Charitable Trust: the G-I-F-T mechanism, a budget of ₹5,00,000 for development and ₹1,00,000 for outreach, phases (development, pilot with selected hospitals, public rollout), partner roles |
| Undated | The original technical HLD and two backend design PDFs specified an architecture built on Cloud Functions. It was never built as written, because Cloud Functions need the paid plan (`backend/README.md`) |
| 15 to 16 Aug 2026 | First commit (the original redesign, "Initial Antigravity version"). The app is connected to a real Firebase backend, with free address search and maps (pull requests #1 and #2) |
| 24 Aug to 2 Sep | The mobile frontend completed and refined |
| 3 to 7 Sep | A real Firestore backend on the Spark plan, real transactions instead of batches, and a written mapping of the HLD to what is actually built (pull request #3) |
| 20 to 22 Sep | Production UI finalised, the frontend audit, storage, maps and verification work (pull request #4) |
| 26 to 29 Sep | In-app chat and calls, store readiness, legal pages, cost fixes, the admin-console work merged in (pull request #5). The design spec for chat, calls, alerts and compliance, and a prioritised audit |
| 1 Oct | The Cloud Functions suite written for the Blaze plan: emailed sign-in, push, ringing calls, two-sided donations |
| 2 Oct | **Free-plan pivot.** All demo and preview code removed, email and password sign-in, two clearly labelled simulations, the Cloudflare Worker deployed for photos and call relay, pre-launch test data cleared, rules and indexes deployed by the owner (pull request #6) |
| 3 to 4 Oct | Photo-upload error reasons; the Requests-tab "Stream has already been listened to" crash fixed with a regression test; the owner's donation-journey and testimonial polish; the admin website brought up to date; repository tidy-up (pull request #7, all six CI jobs green) |

**Decisions on record** (`docs/launch/DECISIONS.md` and related):

- Stay on the free Firebase plan until the owner upgrades; keep data logic in client transactions and the rules.
- No Firebase service-account key goes on Cloudflare.
- No domain has been bought and the email provider (Resend) is deliberately pending, so real email sign-in waits for Blaze.
- Sign-in on the free plan is email and password; the emailed code is the launch plan.
- The phone check is a labelled simulation and the phone gate stays off.
- Usernames are required, lowercase, 3 to 20 characters, and changeable every 30 days.
- Never copy phone numbers onto requests.
- The pull-request base is `master`. The owner performs all Firebase deployments.

**Why the original HLD was not built as written.** It specified Cloud Functions for matching and contact reveal, real FCM push when the app is closed, scheduled functions, an SMS fallback, and a separate admin dashboard. Four were blocked by the free plan. The client-transaction-plus-rules design gives the same behaviour for matching and completion, and the functions are ready to add the rest when Blaze arrives.

---

## 24. Glossary

| Term | Meaning |
|---|---|
| **Rakta Bandhan** | "Blood bond". The app's name and tagline "A bond of humanity, tied by blood" |
| **G-I-F-T** | Group, Identify donors, Fast acceptance, Track and schedule: the founding flow |
| **Requester / donor** | Roles on a single request. Everyone has one account |
| **Request** | A call for blood: group, units, urgency, place. Lives 6 hours |
| **Match** | One donor accepted a request |
| **Two-sided confirmation** | Both people confirm the donation; the second closes the request |
| **Rest period / cooldown** | 90 days after a donation, when a donor cannot be available |
| **Reactivation** | Switching a donor back on after the rest |
| **Spark / Blaze** | Firebase's free plan / paid pay-as-you-go plan (needed for Cloud Functions) |
| **Firestore** | The database. **Security rules** are the server-side checks on every read and write |
| **Transaction** | A group of database changes that succeed or fail together, used so two donors cannot both accept |
| **Geohash** | A short text code for a map cell, used to search "nearby" |
| **FCM** | Firebase Cloud Messaging: push notifications |
| **Topic** | An FCM group everyone can subscribe to (`all`, `bg_Apos`) |
| **WebRTC** | The technology for phone-to-phone audio calls |
| **STUN / TURN** | Helpers that let two phones find each other / relay audio when they cannot connect directly |
| **R2** | Cloudflare's file storage, holding photos |
| **Worker** | A small program running on Cloudflare, here handling photos and relay credentials |
| **App Check** | A check that a request comes from the genuine app (Play Integrity on Android) |
| **Custom token** | A sign-in token the server mints after verifying a code |
| **DPDP Act** | India's Digital Personal Data Protection Act, 2023 |
| **Ember field** | The dark red-to-black gradient reserved for the emotional high points |
| **Simulation** | A screen that looks like a real check but sends and verifies nothing, and says so |

---

## Where to read next

| If you want to | Read |
|---|---|
| Run it or ship it | `CLAUDE.md`, `docs/publishing/README.md`, `docs/launch/SPARK_NOW.md`, `docs/launch/AFTER_BLAZE_UPGRADE.md`, `docs/launch/DEPLOY_RUNBOOK.md` |
| Set up Cloudflare | `docs/launch/CLOUDFLARE_SETUP.md`, `edge/README.md` |
| Know what is still waiting on Rotary | `docs/launch/STAKEHOLDER_REQUIREMENTS_CHECKLIST.md` |
| Fill the store forms | `docs/publishing/store-listing.md` |
| Understand costs | `docs/publishing/cost-estimate.md` |
| Test everything | `EDGE_CASES.md`, `docs/launch/VERIFICATION.md` |
| See the design | `design/v3_updated/Rakta Bandhan Redesign.dc.html` |
| Understand chat, calls and alerts in depth | `docs/specs/2026-09-26-chat-calls-alerts-compliance-design.md` |
| See the prioritised audit | `docs/AUDIT.md` |
| See the original ambitious design | `docs/architecture/` |

*Keep this guide current: whenever data handling, a screen's behaviour, a feature switch, or a deployment step changes, update the matching section here in the same change.*
