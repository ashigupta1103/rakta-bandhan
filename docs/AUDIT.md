# Rakta Bandhan — app audit (26 Sep 2026)

This is a review of everything currently in the repo:
- the Flutter app;
- Firestore rules;
- the admin dashboard;
- platform configuration;
- the design system.

Each finding is marked **Fixed** (on branch `feature/chat-calls-legal-alerts`) or **Suggested** (not yet done). Priorities:

| Priority | Meaning |
|---|---|
| P0 | Blocks launch |
| P1 | Cost or scale |
| P2 | UX |
| P3 | Code health |

## P0 — security & store blockers

| Finding | Status |
|---|---|
| Fake OTP plus one shared password for every account: anyone can sign in as any phone number | **Suggested.** Real OTP via a Cloud Function (see `publishing/README.md`) |
| No iOS Firebase config, so the app crashes on iPhone at launch | **Suggested.** Run `flutterfire configure` (needs a Firebase login) |
| iOS bundle ID `com.example.raktaBandhan` | **Fixed:** `com.raktabandhan.app` |
| App icon was the Flutter logo on every platform | **Fixed:** generated from the approved logo mark |
| Android release builds signed with the debug key | **Fixed:** `key.properties` signing |
| No iOS permission purpose strings, no privacy manifest | **Fixed** |
| No in-app account deletion or data export | **Fixed** |
| Privacy policy and terms were empty placeholders; no public URLs | **Fixed:** full draft text, in the app and on the web; needs counsel sign-off |
| Chat had no report/block (Apple 1.2) | **Fixed** |
| Exact donor coordinates readable by every signed-in user | **Fixed** for new donors (rounded to ~1 km). **Suggested:** a one-off migration to coarsen existing `donors_public` docs |
| Admins can read every chat (for abuse review) | Disclosed in the privacy policy. **Suggested:** limit admin chat reads to requests that have a report |
| OpenStreetMap tile and Nominatim servers used as a production backend (against their usage policies) | **Suggested:** hosted provider before launch |
| Rotary wheel (a trademark) in the logo | **Suggested:** confirm usage rights; the icon avoids it |

## P1 — cost & scale

| Finding | Status |
|---|---|
| Find map and matching screen read *every* available donor on each open: ~$270+/month by month 6 at 5k signups/month | **Fixed:** geohash-bounded `NearbyDonors`, capped at 900 reads |
| Find map re-subscribed its Firestore listener on every rebuild | **Fixed:** memoised per ~5 km cell |
| ID-proof image (~200 KB base64) stored inside the profile doc, downloaded on every profile read, and by the admin list for *all* donors | **Fixed:** moved to `donors/{uid}/private/id_proof` |
| Firebase Phone Auth would cost ≈ $400/month at 5k signups | **Suggested:** own OTP via a DLT SMS or WhatsApp provider (≈ $14/month) |
| Request expiry is lazy (client-side on read) | Fine on Spark. **Suggested:** a scheduled function on Blaze |
| `openRequestsStream` reads all open requests nationwide | Fine at launch scale. **Suggested:** the same geohash bounding once there are hundreds open at a time |
| Home and Request lists filter blood compatibility client-side | Fine at this scale |

## P2 — calling & messaging UX (the focus of this round)

**How two people connect today:**
1. A request is raised.
2. A compatible donor sees it on the Request tab, or is rung by an urgent alert if they opted in.
3. The donor accepts, and both see "You're connected".
4. From there, reaching each other takes **one tap from anywhere**:
   - the connected screen (Call in app / Message / their phone);
   - the Request-tab cards (Message);
   - the **Messages inbox** (chat icon on the Request tab, with an unread badge; the tab itself gets a dot);
   - tracking (Message / Call);
   - the in-app **message banner** that appears over any screen;
   - the chat header (call icon, or tap the name for the contact sheet).

| Before | After |
|---|---|
| Call / WhatsApp buttons showed "coming soon" | In-app voice call (peer-to-peer, encrypted, not recorded) and in-app chat |
| No list of conversations | **Messages inbox**: last message, time, unread state, a call button on live rows, "Active" and "Earlier" sections |
| No sign a new message arrived | Request-tab dot, inbox badge, and a top **banner** (tap to reply, swipe up to dismiss) |
| No read state | **"Seen"** under your latest message |
| Hard to say where to meet | Share the **hospital location** or **your current location**; the location card opens directions |
| Call screen waited on mic and network before appearing | It **opens instantly** ("Starting call…"), with errors shown in place |
| Unanswered calls vanished | A **no-answer screen** with Message, Call again and Their phone |
| A call to someone with the app closed just rang out | After 15 s: "may not have Rakta Bandhan open", with a **Call their phone instead** option |
| Jumping from a call into chat lost the call | An **"On a call · 02:14 — Return"** bar in chat |
| Donor who accepted but couldn't go left the requester stuck | **"Can't make it"**: the request reopens for other donors |

**Suggested next** (in order):
1. **Push notifications on Blaze** for messages, calls and new matches. Everything above still only works while the app is open; this is the biggest remaining gap and fits the "server-side only for important things" rule.
2. **CallKit (iOS) / ConnectionService (Android)** so calls ring on the lock screen. Pair it with the VoIP push; never ship the `voip` background mode without it.
3. **TURN server**: without it, some mobile-to-mobile calls won't connect. About $0/month at this size.
4. A typing indicator: small value against extra writes. Skip unless users ask.
5. A per-conversation mute toggle, once pushes exist.
6. Quick replies in Tamil, Malayalam and Hindi once the app is localised.

## P2 — other UX

- **Suggested:** localisation (Tamil, Malayalam, Hindi). All copy is currently hard-coded English.
- **Suggested:** accessibility pass:
  - check text scaling at 200% on the chat, inbox and call screens;
  - TalkBack/VoiceOver labels on icon-only buttons (added on the new screens; older screens are mixed).
- **Suggested:** an onboarding hint that points donors to **urgent alerts** once, after registration.
- **Suggested:** the Notifications screen still shows derived events only; merge it with the Messages inbox, or link to it.
- **Fixed:** every cancel now confirms; cancelled requests are hidden; "Keep waiting in background" while searching.

## P3 — code health

- **Fixed:** no Material `Icons`, no emoji or Unicode-glyph icons, no ALL-CAPS labels, on-ember colours tokenised. Every Lucide icon name was verified against the package docs.
- **Fixed:** stale default counter test replaced with blood-compatibility and legal-reader tests.
- **Suggested:** tests for `Conversation.unreadFor`, `NearbyDonors` cell maths, and `ChatMessage.fromDoc` (pure logic, no Firebase needed).
- **Suggested:** `Backend` eagerly creates Firebase singletons in its constructor, so nothing touching `Backend.instance` is unit-testable. Inject them, or make them lazy.
- **Suggested:** `find_donors_screen.dart` (≈850 lines) and `onboarding_screen.dart` (≈700) would read better split into widgets.
- **Suggested:** the admin React dashboard doesn't show `reports` yet. Add a Reports page, since the chat report flow writes there.
- **Not verified:** this branch was written without a local Flutter SDK (the network couldn't download it). Run `flutter pub get && flutter analyze && flutter test` before merging, and test calls on two real phones.
