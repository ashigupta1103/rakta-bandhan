import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Product-wide ring geometry ("Two corrections carried into the language",
/// Product Art Direction): three concentric circles at a fixed 216 / 152 /
/// 107 diameter ratio (1.42), scaled per product moment — onboarding runs
/// 1.00 / 1.24 / 1.62 / 0.90 across its four pages, Matched sits at 0.90.
/// Centre and scale travel; the 1.42 ratio never does. This widget only
/// draws the rings — callers place it behind their own composition via a
/// [Stack] + [Align] at whatever centre the moment calls for, and seat
/// anything that belongs "on a ring" using [RingField.pointOnRing] so it
/// sits on a real radius rather than floating decoratively.
class RingField extends StatelessWidget {
  static const double baseOuter = 216;
  static const double baseMiddle = 152;
  static const double baseInner = 107;

  /// Design-px-per-390-wide-frame scale for a ring of [diameter] at [scale],
  /// given [px] (screen width / 390) — the radius, in actual screen px, that
  /// a point "on that ring" sits at.
  static double radiusFor(double diameter, double scale, double px) => diameter * scale * px / 2;

  /// A point on a ring of the given actual-px [radius], [angleDegrees]
  /// clockwise from 3 o'clock (SVG/CSS convention).
  static Offset pointOnRing(double radius, double angleDegrees) {
    final rad = angleDegrees * math.pi / 180;
    return Offset(radius * math.cos(rad), radius * math.sin(rad));
  }

  final double scale;
  final double referenceWidth;
  final Color color;
  final double outerOpacity;
  final double middleOpacity;
  final double innerOpacity;
  final bool innerDashed;
  final double strokeWidth;
  /// Soft fill for the middle band (between middle and inner rings) — a
  /// handful of the reference frames seat a faint tinted disc here (e.g.
  /// Onboarding page 4's `rgba(246,220,222,.14)`); optional because most
  /// ring moments are stroke-only.
  final Color? middleFill;

  const RingField({
    super.key,
    this.scale = 1.0,
    this.referenceWidth = 390,
    this.color = AppColors.onEmber,
    this.outerOpacity = 0.55,
    this.middleOpacity = 0.78,
    this.innerOpacity = 1.0,
    this.innerDashed = false,
    this.strokeWidth = 1.0,
    this.middleFill,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final px = constraints.maxWidth / referenceWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            _ring(radiusFor(baseOuter, scale, px) * 2, color.withValues(alpha: outerOpacity), dashed: false),
            if (middleFill != null)
              Container(
                width: radiusFor(baseMiddle, scale, px) * 2,
                height: radiusFor(baseMiddle, scale, px) * 2,
                decoration: BoxDecoration(shape: BoxShape.circle, color: middleFill),
              ),
            _ring(radiusFor(baseMiddle, scale, px) * 2, color.withValues(alpha: middleOpacity), dashed: false),
            _ring(radiusFor(baseInner, scale, px) * 2, color.withValues(alpha: innerOpacity), dashed: innerDashed),
          ],
        );
      },
    );
  }

  Widget _ring(double diameter, Color ringColor, {required bool dashed}) {
    if (!dashed) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: strokeWidth)),
      );
    }
    return CustomPaint(size: Size(diameter, diameter), painter: _DashedCirclePainter(color: ringColor, strokeWidth: strokeWidth));
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final radius = size.width / 2;
    const dashCount = 40;
    const gapFraction = 0.5;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      final sweep = (1 / dashCount) * 2 * math.pi * (1 - gapFraction);
      canvas.drawArc(Rect.fromCircle(center: Offset(radius, radius), radius: radius), startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
