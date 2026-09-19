repo: ashigupta1103/rakta-bandhan
branch: master

## Last sync
date: 2026-09-09T16:20:00Z

### Updated in this project
- Read-only throughout. No repository files modified, no Flutter written, no commits.
- "Rakta Bandhan Redesign.dc.html" is now the FINAL DESIGN SOURCE OF TRUTH: design system, four-tab shell, 30 screens, all states, and a handoff section (files, screen list, component list, colour tokens, type tokens, assets still needed, must-not-reinterpret list).
- Direction approved by the user. Find locked to Option A (real map, markers projected from real lat/lng — needs a map dependency + warm-styled tile source; the only new dependency).
- Added the four previously-missing destinations: Personal information, Emergency contact, Settings & privacy, Help & support / Privacy / Terms reader.
- Product palette sampled from the supplied logo (assets/branding/logo-full.jpeg): red #B81E14, vermilion #C9481E, orange #D9631F, gold #E0A030, ember #6E1109, ground #FCF8F2, ink #241413.

## Screen map
| Design section | Repo files read |
|---|---|
| Design system, two-palette finding | lib/theme/app_colors.dart, app_theme.dart, app_text_styles.dart |
| Four-tab shell | lib/main.dart, screens/main_navigation_screen.dart |
| Request, create, matching, tracking | screens/requests_screen.dart, create_request_screen.dart, matching_screen.dart, tracking_screen.dart, request_detail_screen.dart |
| Find (map), donor details | screens/find_donors_screen.dart, donor_details_screen.dart |
| My Page, history, cooldown, settings | screens/profile_screen.dart, donation_history_screen.dart, cooldown_screen.dart, settings_screen.dart |
| Entry sequence | screens/splash_screen.dart, login_screen.dart, onboarding/otp/registration/consent/verifying |
| Notifications & states | screens/notifications_screen.dart |
| Personal info, emergency contact, legal | design_new/flutter/APPLY.md (unapplied designs), design/rakta-bandhan-style-guide.md |
| Product context | Rakta_Bandhan_Technical_HLD.md |

## Implementation constraints (binding)
- backend.dart, Firebase, Firestore, auth, schemas, rules: unchanged, out of scope.
- Flat palette retired; one warm logo-derived system.
- One filled crimson primary per screen; destructive = outlined red + confirm.
- Ember field for four moments only: consent, search, match, certificate.
- No hard-coded map marker positions.
- No private name/number/address in Community; blood group opt-in.
- Direct call only on explicit requester consent for critical requests.
- No SnackBar as a destination. No invented copy, imagery, medical, legal or commercial claims.
- Sponsor slots disabled at launch; never above a request or in an emergency flow.
- Four tabs; no admin entry in the consumer app.

## Still needed from the user
Portrait and campaign photography · transparent/vector logo · hands-and-heart asset (must not be recreated) · mission, testimonials, initiative and team copy · certificate wording · medically approved recovery guidance · help answers, Privacy, Terms · leaderboard scoring and funding mechanics.

## Sync history
- 2026-09-09T14:05:00Z — design phase: system + 26 screens.
- 2026-09-09T12:35:13Z — initial read-only audit pass.
