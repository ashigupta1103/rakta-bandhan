import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import 'main_navigation_screen.dart';
import 'registration_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;

  const OtpScreen({
    super.key,
    this.phoneNumber = '9999999999',
    this.countryCode = '+91',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _errorMessage;
  bool _isVerifying = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getMaskedNumber() {
    final phone = widget.phoneNumber;
    if (phone.length >= 4) {
      return '${widget.countryCode} ******${phone.substring(phone.length - 4)}';
    }
    return '${widget.countryCode} ******$phone';
  }

  Future<void> _handleVerify() async {
    final otpStr = _controllers.map((c) => c.text.trim()).join();
    if (otpStr.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit OTP verification code';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isVerifying = true;
    });

    try {
      // Demo mode: any 6-digit code is accepted, no SMS actually sent.
      // Signs in (or creates) a stable account keyed by country code +
      // phone number, so the same person on two different country codes
      // never collides with someone else's local number.
      await Backend.instance.verifyFakeOtp('${widget.countryCode}${widget.phoneNumber}');
      final hasProfile = await Backend.instance.hasProfile();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => hasProfile
              ? const MainNavigationScreen()
              : RegistrationScreen(phoneNumber: widget.phoneNumber),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Incorrect code. Please try again.';
      });
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
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: AppColors.textPrimaryWarm,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                child: const Icon(LucideIcons.shieldCheck, size: 24, color: AppColors.primary),
              ),
              Text(
                'Verify your number',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 22, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${_getMaskedNumber()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),

              // 6 OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    height: 48,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                          // Move forward
                          if (index < 5) {
                            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                          } else {
                            // Dismiss keyboard on last box
                            _focusNodes[index].unfocus();
                          }
                        } else {
                          // Move backward if empty
                          if (index > 0) {
                            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                          }
                        }
                      },
                    ),
                  );
                }),
              ),

              // Inline Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Resend Text Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive it? ",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('OTP verification code has been resent.'),
                        ),
                      );
                    },
                    child: Text(
                      'Resend OTP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Verify button
              LoadingButton(
                label: 'Verify',
                isLoading: _isVerifying,
                onPressed: _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
