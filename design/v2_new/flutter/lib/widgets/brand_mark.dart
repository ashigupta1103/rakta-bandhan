import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

/// The animated Rakta Bandhan mark: concentric hairline rings expanding
/// behind a droplet.
///
/// Shared by the launch screen and onboarding page 1 so the mark behaves
/// identically in both. The parent owns the controller and passes
/// `progress` (0 = unstarted, 1 = settled) — this widget holds no state,
/// which keeps it cheap to embed inside an AnimatedBuilder.
///
/// Ring geometry intentionally mirrors GradientHeroCard's ring treatment so
/// the motif reads as one system across launch, onboarding, hero cards and
/// the matching screen.
class BrandMark extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;

  const BrandMark({
    super.key,
    required this.progress,
    this.size = 132,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ExpandingRingsPainter(progress: t, color: color),
          ),
          Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: Icon(LucideIcons.droplet, size: size * 0.32, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandingRingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ExpandingRingsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Three rings, each starting slightly later than the last.
    const stagger = [0.0, 0.18, 0.36];
    for (var i = 0; i < stagger.length; i++) {
      final local = ((progress - stagger[i]) / (1 - stagger[i])).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final radius = maxRadius * (0.34 + 0.66 * eased) * (0.62 + 0.19 * i);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.30 * (1 - eased * 0.72))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpandingRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
