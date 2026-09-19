import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'otp_screen.dart';
import 'preview_gallery_screen.dart';
import 'preview_ui_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      setState(() {
        _errorMessage = 'Phone number cannot be empty';
      });
    } else if (phoneText.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phoneText)) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number';
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpScreen(phoneNumber: phoneText)),
      );
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
              // Frontend-only entry point for internal testing — gated out
              // of release builds entirely (kReleaseMode is a compile-time
              // constant, so this branch and everything it references is
              // dead-code-eliminated from `flutter build --release`; real
              // users never see it). Still fully reachable in debug/profile
              // builds (`flutter run`) regardless of whether real
              // registration is working. See preview_gallery_screen.dart's
              // own header comment for the "why" of this whole mechanism.
              if (!kReleaseMode) ...[
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
                  child: Text('DEV BUILD ONLY — hidden in production', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.disabledTint)),
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

              // Country Code & Phone Input Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country Code Container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: AppColors.cardBorderWarm,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '+91',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm),
                    ),
                  ),
                  const SizedBox(width: 8),

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
                      decoration: const InputDecoration(
                        hintText: 'Enter phone number',
                        prefixIcon: Icon(LucideIcons.phone, size: 16),
                      ),
                    ),
                  ),
                ],
              ),

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
                  child: const Text('Continue'),
                ),
              ),

              const SizedBox(height: 24),

              // Consent Text
              const Text(
                'By continuing, you consent to receive an OTP code to verify your phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm),
              ),

              // Secondary, lighter preview entry (4 tabs only) — same
              // release-mode gate as the primary banner above. Remove this
              // block (and preview_ui_screen.dart) once the preview is no
              // longer needed.
              if (!kReleaseMode) ...[
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
