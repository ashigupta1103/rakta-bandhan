import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../demo/demo.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'registration_screen.dart';
import 'username_screen.dart';
import '../widgets/rb_icon.dart';

/// "Enter the code we emailed you." Six boxes over one real text field, so
/// typing, pasting the whole code, and the keyboard's one-time-code
/// suggestion all work. It submits by itself on the sixth digit.
class LoginCodeScreen extends StatefulWidget {
  final String email;
  final int resendAfterSeconds;

  const LoginCodeScreen({super.key, required this.email, this.resendAfterSeconds = 30});

  @override
  State<LoginCodeScreen> createState() => _LoginCodeScreenState();
}

class _LoginCodeScreenState extends State<LoginCodeScreen> {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _resendIn = widget.resendAfterSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.resendAfterSeconds);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendIn <= 1) t.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 600));
    });
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (_verifying) return;
    if (code.length != _length) {
      setState(() => _error = 'Enter all 6 digits of the code.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    if (Demo.on) {
      // Simulated check against the fixed demo code — production sign-in
      // never accepts it (this branch can't run outside a demo session).
      if (code != Demo.emailCode) {
        HapticFeedback.mediumImpact();
        setState(() {
          _verifying = false;
          _error = 'That code isn’t right. In the demo the code is ${Demo.emailCode}.';
          _code.clear();
        });
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Demo.instance.registered ? const MainNavigationScreen() : const RegistrationScreen()),
        (route) => false,
      );
      return;
    }
    try {
      await Backend.instance.verifyLoginCode(widget.email, code);
      final hasProfile = await Backend.instance.hasProfile();
      final needsUsername = hasProfile && (await Backend.instance.myDonorDoc()).data()?['username'] == null;
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => !hasProfile ? const RegistrationScreen() : needsUsername ? const UsernameScreen(requiredChoice: true) : const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _verifying = false;
        _error = friendlyAuthError(e);
        _code.clear();
      });
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (Demo.on) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo: nothing is sent. The code is ${Demo.emailCode}.')));
      return;
    }
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final wait = await Backend.instance.requestLoginCode(widget.email);
      if (!mounted) return;
      _code.clear();
      _startCountdown(wait);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code is on its way. The old one no longer works.')));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Change email',
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
                  child: const RbIcon(RbGlyph.mail, size: 24, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Enter your code', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              CodeBoxes(controller: _code, focusNode: _focus, length: _length, hasError: _error != null, onCompleted: _verify),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4)),
              ],
              const SizedBox(height: 24),
              LoadingButton(label: 'Verify and continue', isLoading: _verifying, onPressed: _verify),
              const SizedBox(height: 14),
              Center(
                child: _resendIn > 0
                    ? Text('Resend code in ${_resendIn}s', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))
                    : TextButton(
                        onPressed: _resending ? null : _resend,
                        child: Text(_resending ? 'Sending…' : 'Resend code', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RbIcon(RbGlyph.inbox, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        Demo.on
                            ? 'Demo · nothing was emailed. Enter ${Demo.emailCode} to continue.'
                            : 'The code shows in the email’s subject line. Not there after a minute? Check Spam or Promotions. It works for 10 minutes.',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six digit boxes drawn over a single hidden TextField (sign-in code and
/// the demo phone check share it).
class CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final VoidCallback onCompleted;

  const CodeBoxes({super.key, required this.controller, required this.focusNode, required this.length, required this.hasError, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          // The real input: invisible, but it owns focus, the keyboard,
          // paste and autofill.
          Opacity(
            opacity: 0,
            // Keep the real input in the semantics tree (screen readers).
            alwaysIncludeSemantics: true,
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: (v) {
                  if (v.length == length) onCompleted();
                },
              ),
            ),
          ),
          IgnorePointer(
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final text = controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 46,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasError
                                ? AppColors.primary
                                : (focusNode.hasFocus && i == text.length.clamp(0, length - 1))
                                    ? AppColors.textPrimaryWarm
                                    : AppColors.cardBorderWarm,
                            width: focusNode.hasFocus && i == text.length.clamp(0, length - 1) ? 1.6 : 1,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
