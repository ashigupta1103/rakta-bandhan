import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/gradient_hero_card.dart';
import 'donation_history_screen.dart';
import 'emergency_contact_screen.dart';
import 'legal/about_screen.dart';
import 'legal/consent_preferences_screen.dart';
import 'legal/data_usage_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_screen.dart';
import 'login_screen.dart';
import 'personal_information_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Held as a field rather than created in build() so the count is not
  /// re-queried on every rebuild of the donor-doc StreamBuilder.
  late Future<int> _donationCount;

  @override
  void initState() {
    super.initState();
    // Client-side stand-in for scheduledReactivation.js — flips
    // is_available back on if the 90-day cooldown has already elapsed.
    Backend.instance.maybeReactivate();
    _donationCount = Backend.instance.myDonationCount();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _logOut() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Log out?',
      message: 'You will need your phone number and an OTP to sign back in.',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;

    await Backend.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: Backend.instance.myDonorDocStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final data = snapshot.data!.data() ?? {};
            final name = data['name'] as String? ?? '';
            final bloodGroup = data['blood_group'] as String? ?? '—';
            final isVerified = data['is_verified'] as bool? ?? false;
            final isAvailable = data['is_available'] as bool? ?? false;
            final reactivateAt = data['reactivation_scheduled_at'] as Timestamp?;
            final onCooldown = !isAvailable &&
                reactivateAt != null &&
                reactivateAt.toDate().isAfter(DateTime.now());

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradientHeroCard(
                    startColor: AppColors.gradientHeaderStart,
                    endColor: AppColors.gradientHeaderEnd,
                    gradientBegin: Alignment.topRight,
                    gradientEnd: Alignment.bottomLeft,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 46),
                    ringLeft: -40,
                    ringTop: -50,
                    ringRight: null,
                    ringBottom: null,
                    ringSize: 160,
                    child: Column(
                      children: [
                        AvatarBadge(initials: _initials(name), size: 76, fontSize: 24, translucent: true),
                        const SizedBox(height: 14),
                        Text(
                          name.isEmpty ? 'Your profile' : name,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 22, color: const Color(0xFFFFF9F5)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _translucentPill(bloodGroup, bold: true),
                            const SizedBox(width: 6),
                            _translucentPill(
                              isVerified ? 'Verified' : 'Pending verification',
                              icon: isVerified ? LucideIcons.check : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Availability control — overlaps the hero.
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(43, 20, 20, 0.1), blurRadius: 24, offset: Offset(0, 10))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: isAvailable ? AppColors.warmGreenText : AppColors.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isAvailable
                                              ? 'Available to donate'
                                              : (onCooldown ? 'Recovering' : 'Not available'),
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                                        ),
                                        Text(
                                          onCooldown
                                              ? 'On the 90-day cooldown after your last donation'
                                              : "Toggle off if you can't donate right now",
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isAvailable,
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primaryLightTint,
                              inactiveThumbColor: AppColors.textMuted,
                              inactiveTrackColor: AppColors.border,
                              onChanged: (val) async {
                                await Backend.instance.setAvailability(val);
                                _showSnackBar(val ? 'You are now available for donation' : 'You are now offline');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Donation statistics
                        FutureBuilder<int>(
                          future: _donationCount,
                          builder: (context, countSnapshot) {
                            final count = countSnapshot.data;
                            return Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    icon: LucideIcons.droplet,
                                    iconBg: AppColors.primaryLightTint,
                                    iconColor: AppColors.primary,
                                    value: count?.toString(),
                                    label: 'Donations made',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _statCard(
                                    icon: LucideIcons.sparkle,
                                    iconBg: AppColors.warmAmberIconTint,
                                    iconColor: AppColors.warmAmberText,
                                    value: count?.toString(),
                                    label: 'Lives helped',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('Account'),
                        _menuCard([
                          _menuRow(
                            icon: LucideIcons.user,
                            label: 'Personal information',
                            onTap: () => _push(const PersonalInformationScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.history,
                            label: 'Donation history',
                            iconBg: AppColors.primaryLightTint,
                            iconColor: AppColors.primary,
                            onTap: () => _push(const DonationHistoryScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.phone,
                            label: 'Emergency contact',
                            onTap: () => _push(const EmergencyContactScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.sliders,
                            label: 'Settings',
                            onTap: () => _push(const SettingsScreen()),
                            showDivider: false,
                          ),
                        ]),
                        const SizedBox(height: 20),

                        _sectionLabel('Privacy & legal'),
                        _menuCard([
                          _menuRow(
                            icon: LucideIcons.sliders,
                            label: 'Consent preferences',
                            onTap: () => _push(const ConsentPreferencesScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.lock,
                            label: 'Privacy Policy',
                            onTap: () => _push(const PrivacyPolicyScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.clipboardList,
                            label: 'Terms & Conditions',
                            onTap: () => _push(const TermsScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.shieldCheck,
                            label: 'Data Usage',
                            onTap: () => _push(const DataUsageScreen()),
                            showDivider: true,
                          ),
                          _menuRow(
                            icon: LucideIcons.droplet,
                            label: 'About Rakta Bandhan',
                            onTap: () => _push(const AboutScreen()),
                            showDivider: false,
                          ),
                        ]),

                        GestureDetector(
                          onTap: _logOut,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(LucideIcons.logOut, color: AppColors.textMuted, size: 17),
                                SizedBox(width: 10),
                                Text('Log out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
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
          },
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String? value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorderWarm),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 10),
          value == null
              ? Container(
                  width: 28,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.dividerWarm,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  value,
                  style: AppTextStyles.display(fontSize: 30, color: AppColors.textPrimaryWarm, height: 1),
                ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMutedWarm,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _menuCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorderWarm),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _translucentPill(String label, {bool bold = false, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: bold ? 11 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.whiteTextOnPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.whiteTextOnPrimary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: bold ? 12.5 : 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: AppColors.whiteTextOnPrimary),
          ),
        ],
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool showDivider,
    Color iconBg = AppColors.dividerWarm,
    Color iconColor = AppColors.textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.dividerWarm)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
          ],
        ),
      ),
    );
  }
}
