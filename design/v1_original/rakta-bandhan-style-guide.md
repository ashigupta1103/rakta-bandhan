# Rakta Bandhan — visual design spec

A blood donation app redesign. This document is a build spec, not a mood board — every value is exact so it survives being passed between tools.

## 1. Brand color

One primary color does all the work. No secondary reds, pinks, or greens anywhere in the UI.

| Token | Hex | Use |
|---|---|---|
| Primary (deep red) | `#8C1F2B` | Headers, primary buttons, selected states, map pins, icons that need emphasis |
| Primary text on white | `#8C1F2B` | Links, active tab text |
| Primary light tint | `#F6DCDE` | Badge backgrounds, avatar backgrounds, selected-but-quiet states |
| Primary on-tint text | `#8C1F2B` | Text sitting on the light tint above |
| White text on primary | `#FBE6E8` | Text/icons on solid red backgrounds (not pure white — softer, avoids harsh contrast) |

**Neutrals (everything else):**

| Token | Hex | Use |
|---|---|---|
| Text primary | `#1A1A1A` | Body text, names |
| Text secondary | `#6B6B68` | Supporting text, labels, distances |
| Text muted | `#9C9C98` | Placeholders |
| Border | `#E5E3DD` | Input borders, card borders, dividers |
| Border strong | `#D3D1C7` | Selected/hover input borders |
| Surface / card background | `#FFFFFF` | Cards, sheets |
| Page background | `#F7F6F2` | Screen background behind cards |
| Map base | `#E8E6E1` | Muted map background |
| Map grid/roads | `#DEDCD6` | Road lines on map |

**Rule:** if you're about to add a new color anywhere (a second red, a blue, a green success state, etc.) — stop and check if a neutral or the existing red already does the job. It almost always does.

## 2. Typography

- One font family throughout (system default is fine — San Francisco / Roboto). Do not mix fonts.
- Two weights only: Regular (400) and Medium (500). No bold (700), no light (300).
- Sentence case everywhere. Never ALL CAPS, never Title Case (this fixes the "REGISTER" header problem in the current app).

| Style | Size | Weight | Use |
|---|---|---|---|
| Screen title | 20px | 500 | "Rakta Bandhan", top-of-screen labels |
| Section label | 13px | 500 | "Blood group needed", field labels |
| Body / input text | 14px | 400–500 | Form values, card text |
| Name (card) | 14px | 500 | Donor name |
| Supporting text | 12–13px | 400 | Distance, location, timestamps |

## 3. Spacing and radius

- Base spacing unit: **4px**. All padding/margins are multiples of 4 (8, 12, 16, 20, 24).
- Screen padding: 20px left/right.
- Corner radius: **14px** for buttons, inputs, cards, map corners, badges. This one number should appear everywhere — nothing sharp, nothing pill-shaped, nothing at a different radius.
- Circular only for: avatars, map pin dots, calendar date-selected indicator.

## 4. Icons

- **One icon set only: outline/line style** (Tabler Icons or Feather Icons — pick one, do not mix).
- **No emoji anywhere in the UI.** Replace 📅 with a calendar-outline icon, 📞 with a phone-outline icon.
- Icon size: 16px inline next to labels, 18–20px for standalone actions (back arrow, filter).
- Icons take the same color as the text/element they're attached to — muted grey for passive labels, primary red only when the icon itself needs emphasis (selected state, CTA).

## 5. Components

**Buttons (primary)**
- Background `#8C1F2B`, text `#FBE6E8`, radius 14px, padding 13px vertical.
- Only one primary button visible per screen. Everything else is a plain outlined or text button.

**Inputs**
- Border `#E5E3DD` (1px), radius 14px, padding 12px 14px, background white.
- On focus: border becomes `#8C1F2B`.
- Placeholder text uses Text muted (`#9C9C98`).

**Date/time picker**
- Never trigger the OS native picker. Build a custom in-app calendar component (inline or bottom sheet) styled with the same radius, primary color for the selected date, neutral grey for the grid.

**Blood type selector grid**
- 4 columns, 8px gap, each cell 14px radius.
- Unselected: white background, `#E5E3DD` border, `#1A1A1A` text.
- Selected: `#8C1F2B` background and border, `#FBE6E8` text.

**Donor cards**
- White background, `#E5E3DD` border, 16px radius, 12px padding.
- Left: 40px circular avatar, tint background `#F6DCDE`, initials in `#8C1F2B`.
- Middle: name (14px/500) + location/distance (12px, secondary grey) stacked.
- Right: blood type badge — tint background `#F6DCDE`, text `#8C1F2B`, 8px radius, small pill.
- One action per screen (e.g. one "Send request" button below the list), not a button crammed into every card.

**Map**
- Apply a custom muted/greyscale Google Maps style (roads and labels toned down to greys, no default blue/green Google palette).
- Pins: solid `#8C1F2B` filled pin icon, no default red Google marker.
- Bottom sheet: white surface, 20px top radius, drag handle (36×4px grey bar) centered at top.

## 6. What NOT to do (fixes for the current build)

- No emoji as icons — replace every one with an outline icon.
- No native OS date/time picker breaking into the flow — build a custom component.
- No more than one saturated color (red) — remove pink, green (WhatsApp icon), and any other stray brand colors.
- No inconsistent radius — audit every button/input/card and set them all to 14px.
- No default grey Google Maps styling — apply a custom map style.
- Fix the donor card unit-duplication bug ("12 Km Km away" → "12 km away").
- Keep the existing logo mark as-is — no change needed there.

## 7. Screens covered by this spec

1. Home / Find donors (blood type grid + date + contact + place form)
2. Map + donor list (bottom sheet with donor cards)

Apply the same color, radius, icon, and spacing rules to the remaining screens (register/OTP, profile, request inbox/outbox) even though they aren't mocked up here — the system above is enough to infer them consistently.
