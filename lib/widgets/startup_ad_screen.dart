import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Source of the startup ad. Swap [startupAdLoader] for a real SDK later
/// (e.g. google_mobile_ads): return the ad widget once loaded, or null /
/// throw when no ad is available. The screen never waits past
/// [StartupAdScreen.maxDuration] either way.
typedef StartupAdLoader = Future<Widget?> Function();

/// No ad provider connected yet — the slot stays as a reserved placeholder.
Future<Widget?> startupAdLoader() async => null;

/// Reserved, labelled ad area. Fills the space it is given.
class StartupAdSlot extends StatelessWidget {
  final Widget? ad;
  final bool loading;
  const StartupAdSlot({super.key, this.ad, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Advertisement', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: ad ??
                (loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted))
                    : null),
          ),
        ),
      ],
    );
  }
}

/// Shown once at launch, between the splash and the normal destination.
/// Always continues to [next] after [maxDuration], ad or no ad.
class StartupAdScreen extends StatefulWidget {
  final Widget next;
  final StartupAdLoader loader;
  static const maxDuration = Duration(seconds: 3);

  const StartupAdScreen({super.key, required this.next, this.loader = startupAdLoader});

  @override
  State<StartupAdScreen> createState() => _StartupAdScreenState();
}

class _StartupAdScreenState extends State<StartupAdScreen> {
  Timer? _timer;
  Widget? _ad;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(StartupAdScreen.maxDuration, _continue);
    _load();
  }

  Future<void> _load() async {
    Widget? ad;
    try {
      ad = await widget.loader();
    } catch (_) {} // unavailable ad never blocks the user
    if (mounted) setState(() { _ad = ad; _loading = false; });
  }

  void _continue() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      // The ad takes about 90% of the screen; the name sits underneath.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Expanded(child: StartupAdSlot(ad: _ad, loading: _loading)),
              const SizedBox(height: 10),
              Text('Rakta Bandhan', style: AppTextStyles.display(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
