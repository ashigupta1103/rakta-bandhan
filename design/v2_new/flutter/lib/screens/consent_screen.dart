import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_screen.dart';
import 'verifying_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  void _accept() {
    if (!_agreed) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => const VerifyingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.lock, size: 30, color: AppColors.primary),
              const SizedBox(height: 14),
              Text('Your data, handled carefully', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                "Before you continue, here's what we do with your information.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 22),
              _infoCard(
                'Your phone number is never public',
                'Only shared with a requester after you accept their request.',
              ),
              const SizedBox(height: 12),
              _infoCard(
                'Your location is shown approximately',
                'Nearby donors see a distance, not your exact address.',
              ),
              const SizedBox(height: 12),
              _infoCard(
                'You can request deletion anytime',
                'From Settings → Privacy, in line with the DPDP Act, 2023.',
              ),
              const SizedBox(height: 16),

              // Documents referenced by the agreement below must be readable
              // before the user agrees to them.
              Row(
                children: [
                  _docLink('Privacy Policy', () => _push(const PrivacyPolicyScreen())),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('·', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ),
                  _docLink('Terms & Conditions', () => _push(const TermsScreen())),
                ],
              ),
              const SizedBox(height: 12),

              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (val) => setState(() => _agreed = val ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'I agree to the privacy policy and consent to being contacted for blood donation requests.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _agreed ? _accept : null,
                  child: const Text('I agree, continue'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can review or withdraw individual consents later from Profile → Consent preferences.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _docLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _infoCard(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
