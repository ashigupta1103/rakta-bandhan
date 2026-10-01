import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'registration_screen.dart';

/// "Check your inbox" — waits for the user to tap the link in Firebase's
/// verification email. It notices on its own: it re-checks every few
/// seconds while open and immediately when the app comes back to the
/// foreground (the user usually leaves to open their mail app).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  static const _resendCooldown = 60;

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldownLeft = _resendCooldown;
  bool _checking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    _startCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownLeft <= 1) t.cancel();
      setState(() => _cooldownLeft = (_cooldownLeft - 1).clamp(0, _resendCooldown));
    });
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking || _done) return;
    if (manual) setState(() => _checking = true);
    try {
      final verified = await Backend.instance.refreshEmailVerified();
      if (!mounted) return;
      if (verified) {
        _done = true;
        _poll?.cancel();
        final hasProfile = await Backend.instance.hasProfile();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => hasProfile ? const MainNavigationScreen() : const RegistrationScreen()),
          (route) => false,
        );
        return;
      }
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Not verified yet. Tap the link in the email, then come back here.'),
        ));
      }
    } catch (_) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t check right now. Please try again.')));
      }
    } finally {
      if (mounted && manual) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await Backend.instance.resendVerificationEmail();
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent again. Check your inbox and spam folder.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Backend.authErrorMessage(e))));
    }
  }

  Future<void> _useDifferentEmail() async {
    _poll?.cancel();
    await Backend.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = Backend.instance.currentUser?.email ?? 'your email';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _useDifferentEmail();
      },
      child: Scaffold(
        backgroundColor: AppColors.warmPageBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.mailCheck, size: 26, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Check your inbox', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
                    children: [
                      const TextSpan(text: 'We sent a verification link to\n'),
                      TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm)),
                      const TextSpan(text: '.\nTap it, then come back — this screen moves on by itself.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Tip(icon: LucideIcons.inbox, text: 'The email comes from noreply@ and is titled “Verify your email”.'),
                      SizedBox(height: 10),
                      _Tip(icon: LucideIcons.alertCircle, text: 'Not there after a minute? Look in Spam or Promotions.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                LoadingButton(label: 'I’ve verified — continue', isLoading: _checking, onPressed: () => _check(manual: true)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _cooldownLeft > 0 ? null : _resend,
                  child: Text(_cooldownLeft > 0 ? 'Resend email in ${_cooldownLeft}s' : 'Resend email'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _useDifferentEmail,
                  child: const Text('Use a different email', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45))),
        ],
      );
}
