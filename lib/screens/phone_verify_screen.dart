import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../demo/demo.dart';
import '../services/phone_privacy.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';
import 'consent_screen.dart';
import 'login_code_screen.dart';

/// Registration step: confirm the mobile number with a 6-digit SMS code.
///
/// PRODUCTION STATUS: there is no SMS/phone-auth provider configured, so
/// production registration does not send or check a phone code — the
/// number is stored unverified (see CLAUDE.md, "Auth"). This screen is
/// therefore only reachable from a client-demo session, where the code is
/// the fixed [Demo.phoneOtp]. Wiring it to a real provider later means
/// replacing [_check] — the UI stays.
class PhoneVerifyScreen extends StatefulWidget {
  final String phone;
  const PhoneVerifyScreen({super.key, required this.phone});

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
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

  void _check() {
    if (!Demo.on) return;
    if (_code.text != Demo.phoneOtp) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'That code isn’t right. In the demo the code is ${Demo.phoneOtp}.';
        _code.clear();
      });
      return;
    }
    Demo.instance.registered = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConsentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Change number',
          icon: const RbIcon(RbGlyph.back, color: AppColors.ink),
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
              const Center(child: RbIcon(RbGlyph.mobile, size: 40, color: AppColors.brandRed)),
              const SizedBox(height: 16),
              Text('Verify your mobile number', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent by SMS to\n'),
                    TextSpan(text: '+91 ${maskPhone(widget.phone)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              CodeBoxes(controller: _code, focusNode: _focus, length: 6, hasError: _error != null, onCompleted: _check),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.brandRed, height: 1.4)),
              ],
              const SizedBox(height: 24),
              LoadingButton(label: 'Verify number', isLoading: false, onPressed: _check),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Demo · no SMS is sent. Enter ${Demo.phoneOtp} to continue.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your number is never shown to other users. Matched donors and requesters reach you through in-app messages and calls.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
