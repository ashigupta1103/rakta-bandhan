import 'package:shared_preferences/shared_preferences.dart';

/// First-run flag for the onboarding carousel.
///
/// Deliberately device-local (SharedPreferences → localStorage on web) and
/// NOT server state: a returning user on a new device should still see the
/// value proposition. No `Backend` method is needed or expected for this,
/// so unlike the other services in this folder there is no abstract
/// interface / mock split — there is nothing here for the backend
/// developer to take over.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const _key = 'rb_has_seen_onboarding';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Exposed for QA / demo resets only — nothing in the app calls this.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
