import 'package:flutter/material.dart';

/// Dashed rounded-rect outline — Flutter's `Border` has no dashed style
/// built in, and the design uses `border: 1px dashed` in a few places
/// (the Request tab's "Need blood yourself?" CTA, Community's photo slot).
/// Wrap a plain `Container` (no border of its own) in a `CustomPaint` using
/// this painter rather than duplicating the dash-drawing logic per screen.
class DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const DashedRRectPainter({required this.color, required this.radius, this.strokeWidth = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      const dashLength = 4.0;
      const gapLength = 3.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
}
