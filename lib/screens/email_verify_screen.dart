import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/features.dart';
import '../widgets/rb_icon.dart';
import 'entry_route.dart';
import 'login_screen.dart';
import 'simulated_code_screen.dart';

/// The "check your email" step right after sign-up (free-plan sign-in): a
/// labelled simulation (see [SimulatedCodeScreen]) until an email sender
/// exists. No email is sent and the address stays unproven; the rules accept
/// that until `config/features.email_verified_required` is switched on.
class EmailVerifyScreen extends StatelessWidget {
  final String email;

  const EmailVerifyScreen({super.key, required this.email});

  Future<void> _continue(BuildContext context) async {
    final next = await signedInDestination();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => next), (route) => false);
  }

  /// Leaves the half-made sign-up: the account stays, but the person is
  /// signed out and can sign in again (or use another address).
  Future<void> _back(BuildContext context) async {
    await Backend.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) => SimulatedCodeScreen(
        icon: RbGlyph.mail,
        title: 'Check your email',
        intro: 'We would email a 6-digit code to',
        target: email,
        channel: 'Emails',
        code: kSimulatedEmailCode,
        doneMessage: 'Simulation only: your email was not really verified.',
        onContinue: () => _continue(context),
        onBack: () => _back(context),
      );
}
