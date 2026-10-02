import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/features.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';
import 'consent_screen.dart';
import 'login_code_screen.dart' show CodeBoxes;

/// The "check your number" step after registration.
///
/// SIMULATION: no text-message (SMS / WhatsApp / Truecaller) provider is
/// connected yet, so nothing is sent and nothing is verified — the screen
/// says so, and the code is [kSimulatedPhoneCode]. It never writes
/// `phone_verified_for` (only a server can), so the phone gate in the
/// rules, which is off, would still treat the number as unverified. When a
/// provider exists, swap this screen's internals; the entry point stays.
class PhoneVerifyScreen extends StatefulWidget {
  /// The 10-digit number entered at registration.
  final String phone;

  const PhoneVerifyScreen({super.key, required this.phone});

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _next() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConsentScreen()));

  Future<void> _verify() async {
    if (_verifying) return;
    if (_code.text.length != _length) {
      setState(() => _error = 'Enter all 6 digits of the code.');
      return;
    }
    if (_code.text != kSimulatedPhoneCode) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'That code isn’t right. In this simulation the code is $kSimulatedPhoneCode.';
        _code.clear();
      });
      return;
    }
    setState(() => _verifying = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulation only: your number was not really verified.')));
    _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const RbIcon(RbGlyph.mobile, size: 24, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Check your number', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We would text a 6-digit code to\n'),
                    TextSpan(text: '+91 ${widget.phone}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(12)),
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.45),
                    children: [
                      TextSpan(text: 'Simulation · ', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: 'text messages aren’t connected yet, so nothing is sent. Enter $kSimulatedPhoneCode to continue.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CodeBoxes(controller: _code, focusNode: _focus, length: _length, hasError: _error != null, onCompleted: _verify),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4)),
              ],
              const SizedBox(height: 24),
              LoadingButton(label: 'Verify and continue', isLoading: _verifying, onPressed: _verify),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _verifying ? null : _next,
                child: const Text('Skip for now', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
