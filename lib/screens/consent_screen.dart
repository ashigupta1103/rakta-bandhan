import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_glyph.dart';
import 'legal_reader_screen.dart';
import 'location_permission_screen.dart';
import 'verifying_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  Future<void> _accept() async {
    if (!_agreed) return;
    // Registration usually already asked for location (to fill in the
    // area). Don't ask a second time — go straight on if it's granted.
    var granted = false;
    try {
      final p = await Geolocator.checkPermission();
      granted = p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {}
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => granted ? const VerifyingScreen() : const LocationPermissionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandGlyph(icon: LucideIcons.lock),
              const SizedBox(height: 16),
              Text('Your data, handled carefully', style: AppTextStyles.display(fontSize: 21, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 8),
              const Text(
                "Before you continue, here's what we do with your information.",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
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
                'Settings › Delete my account removes it, in line with the DPDP Act, 2023.',
              ),
              const SizedBox(height: 20),
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
                    const Expanded(
                      child: Text(
                        'I am 18 or older, I agree to the Terms of use and Privacy policy, and I consent to being contacted about blood donation requests.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Wrap(
                  spacing: 4,
                  children: [
                    _docLink('Terms of use', () => const LegalReaderScreen.terms()),
                    _docLink('Privacy policy', () => const LegalReaderScreen.privacy()),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _agreed ? _accept : null,
                  child: const Text('I agree, continue'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docLink(String label, Widget Function() page) => TextButton(
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 36)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
        child: Text(label, style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline, decorationColor: AppColors.red300)),
      );

  Widget _infoCard(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorderWarm),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
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
