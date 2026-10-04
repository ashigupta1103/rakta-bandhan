# Rakta Bandhan — edge-case QA checklist

Final regression checklist for real-device and Firebase testing. Based on the current implementation (see `CLAUDE.md`), not on planned features.

**Nothing here has been executed yet.** Every case starts as *Not tested*. Only mark *Passed* after running the case on a device or against the emulators/live project, and record what you saw under *Actual*.

How to read a case:

- [ ] **Case** — *Expected:* what the app should do. *Actual:* *(fill in)* · *Status:* Not tested · *Notes:*

Status values: Not tested / Passed / Failed / Blocked.

Test accounts needed: a requester, a donor (different blood group compatible with the requester), a third unrelated user, an admin. Test on at least one small (≈ 320–360 dp) and one normal Android phone.

Free-plan vs Blaze: on the free plan (default build) sign-in is email + password with a *simulated* email check (code `123456`, nothing is sent) and a *simulated* phone check (code `246810`). Cloud Functions (push, expiry, call ringing) only run after the Blaze upgrade and `firebase deploy --only functions`. Cases that need functions are marked **[Functions]**.

---

## 1. Authentication

- [ ] **Wrong password** — *Expected:* friendly error (no raw Firebase text); stays on the sign-in screen; fields kept. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Unknown email** — *Expected:* generic "check your details" style message (no account enumeration). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Empty email / empty password** — *Expected:* inline validation, no network call. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Malformed email** — *Expected:* rejected with a clear message. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Duplicate account (email already registered)** — *Expected:* "already in use" style message; no second account. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Weak password** — *Expected:* rejected with Firebase's rule explained in plain words. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Network off during sign-in / sign-up** — *Expected:* "check your connection" message; button re-enables; no stuck spinner. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **App killed during sign-in** — *Expected:* on relaunch the splash routes by real state (signed out → Login). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Double-tap sign-in button** — *Expected:* one request only (button shows loading). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Log out** — *Expected:* confirmation first; returns to Login; back button does not return into the app. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Signed in, no profile yet** — *Expected:* splash → registration, not the main app. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Signed in, offline at launch** — *Expected:* opens the app from cache or routes safely; never strands on the splash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Banned account** — *Expected:* cannot create requests/messages (rules refuse); message is understandable. *Actual:* · *Status:* Not tested · *Notes:*

## 2. Registration / verification

- [ ] **Email check screen (free plan)** — *Expected:* labelled as a simulation; code `123456` continues; wrong code rejected; skippable as designed. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Phone check screen** — *Expected:* labelled simulation; `246810` passes; nothing claims the phone was truly verified. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Required fields missing (name, blood group, area)** — *Expected:* cannot finish; missing field is indicated. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Location permission denied during registration** — *Expected:* user can search/pick an area; no coordinates fabricated (`preciseLocation()` nullable). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Invalid phone number format** — *Expected:* rejected with a clear message. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **ID proof upload fails / too large** — *Expected:* error shown; profile otherwise saved or clearly not; no partial `donors_public` without `donors`. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Username: too short / invalid characters / taken** — *Expected:* 3–20 lowercase letters/digits/underscore, starts with a letter; taken names refused. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Username change inside 30 days** — *Expected:* refused with the date it unlocks. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **App killed mid-registration** — *Expected:* relaunch resumes at registration (no profile) without duplicate docs. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Registration double-submit** — *Expected:* single profile; `donors` and `donors_public` consistent. *Actual:* · *Status:* Not tested · *Notes:*

## 3. Profile / privacy

- [ ] **Settings → What others can see / cannot see** — *Expected:* two sections; phone, exact location, profile photo, ID proof only under *cannot see*. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Another user's view of my donor listing** — *Expected:* name, username, blood group, availability, ~1 km area; no phone, no exact coordinates. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Request contact info** — *Expected:* requester/donor names visible after match; no phone numbers anywhere in the UI. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Coordinates anywhere in UI** — *Expected:* never shown (`shortPlace`, area names only). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Edit personal information** — *Expected:* changes save to both `donors` and `donors_public` in one go. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Availability toggle** — *Expected:* works; blocked during the 90-day rest period with an explanation. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Download my data** — *Expected:* JSON shown, Copy all works, error message on failure. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Delete account** — *Expected:* confirm sheet, password re-asked on the free plan, wrong password → nothing deleted, success → Login. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Delete account while holding an open request / accepted request** — *Expected:* open requests cancelled; accepted request returns to other donors. *Actual:* · *Status:* Not tested · *Notes:*

## 4. Blood requests

- [ ] **No requests at all (Request tab)** — *Expected:* compact empty state, "Need blood yourself?" still available. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Create request, all required fields** — *Expected:* request appears as `open` for the requester. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Create request, missing required field** — *Expected:* cannot submit; field highlighted. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Create request with location permission denied** — *Expected:* search or pin-picker works; no demo-city location stored. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Double-tap submit** — *Expected:* one request created. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Network failure on submit** — *Expected:* error message; can retry; no duplicate afterwards. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **One open request** — *Expected:* shows in "Yours"; Messages empty state says "Your request is active". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Multiple open requests** — *Expected:* all listed; Messages says "Your requests are active" → View my requests. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Cancel request** — *Expected:* goes through the confirm sheet; status `cancelled`; matched donor informed **[Functions]**. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Request already fulfilled** — *Expected:* shown as completed; no "Track request" action. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Request expired (15-min sweep or lazy expiry)** — *Expected:* status `expired`; "Expired — no donor in time". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Open the tracking screen for a deleted/missing request** — *Expected:* safe error/empty state, no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Malformed request document (missing blood_group / location_label / timestamps)** — *Expected:* card still renders with fallbacks; no red error screen. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Missing optional field (units, urgency, hospital note)** — *Expected:* hidden or defaulted, not "null". *Actual:* · *Status:* Not tested · *Notes:*

## 5. Find / matching

- [ ] **No matching donors nearby** — *Expected:* clear "no donors" state with next step; not an endless spinner. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Matching donor found** — *Expected:* list sorted nearest first; blood-group compatibility respects the recipient → donor table. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Multiple matching donors** — *Expected:* all shown (≤30 per cell); no duplicates across neighbouring cells. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor unavailable / on cooldown** — *Expected:* not listed or labelled; cannot accept. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Stale request (already matched by someone else)** — *Expected:* accept fails gracefully ("someone else accepted"); no double match. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Two donors accept at the same moment** — *Expected:* exactly one wins (transaction); the other sees a clear message. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor already holding another active request** — *Expected:* accept refused (`active_request_id` lock). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor backs out (release match)** — *Expected:* request reopens; requester told **[Functions]**. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Map without Google Maps key** — *Expected:* OSM tiles fallback works. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Own request appears in own "can help" list** — *Expected:* never (requester excluded). *Actual:* · *Status:* Not tested · *Notes:*

## 6. Donor confirmation

- [ ] **Donor confirms once** — *Expected:* `donor_confirmed_at` set; donor's 90-day rest starts; `donation_history` written with hospital + group. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor confirms twice (double-tap / retry)** — *Expected:* second call is a no-op; one history entry; one cooldown. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor confirms while offline** — *Expected:* clear failure message or queued write; no false "done". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor confirms on a request that is no longer matched to them** — *Expected:* refused. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor confirms first** — *Expected:* request stays `matched`; requester prompted to confirm. *Actual:* · *Status:* Not tested · *Notes:*

## 7. Requester confirmation

- [ ] **Requester confirms after donor** — *Expected:* request becomes `fulfilled`; donor sees completion. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Requester confirms first** — *Expected:* stays `matched` until the donor confirms; requester sees "Waiting for the donor to confirm". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Both confirm** — *Expected:* exactly one `fulfilled` transition; impact counter bumped once. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Requester confirms twice** — *Expected:* no duplicate effects. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Inconsistent/stale state (confirmed flags set, status not fulfilled)** — *Expected:* UI does not show contradictory prompts; no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Chat closes after fulfilment** — *Expected:* conversation moves to "Earlier"; no sending. *Actual:* · *Status:* Not tested · *Notes:*

## 8. Notifications / FCM

- [ ] **In-app feed empty** — *Expected:* short empty state, no fake items. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor confirmed first → requester feed** — *Expected:* "Donation confirmed — A donor has confirmed the donation for your blood request." with no donor name. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Both confirmed → requester feed** — *Expected:* "Thanks for donating!" replaces the donor-confirmed item. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Requester confirmed first → requester feed** — *Expected:* normal "accepted your request" item (no donor-confirmed item). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor taps confirm repeatedly** — *Expected:* one feed item; one push **[Functions]**. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Push on donor confirmation** **[Functions]** — *Expected:* requester gets "Please confirm the donation"; tap opens the request. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Push on accept / cancel / release / expiry** **[Functions]** — *Expected:* each reaches the right person only. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **FCM token missing** — *Expected:* no crash; app works; push simply absent. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Notification permission denied** — *Expected:* app still works; in-app feed still shows items. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Functions not deployed (free plan)** — *Expected:* no pushes, no errors in-app; feed works. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **App reopened from a notification tap** — *Expected:* routes to the right request/chat without double-ringing. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Blood-group topic** — *Expected:* device subscribes to `all` and `bg_<group>`; a profile blood-group change resubscribes. *Actual:* · *Status:* Not tested · *Notes:*

## 9. Messages

- [ ] **No requests, no conversations** — *Expected:* "No conversations yet" + Request blood / Find donors. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **One open request** — *Expected:* "Your request is active" → View my request (that request's tracking screen) / Find donors. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Multiple open requests** — *Expected:* "Your requests are active" → View my requests (Request tab). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Past requests only** — *Expected:* "No conversations yet", Request blood. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Conversation exists (matched)** — *Expected:* row shows peer name, request context, last message, time; opens chat. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Unread message** — *Expected:* bold row, red dot, tab badge count; clears after opening. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Conversation lookup fails** — *Expected:* safe error ("Couldn't load your messages"), no raw Firebase text. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Empty-state lookup fails** — *Expected:* generic empty state with Request blood / Find donors. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Malformed conversation data (missing names / timestamps)** — *Expected:* row shows fallbacks ("Donor"), no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Stranger tries to read/write a chat** — *Expected:* refused by rules (also covered by `backend/rules-test`). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Send after chat closed/blocked** — *Expected:* sending disabled. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Message over 1000 characters** — *Expected:* refused. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Call action on an open conversation** — *Expected:* call screen starts; mic permission asked; failure handled. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Incoming call while app open / closed** **[Functions]** — *Expected:* in-app incoming screen / native call screen; decline works. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Report a message** — *Expected:* goes to `reports`; confirmation shown. *Actual:* · *Status:* Not tested · *Notes:*

## 10. Community stories

- [ ] **No stories** — *Expected:* compact empty state with a Share action. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Story exists** — *Expected:* identity shows `@username` only. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Story with no username (older post)** — *Expected:* "A donor"; never the registered name. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Post a story (text only / with photo)** — *Expected:* appears under your @username; photo compressed. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Edit own story** — *Expected:* text/topic/photo update; "edited" shown. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Delete own story** — *Expected:* confirm; story and photo removed. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Another user's story** — *Expected:* no edit/delete; Report and Hide available; "Hide posts from @username". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Hide an author, restart app** — *Expected:* still hidden (device-local). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Malformed story document (no body / bad aspect / no image_url)** — *Expected:* card renders or is skipped; no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Story load error** — *Expected:* friendly message by error type; Try again resubscribes. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Tab bar / header lines** — *Expected:* only one hairline under the tabs; no stacked lines. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Hidden story (`is_hidden`)** — *Expected:* not shown to members. *Actual:* · *Status:* Not tested · *Notes:*

## 11. Testimonials

- [ ] **Empty text** — *Expected:* Send disabled. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Whitespace-only text** — *Expected:* Send disabled. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **One short sentence ("Rakta Bandhan helped me find a donor.")** — *Expected:* Send enabled (with consent); accepted by Firestore. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **No minimum-word wording anywhere** — *Expected:* no "10 words" / "minimum" text in the screen or sheet. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Exactly 600 characters** — *Expected:* accepted. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **601 characters** — *Expected:* cannot be typed (limit) / refused by rules. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Consent unchecked** — *Expected:* Send disabled; rules also refuse without `consent_to_publish`. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Consent checked** — *Expected:* Send enabled when text valid. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Loading state** — *Expected:* "Sending…", button disabled, no double submit. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Firebase failure on send** — *Expected:* "Could not send it. Please try again."; sheet stays; text kept. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Rules deployed?** — *Expected:* short quotes only succeed after `firebase deploy --only firestore:rules` (rule now `size() >= 1`). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Published testimonial display** — *Expected:* quotation marks, text, "— @username"; never the real name. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Published testimonial without username** — *Expected:* "— Rakta Bandhan community". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Empty list** — *Expected:* quotation-mark empty state ("No testimonials yet…"), compact, top-aligned. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Keyboard open on the sheet, 320 dp phone** — *Expected:* scrolls; Send reachable; no overflow. *Actual:* · *Status:* Not tested · *Notes:*

## 12. Donation history

- [ ] **Zero donations** — *Expected:* "Your journey", "0 donations", empty message, See who needs help; no units/people-helped/progress bar. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **One donation** — *Expected:* "1 donation" (singular); one row with certificate preview. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Multiple donations** — *Expected:* newest first; donation numbers consistent with the certificate ordinal. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Malformed donation record (no hospital / date / group)** — *Expected:* row and certificate still render with fallbacks. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Count vs list mismatch** — *Expected:* no crash if `myDonationCount` and `donation_history` differ. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Load error** — *Expected:* "Couldn't load donation history" with retry. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **My Page → Your impact (zero)** — *Expected:* "0 donations", journey message, See who needs help; no ten drops. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **My Page → Your impact (with donations)** — *Expected:* real count only; no invented metrics. *Actual:* · *Status:* Not tested · *Notes:*

## 13. Certificates

- [ ] **Preview thumbnail** — *Expected:* the real certificate design, whole, correct proportions, not distorted. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Tap thumbnail / View certificate** — *Expected:* opens the full certificate screen for that donation. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Full certificate on a small phone** — *Expected:* fits; Save/Share visible; no overflow. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Save** — *Expected:* PNG in the gallery; permission prompt handled; denied → helpful message. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Share** — *Expected:* share sheet opens with the PNG and text. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Long name / long hospital name** — *Expected:* content scales down inside the card. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donor name unavailable** — *Expected:* falls back to "A Rakta Bandhan donor". *Actual:* · *Status:* Not tested · *Notes:*

## 14. Settings

- [ ] **Urgent-alert toggle** — *Expected:* opt-in saved on `donors/{uid}.urgent_alerts`. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Phone notification settings shortcut** — *Expected:* opens the OS app settings. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Legal pages** — *Expected:* privacy, terms, guidelines open in the reader; privacy says posts show only the @username. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Privacy sections order** — *Expected:* "What others can see" then "What others cannot see". *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Large system font (200%)** — *Expected:* no clipped text/overflow on Settings, Messages, Donation history. *Actual:* · *Status:* Not tested · *Notes:*

## 15. Network / Firebase failures

- [ ] **Offline read of cached data** — *Expected:* cached content shows; no endless spinners. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Offline write** — *Expected:* clear failure or queued behaviour; UI never claims success falsely. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Timeout / slow network** — *Expected:* loading state then error with retry. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **permission-denied** — *Expected:* message suggests signing in again; no raw code shown. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Missing document** — *Expected:* empty/not-found state, no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Partial data (fields missing)** — *Expected:* sensible fallbacks. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Airplane mode toggled while on a stream screen** — *Expected:* recovers when back online. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Firestore index missing** — *Expected:* error surfaced in logs, UI shows friendly error. *Actual:* · *Status:* Not tested · *Notes:*

## 16. Empty states

- [ ] **Request tab, no requests** — *Expected:* compact, flat (no big card). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Community, no stories** — *Expected:* compact state with Share your story. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Notifications, none** — *Expected:* simple message, no forced CTA. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Messages, none** — *Expected:* sits near the top third, not dead-centre; buttons not oversized. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Donation history, none** — *Expected:* no giant blank area. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Testimonials, none** — *Expected:* quotation-mark empty state, top-aligned. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Release build shows no invented people/stats** — *Expected:* no sample content anywhere. *Actual:* · *Status:* Not tested · *Notes:*

## 17. Duplicate actions / race conditions

- [ ] **Double-tap every primary button** (sign in, register, create request, accept, confirm, send testimonial, post story) — *Expected:* single effect. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Accept from two devices** — *Expected:* one winner. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Cancel while a donor accepts** — *Expected:* consistent final status, no orphan lock on the donor. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Confirm from both sides simultaneously** — *Expected:* one `fulfilled`; history written once. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Edit and delete the same story** — *Expected:* delete wins cleanly. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Rapid back/forward navigation on flow screens** — *Expected:* no duplicate pushes or crashes. *Actual:* · *Status:* Not tested · *Notes:*

## 18. App restart / persistence

- [ ] **Kill and reopen while signed in** — *Expected:* splash → ad screen (≤ 3 s) → main app. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Startup ad screen with no ad provider** — *Expected:* labelled "Advertisement", placeholder box, continues after about 3 s, never blocks. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Kill during an open request** — *Expected:* request state restored from Firestore. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Kill during a call** — *Expected:* call ends cleanly; no ghost "on call" bar. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Hidden authors / local prefs** — *Expected:* kept across restarts. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Device rotation / split-screen** — *Expected:* no state loss or overflow. *Actual:* · *Status:* Not tested · *Notes:*

## 19. Permissions

- [ ] **Location denied (once / permanently)** — *Expected:* map centres on a fallback city for display only; nothing stored from the fallback. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Location services off** — *Expected:* prompt to enable or manual search. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Notifications denied** — *Expected:* see section 8. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Microphone denied (calls)** — *Expected:* clear message; no crash. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Photo/gallery denied (Save certificate, story photo)** — *Expected:* helpful message; Share still works. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Camera denied (ID proof / story photo)** — *Expected:* falls back or explains. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Store-policy permissions absent** — *Expected:* no full-screen-intent, call-log or advertising-ID permissions in the installed manifest. *Actual:* · *Status:* Not tested · *Notes:*

## 20. Release / build checks

- [ ] `flutter analyze` — *Expected:* no issues. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] `flutter test` — *Expected:* all pass. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] `git diff --check` — *Expected:* clean. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] `flutter build apk --release` — *Expected:* succeeds; install and launch on a physical phone. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Release build without `ENABLE_PREVIEW_UI`** — *Expected:* none of the old preview/demo layer. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] `cd backend/rules-test && npm test` — *Expected:* all rules tests pass, including the new short-testimonial test (needs the emulator, Java 21). *Actual:* · *Status:* Not tested · *Notes:*
- [ ] `cd functions && npm test` — *Expected:* unit tests pass. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Deploy checklist (only when the owner decides)** — rules (`firestore:rules`) for the testimonial change; hosting for the updated privacy page; functions after Blaze. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Legal text matches behaviour** — *Expected:* `legal_documents.dart`, hosted HTML, `PrivacyInfo.xcprivacy` and `docs/publishing/store-listing.md` agree. *Actual:* · *Status:* Not tested · *Notes:*
- [ ] **Real-device visual QA** — *Expected:* My Page → Your impact, Donation history, Testimonials (+ Add sheet), Community identity, Messages and Settings all look right on small and normal phones. *Actual:* · *Status:* Not tested · *Notes:*
