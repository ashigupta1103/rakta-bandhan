import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'blood_group_droplet.dart';

/// "Looking for a donor nearby": a slow radar sweep around the requested
/// blood group. Two faint range rings, one soft sweeping wedge, and a dot
/// for each compatible donor actually counted nearby ([found], capped at
/// four) that brightens as the sweep passes it — nothing is invented: with
/// no count there are no dots. Static under reduced motion.
class RadarSearch extends StatefulWidget {
  final String bloodGroup;
  final int? found;
  final double size;
  final bool searching;

  const RadarSearch({super.key, required this.bloodGroup, this.found, this.size = 220, this.searching = true});

  @override
  State<RadarSearch> createState() => _RadarSearchState();
}

class _RadarSearchState extends State<RadarSearch> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RadarSearch old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.searching && !reduce) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => CustomPaint(painter: _RadarPainter(angle: _sweep.value * 2 * math.pi, dots: (widget.found ?? 0).clamp(0, 4), sweeping: widget.searching)),
            ),
          ),
          Container(
            width: s * 0.34,
            height: s * 0.34,
            decoration: BoxDecoration(color: AppColors.onEmber.withValues(alpha: 0.08), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: BloodGroupDroplet(label: widget.bloodGroup, size: s * 0.2, color: AppColors.brandRed, textColor: AppColors.onEmberStrong, fontSize: s * 0.072, serif: true),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double angle;
  final int dots;
  final bool sweeping;
  _RadarPainter({required this.angle, required this.dots, required this.sweeping});

  // Fixed, irregular spots — a dot's place only says "someone nearby",
  // never where (positions are not locations).
  static const _spots = [(0.62, -2.2), (0.8, -0.7), (0.5, 0.9), (0.86, 2.3)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.onEmber.withValues(alpha: 0.14);
    canvas.drawCircle(c, r * 0.96, ring);
    canvas.drawCircle(c, r * 0.64, ring..color = AppColors.onEmber.withValues(alpha: 0.1));

    if (sweeping) {
      // A soft wedge trailing the leading edge — the only moving thing.
      final rect = Rect.fromCircle(center: c, radius: r * 0.96);
      final wedge = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 2,
          colors: [AppColors.onEmber.withValues(alpha: 0), AppColors.onEmber.withValues(alpha: 0.16)],
          transform: GradientRotation(angle - math.pi / 2),
        ).createShader(rect);
      canvas.drawArc(rect, angle - math.pi / 2, math.pi / 2, true, wedge);
      final edge = Paint()
        ..color = AppColors.onEmber.withValues(alpha: 0.32)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c, c + Offset(math.cos(angle), math.sin(angle)) * r * 0.96, edge);
    }

    for (var i = 0; i < dots; i++) {
      final (dist, a) = _spots[i];
      final p = c + Offset(math.cos(a), math.sin(a)) * r * dist;
      // Brightest just after the sweep passes, fading over the next turn.
      final since = ((angle - a) % (2 * math.pi)) / (2 * math.pi);
      final glow = sweeping ? (1 - since).clamp(0.35, 1.0) : 0.9;
      canvas.drawCircle(p, 9, Paint()..color = AppColors.onEmber.withValues(alpha: 0.12 * glow));
      canvas.drawCircle(p, 4.2, Paint()..color = AppColors.onEmberStrong.withValues(alpha: glow));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.angle != angle || old.dots != dots || old.sweeping != sweeping;
}
