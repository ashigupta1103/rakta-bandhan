import 'package:flutter/material.dart';
import '../services/features.dart';
import '../widgets/rb_icon.dart';
import 'consent_screen.dart';
import 'simulated_code_screen.dart';

/// The "check your number" step after registration: a labelled simulation
/// (see [SimulatedCodeScreen]) until an SMS / WhatsApp / Truecaller provider
/// exists. It never writes `phone_verified_for` (only a server can), so the
/// phone gate in the rules, which is off, would still treat the number as
/// unverified.
class PhoneVerifyScreen extends StatelessWidget {
  /// The 10-digit number entered at registration.
  final String phone;

  const PhoneVerifyScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) => SimulatedCodeScreen(
        icon: RbGlyph.mobile,
        title: 'Check your number',
        intro: 'We would text a 6-digit code to',
        target: '+91 $phone',
        channel: 'Text messages',
        code: kSimulatedPhoneCode,
        doneMessage: 'Simulation only: your number was not really verified.',
        onContinue: () async {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConsentScreen()));
        },
      );
}
