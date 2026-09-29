# Chat, in-app calls, urgent alerts & store compliance — design

Status: approved direction (2026-09-26) — stay on Firebase Spark during development, move to Blaze after; calling and messaging happen inside the app (Instagram-style), not via WhatsApp.

## Constraints that shape everything

- **Spark plan**: no Cloud Functions, so no server-sent push. Anything that "rings" only works while the app process is alive. Every feature below is built so the Blaze upgrade only *adds* a push trigger — no client rewrite.
- **Store rules** (researched):
  - Android 14+ reserves full-screen intents for calling/alarm apps, so the urgent alert is a high-importance notification plus an in-app full-screen takeover.
  - On iOS, PushKit VoIP pushes must report a real CallKit call. Only real calls may ever use that path, never donation alerts.
  - Apple 5.1.1(v) and Google Play both require in-app account deletion.
  - Chat is user-generated content, so Apple 1.2 requires reporting and blocking.

## Data model (all under the request the two people were matched on)

| Path | Fields | Who |
|---|---|---|
| `requests/{id}/messages/{mid}` | `sender_uid`, `kind` (`text`\|`system`\|`call`), `text`, `sent_at` | read: both participants; create: participant, own uid, while request `matched`; delete: sender |
| `requests/{id}/calls/{cid}` | `caller_uid`, `callee_uid`, `caller_name`, `status` (`ringing`→`accepted`→`ended`, or `declined`/`missed`), `offer`, `answer`, timestamps | participants; collection-group read by `callee_uid` for incoming-call detection |
| `requests/{id}/calls/{cid}/{caller,callee}_candidates/{x}` | ICE candidates | participants |
| `requests/{id}.chat_closed_by` | uid that blocked | either participant may set once |
| `reports/{rid}` | reporter, reported, request, reason | create: self; read: admin |
| `donors/{uid}.urgent_alerts` | bool | owner |

A chat exists only between the two people on a matched request. There are no open DMs, which keeps the abuse surface small.

## Units

- `ChatService`: stream messages, send, close chat (block), report.
- `CallService`: WebRTC (flutter_webrtc) audio-only, with Firestore as the signalling channel. STUN = Google public servers; TURN is a config slot (needed for roughly 10–20% of mobile NAT pairs; paid, and it has to be decided before launch). It also exposes a stream of incoming calls.
- `UrgentAlertService`: watches open requests while the app is alive. It fires only for requests that are compatible, `urgent`/`critical`, within 25 km, less than 20 minutes old, not the donor's own, not seen before, and only when the donor is available with no active match and has opted in.
- `AccountService`: data export (JSON) and account deletion. Deletion cancels own requests, releases any match, deletes own messages, scrubs PII from shared request docs, deletes both donor docs, then the auth user.
- `LiveEventsHost`: mounted in the main tab shell. It turns incoming calls and urgent alerts into full-screen routes with a looping sound.

## UI

- **Chat**:
  - Warm paper ground. Header shows the other person, request context, a call button and a menu (call phone number, report, block).
  - A pinned safety strip: blood must never be bought or sold.
  - My bubbles are brand red and theirs are white; call logs and system events appear as centred hairline rows.
  - Donation-specific quick replies. When the chat is closed, a read-only footer replaces the composer.
- **Call**:
  - Ember field, the same family as matching and matched. A pulsing RingField surrounds the other person's disc while ringing.
  - Status line (Calling / Ringing / timer) and request context chip.
  - Controls: mute, speaker, message, end. Incoming calls get Decline/Accept.
- **Contact screens** (donor found, match contact): *Voice call* (in-app, primary), *Message* (in-app), and "call from your phone" as a small fallback link (a `tel:` link, no permissions).
- **Urgent alert**: opt-in toggle on My Page and in Settings. Turning it on explains the feature, then asks for OS notification permission. The alert itself is a full-screen takeover with a looping chime and vibration, *View request* / *Not now*, and auto-dismisses after 45 s.

## Also in scope

- Request fixes: hide cancelled requests, a "Keep waiting in background" button while searching, and confirmation before any cancel.
- A matched donor can release a match they can't honour. The request returns to `open`; previously the requester was stuck.
- `donors_public` coordinates are coarsened to about 1 km. They were exact, which contradicted the consent screen's "approximate location" promise.
- Privacy policy and terms written against actual behaviour. A reader page with a summary, contents and numbered sections. A draft banner shows until `kLegalApproved` is flipped.
- iOS usage strings, Android permissions and a proper app label.
- AI-slop cleanup:
  - Sentence case instead of ALL CAPS eyebrows.
  - No Unicode glyphs used as icons, and no Material `Icons`.
  - On-ember colours as tokens.
  - A brand-shaped `BrandGlyph` instead of generic tinted-circle icon chips on state screens.

## Explicitly not done now

- Real OTP (a launch blocker; needs Blaze/SMS).
- Closed-app push and CallKit/ConnectionService ringing (Blaze).
- TURN server procurement.
- Web account-deletion page (needs a real contact address).
