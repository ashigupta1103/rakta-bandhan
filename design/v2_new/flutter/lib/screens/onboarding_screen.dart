import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/brand_mark.dart';
import 'login_screen.dart';

/// First-run value proposition. Four pages, then the existing LoginScreen.
///
/// Only reachable from SplashScreen when OnboardingService reports the user
/// has not seen it. Marks itself seen on Skip or on finishing page 4, and
/// uses pushReplacement so Back cannot re-enter it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _entry;
  int _index = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      dark: true,
      headline: 'Rakta Bandhan',
      body: 'Every drop connects a life.',
      serifHeadline: true,
    ),
    _OnboardingPage(
      headline: 'Find blood when it matters',
      body: 'Connect with verified donors by blood group and location — in minutes, not hours.',
    ),
    _OnboardingPage(
      headline: "Know who's available",
      body: 'See nearby donors who are ready to help right now, not just who is registered.',
    ),
    _OnboardingPage(
      headline: "Help, without exposing what shouldn't be",
      body: 'Donors stay private. Contact details are shared only after someone accepts a request.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _entry.forward(from: 0);
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markSeen();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool get _isDark => _pages[_index].dark;

  @override
  Widget build(BuildContext context) {
    final onDark = _isDark;
    final headlineColor = onDark ? const Color(0xFFFFF9F5) : AppColors.textPrimaryWarm;
    final bodyColor = onDark ? const Color(0xFFE9BFC4) : AppColors.textSecondary;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: onDark
                ? const [AppColors.gradientHeroStart, AppColors.gradientMatchingEnd]
                : const [AppColors.warmPageBackground, AppColors.warmPageBackground],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 52,
                            child: Center(
                              child: _parallax(
                                index: i,
                                child: _stagger(
                                  begin: 0.0,
                                  end: 0.55,
                                  dy: 18,
                                  child: _heroFor(i),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 48,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                _stagger(
                                  begin: 0.2,
                                  end: 0.75,
                                  child: page.serifHeadline
                                      ? Text(
                                          page.headline,
                                          style: AppTextStyles.display(
                                            fontSize: 32,
                                            color: headlineColor,
                                            height: 1.15,
                                          ),
                                        )
                                      : Text(
                                          page.headline,
                                          style: AppTextStyles.display(
                                            fontSize: 26,
                                            color: headlineColor,
                                            height: 1.25,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                _stagger(
                                  begin: 0.35,
                                  end: 0.9,
                                  child: Text(
                                    page.body,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: bodyColor,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _controls(onDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(bool onDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _index == _pages.length - 1 ? 0 : 1,
              child: IgnorePointer(
                ignoring: _index == _pages.length - 1,
                child: GestureDetector(
                  onTap: _finish,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: onDark
                            ? const Color(0xFFE9BFC4)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: i == _index ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? (onDark ? const Color(0xFFFBE6E8) : AppColors.primary)
                          : (onDark
                              ? const Color(0x40FBE6E8)
                              : AppColors.borderStrong),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: _PressableCircle(
                onTap: _next,
                background: onDark ? const Color(0xFFFBF7F1) : AppColors.primary,
                child: Icon(
                  _index == _pages.length - 1
                      ? LucideIcons.check
                      : LucideIcons.chevronRight,
                  size: 22,
                  color: onDark ? AppColors.gradientHeroEnd : AppColors.whiteTextOnPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal parallax: heroes drift at ~40% of the page delta, so the
  /// illustration trails the swipe rather than moving locked to it.
  Widget _parallax({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, inner) {
        var delta = 0.0;
        if (_pageController.hasClients && _pageController.position.haveDimensions) {
          delta = (_pageController.page ?? index.toDouble()) - index;
        }
        return Transform.translate(offset: Offset(-delta * 46, 0), child: inner);
      },
      child: child,
    );
  }

  Widget _stagger({
    required Widget child,
    required double begin,
    required double end,
    double dy = 14,
  }) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, inner) {
        final raw = ((_entry.value - begin) / (end - begin)).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy * (1 - t)), child: inner),
        );
      },
      child: child,
    );
  }

  Widget _heroFor(int index) {
    switch (index) {
      case 0:
        return AnimatedBuilder(
          animation: _entry,
          builder: (context, _) => BrandMark(
            progress: _entry.value,
            size: 168,
            color: const Color(0xFFFBE6E8),
          ),
        );
      case 1:
        return const _HeroFind();
      case 2:
        return const _HeroAvailable();
      default:
        return const _HeroPrivacy();
    }
  }
}

@immutable
class _OnboardingPage {
  final String headline;
  final String body;
  final bool dark;
  final bool serifHeadline;

  const _OnboardingPage({
    required this.headline,
    required this.body,
    this.dark = false,
    this.serifHeadline = false,
  });
}

/// Circular next action with a restrained press response (0.94 scale).
class _PressableCircle extends StatefulWidget {
  final VoidCallback onTap;
  final Color background;
  final Widget child;

  const _PressableCircle({
    required this.onTap,
    required this.background,
    required this.child,
  });

  @override
  State<_PressableCircle> createState() => _PressableCircleState();
}

class _PressableCircleState extends State<_PressableCircle> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.background,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: AppColors.shadowButton, blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Page 2 — a request card with compatible blood groups arranged around it.
class _HeroFind extends StatelessWidget {
  const _HeroFind();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorderWarm),
            ),
          ),
          Container(
            width: 186,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorderWarm),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowCard, blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLightTint,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'O+',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gradientHeroEnd,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Urgent',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.whiteTextOnPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 8, width: 128, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 7),
                Container(height: 8, width: 92, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Container(height: 7, width: 62, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(top: 6, left: 12, child: _GroupChip('A+')),
          const Positioned(bottom: 14, left: 0, child: _GroupChip('O-')),
          const Positioned(top: 30, right: 0, child: _GroupChip('B+')),
          const Positioned(bottom: 2, right: 24, child: _GroupChip('AB+')),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  const _GroupChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorderWarm),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
    );
  }
}

/// Page 3 — nearby donors with live availability.
class _HeroAvailable extends StatelessWidget {
  const _HeroAvailable();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row('RM', 'O+', '2.4 km', true, 1),
          const SizedBox(height: 10),
          _row('PN', 'A-', '3.1 km', true, 0.94),
          const SizedBox(height: 10),
          _row('KI', 'B+', '4.6 km', false, 0.88),
        ],
      ),
    );
  }

  Widget _row(String initials, String group, String distance, bool available, double scale) {
    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderWarm),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowCard, blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(height: 8, width: 58, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 6),
                      Text(group, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(distance, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: available ? AppColors.warmGreenBg : AppColors.dividerWarm,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: available ? AppColors.warmGreenText : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    available ? 'Available' : 'Resting',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: available ? AppColors.warmGreenText : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 4 — distance-only markers inside a privacy radius.
class _HeroPrivacy extends StatelessWidget {
  const _HeroPrivacy();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 228,
            height: 228,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLightTint.withValues(alpha: 0.35),
            ),
          ),
          Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: AppColors.shadowButton, blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.lock, size: 22, color: AppColors.whiteTextOnPrimary),
          ),
          const Positioned(top: 22, right: 26, child: _DistancePin('1.8 km')),
          const Positioned(bottom: 40, left: 10, child: _DistancePin('3.2 km')),
          const Positioned(bottom: 8, right: 44, child: _DistancePin('4.6 km')),
        ],
      ),
    );
  }
}

class _DistancePin extends StatelessWidget {
  final String label;
  const _DistancePin(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorderWarm),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.droplet, size: 11, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
