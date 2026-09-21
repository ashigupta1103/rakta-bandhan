import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Branded launch — a deliberate brand reveal, not a loading screen.
///
/// Root cause of the previous "blank box, logo flashes, gone" bug: the
/// reveal animation ran on a fixed clock completely decoupled from the
/// actual image decode. `Image.asset` on a ~400KB *undownsampled 4160×4160*
/// JPEG has real, variable decode latency — the opacity curve was reaching
/// "fully visible" long before the image had anything to paint, so the mark
/// popped in whenever decode happened to finish (often barely before the
/// 1.5s floor fired navigation) instead of at frame 1 of the reveal.
///
/// Fixed by decoupling "resolve where we're going" from "when the reveal is
/// allowed to start": the exact [ResizeImage]-wrapped provider used on
/// screen is precached via [precacheImage] first, so it's fully decoded and
/// sits in the image cache *before* the reveal Column is even built — the
/// animation only ever plays over pixels that are already there.
///
/// Routing precedence — the ring-carousel onboarding step is retired (not
/// in the approved entry flow: Splash -> Login -> OTP -> Registration, per
/// design_updated/Rakta Bandhan Redesign.dc.html's "Entry" section). The
/// screen and its OnboardingService are left in place, still reachable from
/// Preview Gallery for inspection, just no longer routed to for real users:
///   has donor profile -> MainNavigationScreen
///   no profile         -> LoginScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Decoded once at a size that actually matches how it's displayed (176
  // logical px, so 2x for retina) rather than the source's full 4160×4160 —
  // this is most of the decode-latency fix on its own. Precached below
  // using this *exact* provider so the cache key matches what's painted.
  static const _logoImage = ResizeImage(AssetImage('assets/branding/final-logo.jpeg'), width: 352);

  bool _prepareStarted = false;
  bool _assetReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepareStarted) return;
    _prepareStarted = true;
    _prepare();
  }

  Future<void> _prepare() async {
    // Resolve the destination concurrently with the decode — no reason to
    // make navigation wait on Firestore reads it doesn't need the logo for.
    final destinationFuture = _resolveDestination();

    await precacheImage(_logoImage, context);
    if (!mounted) return;
    setState(() => _assetReady = true);

    await _controller.forward();
    // Hold the fully-revealed mark — a brand moment, not a blip.
    await Future.delayed(const Duration(milliseconds: 550));

    final next = await destinationFuture;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (routeContext, primaryAnimation, secondaryAnimation) => next,
        transitionsBuilder: (routeContext, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<Widget> _resolveDestination() async {
    final user = Backend.instance.currentUser;
    final hasProfile = user != null && await Backend.instance.hasProfile();
    return hasProfile ? const MainNavigationScreen() : const LoginScreen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      // Before the asset is decoded: the cream ground only — never a
      // placeholder box, plate, or spinner standing in for the logo.
      body: _assetReady ? Center(child: _reveal()) : const SizedBox.shrink(),
    );
  }

  Widget _reveal() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        final mark = Curves.easeOutCubic.transform((v / 0.45).clamp(0.0, 1.0));
        final tagline = Curves.easeOutCubic.transform(((v - 0.55) / 0.45).clamp(0.0, 1.0));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: mark,
              child: Transform.scale(
                scale: 0.92 + 0.08 * mark,
                child: Container(
                  width: 176,
                  height: 176,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 32, offset: const Offset(0, 14))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image(image: _logoImage, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: tagline,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - tagline)),
                child: const Text(
                  'Every drop connects a life.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
