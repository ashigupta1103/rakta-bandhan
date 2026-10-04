import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One revocable consent the user can grant or withdraw.
@immutable
class ConsentOption {
  final String id;
  final String title;
  final String description;

  /// Essential consents cannot be switched off while the account exists —
  /// the app cannot function without them. Shown locked, not hidden.
  final bool essential;

  /// True where the underlying capability is not wired up yet. Rendered
  /// with a "Not active yet" note so the toggle never implies a behaviour
  /// the app does not actually have.
  final bool notYetActive;

  final bool defaultValue;

  const ConsentOption({
    required this.id,
    required this.title,
    required this.description,
    this.essential = false,
    this.notYetActive = false,
    this.defaultValue = false,
  });
}

/// The consent catalogue. Each entry describes something the app genuinely
/// does today (or, where flagged, does not do yet).
const kConsentOptions = <ConsentOption>[
  ConsentOption(
    id: 'account',
    title: 'Account & matching',
    description:
        'Store your name, phone number and blood group so you can be matched with people who need blood.',
    essential: true,
    defaultValue: true,
  ),
  ConsentOption(
    id: 'contact_reveal',
    title: 'Share my number after a match',
    description:
        'Reveal your phone number to the other party once a request is accepted, so you can arrange the donation.',
    defaultValue: true,
  ),
  ConsentOption(
    id: 'approx_location',
    title: 'Approximate location',
    description:
        'Use your location to find nearby requests and donors. Others only ever see a distance, never your address.',
    defaultValue: true,
  ),
  ConsentOption(
    id: 'push',
    title: 'Request notifications',
    description:
        'Send you an alert when a compatible request is raised near you.',
    defaultValue: true,
  ),
  ConsentOption(
    id: 'analytics',
    title: 'Analytics & diagnostics',
    description:
        'Share anonymous usage and crash information to help improve the app.',
    notYetActive: true,
    defaultValue: false,
  ),
];

/// Consent preference storage.
///
/// MISSING BACKEND BOUNDARY — `Backend` has no consent read/write today and
/// there is no `consents` field on `donors/{uid}`. The backend developer
/// should add something like:
///
///   Future<Map<String, bool>> getConsents();
///   Future<void> setConsent(String id, bool value);
///
/// writing to `donors/{uid}.consents`, then swap the implementation below
/// for one that calls it. The screen talks only to this interface, so no UI
/// change will be required.
abstract class ConsentPreferencesService {
  Future<Map<String, bool>> load();
  Future<void> setConsent(String id, bool value);
}

class MockConsentPreferencesService implements ConsentPreferencesService {
  static const _prefix = 'rb_consent_';

  @override
  Future<Map<String, bool>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final option in kConsentOptions)
        option.id: option.essential
            ? true
            : prefs.getBool('$_prefix${option.id}') ?? option.defaultValue,
    };
  }

  @override
  Future<void> setConsent(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', value);
  }
}
