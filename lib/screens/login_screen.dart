import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/features.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';
import 'entry_route.dart';
import 'legal_reader_screen.dart';
import 'login_code_screen.dart';

/// Human wording for a failed sign-in step. The sign-in functions send
/// readable messages for expected cases (wrong or expired code); anything
/// that looks like a raw code ("NOT_FOUND", "INTERNAL") or a missing /
/// unreachable function is translated here — only the error code goes to
/// the debug log, never the email or the code.
String friendlyAuthError(Object e) {
  if (e is FirebaseFunctionsException) {
    debugPrint('sign-in failed: functions/${e.code}');
    final m = (e.message ?? '').trim();
    final readable = m.contains(' ') && m != m.toUpperCase();
    const machine = {'internal', 'unknown', 'not-found', 'unimplemented', 'unavailable', 'deadline-exceeded', 'resource-exhausted', 'cancelled', 'data-loss'};
    if (readable && !machine.contains(e.code)) return m;
    return switch (e.code) {
      'not-found' || 'unimplemented' => 'Sign-in isn’t available right now. Please try again in a little while.',
      'unavailable' || 'deadline-exceeded' => 'We couldn’t reach Rakta Bandhan. Check your connection and try again.',
      'resource-exhausted' => 'Too many attempts. Wait a few minutes and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  debugPrint('sign-in failed: ${e.runtimeType}');
  return Backend.authErrorMessage(e);
}

/// Sign in. With [kEmailCodeLive] there is no password: enter your email
/// and we send a 6-digit code (LoginCodeScreen). Until then (free Firebase
/// plan) it is email + password, and a new account confirms its address
/// from the verification email Firebase sends (VerifyEmailScreen). Either
/// way a new account then completes registration.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _creating = false;
  bool _showPassword = false;
  String? _emailError;
  String? _error;

  static final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!emailPattern.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return;
    }
    final password = _passwordController.text;
    if (!kEmailCodeLive) {
      if (password.isEmpty) {
        setState(() => _error = 'Enter your password.');
        return;
      }
      if (_creating && password.length < 8) {
        setState(() => _error = 'Use at least 8 characters for your password.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _emailError = null;
      _error = null;
    });
    try {
      if (kEmailCodeLive) {
        final resendAfter = await Backend.instance.requestLoginCode(email);
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoginCodeScreen(email: email, resendAfterSeconds: resendAfter)));
        return;
      }
      if (_creating) {
        await Backend.instance.signUpWithEmail(email, password);
      } else {
        final user = await Backend.instance.signInWithEmail(email, password);
        // Someone who never confirmed their address lands on the "check your
        // inbox" screen next; make sure there is a fresh link waiting.
        if (!user.emailVerified) await Backend.instance.resendVerificationEmail().catchError((_) {});
      }
      final next = await signedInDestination();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => next), (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  /// Sends Firebase's password-reset email. The wording never says whether
  /// an account exists for the address.
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!emailPattern.hasMatch(email)) {
      setState(() => _emailError = 'Enter your email above first.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Backend.instance.sendPasswordReset(email);
    } catch (e) {
      if (!(e is FirebaseAuthException && e.code == 'user-not-found')) {
        if (mounted) setState(() => _error = friendlyAuthError(e));
        return;
      }
    }
    messenger.showSnackBar(SnackBar(content: Text('If an account exists for $email, a reset link is on its way. Check Spam too.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              // Centred in the available height, so a tall phone doesn't
              // leave the form stranded at the top over empty space.
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(child: Image.asset('assets/branding/final-logo-transparent.png', width: 104, fit: BoxFit.contain)),
                  const SizedBox(height: 22),
                  Text('Welcome to Rakta Bandhan', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 26, color: AppColors.ink, height: 1.15)),
                  const SizedBox(height: 6),
                  const Text(
                    'Find a blood donor nearby — or be one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: AppColors.ink2, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  const Text('Email', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: kEmailCodeLive ? TextInputAction.send : TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(fontSize: 15.5, color: AppColors.ink),
                    onSubmitted: kEmailCodeLive ? (_) => _busy ? null : _submit() : null,
                    onChanged: (_) => _emailError == null && _error == null ? null : setState(() {
                      _emailError = null;
                      _error = null;
                    }),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                      prefixIcon: const RbIcon(RbGlyph.mail, size: 19, color: AppColors.ink2),
                      errorText: _emailError,
                      errorMaxLines: 3,
                    ),
                  ),
                  if (!kEmailCodeLive) ...[
                    const SizedBox(height: 16),
                    const Text('Password', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                      style: const TextStyle(fontSize: 15.5, color: AppColors.ink),
                      onSubmitted: (_) => _busy ? null : _submit(),
                      onChanged: (_) => _error == null ? null : setState(() => _error = null),
                      decoration: InputDecoration(
                        hintText: _creating ? 'At least 8 characters' : 'Your password',
                        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                        prefixIcon: const RbIcon(RbGlyph.lock, size: 19, color: AppColors.ink2),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: RbIcon(_showPassword ? RbGlyph.eyeOff : RbGlyph.eye, size: 19, color: AppColors.ink2),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.brandRed, height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: kEmailCodeLive ? 'Send me a code' : (_creating ? 'Create account' : 'Sign in'),
                    isLoading: _busy,
                    onPressed: _submit,
                  ),
                  if (!kEmailCodeLive) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => setState(() {
                            _creating = !_creating;
                            _error = null;
                          }),
                          child: Text(
                            _creating ? 'Have an account? Sign in' : 'New here? Create an account',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandRed),
                          ),
                        ),
                        if (!_creating)
                          TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text('Forgot password?', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const RbIcon(RbGlyph.lock, size: 14, color: AppColors.ink2, accent: Colors.transparent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          kEmailCodeLive
                              ? 'No password. We email a 6-digit code each time.'
                              : 'A new account confirms its email once, with a link we send.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('By continuing you agree to our ', style: TextStyle(fontSize: 12, color: AppColors.mutedInk)),
                      _link('Terms of use', const LegalReaderScreen.terms()),
                      const Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.mutedInk)),
                      _link('Privacy policy', const LegalReaderScreen.privacy()),
                      const Text('.', style: TextStyle(fontSize: 12, color: AppColors.mutedInk)),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(String label, Widget page) => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.brandRed, fontWeight: FontWeight.w600)),
      );
}
