import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_button.dart';
import 'admin_dashboard_screen.dart';

/// Real Firebase email/password sign-in, then a Firestore check that the
/// signed-in uid has an `admins/{uid}` doc (see backend/README.md for how
/// the first admin is bootstrapped — nothing in-app can create one).
///
/// Signing in here uses the same FirebaseAuth instance as the donor OTP
/// flow (Backend._auth) — there's only one signed-in user per app
/// instance, so this replaces any donor session that was active. That's
/// an accepted trade-off for a lightweight companion console, not a bug:
/// sign back in as a donor afterwards if you need both.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController(text: 'admin@raktabandhan.org');
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _looksLikeEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  Future<void> _handleSignIn() async {
    setState(() {
      _emailError = _emailController.text.trim().isEmpty
          ? 'Work email is required'
          : (!_looksLikeEmail ? 'Enter a valid email address' : null);
      _passwordError = _passwordController.text.isEmpty ? 'Password is required' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _isSigningIn = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final isAdmin = await Backend.instance.isCurrentUserAdmin();
      if (!isAdmin) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _passwordError = 'This account is not an admin.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _passwordError = 'Incorrect email or password.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _passwordError = 'Sign-in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldCheck, size: 30, color: AppColors.primary),
              const SizedBox(height: 14),
              const Text('Admin console', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 6),
              const Text(
                'Invite-only. Accounts are provisioned by a super-admin — there is no public sign-up.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Work email', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.mail, size: 15),
                  hintText: 'admin@raktabandhan.org',
                ),
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text(_emailError!, style: const TextStyle(fontSize: 12, color: AppColors.primary))),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.lock, size: 15), hintText: '••••••••••'),
              ),
              if (_passwordError != null) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text(_passwordError!, style: const TextStyle(fontSize: 12, color: AppColors.primary))),
              ],
              const SizedBox(height: 20),
              LoadingButton(label: 'Sign in', isLoading: _isSigningIn, onPressed: _handleSignIn),
              const SizedBox(height: 16),
              const Text(
                'Protected by two-factor authentication and device attestation (App Check).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
