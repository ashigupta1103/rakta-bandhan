import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';
import 'login_code_screen.dart' show CodeBoxes;

/// A "we sent you a code" step that sends nothing.
///
/// SIMULATION: used for the email check after sign-up and the phone check
/// after registration, because no email or text-message provider is connected
/// yet. It says so on screen, accepts one fixed [code], and verifies nothing
/// (only a server can mark an email or number as proven). It can be skipped.
/// When a provider exists, replace the screen; the places that open it stay.
class SimulatedCodeScreen extends StatefulWidget {
  final RbGlyph icon;
  final String title;

  /// "We would text a 6-digit code to" — followed by [target] on its own line.
  final String intro;
  final String target;

  /// What isn't connected, capitalised: "Text messages", "Email delivery".
  final String channel;

  /// The one code that continues.
  final String code;

  /// Shown once the right code is entered (not when skipping).
  final String doneMessage;

  /// Runs after the right code, or after "Skip for now".
  final Future<void> Function() onContinue;

  /// The back arrow and the system back gesture. Defaults to closing the screen.
  final VoidCallback? onBack;

  const SimulatedCodeScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.intro,
    required this.target,
    required this.channel,
    required this.code,
    required this.doneMessage,
    required this.onContinue,
    this.onBack,
  });

  @override
  State<SimulatedCodeScreen> createState() => _SimulatedCodeScreenState();
}

class _SimulatedCodeScreenState extends State<SimulatedCodeScreen> {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
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

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await widget.onContinue();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != _length) {
      setState(() => _error = 'Enter all 6 digits of the code.');
      return;
    }
    if (_code.text != widget.code) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'That code isn’t right. In this simulation the code is ${widget.code}.';
        _code.clear();
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.doneMessage)));
    await _continue();
  }

  void _back() => widget.onBack != null ? widget.onBack!() : Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.warmPageBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
            onPressed: _back,
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
                    child: RbIcon(widget.icon, size: 24, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    children: [
                      TextSpan(text: '${widget.intro}\n'),
                      TextSpan(text: widget.target, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(12)),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.45),
                      children: [
                        const TextSpan(text: 'Simulation · ', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: '${widget.channel} aren’t connected yet, so nothing is sent. Enter ${widget.code} to continue.'),
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
                LoadingButton(label: 'Verify and continue', isLoading: _busy, onPressed: _verify),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _continue,
                  child: const Text('Skip for now', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
