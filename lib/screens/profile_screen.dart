import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/impact_trail.dart';
import '../widgets/pulsing_dot.dart';
import 'cooldown_screen.dart';
import 'donation_history_screen.dart';
import 'emergency_contact_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'personal_information_screen.dart';
import 'settings_screen.dart';

/// Profile — rebuilt per Visual Richness Proposal #08: "the red hero band
/// is gone... identity now comes from the avatar with its group droplet
/// attached, the live availability pulse, and the impact trail." Donor
/// identity, not account settings — legal/account rows stay in Settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Client-side stand-in for scheduledReactivation.js — flips
    // is_available back on if the 90-day cooldown has already elapsed.
    Backend.instance.maybeReactivate();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logOut() async {
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
      appBar: AppHeader(
        title: 'My page',
        onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
      ),
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
            final reactivateAt = (data['reactivation_scheduled_at'] as Timestamp?)?.toDate();

            return FutureBuilder<int>(
              future: Backend.instance.myDonationCount(),
              builder: (context, donationSnap) {
                final donationCount = donationSnap.data ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(_initials(name), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ),
                              if (bloodGroup != '—')
                                Positioned(
                                  right: -8,
                                  bottom: -6,
                                  child: BloodGroupDroplet(label: bloodGroup, size: 34, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 11),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'Your profile' : name,
                                    style: AppTextStyles.display(fontSize: 26, color: AppColors.textPrimaryWarm, height: 1.1),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(color: isVerified ? AppColors.warmGreenBg : AppColors.warmAmberBg, shape: BoxShape.circle),
                                        alignment: Alignment.center,
                                        child: isVerified
                                            ? const Icon(LucideIcons.check, size: 9, color: AppColors.warmGreenText)
                                            : const Icon(LucideIcons.clock, size: 9, color: AppColors.warmAmberText),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isVerified ? 'Verified donor' : 'Verification pending',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isVerified ? AppColors.warmGreenText : AppColors.warmAmberText),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Row(
                          children: [
                            PulsingDot(color: isAvailable ? AppColors.warmGreenText : AppColors.textMutedWarm, size: 9),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAvailable ? 'Available to donate' : 'Not available',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                                  ),
                                  const Text('Toggle off if you can\'t donate right now', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: isAvailable,
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primaryLightTint,
                              inactiveThumbColor: AppColors.textMuted,
                              inactiveTrackColor: AppColors.dividerWarm,
                              onChanged: (val) async {
                                await Backend.instance.setAvailability(val);
                                _showSnackBar(val ? 'You are now available for donation' : 'You are now offline');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text('YOUR IMPACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
                      const SizedBox(height: 14),
                      ImpactTrail(
                        count: donationCount,
                        caption: '${donationCount == 1 ? '1 donation' : '$donationCount donations'} · $donationCount ${donationCount == 1 ? 'life' : 'lives'} helped',
                      ),
                      if (donationCount > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(999)),
                          child: const Text('Lifesaver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
                        ),
                      ],
                      if (reactivateAt != null && !isAvailable) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CooldownScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 15, color: AppColors.goldDeep),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('On cooldown · eligible again in ${_eligibleInDays(reactivateAt)} days', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                                ),
                                const Icon(LucideIcons.chevronRight, size: 15, color: AppColors.chevronMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(height: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.symmetric(vertical: 18)),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.cardBorderWarm),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _menuRow(
                              icon: LucideIcons.user,
                              label: 'Personal information',
                              iconBg: AppColors.primaryLightTint,
                              iconColor: AppColors.primary,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInformationScreen())),
                              showDivider: true,
                            ),
                            _menuRow(
                              icon: LucideIcons.history,
                              label: 'Donation history',
                              iconBg: AppColors.primaryLightTint,
                              iconColor: AppColors.primary,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DonationHistoryScreen())),
                              showDivider: true,
                            ),
                            _menuRow(
                              icon: LucideIcons.phone,
                              label: 'Emergency contact',
                              iconBg: AppColors.primaryLightTint,
                              iconColor: AppColors.primary,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyContactScreen())),
                              showDivider: true,
                            ),
                            _menuRow(
                              icon: LucideIcons.sliders,
                              label: 'Settings',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                              showDivider: false,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _logOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.logOut, color: AppColors.textMuted, size: 17),
                              const SizedBox(width: 10),
                              Text('Log out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  int _eligibleInDays(DateTime reactivateAt) {
    final remaining = reactivateAt.difference(DateTime.now());
    return remaining.inDays < 0 ? 0 : remaining.inDays + 1;
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
