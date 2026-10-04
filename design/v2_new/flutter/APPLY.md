# Phase 1 — how to apply

This folder mirrors the repo layout exactly. Copy its contents over the root
of `ashigupta1103/rakta-bandhan` (branch `master`, based on `39b6be4`), then:

```
flutter pub get
flutter analyze
flutter run -d chrome        # or your device
flutter build web --release
```

## Created (15)

```
lib/screens/onboarding_screen.dart
lib/screens/personal_information_screen.dart
lib/screens/emergency_contact_screen.dart
lib/screens/legal/terms_screen.dart
lib/screens/legal/privacy_policy_screen.dart
lib/screens/legal/data_usage_screen.dart
lib/screens/legal/consent_preferences_screen.dart
lib/screens/legal/about_screen.dart
lib/services/onboarding_service.dart
lib/services/consent_preferences_service.dart
lib/services/emergency_contact_service.dart
lib/widgets/brand_mark.dart
lib/widgets/confirm_sheet.dart
lib/widgets/legal_document_page.dart
lib/widgets/mobile_shell.dart
```

## Modified (7)

```
lib/main.dart
lib/screens/splash_screen.dart
lib/screens/profile_screen.dart
lib/screens/settings_screen.dart
lib/screens/consent_screen.dart
web/index.html
pubspec.yaml
```

## Not touched

`lib/services/backend.dart` and every other service, `lib/theme/*`, the 8
existing widgets, and 27 of 31 screens — including all admin screens,
matching, tracking, cooldown, requests, home, map, notifications, OTP,
registration and login. No Firebase config, rules or schema changes.

## Legal copy

All three policy documents render a visible amber banner marking them as
unreviewed placeholder text. Replace the `LegalSection` lists in
`lib/screens/legal/*_screen.dart` with approved copy and set
`isPlaceholder: false` on the `LegalDocumentPage` to remove the banner.

## Resetting onboarding while demoing

```dart
await OnboardingService.instance.reset();
```
