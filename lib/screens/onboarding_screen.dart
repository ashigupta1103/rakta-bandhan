import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/ring_field.dart';
import 'login_screen.dart';

/// First-run value proposition — four pages built to the approved
/// "Onboarding Art Direction, revision 2" spec: one ring group (three
/// circles at a fixed 216/152/107 ratio) scaled 1.00 -> 1.24 -> 1.62 -> 0.90
/// across the pages, off-centre at design point (252, 300) on the 390-wide
/// canonical frame, with page-2's compatible-group content rendered as the
/// droplet tokens from the Visual Richness Proposal layered on top of that
/// approved ring system. No screenshot heroes — diagrams and typography only.
///
/// Only reachable from SplashScreen when OnboardingService reports the user
/// has not seen it. Marks itself seen on Skip or on finishing page 4, and
/// uses pushReplacement so Back cannot re-enter it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// Design constants shared by every page — see class doc.
const double _kFrameWidth = 390;
// Design content height excluding the mockup's fake status bar (46, real
// SafeArea supplies the actual one) and the bottom Skip/dots/next chrome
// (104) this screen renders itself as a sibling row below the PageView.
const double _kContentHeight = 844 - 46 - 104;
const double _kRingCenterX = 252;
const double _kRingCenterY = 300 - 46;

// Page 1's brand mark — decoded once at a size matched to how it's actually
// displayed (well under the source's native 4160×4160) so it paints
// instantly once precached, the same fix applied to Splash.
const _logoImage = ResizeImage(AssetImage('assets/branding/final-logo.jpeg'), width: 460);

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _entry;
  int _index = 0;
  bool _logoReady = false;
  bool _logoPrecacheStarted = false;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(dark: false, ringScale: 1.00),
    _OnboardingPage(
      dark: false,
      ringScale: 1.24,
      eyebrow: '2 units · urgent',
      headline: 'Find blood when it matters',
      body: 'Four blood groups can answer one need. We alert every compatible donor nearby at once.',
    ),
    _OnboardingPage(
      dark: false,
      ringScale: 1.62,
      headline: "Know who's available",
      body: 'Real people, ready right now — not a directory of everyone who ever registered.',
    ),
    _OnboardingPage(
      dark: false,
      ringScale: 0.90,
      headline: "Help, without exposing what shouldn't be",
      body: 'You see distance. Names and numbers stay sealed until someone accepts.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoPrecacheStarted) return;
    _logoPrecacheStarted = true;
    precacheImage(_logoImage, context).then((_) {
      if (mounted) setState(() => _logoReady = true);
    });
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
        pageBuilder: (routeContext, primaryAnimation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (routeContext, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  bool get _isDark => _pages[_index].dark;

  @override
  Widget build(BuildContext context) {
    final onDark = _isDark;
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: onDark
              ? const LinearGradient(
                  begin: Alignment(-0.2, -1),
                  end: Alignment(0.2, 1),
                  colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
                  stops: [0, 0.62, 1],
                )
              : const LinearGradient(colors: [AppColors.warmPageBackground, AppColors.warmPageBackground]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, i) => _OnboardingPageView(page: _pages[i], entry: _entry, pageController: _pageController, index: i, logoReady: _logoReady),
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
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: onDark ? const Color(0xFFE9BFC4) : AppColors.textSecondary),
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
                          : (onDark ? const Color(0x40FBE6E8) : AppColors.borderStrong),
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
                background: AppColors.primary,
                child: Icon(
                  _index == _pages.length - 1 ? LucideIcons.check : LucideIcons.chevronRight,
                  size: 22,
                  color: AppColors.whiteTextOnPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _OnboardingPage {
  final bool dark;
  final double ringScale;
  final String? eyebrow;
  final String? headline;
  final String? body;

  const _OnboardingPage({required this.dark, required this.ringScale, this.eyebrow, this.headline, this.body});
}

/// One onboarding page's content, laid out with the design's own coordinate
/// system (390-wide frame, ring centred at (252, 254) in content-space)
/// scaled to the actual available box via [LayoutBuilder] — a faithful,
/// responsive reproduction rather than a literal fixed-px copy per Phase 17.
class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final AnimationController entry;
  final PageController pageController;
  final int index;
  final bool logoReady;

  const _OnboardingPageView({required this.page, required this.entry, required this.pageController, required this.index, required this.logoReady});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final px = constraints.maxWidth / _kFrameWidth;
        final py = constraints.maxHeight / _kContentHeight;
        Offset at(double designX, double designY) => Offset(designX * px, designY * py);
        final ringCenter = at(_kRingCenterX, _kRingCenterY);

        return _parallax(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Soft ambient glow behind the ring — fills the dead space
              // around it with atmosphere instead of flat colour.
              Positioned(
                left: ringCenter.dx - (RingField.baseOuter * page.ringScale * px) * 0.75,
                top: ringCenter.dy - (RingField.baseOuter * page.ringScale * px) * 0.75,
                width: RingField.baseOuter * page.ringScale * px * 1.5,
                height: RingField.baseOuter * page.ringScale * px * 1.5,
                child: _stagger(
                  begin: 0.0,
                  end: 0.8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: page.dark
                            ? [const Color(0x2AFBE6E8), Colors.transparent]
                            : [AppColors.primaryLightTint.withValues(alpha: 0.55), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              // Ring field, seated at the page's off-centre point.
              Positioned(
                left: ringCenter.dx - (RingField.baseOuter * page.ringScale * px) / 2,
                top: ringCenter.dy - (RingField.baseOuter * page.ringScale * px) / 2,
                width: RingField.baseOuter * page.ringScale * px,
                height: RingField.baseOuter * page.ringScale * px,
                child: _stagger(
                  begin: 0.0,
                  end: 0.65,
                  child: RingField(
                    scale: page.ringScale,
                    referenceWidth: _kFrameWidth,
                    color: page.dark ? const Color(0xFFFBE6E8) : const Color(0xFFC8B8A0),
                    innerDashed: index == 3,
                    strokeWidth: 1.4,
                    middleFill: page.dark ? const Color(0x14FBE6E8) : AppColors.primaryLightTint.withValues(alpha: 0.16),
                  ),
                ),
              ),
              // Per-page content seated on/around the ring.
              ..._content(context, px, py, ringCenter),
              // Headline + body, left-aligned at x=28, baseline ~y=452
              // (design y=498 minus the 46px status-bar offset).
              if (page.headline != null)
                Positioned(
                  left: 28 * px,
                  right: 28 * px,
                  top: 452 * py,
                  child: _stagger(
                    begin: 0.2,
                    end: 0.75,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.headline!,
                          style: AppTextStyles.display(fontSize: 29, color: AppColors.textPrimaryWarm, height: 1.18),
                        ),
                        if (page.body != null) ...[
                          Container(width: 40, height: 1, margin: const EdgeInsets.symmetric(vertical: 18), color: const Color(0xFFD8CFC2)),
                          Text(page.body!, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.62)),
                        ],
                      ],
                    ),
                  ),
                ),
              // Page 1's supporting tagline — the logo itself carries the
              // wordmark, so no separate recreated "Rakta Bandhan" text.
              if (index == 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: ringCenter.dy + (RingField.baseOuter * page.ringScale * px) * 0.75,
                  child: _stagger(
                    begin: 0.3,
                    end: 0.8,
                    child: const Text(
                      'Every drop connects a life.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.55),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, double px, double py, Offset ringCenter) {
    switch (index) {
      case 0:
        return _brandContent(ringCenter, px);
      case 1:
        return _compatibilityContent(ringCenter, px, py);
      case 2:
        return _peopleContent(ringCenter, px, py);
      default:
        return _protectionContent(ringCenter, px, py);
    }
  }

  /// Page 1 — the actual Rakta Bandhan mark as the unmistakable hero,
  /// seated at the ring's own centre so the ring reads as its halo. A
  /// handful of thin red lines and small plain nodes extend from the
  /// ring's own radius outward, hinting at connection/community without
  /// competing with the mark — restrained on purpose, per direction.
  List<Widget> _brandContent(Offset center, double px) {
    final outerRadius = (RingField.baseOuter * px) / 2;
    // Three short stubs only, uneven angles/reach/opacity — a loose hint
    // of connection, not a diagram. Nodes are plain dots, no identity.
    final stubs = [
      (angle: -34.0, reach: 30 * px, node: 5 * px, opacity: 0.34),
      (angle: 148.0, reach: 24 * px, node: 4 * px, opacity: 0.26),
      (angle: 96.0, reach: 34 * px, node: 5 * px, opacity: 0.30),
    ];

    return [
      Positioned.fill(
        child: _stagger(
          begin: 0.35,
          end: 0.85,
          child: CustomPaint(
            painter: _ConnectionStubsPainter(
              center: center,
              outerRadius: outerRadius,
              color: AppColors.primary,
              stubs: stubs,
            ),
          ),
        ),
      ),
      // The mark itself, seated on a white rounded-square card so the
      // asset's own baked-in white margin reads as the card's surface
      // rather than a stray rectangle. Fades in on its own once decoded
      // rather than popping in or showing empty space.
      Positioned(
        left: center.dx,
        top: center.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: AnimatedOpacity(
            opacity: logoReady ? 1 : 0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 132 * px,
              height: 132 * px,
              padding: EdgeInsets.all(18 * px),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28 * px),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryLightTint.withValues(alpha: 0.55), blurRadius: 34 * px, spreadRadius: 2 * px),
                  const BoxShadow(color: AppColors.shadowCard, blurRadius: 16, offset: Offset(0, 8)),
                ],
              ),
              child: logoReady ? const Image(image: _logoImage, fit: BoxFit.contain) : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ];
  }

  /// Page 2 — the need as a filled droplet at centre, compatible groups as
  /// smaller tinted droplets on the ring (Visual Richness Proposal); AB sits
  /// grey because it cannot help.
  List<Widget> _compatibilityContent(Offset center, double px, double py) {
    Widget droplet({required Offset offset, required String label, required bool primary, bool inert = false}) {
      return Positioned(
        left: center.dx + offset.dx,
        top: center.dy + offset.dy,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: _stagger(
            begin: primary ? 0.0 : 0.3,
            end: primary ? 0.55 : 0.85,
            child: BloodGroupDroplet(
              label: label,
              size: primary ? 76 * px : 26 * px,
              filled: true,
              color: inert ? AppColors.dividerWarm : (primary ? AppColors.primary : AppColors.primaryLightTint),
              textColor: inert ? AppColors.textSecondary : (primary ? const Color(0xFFFBE6E8) : AppColors.primary),
              fontSize: primary ? 26 * px : 10 * px,
              serif: primary,
            ),
          ),
        ),
      );
    }

    return [
      droplet(offset: const Offset(0, 0), label: 'O+', primary: true),
      Positioned(
        left: center.dx - 64 * px,
        top: center.dy + 42 * py,
        child: _stagger(
          begin: 0.35,
          end: 0.9,
          child: SizedBox(
            width: 128 * px,
            child: const Text(
              '2 UNITS · URGENT',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      droplet(offset: const Offset(-16, -134), label: 'A+', primary: false),
      droplet(offset: const Offset(-80, -88), label: 'O−', primary: false),
      droplet(offset: const Offset(48, -88), label: 'B+', primary: false),
      droplet(offset: const Offset(-16, 96), label: 'AB', primary: false, inert: true),
    ];
  }

  /// Page 3 — "You" at the centre, real people seated on real ring radii,
  /// size/opacity falling off with distance.
  List<Widget> _peopleContent(Offset center, double px, double py) {
    Widget person({required Offset offset, required String initials, required String group, required bool live, required double size, required double opacity}) {
      return Positioned(
        left: center.dx + offset.dx * px,
        top: center.dy + offset.dy * py,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Opacity(
            opacity: opacity,
            child: _stagger(
              begin: 0.25,
              end: 0.85,
              child: Container(
                width: size * px,
                height: size * px,
                decoration: BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle, boxShadow: const [
                  BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
                ]),
                alignment: Alignment.center,
                child: Text(initials, style: TextStyle(fontSize: size * 0.27 * px, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ),
          ),
        ),
      );
    }

    return [
      Positioned(
        left: center.dx - 7 * px,
        top: center.dy - 7 * px,
        child: Container(
          width: 14 * px,
          height: 14 * px,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        ),
      ),
      person(offset: const Offset(-99, -78), initials: 'RM', group: 'O+', live: true, size: 56, opacity: 1),
      person(offset: const Offset(-4, -101), initials: 'PN', group: 'A−', live: true, size: 48, opacity: 0.92),
      person(offset: const Offset(-85, 93), initials: 'SS', group: 'AB+', live: false, size: 40, opacity: 0.82),
      person(offset: const Offset(79, 104), initials: 'KI', group: 'B+', live: false, size: 34, opacity: 0.5),
    ];
  }

  /// Page 4 — a closed boundary around the lock; distance-only marker cards
  /// with a redaction bar where a name would be.
  List<Widget> _protectionContent(Offset center, double px, double py) {
    Widget card({required Offset offset, required String km, required bool primary}) {
      return Positioned(
        left: center.dx + offset.dx * px,
        top: center.dy + offset.dy * py,
        child: Opacity(
          opacity: primary ? 1 : 0.6,
          child: _stagger(
            begin: 0.3,
            end: 0.85,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 9 * px, vertical: 7 * px),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.cardBorderWarm),
                borderRadius: BorderRadius.circular(12),
                boxShadow: primary ? const [BoxShadow(color: AppColors.shadowCard, blurRadius: 12, offset: Offset(0, 4))] : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (primary)
                    Row(children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.warmGreenText, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 44 * px, height: 7, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                    ])
                  else
                    Container(width: 34 * px, height: 6, decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(4))),
                  SizedBox(height: 6 * px),
                  Text(km, style: TextStyle(fontSize: primary ? 12.5 : 11, fontWeight: FontWeight.w700, color: primary ? AppColors.textPrimaryWarm : AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return [
      Positioned(
        left: center.dx - 42 * px,
        top: center.dy - 42 * px,
        child: Container(
          width: 84 * px,
          height: 84 * px,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: const [
            BoxShadow(color: AppColors.shadowButton, blurRadius: 30, offset: Offset(0, 12)),
          ]),
          alignment: Alignment.center,
          child: Icon(LucideIcons.lock, size: 32 * px, color: AppColors.whiteTextOnPrimary),
        ),
      ),
      card(offset: const Offset(-164, -89), km: '1.8 km', primary: true),
      card(offset: const Offset(52, -96), km: '3.2 km', primary: false),
      card(offset: const Offset(-64, 104), km: '4.6 km', primary: false),
    ];
  }

  /// Horizontal parallax: content drifts at ~40% of the page delta, so it
  /// trails the swipe rather than moving locked to it.
  Widget _parallax({required Widget child}) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, inner) {
        var delta = 0.0;
        if (pageController.hasClients && pageController.position.haveDimensions) {
          delta = (pageController.page ?? index.toDouble()) - index;
        }
        return Transform.translate(offset: Offset(-delta * 46, 0), child: inner);
      },
      child: child,
    );
  }

  Widget _stagger({required Widget child, required double begin, required double end}) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, inner) {
        final raw = ((entry.value - begin) / (end - begin)).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(raw);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: inner));
      },
      child: child,
    );
  }
}

/// Thin red connection-line stubs radiating from the ring's outer radius,
/// each ending in a small plain node — the "hint of a network" behind
/// Page 1's brand mark. Deliberately unlabeled dots, not avatars: nothing
/// here claims to represent a specific person.
class _ConnectionStubsPainter extends CustomPainter {
  final Offset center;
  final double outerRadius;
  final Color color;
  final List<({double angle, double reach, double node, double opacity})> stubs;

  _ConnectionStubsPainter({required this.center, required this.outerRadius, required this.color, required this.stubs});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stub in stubs) {
      final rad = stub.angle * math.pi / 180;
      final from = center + Offset(outerRadius * math.cos(rad), outerRadius * math.sin(rad));
      final to = center + Offset((outerRadius + stub.reach) * math.cos(rad), (outerRadius + stub.reach) * math.sin(rad));
      final linePaint = Paint()
        ..color = color.withValues(alpha: stub.opacity)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(from, to, linePaint);
      canvas.drawCircle(to, stub.node / 2, Paint()..color = color.withValues(alpha: stub.opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionStubsPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.stubs != stubs;
}

/// Circular next action with a restrained press response (0.94 scale).
class _PressableCircle extends StatefulWidget {
  final VoidCallback onTap;
  final Color background;
  final Widget child;

  const _PressableCircle({required this.onTap, required this.background, required this.child});

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
            boxShadow: const [BoxShadow(color: AppColors.shadowButton, blurRadius: 18, offset: Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
