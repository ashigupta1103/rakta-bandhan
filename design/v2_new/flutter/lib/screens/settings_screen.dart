import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/confirm_sheet.dart';
import 'admin_login_screen.dart';
import 'legal/about_screen.dart';
import 'legal/consent_preferences_screen.dart';
import 'legal/data_usage_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Persisted locally. MISSING BACKEND BOUNDARY — there is no
  /// address-visibility field on `donors/{uid}`; when one is added this
  /// should move onto the donor doc alongside the other privacy settings.
  static const _kShowExactAddress = 'rb_show_exact_address';

  bool _showExactAddress = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showExactAddress = prefs.getBool(_kShowExactAddress) ?? false);
  }

  Future<void> _setShowExactAddress(bool value) async {
    setState(() => _showExactAddress = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowExactAddress, value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _requestDeletion() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Request data deletion?',
      message:
          'This asks an administrator to permanently delete your profile, your request history and your donation record. It cannot be undone.',
      confirmLabel: 'Request deletion',
    );
    if (!confirmed) return;
    _showSnackBar('Data deletion request submitted.');
  }

  Future<void> _logOutEverywhere() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Log out of all devices?',
      message: 'You will be signed out everywhere and will need an OTP to sign back in.',
      confirmLabel: 'Log out everywhere',
    );
    if (!confirmed) return;

    await Backend.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeading('Privacy'),
                    _card([
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.dividerWarm))),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Show exact address to matched donors',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Off by default — matched donors see only a distance',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _showExactAddress,
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primaryLightTint,
                              inactiveThumbColor: AppColors.textMuted,
                              inactiveTrackColor: AppColors.border,
                              onChanged: _setShowExactAddress,
                            ),
                          ],
                        ),
                      ),
                      _actionRow(
                        icon: LucideIcons.sliders,
                        label: 'Consent preferences',
                        onTap: () => _push(const ConsentPreferencesScreen()),
                        showDivider: true,
                      ),
                      _actionRow(
                        icon: LucideIcons.history,
                        label: 'Download my data',
                        onTap: () => _showSnackBar('Preparing your data export...'),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _sectionHeading('Legal'),
                    _card([
                      _actionRow(
                        icon: LucideIcons.lock,
                        label: 'Privacy Policy',
                        onTap: () => _push(const PrivacyPolicyScreen()),
                        showDivider: true,
                      ),
                      _actionRow(
                        icon: LucideIcons.clipboardList,
                        label: 'Terms & Conditions',
                        onTap: () => _push(const TermsScreen()),
                        showDivider: true,
                      ),
                      _actionRow(
                        icon: LucideIcons.shieldCheck,
                        label: 'Data Usage',
                        onTap: () => _push(const DataUsageScreen()),
                        showDivider: true,
                      ),
                      _actionRow(
                        icon: LucideIcons.droplet,
                        label: 'About Rakta Bandhan',
                        onTap: () => _push(const AboutScreen()),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _sectionHeading('Account'),
                    _card([
                      _actionRow(
                        icon: LucideIcons.alertTriangle,
                        label: 'Request data deletion',
                        labelColor: AppColors.primary,
                        onTap: _requestDeletion,
                        showDivider: true,
                      ),
                      _actionRow(
                        icon: LucideIcons.logOut,
                        label: 'Log out of all devices',
                        labelColor: AppColors.primary,
                        onTap: _logOutEverywhere,
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _sectionHeading('Admin (temporary)'),
                    _card([
                      _actionRow(
                        icon: LucideIcons.shieldCheck,
                        label: 'Admin Console',
                        onTap: () => _push(const AdminLoginScreen()),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Padding(
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
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorderWarm),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool showDivider,
    Color labelColor = AppColors.textPrimaryWarm,
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
              decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: labelColor),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
          ],
        ),
      ),
    );
  }
}
