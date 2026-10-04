# Rakta Bandhan — full build spec for wireframes
9 screens, clickable navigation. Visual system + screen content combined so nothing gets lost in translation.

---

## PART A — Visual system (applies to every screen below)

**Color**
| Token | Hex | Use |
|---|---|---|
| Primary (deep red) | `#8C1F2B` | Headers, primary buttons, selected states, map pins, urgent badges |
| Primary light tint | `#F6DCDE` | Badge backgrounds, avatar backgrounds |
| Text on primary | `#FBE6E8` | Text/icons on solid red |
| Text primary | `#1A1A1A` | Names, body |
| Text secondary | `#6B6B68` | Labels, distances |
| Text muted | `#9C9C98` | Placeholders |
| Border | `#E5E3DD` | Inputs, card borders |
| Page background | `#F7F6F2` | Screen background |
| Map base | `#E8E6E1` | Muted map |

Rule: red is the only saturated color anywhere. Status colors are the one exception — see Status colors below.

**Status colors (for Requests/Availability only)**
| Status | Background | Text |
|---|---|---|
| Urgent | `#F6DCDE` | `#8C1F2B` |
| Pending / awaiting | `#FAEEDA` | `#854F0B` |
| Available / verified | `#EAF3DE` | `#3B6D11` |
| Completed | `#EAF3DE` | `#3B6D11` |

**Typography:** one system font, weights 400/500 only, sentence case everywhere (never ALL CAPS — this replaces "RAKTA BANDHAN" / "NEED BLOOD?" caps shown in the draft below with normal case).

**Radius:** 14px on all buttons, inputs, cards, badges. 16px top corners on bottom sheets. Circular for avatars/pins only.

**Icons:** one outline icon set (Tabler or Feather) — no emoji anywhere in the actual build. Every 👤 📍 🔍 🩸 ✓ ● placeholder below maps to an outline icon:
- 👤 → user/person outline icon
- 📍 → map-pin outline icon
- 🔍 → search outline icon
- 🩸 → droplet outline icon
- ✓ → check-circle icon, filled green tint background per Status colors
- ● (availability dot) → small filled circle, green `#3B6D11` when available, grey `#9C9C98` when not
- ♥ (splash) → droplet or heart outline icon, matching the existing logo mark — do not introduce a new symbol

**Buttons:** one primary (solid `#8C1F2B`) button per screen max. Secondary actions (Call, WhatsApp, View) are outlined, not filled.

---

## PART B — Screens

### 1. Splash
Icon (droplet/heart, matches existing logo) → "Rakta Bandhan" (20px/500, sentence case) → "Every drop counts. Together, we save lives." (13px, secondary grey) → auto-advance after ~2s.

### 2. Login
"Welcome to Rakta Bandhan" (title) + "Your help can save a life." (subtitle). Country code `+91` + phone input (14px radius, bordered). Primary button "Continue". Fine-print consent text below in muted grey, 12px.

### 3. OTP
"Verify your number" title. Subtext with masked number. 6 individual OTP boxes (14px radius each, bordered, center-aligned digits). "Didn't receive it? Resend OTP" as a text link in primary red. Primary button "Verify".

### 4. Registration
Fields in order: Name, WhatsApp number, Location (text input + map-pin icon, supports free-text search), Blood group (4×2 selector grid per style system — unselected white/bordered, selected solid red). Primary button "Complete registration".

### 5. Home (hero screen — most important)
- Greeting: "Good morning, [Name]" (20px/500) + "Ready to make a difference?" (secondary grey, 14px).
- Emergency card: white card, 16px radius, border. Droplet icon + "Need blood?" (sentence case, not caps) + "Find compatible donors near you." Primary button inside card: "Find blood donors".
- "Nearby requests" section label, then a request card: blood type badge (red tint) + "Urgent" status badge (Status colors table) + location + distance, outlined "View request" button.
- "Your impact" section: two stat blocks side by side — number (24px/500) + label below (13px, secondary grey) — "Donations" and "Lives helped". Use `--surface-1` muted background block, not bordered card, to visually distinguish stats from actionable cards.

### 6. Map / Find donors
- Search bar at top: bordered input, 14px radius, search icon leading.
- Map: muted grey base (`#E8E6E1`), solid red filled pin icons (no default map-pin red), user location as a soft red circle with radius ring if a distance filter is active.
- Bottom sheet (16px top radius, drag handle bar centered): "Nearby donors" label, then donor cards — avatar circle (red tint bg), name + blood type badge, verified check-icon badge (green tint), distance + availability status dot, two outlined buttons side by side ("View", "Request").

### 7. Donor details (bottom sheet from map, or full screen)
Avatar (large, circular, red tint bg) centered, name (20px/500), blood type as a badge below name, verified badge + availability status dot with label, distance + city with map-pin icons. Divider line. Two-row info block: "Blood group" / "O positive", "Availability" / "Available now" — label left (secondary grey) value right (primary text). Primary button "Request donor" full width. Two secondary outlined buttons below, side by side: "Call", "WhatsApp".

### 8. Requests
Title "Blood requests" (not "Inbox/Outbox"). Two-tab toggle: "Received" / "My requests" — active tab solid red pill, inactive plain text. Cards: blood type badge, location + distance, status badge (Pending/Accepted/Completed per Status colors table), outlined "View" button. No duplicated unit strings — distance format is always `"{n} km away"`, single unit only.

### 9. Profile
Avatar circle centered, name (20px/500), blood type badge, verified badge, availability status dot + label. Divider. List rows (each a tappable row, chevron-right trailing): Personal information, Donation history, Emergency contact, Settings. Divider. "Availability" row with a toggle switch (on = red fill, off = grey/border only — reuse primary color for the "on" state, not a separate green/blue toggle color). Divider. "Log out" as a plain text row in secondary grey (not a button — de-emphasized since it's a rare action).

---

## Notes for whoever builds this
- Every emoji/symbol placeholder in this doc is a content marker only — the actual build uses the icon system in Part A, never literal emoji glyphs.
- Keep header/title text in sentence case even where the content draft shows caps ("RAKTA BANDHAN", "NEED BLOOD?") — this was one of the original app's "looks AI-made" issues and should not carry over.
- Reuse the same 14px radius, same red, same card border style across all 9 screens without exception — consistency across the full flow is the main goal of this redesign.
