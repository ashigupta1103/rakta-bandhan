import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_mark.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';

/// Branded launch. Roughly one second, no interaction, auto-advances.
///
/// Routing precedence (unchanged from the original apart from the new
/// onboarding branch):
///   has donor profile        -> MainNavigationScreen
///   no profile, seen intro   -> LoginScreen
///   no profile, first run    -> OnboardingScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _route();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    // Fixed ~1s floor so the mark always completes; profile and first-run
    // lookups happen concurrently and are almost always faster.
    final delay = Future.delayed(const Duration(milliseconds: 1000));
    final user = Backend.instance.currentUser;
    final hasProfile = user != null && await Backend.instance.hasProfile();
    final seenOnboarding = await OnboardingService.instance.hasSeenOnboarding();
    await delay;
    if (!mounted) return;

    final Widget next = hasProfile
        ? const MainNavigationScreen()
        : (seenOnboarding ? const LoginScreen() : const OnboardingScreen());

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final v = _controller.value;
            // Wordmark trails the mark: starts at 45% of the timeline.
            final wordmark = Curves.easeOutCubic.transform(
              ((v - 0.45) / 0.55).clamp(0.0, 1.0),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(progress: v, size: 132),
                const SizedBox(height: 10),
                Opacity(
                  opacity: wordmark,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - wordmark)),
                    child: Column(
                      children: [
                        Text(
                          'Rakta Bandhan',
                          style: AppTextStyles.display(
                            fontSize: 24,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Every drop connects a life.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
