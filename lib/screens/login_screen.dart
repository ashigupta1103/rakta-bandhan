import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
import '../demo/demo_hub_screen.dart';
import '../preview_mode.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';
import 'legal_reader_screen.dart';
import 'login_code_screen.dart';
import 'main_navigation_screen.dart';

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

/// Sign in with no password: enter your email, we send a 6-digit code
/// (LoginCodeScreen). New and returning users take the same path — the
/// same email always opens the same account; a new account then completes
/// registration. Phone verification belongs to registration, not sign-in.
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
    if (Demo.on) {
      // Simulated: no email is sent. Only the demo address is accepted so a
      // real address typed into a demo build never looks like it worked.
      if (email.toLowerCase() != Demo.email) {
        setState(() => _error = 'In the demo, sign in with ${Demo.email}.');
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => LoginCodeScreen(email: email)));
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
        _error = friendlyAuthError(e);
      });
    }
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
                  if (Demo.on) ...[_demoHint(), const SizedBox(height: 14)],
                  const Text('Email', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(fontSize: 15.5, color: AppColors.ink),
                    onSubmitted: (_) => _busy ? null : _sendCode(),
                    onChanged: (_) => _error == null ? null : setState(() => _error = null),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                      prefixIcon: const RbIcon(RbGlyph.mail, size: 19, color: AppColors.ink2),
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(label: 'Send me a code', isLoading: _busy, onPressed: _sendCode),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RbIcon(RbGlyph.lock, size: 14, color: AppColors.ink2, accent: Colors.transparent),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'No password. We email a 6-digit code each time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppColors.ink2),
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
                  // Client preview — only in preview builds (kEnablePreviewUi);
                  // a production release has no demo entry, route or data.
                  if (kEnablePreviewUi && !Demo.on) ...[
                    const SizedBox(height: 26),
                    const Divider(height: 1, color: AppColors.warmBorder),
                    const SizedBox(height: 18),
                    const Text('Preview', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.warmBorder)),
                      onPressed: () {
                        Demo.instance.start(DemoRole.requester);
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (r) => false);
                      },
                      icon: const RbIcon(RbGlyph.droplet, size: 17, color: AppColors.brandRed),
                      label: const Text('Explore the Rakta Bandhan demo'),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DemoHubScreen())),
                        child: const Text('Choose a demo journey', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                      ),
                    ),
                    const Text(
                      'Simulated data on this device only — no sign-in, nothing sent or saved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.mutedInk),
                    ),
                  ],
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

  /// Demo builds only: says the code is simulated and fills the address.
  Widget _demoHint() => Material(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _emailController.text = Demo.email;
            _error = null;
          }),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.45),
                children: [
                  TextSpan(text: 'Demo · ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: 'no email is sent. Tap to use ${Demo.email}; the code is ${Demo.emailCode}.'),
                ],
              ),
            ),
          ),
        ),
      );
}
