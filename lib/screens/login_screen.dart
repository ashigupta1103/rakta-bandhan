import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../preview_mode.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'otp_screen.dart';
import 'preview_gallery_screen.dart';
import 'preview_ui_screen.dart';

class _Country {
  final String name;
  final String short;
  final String? isoCode; // null = custom/"Other" (shown with a globe icon)
  final String code;
  final int? digits; // null = custom/"Other", any length 4-15 accepted
  const _Country(this.name, this.short, this.isoCode, this.code, this.digits);
}

const _kCountries = [
  _Country('India', 'IN', 'IN', '+91', 10),
  _Country('United States / Canada', 'US', 'US', '+1', 10),
  _Country('United Kingdom', 'UK', 'GB', '+44', 10),
  _Country('United Arab Emirates', 'UAE', 'AE', '+971', 9),
  _Country('Saudi Arabia', 'SA', 'SA', '+966', 9),
  _Country('Other', '', null, '', null),
];

/// Real flag artwork (country_flags package), not emoji glyphs.
class _FlagIcon extends StatelessWidget {
  final _Country country;
  final double height;
  const _FlagIcon(this.country, {this.height = 18});

  @override
  Widget build(BuildContext context) {
    if (country.isoCode == null) {
      return Icon(LucideIcons.globe, size: height, color: AppColors.textSecondary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CountryFlag.fromCountryCode(
        country.isoCode!,
        height: height,
        width: height * 4 / 3,
        shape: const RoundedRectangle(3),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customCodeController = TextEditingController();
  _Country _country = _kCountries.first;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _customCodeController.dispose();
    super.dispose();
  }

  String get _effectiveCode =>
      _country.digits == null ? '+${_customCodeController.text.trim()}' : _country.code;

  void _handleContinue() {
    final phoneText = _phoneController.text.trim();
    final customCode = _customCodeController.text.trim();

    if (_country.digits == null && (customCode.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(customCode))) {
      setState(() => _errorMessage = 'Please enter a valid country code');
      return;
    }
    if (phoneText.isEmpty) {
      setState(() => _errorMessage = 'Phone number cannot be empty');
      return;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneText)) {
      setState(() => _errorMessage = 'Phone number must contain digits only');
      return;
    }
    final expectedDigits = _country.digits;
    final validLength = expectedDigits == null
        ? phoneText.length >= 4 && phoneText.length <= 15
        : phoneText.length == expectedDigits;
    if (!validLength) {
      setState(() {
        _errorMessage = expectedDigits == null
            ? 'Please enter a valid phone number'
            : 'Please enter a valid $expectedDigits-digit phone number';
      });
      return;
    }

    setState(() => _errorMessage = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpScreen(phoneNumber: phoneText, countryCode: _effectiveCode),
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select country', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              ),
            ),
            const SizedBox(height: 8),
            for (final c in _kCountries)
              ListTile(
                onTap: () => Navigator.pop(context, c),
                leading: _FlagIcon(c, height: 22),
                title: Text(
                  c.digits == null ? c.name : '${c.short}  ${c.code}',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                ),
                subtitle: c.digits == null ? null : Text(c.name, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: c == _country ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary) : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _country = picked;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Frontend-only entry point for internal testing — gated by
              // kEnablePreviewUi (see definition above), off in any normal
              // release build so real users never see it. See
              // preview_gallery_screen.dart's own header comment for the
              // "why" of this whole mechanism.
              if (kEnablePreviewUi) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviewGalleryScreen())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.goldTint,
                      border: Border.all(color: AppColors.gold, width: 1.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.eye, size: 18, color: AppColors.goldDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Preview UI — All Screens', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.goldDeepest)),
                              const Text('No sign-in, no backend — sample data only', style: TextStyle(fontSize: 11.5, color: AppColors.goldDeep)),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.goldDeep),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('PREVIEW MODE — hidden in normal production builds', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.disabledTint)),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/branding/final-logo-transparent.png',
                  width: 148,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Text(
                'Welcome to Rakta Bandhan',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your help can save a life.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // Country Code & Phone Input — flag + code + divider + plain
              // field. Radius matches the system's 12px control per the
              // design doc's own note on this screen: "The current 30px
              // pill becomes the system's 12px control, so Login stops
              // being the one screen with its own radius."
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.cardBorderWarm, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openCountryPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FlagIcon(_country, height: 18),
                            const SizedBox(width: 6),
                            Text(
                              _country.digits == null ? _country.name : _country.code,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                            ),
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 26, color: AppColors.cardBorderWarm),
                    const SizedBox(width: 12),

                    // Phone TextField
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (val) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Enter your phone number',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_country.digits == null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customCodeController,
                  keyboardType: TextInputType.phone,
                  onChanged: (val) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Country code, e.g. 33',
                    prefixText: '+ ',
                  ),
                ),
              ],

              // Inline Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Continue'),
                      SizedBox(width: 8),
                      Icon(LucideIcons.arrowRight, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // OTP-only reassurance — per the approved design doc
              // (design_updated/Rakta Bandhan Redesign.dc.html, Login
              // frame): "The unavailable illustration is not replaced; the
              // space it occupied becomes the OTP-only reassurance, which
              // is more useful anyway." Replaces the hands-and-heart image
              // that used to sit below the consent text and add a full
              // extra screen of scrolling for no functional reason.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.goldTint,
                  border: Border.all(color: AppColors.warmBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.goldDeep),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                          children: [
                            TextSpan(text: 'We verify your phone with '),
                            TextSpan(text: 'a one-time code', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: '. No password is required.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Consent Text
              const Text(
                'By continuing, you consent to receive an OTP code to verify your phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm),
              ),

              // Secondary, lighter preview entry (4 tabs only) — same
              // kEnablePreviewUi gate as the primary banner above. Remove
              // this block (and preview_ui_screen.dart) once the preview is
              // no longer needed.
              if (kEnablePreviewUi) ...[
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviewUiScreen())),
                    child: const Text('Preview UI — 4 main tabs only (no backend)', style: TextStyle(fontSize: 12, color: AppColors.disabledTint)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
