import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/heart_connector.dart';
import '../widgets/ring_field.dart';
import '../widgets/step_tracker.dart';
import 'about_screen.dart';
import 'cancel_confirm_screen.dart';
import 'certificate_screen.dart';
import 'community_screen.dart';
import 'consent_screen.dart';
import 'corporate_partnerships_screen.dart';
import 'create_experience_screen.dart';
import 'create_request_screen.dart';
import 'donation_history_screen.dart';
import 'donor_details_screen.dart';
import 'emergency_contact_screen.dart';
import 'help_support_screen.dart';
import 'legal_reader_screen.dart';
import 'login_screen.dart';
import 'no_donor_found_screen.dart';
import 'notifications_screen.dart';
import 'onboarding_screen.dart';
import 'otp_screen.dart';
import 'registration_screen.dart';
import 'settings_screen.dart';
import 'testimonials_screen.dart';
import 'tic_tac_toe_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// TEMPORARY PREVIEW GALLERY — NOT PART OF THE REAL APP.
//
// Every screen opened from here is either (a) the real, unmodified
// production screen — safe because it makes no Firebase/Firestore call
// from initState/build, only from a button press the reviewer won't tap —
// (b) a small local recreation built from the same real shared widgets
// (HeartConnector, StepTracker, RingField, BloodGroupDroplet…) with
// clearly-labelled sample data, for screens whose real version reads a
// live Firestore stream/document by ID and would otherwise hang or error
// with no such document, or (c) an honest "can't be safely previewed"
// card for the couple of screens where neither of those is safe. Nothing
// in this file writes to Firestore, calls FirebaseAuth, or invents a
// screen that doesn't exist in lib/screens/. Delete this file (and its
// one entry point in login_screen.dart) once it's no longer needed.
// ═══════════════════════════════════════════════════════════════════════

class PreviewGalleryScreen extends StatelessWidget {
  const PreviewGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _banner(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text('Preview Gallery', style: AppTextStyles.display(fontSize: 24, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  const Text('Every screen below opens with sample data. Tap any row to view it.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                  const SizedBox(height: 20),

                  _category(context, 'Authentication & onboarding', [
                    _entry('Splash', () => const _UnavailablePreview(title: 'Splash', reason: "Resolves its destination using the signed-in user's Firebase Auth ID with no fallback for a signed-out preview session — opening it here would crash instead of showing anything useful. It's a 2-second brand animation with no interactive content to screenshot anyway.")),
                    _entry('Onboarding', () => const OnboardingScreen()),
                    _entry('Login', () => const LoginScreen()),
                    _entry('OTP verification', () => const OtpScreen()),
                    _entry('Consent', () => const ConsentScreen()),
                    _entry('Registration', () => const RegistrationScreen(phoneNumber: '9999999999')),
                  ]),

                  _category(context, 'Request flow', [
                    _entry('Request / Find / Community / My Page tabs', () => const _UnavailablePreview(title: 'Tab roots', reason: 'Already viewable in full via "Preview UI" from the Login screen — not duplicated here.'), subtitle: 'See "Preview UI" on the Login screen'),
                    _entry('Create request', () => const CreateRequestScreen()),
                    _entry('Matching', () => const _PreviewFrame(title: 'Matching', child: _MatchingPreview())),
                    _entry('Donor found', () => const _PreviewFrame(title: 'Donor found', child: _DonorFoundPreview())),
                    _entry('Match contact', () => const _PreviewFrame(title: 'Match contact', child: _MatchContactPreview())),
                    _entry('Tracking', () => const _PreviewFrame(title: 'Tracking', child: _TrackingPreview())),
                    _entry('Request detail', () => const _UnavailablePreview(title: 'Request detail', reason: 'Listens to a live Firestore document by ID with no offline/error fallback — a sample ID would leave it spinning forever instead of showing content.')),
                    _entry('No donor found', () => const NoDonorFoundScreen(requestId: 'preview-request')),
                    _entry('Cancel confirmation', () => const CancelConfirmScreen(requestId: 'preview-request')),
                  ]),

                  _category(context, 'Find donors', [
                    _entry('Donor details', () => const DonorDetailsScreen(donorId: 'preview-donor', name: 'Sample Donor', initials: 'SD', bloodGroup: 'O+', isVerified: true, distanceKm: 2.4, isAvailable: true)),
                  ]),

                  _category(context, 'Community', [
                    _entry('Community (Stories / What\'s New / Impact)', () => const CommunityScreen()),
                    _entry('Share an experience', () => const CreateExperienceScreen()),
                  ]),

                  _category(context, 'My Page', [
                    _entry('Personal information', () => const _PreviewFrame(title: 'Personal information', child: _PersonalInfoPreview())),
                    _entry('Donation history', () => const DonationHistoryScreen()),
                    _entry('Certificate', () => CertificateScreen(record: const DonationRecord(hospital: 'Sample Hospital', date: '20 Sep 2026', bloodGroup: 'AB+'), donationNumber: 1)),
                    _entry('Cooldown', () => const _PreviewFrame(title: 'Cooldown', child: _CooldownPreview())),
                    _entry('Emergency contact', () => const EmergencyContactScreen()),
                    _entry('Settings & privacy', () => const SettingsScreen()),
                  ]),

                  _category(context, 'While you wait — game', [
                    _entry('Play a round of XO', () => const TicTacToeScreen()),
                  ]),

                  _category(context, 'Notifications & More menu', [
                    _entry('Notifications', () => const NotificationsScreen()),
                    _entry('More menu (About / Testimonials / Help / …)', () => const SizedBox.shrink(), onTap: (ctx) => showMoreSheet(ctx), subtitle: 'Opens the real sheet — every row below is now a real screen'),
                  ]),

                  _category(context, 'Trust & brand (behind More)', [
                    _entry('About Rakta Bandhan', () => const AboutScreen()),
                    _entry('Testimonials', () => const TestimonialsScreen()),
                    _entry('Corporate partnerships', () => const CorporatePartnershipsScreen()),
                    _entry('Help & support', () => const HelpSupportScreen()),
                    _entry('Privacy policy', () => const LegalReaderScreen(title: 'Privacy policy')),
                    _entry('Terms of use', () => const LegalReaderScreen(title: 'Terms of use')),
                  ]),

                  _category(context, 'Not included', [
                    _entry('Admin console screens', () => const _UnavailablePreview(title: 'Admin', reason: 'Deliberately kept out of this consumer-app preview — Admin is a separate operator surface.')),
                    _entry('Accept result', () => const _UnavailablePreview(title: 'Accept result', reason: 'Needs an internal result-type value from a real accept action; not safely constructible from sample data.')),
                    _entry('Home (legacy)', () => const _UnavailablePreview(title: 'Home', reason: "Superseded by the Request tab in Phase 1 — left in the codebase unreferenced, not part of the app's real navigation.")),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, size: 13, color: Colors.white),
          const SizedBox(width: 7),
          const Expanded(child: Text('PREVIEW MODE — sample data only, no backend connection', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3))),
          GestureDetector(onTap: () => Navigator.pop(context), child: const Text('Exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold))),
        ],
      ),
    );
  }

  Widget _category(BuildContext context, String title, List<_GalleryEntry> entries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  InkWell(
                    onTap: () => entries[i].onTap(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(border: i < entries.length - 1 ? const Border(bottom: BorderSide(color: AppColors.warmDivider)) : null),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entries[i].label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                                if (entries[i].subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(entries[i].subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.disabledTint)),
                                ],
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _GalleryEntry _entry(String label, Widget Function() builder, {String? subtitle, void Function(BuildContext)? onTap}) {
    return _GalleryEntry(
      label: label,
      subtitle: subtitle,
      onTap: onTap ?? (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => builder())),
    );
  }
}

class _GalleryEntry {
  final String label;
  final String? subtitle;
  final void Function(BuildContext) onTap;
  const _GalleryEntry({required this.label, this.subtitle, required this.onTap});
}

/// Wraps a real screen or a local recreation with the preview banner and
/// an explicit "Back to gallery" — used for every entry that isn't the
/// unmodified real production screen.
class _PreviewFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _PreviewFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.arrowLeft, size: 14, color: Colors.white), SizedBox(width: 6), Text('Back to gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))]),
                  ),
                  const Spacer(),
                  const Text('PREVIEW · SAMPLE DATA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.gold, letterSpacing: 0.3)),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _UnavailablePreview extends StatelessWidget {
  final String title;
  final String reason;
  const _UnavailablePreview({required this.title, required this.reason});

  @override
  Widget build(BuildContext context) {
    return _PreviewFrame(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 52, height: 52, decoration: const BoxDecoration(color: AppColors.sand, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(LucideIcons.info, size: 22, color: AppColors.ink2)),
              const SizedBox(height: 16),
              Text('$title can\'t be safely previewed here', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(reason, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Local previews

class _MatchingPreview extends StatelessWidget {
  const _MatchingPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.emberFieldStart,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment(-0.3, -1), end: Alignment(0.3, 1), colors: [AppColors.emberFieldStart, AppColors.emberFieldMid, AppColors.emberFieldEnd])),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(child: RingField(color: Color(0xFFFBE6E8), outerOpacity: 0.16, middleOpacity: 0.26)),
                    const BloodGroupDroplet(label: 'O+', size: 60, filled: true, color: AppColors.primary, textColor: Color(0xFFFBE6E8), fontSize: 20, serif: true),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('SEARCHING (sample)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: Color(0xFFE0A8AF))),
              const SizedBox(height: 10),
              const Text('Notifying compatible donors near you', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFFF9F5))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonorFoundPreview extends StatelessWidget {
  const _DonorFoundPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3A050B),
      child: const DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-0.4, -0.9), radius: 1.5, colors: [Color(0xFF8C1420), Color(0xFF5C0C14), Color(0xFF3A050B)], stops: [0, 0.55, 1])),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeartConnector(leftInitials: 'You', rightInitials: 'RD', leftIsPublic: false, rightIsPublic: true, rightBloodGroup: 'O+', discSize: 68),
                SizedBox(height: 26),
                Text('RedDrop is on the way', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, color: Color(0xFFFDF6F0), fontWeight: FontWeight.w600)),
                SizedBox(height: 10),
                Text('(sample donor identity)', style: TextStyle(fontSize: 12, color: Color(0x99FDF6F0))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchContactPreview extends StatelessWidget {
  const _MatchContactPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3A050B),
      child: const DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-0.4, -0.9), radius: 1.5, colors: [Color(0xFF8C1420), Color(0xFF5C0C14), Color(0xFF3A050B)], stops: [0, 0.55, 1])),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeartConnector(leftInitials: 'You', rightInitials: 'SP', leftIsPublic: true, rightIsPublic: false, discSize: 68),
                SizedBox(height: 26),
                Text("YOU'RE CONNECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFFE0A8AF))),
                SizedBox(height: 12),
                Text('Sample Patient needs your help', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Color(0xFFFFF9F5), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingPreview extends StatelessWidget {
  const _TrackingPreview();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BloodGroupDroplet(label: 'O+', size: 48, filled: true, color: AppColors.brandRed, textColor: AppColors.whiteTextOnPrimary, fontSize: 16, serif: true),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sample Hospital', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                    const Text('2 unit(s) · critical · sample data', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))]),
            child: const StepTracker(steps: [
              TrackerStep(label: 'Submitted', sub: 'Request created (sample)', status: StepStatus.done, icon: LucideIcons.send),
              TrackerStep(label: 'Donor found', sub: '1 donor accepted (sample)', status: StepStatus.done, icon: LucideIcons.search),
              TrackerStep(label: 'Matched', sub: 'Sample Donor accepted your request', status: StepStatus.current, icon: LucideIcons.handshake),
              TrackerStep(label: 'Completed', sub: 'Marked once the donation is confirmed', status: StepStatus.pending, icon: LucideIcons.checkCircle),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PersonalInfoPreview extends StatelessWidget {
  const _PersonalInfoPreview();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BloodGroupDroplet(label: 'AB+', size: 60, filled: true, color: AppColors.primary, textColor: Color(0xFFFBE6E8), fontSize: 19, serif: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preview Donor', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
                    const Text('+91 9•••••••40 (sample)', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _row('Blood group', 'AB+'),
                _row('Phone number', '+91 9••• •••40'),
                _row('Member since', '1 Jan 2026 (sample)', isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.dividerWarm))),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))), Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))]),
    );
  }
}

class _CooldownPreview extends StatelessWidget {
  const _CooldownPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))]),
        child: Column(
          children: [
            Container(
              width: 176,
              height: 176,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [AppColors.vermilion, AppColors.dividerWarm, AppColors.dividerWarm], stops: [0, 0.24, 1])),
              child: Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('68', style: AppTextStyles.display(fontSize: 44, color: AppColors.ink)),
                      const Text('days to go (sample)', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text("You've already helped.\nNow let your body recover.", textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 21, color: AppColors.ink, height: 1.25)),
          ],
        ),
      ),
    );
  }
}
