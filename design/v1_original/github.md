repo: ashigupta1103/rakta-bandhan
branch: master

## Last sync
date: 2026-08-20T20:21:34Z

### Updated in this project
- Built "Rakta Bandhan Mobile.dc.html" — mobile-first reinterpretation of the Flutter app, using the repo's own style guide (design/rakta-bandhan-style-guide.md, design/rakta-bandhan-full-build-spec.md) and screen source (lib/screens/*, lib/theme/*).
- Expanded from the app's 9 screens to ~30, adding auth states (consent, verification-pending, OTP error states), requester create/matching flow, map states, a notification center, and a mobile companion admin console addressing gaps flagged in the architecture doc (real admin login vs. backdoor, accept-time exclusivity guard).
- Admin console is a lighter, card-based companion view (per product decision: back-office staff mainly use desktop).

## Screen map
| Project screen(s) | Repo source |
|---|---|
| Splash, Welcome, OTP, Registration | lib/screens/splash_screen.dart, login_screen.dart, otp_screen.dart, registration_screen.dart |
| Home / Requests / Profile tabs | lib/screens/home_screen.dart, requests_screen.dart, profile_screen.dart, main_navigation_screen.dart |
| Map / find donors, Donor profile | lib/screens/find_donors_screen.dart, donor_details_screen.dart |
| Visual system (colors, radius, type) | lib/theme/app_colors.dart, lib/theme/app_theme.dart, design/rakta-bandhan-style-guide.md |
| Consent, Verification pending, Create request, Matching, Admin console | new — not in repo, added per brief (architecture doc gaps + full product scope) |
