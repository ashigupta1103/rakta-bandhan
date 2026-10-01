import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../preview_mode.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import 'legal_reader_screen.dart';
import 'main_navigation_screen.dart';
import 'preview_gallery_screen.dart';
import 'preview_ui_screen.dart';
import 'registration_screen.dart';
import 'verify_email_screen.dart';

/// Sign in / create account with email and password. New accounts get a
/// verification email (Firebase's own, free) and go to VerifyEmailScreen;
/// nothing else in the app opens until the address is confirmed. The phone
/// number is collected on the registration screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 8;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Enter your password.';
    if (_creating) {
      if (password.length < minPasswordLength) return 'Use at least $minPasswordLength characters for your password.';
      if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
        return 'Use a mix of letters and numbers in your password.';
      }
      if (_confirmController.text != password) return 'The two passwords don’t match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_creating) {
        await Backend.instance.signUpWithEmail(email, password);
      } else {
        await Backend.instance.signInWithEmail(email, password);
      }
      if (!mounted) return;
      await _continueSignedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = Backend.authErrorMessage(e);
      });
    }
  }

  /// Verified → profile or registration. Unverified → the verify screen.
  Future<void> _continueSignedIn() async {
    final verified = await Backend.instance.refreshEmailVerified();
    Widget next;
    if (!verified) {
      next = const VerifyEmailScreen();
    } else {
      next = await Backend.instance.hasProfile() ? const MainNavigationScreen() : const RegistrationScreen();
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => next), (route) => false);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Type your email address above first, then tap “Forgot password”.');
      return;
    }
    try {
      await Backend.instance.sendPasswordReset(email);
    } catch (_) {
      // Deliberately the same message either way — never reveal whether an
      // account exists for an address.
    }
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('If an account exists for $email, a password reset link is on its way. Check your inbox and spam folder.'),
    ));
  }

  void _toggleMode() => setState(() {
        _creating = !_creating;
        _error = null;
        _confirmController.clear();
      });

  InputDecoration _field(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 17, color: AppColors.textSecondary),
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: AutofillGroup(
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
                  _creating ? 'Create your account' : 'Welcome to Rakta Bandhan',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm),
                ),
                const SizedBox(height: 8),
                Text(
                  _creating ? 'We’ll email you a link to confirm it’s really you.' : 'Your help can save a life.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) => _error == null ? null : setState(() => _error = null),
                  decoration: _field('you@example.com', LucideIcons.mail),
                ),
                const SizedBox(height: 16),
                const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  textInputAction: _creating ? TextInputAction.next : TextInputAction.done,
                  autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                  onSubmitted: (_) => _creating ? null : _submit(),
                  onChanged: (_) => _error == null ? null : setState(() => _error = null),
                  decoration: _field(
                    _creating ? 'At least $minPasswordLength characters, letters and numbers' : 'Your password',
                    LucideIcons.lock,
                    suffix: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: AppColors.textSecondary),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                if (_creating) ...[
                  const SizedBox(height: 16),
                  const Text('Confirm password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) => _error == null ? null : setState(() => _error = null),
                    decoration: _field('Type it again', LucideIcons.lock),
                  ),
                ],
                if (!_creating)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.primary, height: 1.4)),
                  ),
                ],
                LoadingButton(label: _creating ? 'Create account' : 'Sign in', isLoading: _busy, onPressed: _submit),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_creating ? 'Already have an account?' : 'New to Rakta Bandhan?', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(_creating ? 'Sign in' : 'Create account', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                        child: Text(
                          'Your email is used to sign in and to recover your account. It is never shown to other users.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalReaderScreen.terms())),
                      child: const Text('Terms', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                    const Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textMutedWarm)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalReaderScreen.privacy())),
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
      ),
    );
  }
}
