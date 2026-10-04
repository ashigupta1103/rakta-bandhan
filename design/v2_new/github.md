repo: ashigupta1103/rakta-bandhan
branch: master

## Last sync
date: 2026-08-26T11:16:14Z
commit: 39b6be408687

### Updated in this project
- Authored Phase 1 Flutter implementation under `flutter/` (mirrors repo layout; copy over repo root — see `flutter/APPLY.md`): branded 1s launch, 4-page onboarding, Profile restructure, personal information, emergency contact, and five legal/consent screens.
- Added the onboarding + launch experience to the HTML design prototype so design and Flutter agree on composition, copy and motion.
- One new dependency: `shared_preferences` (first-run flag, consent preferences, emergency contact). `google_fonts`/Newsreader and `lucide_icons_flutter` were already present.
- `lib/services/backend.dart` deliberately untouched, as were all other services, the theme, the 8 existing widgets and 27 of 31 screens.

## Screen map
| Project screen(s) | Repo files |
|---|---|
| Launch, Onboarding 1–4 (prototype + `flutter/lib/screens/onboarding_screen.dart`) | lib/screens/splash_screen.dart (rewritten), new onboarding_screen.dart |
| Profile (restructured) | lib/screens/profile_screen.dart, services/backend.dart (read-only seam) |
| Personal information, Emergency contact | new screens; services/emergency_contact_service.dart (mock boundary) |
| Terms, Privacy Policy, Data Usage, Consent Preferences, About | new lib/screens/legal/*; widgets/legal_document_page.dart |
| Settings (legal entries, persisted privacy toggle) | lib/screens/settings_screen.dart |
| Flutter Web phone shell | lib/main.dart, lib/widgets/mobile_shell.dart, web/index.html |
| Visual system (colors, type, gradients, ring motif) | lib/theme/app_colors.dart, app_text_styles.dart, widgets/gradient_hero_card.dart |
| Home / Requests / Map / Matching / Tracking / Admin (unchanged this pass) | lib/screens/home_screen.dart, requests_screen.dart, find_donors_screen.dart, matching_screen.dart, tracking_screen.dart, admin_*.dart |

## Sync history
- 2026-08-20T20:21:34Z — initial association; built the mobile-first HTML prototype from the repo's style guide and Flutter screens.
