import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../preview_mode.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import 'legal_reader_screen.dart';
import 'login_code_screen.dart';
import 'preview_gallery_screen.dart';
import 'preview_ui_screen.dart';

/// Sign in with no password: enter your email, we send a 6-digit code
/// (LoginCodeScreen). New and returning users take the same path — the
/// same email always opens the same account. Codes by SMS will join this
/// screen later; the phone number is collected on registration.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;

  static final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resendAfter = await Backend.instance.requestLoginCode(email);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.push(context, MaterialPageRoute(builder: (_) => LoginCodeScreen(email: email, resendAfterSeconds: resendAfter)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = Backend.authErrorMessage(e);
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
              // kEnablePreviewUi, off in any normal release build.
              if (kEnablePreviewUi) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviewGalleryScreen())),
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: const Text('Preview UI — all screens (no backend)'),
                ),
              ],
              const SizedBox(height: 20),
              Center(child: Image.asset('assets/branding/final-logo-transparent.png', width: 148, fit: BoxFit.contain)),
              const SizedBox(height: 12),
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
              const SizedBox(height: 36),
              const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _busy ? null : _sendCode(),
                onChanged: (_) => _error == null ? null : setState(() => _error = null),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(LucideIcons.mail, size: 17, color: AppColors.textSecondary),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.4)),
              ],
              const SizedBox(height: 20),
              LoadingButton(label: 'Send me a code', isLoading: _busy, onPressed: _sendCode),
              const SizedBox(height: 22),
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
                            TextSpan(text: 'No password needed. We email you '),
                            TextSpan(text: 'a 6-digit code', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' each time you sign in. Your email is never shown to other users.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('By continuing you agree to our ', style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalReaderScreen.terms())),
                    child: const Text('Terms', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalReaderScreen.privacy())),
                    child: const Text('Privacy policy', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const Text('.', style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm)),
                ],
              ),
              if (kEnablePreviewUi) ...[
                const SizedBox(height: 12),
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
