import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'data_usage_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

/// About + legal entry point. Also the single place the app version and
/// open-source licences are exposed.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // TODO(backend): read from package_info_plus once the dependency is
  // approved — hardcoded to match pubspec.yaml's `version:` for now.
  static const _version = '1.0.0 (build 1)';

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
                    'About',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLightTint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.droplet, size: 26, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rakta Bandhan',
                          style: AppTextStyles.display(fontSize: 22, color: AppColors.textPrimaryWarm),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Every drop connects a life.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Version $_version',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMutedWarm),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _sectionLabel('Legal'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorderWarm),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _row(
                            context,
                            icon: LucideIcons.lock,
                            label: 'Privacy Policy',
                            onTap: () => _push(context, const PrivacyPolicyScreen()),
                          ),
                          _row(
                            context,
                            icon: LucideIcons.clipboardList,
                            label: 'Terms & Conditions',
                            onTap: () => _push(context, const TermsScreen()),
                          ),
                          _row(
                            context,
                            icon: LucideIcons.shieldCheck,
                            label: 'Data Usage',
                            onTap: () => _push(context, const DataUsageScreen()),
                          ),
                          _row(
                            context,
                            icon: LucideIcons.clipboardList,
                            label: 'Open-source licences',
                            isLast: true,
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: 'Rakta Bandhan',
                              applicationVersion: _version,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('Contact'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorderWarm),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'For data requests, account issues or anything urgent, contact the Rakta Bandhan administrator team.\n\nContact details to be confirmed before release.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.55),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Rakta Bandhan is a coordination tool, not a medical provider. It does not collect, test or store blood.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMutedWarm, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.dividerWarm)),
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
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
          ],
        ),
      ),
    );
  }
}
