# PROJECT_HANDOFF.md — Rakta Bandhan Redesign

This document is a full context handoff from a prior Claude conversation (chat-based, not Claude Code) to Claude Code. It covers a UI/UX redesign of an existing Flutter blood-donation app. Read this fully before making changes.

---

## 1. PROJECT OVERVIEW

**What we're building:** A visual redesign of an existing Flutter app called **Rakta Bandhan** ("blood bond" in Hindi) — a blood donation app that connects people who need blood with nearby donors.

**Purpose:** The app already existed and was functional, but the client reviewed it and said it looked "very shitty," specifically that it "looks like fully AI" — meaning it read as an unpolished, templated, AI-generated UI rather than an intentionally designed product. The task was to diagnose exactly what made it look that way and rebuild the UI with a consistent, professional design system, while preserving the original functional flow.

**Target users:** People in India (the original recording showed Trivandrum, Kerala as the working location; mock donor data referenced other Indian cities — Chennai, Bangalore, Trichy, Mysuru) who either need blood urgently or want to register as donors.

**Intended platforms:** Originally scoped as mobile-only. Later in the conversation the user explicitly stated the app **must work on iOS, Android, Web (Chrome/Edge), and Windows** — i.e., all platforms Flutter can target. This is a hard requirement, not a nice-to-have.

**Overall UX:** Phone-based signup (OTP verification) → complete profile with blood group → land on a home screen with an emergency "find donors" action, nearby urgent requests, and personal impact stats → search donors via map or list → view donor details → send/manage blood requests → manage profile and availability status.

---

## 2. ORIGINAL REQUIREMENTS (chronological, all still relevant)

1. Redesign an existing Flutter blood donation app because the client said it "looks very shitty" / "looks like fully AI."
2. User uploaded two screen recordings of the existing app (`.mp4` files) showing: Welcome/phone entry, Register form, Home (Find Blood Donors form with blood group grid), a native OS date picker popping up mid-flow, a Map screen with donor pins, a donor list (bottom sheet style), and a Requests screen with Inbox/Outbox tabs.
3. User wanted help understanding **what to search for** as design inspiration (Dribbble/Mobbin/etc.) — this was later abandoned in favor of Claude directly mocking up screens (see Section 4).
4. User stated explicitly they didn't want the app to "look like an AI-made app" even though it is being built with AI assistance — meaning the deliverable itself, not the process, needed to look intentional/professional.
5. After diagnosis, user made these explicit choices when asked to choose a direction:
   - Color: **"deep red"**
   - Corner radius: **"softly rounded"**
   - Calendar: agreed it needed fixing (replace native OS picker)
   - Map: **"muted grey"**
   - Logo: **"should be same no need to change that"** — do not redesign the existing logo mark.
6. User wanted a full detailed style guide document to hand to ChatGPT, which would help structure a build prompt, which would come back to Claude for enhancement, then go to a build tool ("Antigravity") to produce a wireframe.
7. User later provided a 9-screen wireframe content spec (Splash, Login, OTP, Registration, Home, Find Donors/Map, Donor Details, Requests, Profile) that had been produced with ChatGPT's help, based on an "audit" of the old app. User said the final result "has to be similar to this" — i.e., this screen list and content structure is a requirement, not just inspiration.
8. Antigravity turned out to be **an actual agentic Flutter IDE working on the real codebase**, not a wireframe-only tool — this was discovered when the user shared a screenshot of the Antigravity file explorer showing a real Flutter project (`lib/`, `pubspec.yaml`, Android/iOS folders, already generated from the client's screen recording).
9. User wants the implementation to proceed **phase by phase**: theme foundation first, then one screen at a time, reviewing/approving each plan before the next is built — this was Claude's recommendation and the user followed it throughout.
10. User explicitly requested: **"keep giving prompt after you give changes"** — i.e., after reviewing/correcting each Antigravity plan, always supply the next screen's prompt automatically without being asked.
11. User hit a Windows/OneDrive file-lock error when running `flutter run` — needed a fix.
12. User stated: **"i want as app that works in ios and android both also works in edge chrome or windows whatever works everywhere"** and then, when offered a "defer iOS" option, said **"i have to work with all"** — all four platform targets (iOS, Android, Web, Windows) are required, not optional, though iOS requires a macOS build environment which is not available locally (Windows machine).

---

## 3. DESIGN / UI REQUIREMENTS (exact values)

### Color palette

| Token | Hex | Use |
|---|---|---|
| Primary (deep red) | `#8C1F2B` | Headers, primary buttons, selected states, map pins, urgent badges — the **only** saturated color in the app |
| Primary light tint | `#F6DCDE` | Badge backgrounds, avatar backgrounds |
| Text on primary | `#FBE6E8` | Text/icons on solid red backgrounds (deliberately not pure white — softer contrast) |
| Text primary | `#1A1A1A` | Body text, names |
| Text secondary | `#6B6B68` | Supporting text, labels, distances |
| Text muted | `#9C9C98` | Placeholders |
| Border | `#E5E3DD` | Input borders, card borders, dividers |
| Border strong | `#D3D1C7` | Selected/hover input borders |
| Surface / card background | `#FFFFFF` | Cards, sheets |
| Page background | `#F7F6F2` | Screen background behind cards |
| Map base | `#E8E6E1` | Muted map background |
| Map grid/roads | `#DEDCD6` | Road lines on map |

### Status colors (Requests / Availability only — the one exception to "single saturated color")

| Status | Background | Text |
|---|---|---|
| Urgent | `#F6DCDE` | `#8C1F2B` |
| Pending / awaiting | `#FAEEDA` | `#854F0B` |
| Available / verified | `#EAF3DE` | `#3B6D11` |
| Completed | `#EAF3DE` | `#3B6D11` |

### Typography
- One system font family throughout — do not mix fonts.
- Two weights only: Regular (400) and Medium (500). No bold (700), no light (300).
- **Sentence case everywhere. Never ALL CAPS.** (This directly fixes an original-app problem — see Section 11.)

| Style | Size | Weight | Use |
|---|---|---|---|
| Screen title | 20px | 500 | "Rakta Bandhan", top-of-screen labels |
| Section label | 13px | 500 | "Blood group needed", field labels |
| Body / input text | 14px | 400–500 | Form values, card text |
| Name (card) | 14px | 500 | Donor name |
| Supporting text | 12–13px | 400 | Distance, location, timestamps |

### Spacing and radius
- Base spacing unit: **4px**. All padding/margins are multiples of 4.
- Screen padding: 20px left/right.
- Corner radius: **14px** on all buttons, inputs, cards, map corners, badges — one consistent value everywhere.
- **16px** top corners specifically for bottom sheets.
- Circular only for: avatars, map pin dots, calendar selected-date indicator.

### Icons
- **One outline/line icon set only** — Tabler or Feather were proposed in the spec; the actual Flutter implementation used the **`lucide_icons`** package.
- **No emoji anywhere in the UI**, ever — this was one of the biggest "looks AI-made" signals in the original app (📅, 📞, 👤, 📍, 🩸, ✓, ● were all used as literal icon placeholders in the original app and in the user's wireframe content draft — these must always map to real outline icons, never literal emoji glyphs, in the actual build).
- Icon size: 16px inline next to labels, 18–20px for standalone actions.
- Default `IconThemeData` was added to the Flutter theme: size 16, color `AppColors.textSecondary`, so icon styling doesn't need to be restated per screen.

### Components

**Buttons (primary):** background `#8C1F2B`, text `#FBE6E8`, radius 14px, padding 13px vertical. Only one primary button visible per screen — everything else is outlined or plain text.

**Buttons (secondary/outlined):** transparent background, border `#E5E3DD`, text `#8C1F2B`, 14px radius.

**Inputs:** border `#E5E3DD` (1px), radius 14px, padding 12px/14px, white background. On focus, border becomes `#8C1F2B`. Placeholder text uses `textMuted`.

**Date/time picker:** must NEVER trigger the native OS picker — this was an explicit, named problem in the original app (a native calendar dialog popped up mid-flow, breaking the illusion of a designed product). Build a custom in-app component instead.

**Blood type selector grid:** 4 columns, 8px gap, 14px radius per cell. Unselected: white background, `#E5E3DD` border, `#1A1A1A` text. Selected: `#8C1F2B` background and border, `#FBE6E8` text. **Single-select only (radio behavior)** — selecting a new blood type deselects the previous one.

**Donor cards:** white background, `#E5E3DD` border, 16px radius, 12px padding. Left: 40px circular avatar, tint background `#F6DCDE`, initials in `#8C1F2B`. Middle: name (14px/500) + location/distance (12px, secondary grey). Right: blood type badge — tint background `#F6DCDE`, text `#8C1F2B`, small pill. One primary action per screen, not crammed into every card.

**Map:** custom muted/greyscale style (background `#E8E6E1`, roads `#DEDCD6`) — not default Google Maps styling. Pins: solid `#8C1F2B` filled pin icon, not the default red Google marker. Bottom sheet: white surface, 16–20px top radius, centered drag handle (36×4px grey bar).

---

## 4. DESIGN REFERENCES / INSPIRATION

**Important: no specific external design references (Dribbble shots, specific app screenshots, named URLs) were actually used or approved in this conversation.** Early on, Claude suggested general search categories and sites (Dribbble, Mobbin, Behance, Pinterest, Land-book) and named example apps for structural inspiration only:

- Healthcare app home screens: Ada Health, Calm, Headspace, Oscar Health (suggested for information hierarchy)
- Map + bottom sheet pattern: Uber, Airbnb, Google Maps (suggested for the map/donor-list screen pattern)
- Card layouts: dating apps, social app profile cards (suggested for donor card scannability)

**None of these were confirmed as chosen references by the user.** The user pivoted away from the "search for inspiration" approach entirely and asked Claude to directly design and mock up the screens instead. All actual visual decisions (colors, radius, layout) came from Claude's mockups (built with the Visualizer tool) plus the user's direct one-word approvals ("deep red," "softly rounded," "muted grey," "logo should be same"). Do not assume any specific external app's exact visuals were referenced beyond these general structural mentions.

---

## 5. ANTIGRAVITY PROMPTS (exact wording, what each accomplished)

Antigravity is an agentic Flutter IDE the user is using, working directly on the real `rakta_bandhan` Flutter project (already scaffolded from the client's screen recording before this conversation's redesign work began). The working approach was: **audit → build shared theme foundation → one screen at a time, review each plan before approval, review each completion report after.**

### Audit prompt
```
Read design/v1_original/rakta-bandhan-style-guide.md and design/v1_original/rakta-bandhan-full-build-spec.md.

Before making any changes, explore the lib/ folder and give me a summary of:
1. Every screen/widget file that currently exists and what it renders
2. Any existing theme, colors, or constants file (if none exists, say so)
3. Which packages are currently used for icons, date pickers, and maps

Do not change any code yet. Just report back.
```
Purpose: establish ground truth before touching anything. (Result of this specific run was not reported back in the conversation — the user proceeded straight to the foundation build.)

### Design foundation prompt
Goal: build `AppColors` and `AppTheme` as a single source of truth before any screen work. Result (Antigravity's own plan, approved with one addition): created `lib/theme/app_colors.dart` (all hex constants above) and `lib/theme/app_theme.dart` (ThemeData: 14px radius buttons/inputs, 400/500 text weights, bottom sheet 16px top radius). **Claude's addition, approved and applied:** add a default `IconThemeData` (size 16, color `AppColors.textSecondary`) so icon styling isn't restated per screen. Also added `lucide_icons` package to `pubspec.yaml`.

### Splash screen
Result: `splash_screen.dart` — `LucideIcons.droplet` icon in `AppColors.primary`, "Rakta Bandhan" at 20px/500, tagline "Every drop counts. Together, we save lives." in `textSecondary`. **Correction applied:** use `Navigator.pushReplacement` (not `push`) so Splash isn't reachable via back button. A placeholder `login_screen.dart` was created alongside it with a `// TODO` comment.

### Login screen
Result: `login_screen.dart` — "Welcome to Rakta Bandhan" title, "Your help can save a life." subtitle, `+91` prefix + phone `TextField`, primary "Continue" button, muted consent text. **Correction applied:** added validation (non-empty, exactly 10 digits, numeric only) with inline red error text instead of navigating unconditionally, and `keyboardType: TextInputType.phone`.

**Note — user error and recovery:** the user let Antigravity build the OTP screen before Claude's login corrections were sent. Recovery: asked Antigravity to retroactively add the validation to `login_screen.dart` only (without touching `otp_screen.dart`), then reviewed the already-built OTP code directly.

### OTP screen
Reviewed actual code (not just a plan, since it was already built). Found and fixed one bug:
```dart
// WRONG — found in the back button:
Icons.arrow_back
// FIXED to:
LucideIcons.arrowLeft
```
This was flagged as exactly the "mixed icon set" problem the whole redesign was meant to eliminate. Everything else in the OTP implementation was correct on first pass: masked phone display (`+91 ******1234`), 6-box input with auto-forward/back focus, inline error if incomplete, "Resend OTP" link in primary red, themed "Verify" button, placeholder `registration_screen.dart` created with `// TODO`.

### Registration screen
Plan reviewed and approved with one clarification requested and confirmed: blood group grid must be **single-select only (radio behavior)** — this wasn't explicit in Antigravity's plan wording and was locked down before approval. Also flagged (and confirmed correct): don't create a second color constant (e.g. `whiteTextOnPrimary` vs `textOnPrimary`) meaning the same thing — reuse the existing one.

### Home screen
Plan reviewed and approved with one explicit confirmation required: the "Need blood?" heading must be in **sentence case, not uppercase** ("NEED BLOOD?" was explicitly named as one of the original app's exact problems). Also confirmed: distance text format must be singular/non-duplicated ("2.4 km away", never a repeated unit).

### Map / Find Donors screen
Plan required a correction before approval: proposed map background colors (`0xFFE0DFDB` / `0xFFE8E5DD`) did not match the spec's exact `#E8E6E1`, and the color was going to be hardcoded inline in the screen file rather than referenced from `AppColors`. Correction sent and applied: use `AppColors.mapBase` (`#E8E6E1` exactly) and ensure no hardcoded hex values appear in screen files — everything routes through `AppColors`. Antigravity's plan correctly **did not** add `google_maps_flutter` without asking first — it built a static, custom-drawn placeholder map (grey grid background + `AppColors.primary` pin icons via `Positioned` widgets in a `Stack`) instead of requiring a live Google Maps API key.

### Donor Details screen
Plan approved with no corrections needed — it correctly proposed passing donor data (name, initials, blood group, distance, verified/availability status) via constructor parameters from `find_donors_screen.dart` rather than hardcoding new fake data on the details screen, which Claude had specifically asked for.

### Requests screen
Plan approved with no corrections — it correctly reused the existing status color constants from `app_colors.dart` (Pending/Urgent/Accepted/Completed) rather than creating new ones, and used the "Blood requests" / "Received" / "My requests" naming instead of the original app's "Inbox/Outbox."

### Profile screen
Plan approved with no corrections — it even proactively made the availability status dot/label dynamically reflect the `Switch` state (Available/Unavailable) rather than being static, which was a good addition beyond what was asked. Explicit styling was applied for the `Switch` (`activeColor: AppColors.primary`, `activeTrackColor: AppColors.primaryLightTint`) since Flutter's default Switch does not automatically use theme primary color.

### Bottom Navigation
Plan required one explicit confirmation before approval: `FindDonorsScreen` and `DonorDetailsScreen` must **not** become tabs in the `IndexedStack` — they must remain reachable only via `Navigator.push` on top of `MainNavigationScreen`, so the bottom nav bar disappears while viewing them and back returns to whichever tab launched them. Confirmed correct in the final walkthrough: `main_navigation_screen.dart` created with `IndexedStack` holding `HomeScreen`, `RequestsScreen`, `ProfileScreen`; `registration_screen.dart` updated to navigate to `MainNavigationScreen` via `pushAndRemoveUntil` (clearing the Login/OTP/Registration backstack).

---

## 6. ITERATIONS AND CHANGES (chronological, with reasoning)

1. **Initial ask:** help finding design inspiration (search keywords for Dribbble/Mobbin). → **Changed to:** user didn't know how to choose between options as a design novice, and revealed the real driver — a client called the existing app "very shitty," "looks like fully AI." Claude pivoted from "help you search" to "let me diagnose your actual screens."
2. **Diagnosis phase:** Claude extracted frames from two user-uploaded screen recordings and identified concrete issues: emoji mixed with real icons, an overly detailed logo, no single accent color (red/pink/green all present), a native OS date picker breaking into the flow, inconsistent donor card styling, a text bug ("12 Km Km away"), and an unstyled default grey Google Map.
3. **First mockup (Visualizer):** built using a wine/maroon primary (`#5C1A2B`) as one possible direction, with Tabler-style icons, soft radius, tinted badges. Presented as "one direction, not the only right answer."
4. **User feedback:** "deep red / what does it mean [re: icon set] / softly rounded / the calendar / muted grey / logo should be same no need to change." → **Changed to:** second mockup using `#8C1F2B` (a more muted/deep red than the first draft), explicit clarification given on what "icon set" means, custom in-app calendar component shown inline (not native), map area mocked with muted grey + red pins.
5. User approved and asked for a second mockup of the map/donor-list screen in the same system. → Built: map header with location + filter + blood-type badge, muted map with pins, bottom sheet with donor cards, fixed the "12 Km Km away" bug in the mock (now "12 km away"), badges shown as tinted (not solid) backgrounds so multiple badges in a list don't visually shout over each other.
6. User asked: "will [ChatGPT → Claude → Antigravity] workflow work?" → Claude gave an honest assessment (yes but risk of drift at each handoff) and produced a `rakta-bandhan-style-guide.md` file with exact hex/px values specifically to minimize reinterpretation risk.
7. User provided a 9-screen wireframe content draft (from their own ChatGPT session) and said "it has to be similar to this." → Claude reviewed it positively, flagged that it still used emoji as icon placeholders (a problem if taken literally into the build), and merged it with the visual spec into `rakta-bandhan-full-build-spec.md` — one document with both screen content and exact visual rules.
8. User asked for a literal prompt to paste into Antigravity. → Claude provided one, plus instructions to attach both spec files.
9. User said they couldn't attach `.md` files to the Antigravity agent. → Claude suggested: drop files into the project folder directly (agentic tools read the filesystem), or rename to `.txt`, or paste content directly into the prompt.
10. **User revealed Antigravity is actually building real Flutter code** (screenshot of a real project with `lib/`, `pubspec.yaml`, `android/`, `ios/` folders — described as "generated from the recording we had"). → Claude changed its whole approach: recommended an audit-first, foundation-first, then one-screen-at-a-time phased build with review at each step, rather than treating Antigravity as a wireframe tool.
11. Foundation plan reviewed → approved with the `IconThemeData` addition.
12. Splash plan reviewed → approved with `pushReplacement` correction.
13. Login plan reviewed → approved with validation + phone keyboard type correction.
14. **User error:** approved/let Antigravity run ahead and build OTP before sending Login's correction. → Claude gave calm recovery steps (retroactively patch Login, review OTP code directly since the plan-review step was skipped for it).
15. OTP code reviewed directly → found and fixed the `Icons.arrow_back` vs `LucideIcons.arrowLeft` bug.
16. Walkthrough confirmed foundation/Splash/Login/OTP all correct.
17. Registration plan reviewed → approved with single-select clarification + duplicate-constant-naming check.
18. Home plan reviewed → approved with sentence-case ("Need blood?" not "NEED BLOOD?") and distance-format confirmations.
19. User asked "keep giving prompt after you give changes" → Claude changed its response pattern from that point forward: always append the next screen's ready-to-paste prompt immediately after reviewing/approving the current one, without being asked each time.
20. Map/Find Donors plan reviewed → **correction required and applied:** wrong hex values proposed for map background, and inline hardcoding instead of using `AppColors` — both fixed before approval.
21. Donor Details plan reviewed → approved with no corrections (data-passing via constructor was already handled correctly).
22. Requests plan reviewed → approved with no corrections (status color reuse was already correct).
23. Profile plan reviewed → approved with no corrections (dynamic switch-linked status was a good unprompted addition).
24. Bottom Navigation plan reviewed → approved with one required confirmation (Find Donors/Donor Details must stay push-screens, not tabs) — confirmed correct in the final report.
25. Final walkthrough reviewed — full 11-item summary, `dart analyze` clean. One unresolved visual flag carried forward: Donor Details "Info Grid block" was implemented as a bordered white container, while the original spec described a simpler divider + label/value row layout — **this was never visually confirmed one way or the other**, since the app had not yet been run.
26. User tried `flutter run`, hit a Windows/OneDrive file-lock error (`Flutter failed to delete a directory at ...ios\Flutter\ephemeral\Packages\.packages`). → Claude diagnosed this as a OneDrive-sync-vs-file-lock conflict (environment issue, not a code issue) and gave two fixes: manually delete the stuck folder (pausing OneDrive sync if needed), or move the whole project outside any OneDrive-synced folder (the durable fix).
27. User asked about iOS + Android + Web + Windows support. → Claude explained Flutter already supports all of these from one codebase, but iOS specifically requires macOS/Xcode, which is unavailable on a Windows machine — gave three options (cloud Mac build service like Codemagic, borrow/rent Mac access, or defer iOS until later) and recommended deferring.
28. User said "i have to work with all" (rejecting deferral). → Claude gave a concrete non-blocking roadmap: get Windows/Web/Android working today (no cost, no blockers), then separately set up Codemagic + an Apple Developer account ($99/yr) + a GitHub repo (needed since cloud Mac builders build from a git remote, not the local machine) for iOS — explicitly framed as parallel tracks, not something that blocks seeing the app run today.
29. **As of the end of this conversation, the user has not yet successfully run the app and has not visually confirmed any screen renders correctly.** The OneDrive error was the last blocker discussed before this handoff was requested.

---

## 7. CURRENT IMPLEMENTATION STATE

### Definitely implemented (reported complete by Antigravity, `dart analyze` clean at each step)
- `pubspec.yaml` — `lucide_icons` added
- `lib/theme/app_colors.dart` — all color constants from Section 3
- `lib/theme/app_theme.dart` — ThemeData (button/input/text/icon theming, 14px/16px radius rules)
- `main.dart` — wired to `AppTheme.lightTheme`, entry point is `SplashScreen`
- `splash_screen.dart` — complete, 2-second auto-navigate via `pushReplacement`
- `login_screen.dart` — complete, with phone validation and error states
- `otp_screen.dart` — complete, with icon bug fixed
- `registration_screen.dart` — complete, single-select blood group grid, validation
- `home_screen.dart` — complete (greeting, emergency card, nearby requests, impact stats)
- `find_donors_screen.dart` — complete, but map is a **static custom-drawn placeholder**, not a real interactive map
- `donor_details_screen.dart` — complete, data passed via constructor from Find Donors
- `requests_screen.dart` — complete, Received/My Requests tabs, status badges
- `profile_screen.dart` — complete, dynamic availability switch, logout flow
- `main_navigation_screen.dart` — complete, `IndexedStack` bottom nav for Home/Requests/Profile

### Probably implemented but NOT visually verified by a human
**Everything above.** `dart analyze` only checks that the code compiles — it does not confirm visual correctness, layout, spacing, or that the screens actually look like the intended design. The user has not yet successfully run the app on any device or browser. Treat all of the above as "code exists and compiles" rather than "confirmed correct."

### Requested but unclear whether implemented
- Whether the Donor Details "Info Grid block" ended up looking like a nested/redundant card (bordered container) versus the simpler divider-based layout originally specified — flagged, never resolved.

### Still pending / not started
- Actually running and visually reviewing the app (blocked by the OneDrive error at end of conversation)
- Real Google Maps integration (explicitly deferred, static placeholder in place instead)
- Real backend/auth (OTP currently accepts any 6-digit input with no real verification)
- Real Call/WhatsApp integration (currently `SnackBar` placeholders)
- Real location search functionality on Registration
- iOS build pipeline (Codemagic account, Apple Developer account, GitHub repo push)
- Any real persistence/data layer

---

## 8. SCREEN-BY-SCREEN SPECIFICATION

### 1. Splash
- **Purpose:** brand intro, auto-advances to Login.
- **Elements:** `LucideIcons.droplet` icon in `AppColors.primary`, "Rakta Bandhan" (20px/500), tagline "Every drop counts. Together, we save lives." (13px/400, `textSecondary`).
- **Navigation:** auto-navigates to Login after 2 seconds via `Navigator.pushReplacement` (not reachable via back button).
- **State/validation:** none.

### 2. Login
- **Purpose:** phone number entry to begin auth.
- **Elements:** "Welcome to Rakta Bandhan" (title), "Your help can save a life." (subtitle), `+91` prefix container + phone `TextField`, primary "Continue" button, muted consent fine print (12px).
- **Validation:** phone must be non-empty, exactly 10 digits, numeric only; inline red error shown if invalid; `keyboardType: TextInputType.phone`.
- **Navigation:** on valid submit → `OtpScreen(phoneNumber: phoneText)` via `Navigator.push`.

### 3. OTP
- **Purpose:** verify phone via 6-digit code (mock — no real SMS/verification backend).
- **Elements:** "Verify your number" title, subtitle with masked number (`+91 ******1234`), 6 individual digit boxes (14px radius, centered), "Didn't receive it? Resend OTP" link in primary red, primary "Verify" button.
- **Interactions:** auto-forward focus on digit entry, auto-backward focus on delete/backspace.
- **Validation:** all 6 boxes must be filled; inline red error if incomplete. **No real OTP check — any 6 digits are accepted.**
- **Navigation:** back button uses `LucideIcons.arrowLeft`. On verify → `RegistrationScreen`. Resend shows a `SnackBar`, no real resend logic.

### 4. Registration
- **Purpose:** complete donor/user profile.
- **Elements:** Name field, WhatsApp number field (`keyboardType: TextInputType.phone`), Location field (text input + `LucideIcons.mapPin`, no real search wired), Blood group 4×2 selector grid (single-select/radio behavior), primary "Complete registration" button.
- **Validation:** Name and WhatsApp number required, blood group must be selected; inline errors shown, no silent navigation.
- **Navigation:** on success → `MainNavigationScreen` via `pushAndRemoveUntil` (clears Login/OTP/Registration from the back stack).

### 5. Home (hero screen)
- **Purpose:** main landing screen post-auth; emergency action + social proof/impact.
- **Elements:** greeting "Good morning, Ashi" (20px/500) + "Ready to make a difference?" subtitle (14px, `textSecondary`, placeholder name — no real user data wired); Emergency card (white, 16px radius, bordered) with droplet icon, "Need blood?" heading (sentence case, **not** caps), body text, primary "Find blood donors" button; "Nearby requests" section with a request card (blood type badge, "Urgent" status badge, location/distance "2.4 km away", outlined "View request" button); "Your impact" section — two stat blocks (Donations: 2, Lives helped: 6) in a muted, borderless container, 24px/500 numbers with 13px labels.
- **Navigation:** "Find blood donors" → `FindDonorsScreen`.

### 6. Map / Find Donors
- **Purpose:** search/browse donors by location.
- **Elements:** search bar (themed input, `LucideIcons.search` leading icon, "Search location" placeholder); static custom-drawn map area (`AppColors.mapBase` `#E8E6E1` background, `AppColors.mapGridRoads` `#DEDCD6` grid lines, `AppColors.primary` solid pin icons via `Stack`/`Positioned` — **not a real Google Map**); bottom sheet (16px top radius, drag handle, "Nearby donors" label) with a scrollable list of donor cards (circular initials avatar, name, blood type badge, verified check badge, distance, availability dot, outlined "View" and "Request" buttons) using 2–3 sample donors.
- **Navigation:** "View" → `DonorDetailsScreen` (with donor data passed via constructor). "Request" shows a `SnackBar` placeholder.

### 7. Donor Details
- **Purpose:** detailed donor profile, initiate a request.
- **Elements:** centered ~80px circular avatar (initials), name (20px/500), blood type badge (pill), verified badge + availability status dot/label, distance + city with map-pin icon, divider, info block (Blood group / "O positive", Availability / "Available now" — implemented as a bordered white container, flagged as possibly not matching the simpler original spec), primary "Request donor" button (full width), two outlined secondary buttons side by side ("Call" with phone icon, "WhatsApp" with message icon).
- **Data:** all fields (initials, name, blood group, verified, distance, availability) passed dynamically via constructor from whichever donor card was tapped on the Map/Find Donors screen — not hardcoded.
- **Interactions:** Call/WhatsApp show `SnackBar` placeholders, no real telephony/WhatsApp integration.

### 8. Requests
- **Purpose:** view incoming and outgoing blood requests.
- **Elements:** title "Blood requests" (not "Inbox/Outbox" — explicit rename from the original app); two-tab toggle "Received" / "My requests" (active = solid red pill with white text, inactive = plain text); scrollable list of 3–4 sample request cards, each with blood type badge, location/distance ("2.4 km away · City Hospital" — single unit, no duplication), status badge (Pending = amber tint, Urgent = primary tint, Accepted/Completed = green tint — reusing the same status constants as Home), outlined "View" button.
- **Interactions:** "View" shows a `SnackBar` placeholder.

### 9. Profile
- **Purpose:** view/manage own profile and settings.
- **Elements:** centered ~80px circular avatar ("AG" initials), name (20px/500, "Ashi Gupta" placeholder), blood type badge ("O+"), verified badge + availability status (dynamically tied to the Switch below), divider, tappable menu rows (Personal information, Donation history, Emergency contact, Settings — each with leading icon + trailing chevron, `SnackBar` placeholder on tap), divider, Availability row with a `Switch` (explicitly styled `activeColor: AppColors.primary`, `activeTrackColor: AppColors.primaryLightTint` since Flutter's default Switch doesn't inherit theme primary color automatically), divider, "Log out" as a de-emphasized plain text row (not a button, `textSecondary` color).
- **Navigation:** "Log out" → `LoginScreen` via `pushAndRemoveUntil` (clears entire nav stack).

### Bottom Navigation shell (`main_navigation_screen.dart`)
- **Purpose:** connects Home/Requests/Profile as persistent tabs.
- **Elements:** `BottomNavigationBar` with `LucideIcons.home`, `LucideIcons.clipboardList`, `LucideIcons.user`; selected = `AppColors.primary`, unselected = `AppColors.textMuted`; white background with a subtle top border (`AppColors.border`).
- **Behavior:** uses `IndexedStack` (not simple screen replacement) so tab state/scroll position is preserved when switching tabs. `FindDonorsScreen` and `DonorDetailsScreen` are **not** tabs — they are pushed on top of this shell via `Navigator.push`, hiding the bottom nav bar while active, and returning to the correct tab on back.

---

## 9. FUNCTIONAL REQUIREMENTS (real vs. mock)

| Area | Status | Notes |
|---|---|---|
| Authentication / Login | **Mock** | Phone format validated locally; no real backend auth |
| OTP verification | **Mock** | Any 6-digit input is accepted as "verified" — no real SMS/OTP backend |
| Registration | **Mock** | Local form validation only; no persistence backend |
| Donor search | **Mock** | Static placeholder donor data (2–3 sample donors); no live backend or real map |
| Donor details | **Mock** | Data passed from the mock donor card that was tapped, not from a real data source |
| Blood requests | **Mock** | 3–4 placeholder request cards with mixed statuses; no backend |
| Profile | **Mock** | Hardcoded placeholder user ("Ashi Gupta", "AG", O+); Switch toggles local UI state only, not persisted |
| Navigation | **Real** | Fully functional Flutter `Navigator` routing throughout |
| Location / Maps | **Mock** | Static custom-drawn placeholder map — explicitly NOT integrated with `google_maps_flutter` or any real geolocation, pending an explicit decision + API key/billing setup |
| Calling | **Mock** | "Call" button shows a `SnackBar`, no real telephony intent |
| WhatsApp | **Mock** | "WhatsApp" button shows a `SnackBar`, no real WhatsApp deep link/intent |
| Notifications | **Not discussed** | Not mentioned anywhere in the conversation |
| Persistence / backend / API | **Not discussed** | No backend, database, or API was ever specified or implemented |

---

## 10. TECHNICAL REQUIREMENTS

- **Framework:** Flutter, Dart SDK `^3.13.0` (from `pubspec.yaml`).
- **Project name:** `rakta_bandhan`.
- **Dependencies (confirmed):**
  - `cupertino_icons: ^1.0.8`
  - `flutter_lints: ^6.0.0` (dev dependency)
  - `lucide_icons` — added during this conversation, the app's sole icon package
- **State management:** none specified beyond built-in `StatefulWidget`/`setState`. No Provider, Riverpod, Bloc, or similar was discussed or implemented.
- **Backend / API / database:** none. Not discussed beyond acknowledging OTP/auth/maps are currently mock.
- **Platform build status:**
  - **Android:** buildable directly on the user's Windows machine (no blockers beyond the general Flutter toolchain).
  - **Web (Chrome/Edge):** buildable directly on Windows.
  - **Windows desktop:** buildable directly on Windows.
  - **iOS:** **cannot be built from a Windows machine.** Requires macOS + Xcode. Recommended path: a cloud Mac CI service (Codemagic was specifically named, has a Flutter-focused free tier) connected to a Git repository, plus an Apple Developer account (~$99/year) for signing/distribution/testing on real devices.
- **Known environment issue:** the project folder lives inside a OneDrive-synced path (`C:\Users\Ashi Gupta\OneDrive\Pictures\Desktop\rakta_bandhan`). OneDrive's file-locking during sync conflicts with Flutter's build process, causing errors like:
  ```
  Flutter failed to delete a directory at
  "...\rakta_bandhan\ios\Flutter\ephemeral\Packages\.packages".
  ```
  Recommended durable fix: move the project to a non-OneDrive-synced path (e.g. `C:\Dev\rakta_bandhan`). This was given as guidance but **not confirmed resolved** by the end of the conversation.
- **Git / GitHub:** not yet set up as of this handoff, but required for the recommended iOS build path (Codemagic builds from a git remote, not a local machine).

---

## 11. WHAT I DID NOT WANT (explicit rejections/negative constraints — preserve these)

- **No emoji as UI icons, anywhere, ever.** This was the single most repeated correction throughout the whole conversation, in the original app diagnosis, the wireframe content draft, and code review (caught in the OTP screen's back button).
- **No native OS date/time picker.** Must always be a custom in-app component.
- **No more than one saturated brand color.** Red (`#8C1F2B`) is the only one; the original app's mixed red/pink/green was explicitly named as a problem. Status colors (Pending/Urgent/Available/Completed) are the one sanctioned exception, and even those must come from the shared `AppColors` constants, never introduced ad hoc.
- **No inconsistent corner radius.** Every button, input, card, and badge must use the same 14px value (16px only for bottom-sheet top corners). Do not introduce sharp corners or pill-shapes elsewhere.
- **No default/unstyled Google Maps grey theme.** Must be a custom muted style if/when real maps are integrated.
- **No ALL CAPS text.** The original app's "REGISTER" and "NEED BLOOD?" headers in all-caps were named specifically as looking templated; everything must be sentence case.
- **Do not change the existing logo.** User was explicit and direct about this — leave it as-is.
- **No duplicated-unit text bugs** (e.g. "12 Km Km away" from the original app) — always a single, correctly formatted unit string.
- **No hardcoded inline hex colors in screen files.** Every color must reference an `AppColors` constant — caught and corrected on the Find Donors screen when Antigravity initially proposed inline hex values.
- **No duplicate color constants with different names for the same value** (e.g. `whiteTextOnPrimary` vs `textOnPrimary`) — checked explicitly on the Registration screen.
- **Do not make `FindDonorsScreen` or `DonorDetailsScreen` into bottom-nav tabs.** They must remain push-based screens that hide the bottom nav while active.
- **Do not build all 9 screens (or the whole app) in a single giant prompt.** The user and Claude explicitly agreed on a one-screen-at-a-time, review-before-approve approach specifically to avoid inconsistency creeping back in across screens.
- **Do not add `google_maps_flutter` (or any new API-key-dependent package) without flagging it first for discussion** — Antigravity correctly followed this instruction on its own.
- **Do not silently accept an Antigravity plan without checking it against the spec files** — the user's own working pattern throughout was to paste every plan back for review before approving.

---

## 12. KNOWN ISSUES

1. **OTP back button initially used `Icons.arrow_back` (default Material icon) instead of `LucideIcons.arrowLeft`.** — Fixed and confirmed.
2. **Map background color initially proposed as `0xFFE0DFDB` / `0xFFE8E5DD`, not the spec's exact `#E8E6E1`, and was going to be hardcoded inline rather than referenced from `AppColors`.** — Fixed and confirmed (now `AppColors.mapBase`).
3. **Donor Details "Info Grid block" was implemented as a bordered white container**, while the original spec described a simpler divider + label/value row layout. **Flagged as a visual risk — never confirmed resolved, since the app has not been run.** Needs a human visual check: does it look like a redundant "card inside a card"?
4. **Find Donors screen's map is a static, custom-drawn placeholder** (grid lines + positioned pin icons), not a real interactive map. **Flagged as a visual risk** — needs a human check on whether it reads as intentional or as broken/empty, especially since there's no live user location or real donor coordinates.
5. **OneDrive sync causes Flutter build file-lock errors** on the user's Windows machine (`flutter run` failed trying to delete `ios/Flutter/ephemeral/Packages/.packages`). Guidance given (move project outside OneDrive-synced folder) but **not confirmed resolved**.
6. **The app has never been successfully run or visually verified by the user as of this handoff.** All implementation status above is based solely on `dart analyze` (a compile-check) and Antigravity's own self-reported walkthroughs — none of it has been confirmed by an actual human looking at rendered screens. This is the single most important caveat for whoever picks this up next.

---

## 13. TODO / REMAINING WORK

### Critical
- Resolve the OneDrive file-lock issue (move project out of any OneDrive-synced folder) and get `flutter run` working.
- Actually run the app and visually verify every one of the 9 screens + bottom nav against the design spec — this has never happened yet.
- Specifically resolve the Donor Details "Info Grid block" bordered-container question (Section 12, item 3).
- Specifically resolve whether the Find Donors static map placeholder looks acceptable (Section 12, item 4).

### Important
- Decide: keep the static map placeholder long-term, or integrate `google_maps_flutter` with a real API key + billing setup (this was explicitly deferred, not rejected).
- Set up a Git repository and push the code (prerequisite for any cloud-based iOS build).
- Set up Codemagic (or equivalent) + an Apple Developer account for iOS builds, once the app's design is confirmed and stable on Android/Web/Windows.
- Decide on and implement a real backend/auth solution — OTP currently accepts any input, which is fine for a prototype but not for anything real.
- Wire up real Call and WhatsApp intents (currently `SnackBar` placeholders).
- Wire up real location search on the Registration screen.

### Optional / polish
- Replace hardcoded placeholder data (name "Ashi Gupta"/"Ashi", initials "AG", donation stats "2"/"6", sample donors, sample requests) with real dynamic data once a backend exists.
- Test layouts on multiple device sizes for overflow/wrapping issues (not yet tested at all).
- Check color contrast, especially the red-selected-state-on-red-badge scenarios, for accessibility.
- Decide on a state management approach if/when the app grows beyond simple `setState` usage.

---

## 14. IMPORTANT FILES

| File | Purpose |
|---|---|
| `design/v1_original/rakta-bandhan-style-guide.md` | Standalone visual style guide: exact hex colors, typography scale, spacing/radius rules, component specs, and an explicit "what NOT to do" list. Intended to be dropped into the project folder and read by Antigravity. |
| `design/v1_original/rakta-bandhan-full-build-spec.md` | Merged document combining the 9-screen content wireframe (from the user's own ChatGPT session) with the same visual system from the style guide — this is the primary spec Antigravity was instructed to follow screen-by-screen. |
| `lib/theme/app_colors.dart` | All color constants (brand, neutral, status) — single source of truth for color, referenced by every screen. |
| `lib/theme/app_theme.dart` | Central `ThemeData` — button/input/text/icon theming, radius rules, wired into `MaterialApp` in `main.dart`. |
| `lib/main.dart` (or project root `main.dart`) | App entry point; sets `theme: AppTheme.lightTheme` and `home: SplashScreen`. |
| `lib/screens/splash_screen.dart` | Splash screen. |
| `lib/screens/login_screen.dart` | Login/phone entry screen. |
| `lib/screens/otp_screen.dart` | OTP verification screen. |
| `lib/screens/registration_screen.dart` | Profile completion screen. |
| `lib/screens/home_screen.dart` | Home/hero screen. |
| `lib/screens/find_donors_screen.dart` | Map/donor search screen (static placeholder map). |
| `lib/screens/donor_details_screen.dart` | Donor detail view/bottom sheet. |
| `lib/screens/requests_screen.dart` | Blood requests (Received/My requests) screen. |
| `lib/screens/profile_screen.dart` | User profile screen. |
| `lib/screens/main_navigation_screen.dart` | Bottom nav shell (`IndexedStack` of Home/Requests/Profile). |
| `pubspec.yaml` | Dependencies — notably `lucide_icons`, added during this redesign. |
| Two original screen recordings (`.mp4`, not part of the Flutter project) | Used only for diagnosis at the start of the conversation; not project assets, just reference material Claude analyzed frame-by-frame to identify the original app's problems. |

*Note: exact `lib/` subfolder structure (e.g. whether screens live in `lib/screens/` vs directly in `lib/`) was described by Antigravity in its own plans but not independently verified — check the actual project structure before assuming paths.*

---

## 15. SOURCE OF TRUTH

- **User's explicit requirements:** deep red as primary color, softly rounded corners, fix the native calendar, muted grey map, keep the existing logo unchanged, all four platforms (iOS/Android/Web/Windows) required, one-screen-at-a-time build approach, always provide the next prompt automatically.
- **User-provided content structure:** the 9-screen list and per-screen content/copy came from the user's own ChatGPT-assisted "audit," not from Claude — Claude merged it with the visual system but did not invent the screen list or its content.
- **Claude's proposals, accepted by the user through continued use (not explicitly debated/negotiated):** the exact hex values (`#8C1F2B` etc. beyond "deep red"), the specific typography scale, the 4px spacing system, the exact component specs (button padding, card layout, badge style), the status color system, and the general "single accent color + consistent radius + one icon set" diagnosis framework. These were never contested by the user, but also were never explicitly "approved" beyond being used without objection — treat them as strong defaults that shaped everything downstream, not as separately-negotiated requirements.
- **Antigravity's own implementation choices**, confirmed via `dart analyze` and self-reported walkthroughs at each step — code exists and compiles, but has NOT been visually verified by the user (see Section 12, item 6). Treat implementation reports as "claimed complete," not "confirmed correct."
- **Claude's own suggestions that were explicitly acted upon (i.e., became requirements once approved):** `IconThemeData` default addition, `pushReplacement` for Splash, phone validation on Login, single-select confirmation on Registration's blood grid, sentence-case confirmation on Home, the `AppColors.mapBase` correction on Find Donors, and the "don't make Find Donors/Donor Details into tabs" confirmation on Bottom Navigation.

---

## 16. DECISIONS THAT MUST BE PRESERVED (do not casually reverse)

- `#8C1F2B` is the one and only saturated/primary brand color across the entire app.
- 14px corner radius everywhere (16px only for bottom-sheet top corners) — no exceptions, no per-screen deviation.
- `lucide_icons` is the only icon package; no emoji, no default Material icons anywhere in the actual UI.
- No native OS date/time pickers — always custom in-app components.
- The existing logo mark is unchanged — do not redesign or simplify it, despite Claude's own earlier (unapproved) suggestion to simplify it.
- Blood group selector grid is single-select (radio behavior), not multi-select.
- Only one primary (solid) button visible per screen; everything else is outlined or plain text.
- `AppColors` is the single source of truth for every color — no hardcoded hex values in screen files, no duplicate constants for the same value.
- `FindDonorsScreen` and `DonorDetailsScreen` are push-based screens, not bottom-nav tabs.
- The status color system (Urgent/Pending/Available/Completed) is shared and reused identically between Home and Requests screens — don't fork it per screen.
- Sentence case everywhere; never ALL CAPS.
- Distance format is always a single unit string ("2.4 km away"), never duplicated.
- Registration → Home flow uses `pushAndRemoveUntil` to `MainNavigationScreen` so the auth flow isn't reachable via back button once inside the main app; Log out does the reverse (`pushAndRemoveUntil` back to `LoginScreen`).

---

## 17. OPEN QUESTIONS (genuinely undetermined — do not invent answers)

- Should the app pursue real `google_maps_flutter` integration now, or keep the static placeholder map long-term? Never decided — explicitly deferred pending discussion.
- What backend/auth provider (if any) will be used? Never discussed at all (no Firebase, no custom API, nothing named).
- What state management approach should be used if the app outgrows simple `setState`? Never discussed.
- Does the Donor Details "Info Grid block" need to be simplified from a bordered container to a plain divider layout? Flagged as a concern, never visually confirmed either way.
- Has the client actually seen anything beyond the two mockup images Claude generated early in this conversation? Not clear — the user has been iterating with Claude and Antigravity since, but no confirmation of client re-review was mentioned.
- What is the priority/timeline for setting up the iOS build pipeline relative to finishing Android/Web/Windows first?
- Where will real donor/request/profile data ultimately come from (manual entry only, or some backend/database)? Not discussed.

---

## 18. FINAL CLAUDE CODE INSTRUCTIONS

1. **Inspect the existing code before changing anything.** All 9 screens plus the theme foundation and bottom navigation shell are reported as already implemented and compiling cleanly (`dart analyze` clean at every step). Read the actual files first — do not assume Section 7/8 above is a to-build list; it's a status report of what should already exist.
2. **The app has never been visually run or verified by a human.** Your first priority should likely be helping the user actually get `flutter run` working (resolve the OneDrive path issue if it still exists) and then doing a careful visual pass against Section 3 (exact colors/radius/typography) and Section 8 (screen-by-screen spec) — treat this as an unverified codebase, not a finished one.
3. **Preserve every approved UI decision in Section 16 without exception.** These were arrived at through multiple rounds of explicit user approval and correction — do not "improve" or substitute your own defaults (different accent color, different radius, different icon package, native pickers, etc.).
4. **Do not rebuild working features unnecessarily.** If a screen already matches spec, leave it alone — focus effort on the two specifically flagged visual-risk items (Section 12, items 3 and 4) and on getting the app actually running.
5. **Do not reintroduce any of the rejected designs/approaches in Section 11** — most importantly: no emoji icons, no native date pickers, no multiple saturated colors, no ALL CAPS text, no logo changes, no hardcoded inline colors.
6. **Clearly distinguish prototype/mock functionality from production functionality** (Section 9) when discussing next steps with the user — don't let "the OTP screen works" be confused with "OTP verification is real," for example.
7. **Use `design/v1_original/rakta-bandhan-style-guide.md` and `design/v1_original/rakta-bandhan-full-build-spec.md` (if present in the project) as ongoing design reference/context** for any future screen work or edits — they are the canonical visual and content spec.
8. **Ask before making major architectural changes** — e.g., adding a state management library, adding `google_maps_flutter` and its API key/billing requirement, choosing a backend, or restructuring navigation — none of these were decided in this conversation, and the user has shown a strong preference throughout for reviewing and approving changes before they're made, not having them made unilaterally.
9. **When in doubt about a visual detail not covered here, default to the exact values in Section 3** rather than a generic Flutter/Material default.
