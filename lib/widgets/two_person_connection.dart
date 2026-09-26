import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import 'ring_field.dart';

/// The "Matched" emotional-peak composition, shared by Donor Found, Match
/// Contact and Accept Result's success case: the committed ring group at
/// 0.90x recentred on the connection, two avatar discs seated on the
/// middle ring's own radius, joined by a hairline with a small check badge
/// at its centre marking the connection as confirmed/live.
class TwoPersonConnection extends StatelessWidget {
  final String leftLabel;
  final String rightInitials;

  const TwoPersonConnection({super.key, required this.leftLabel, required this.rightInitials});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final px = constraints.maxWidth / 390;
        final ringRadius = RingField.radiusFor(RingField.baseMiddle, 0.90, px);
        // Bug fix: a Stack mixing Positioned children (the two avatars)
        // with non-positioned ones (the hairline, the check badge) sizes
        // itself to its *largest non-positioned child* under loose
        // constraints — here that was the ~140px hairline, not the screen.
        // Both avatars were then positioned correctly against the true
        // width but rendered inside — and clipped by — that shrunk box.
        // Forcing the Stack to the LayoutBuilder's own measured size (and
        // disabling clipping as a safety net) makes it actually fill the
        // space the math already assumed it had.
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RingField(scale: 0.90, referenceWidth: 390, color: AppColors.onEmber, outerOpacity: 0.5, middleOpacity: 0.75, innerOpacity: 1),
              ),
              SizedBox(
                width: ringRadius * 2,
                height: 1,
                child: CustomPaint(painter: _HairlinePainter(color: const Color(0x99FBE6E8))),
              ),
              Container(
                width: 22 * px,
                height: 22 * px,
                decoration: const BoxDecoration(color: AppColors.warmGreenBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(LucideIcons.check, size: 12 * px, color: AppColors.warmGreenText),
              ),
              Positioned(
                left: constraints.maxWidth / 2 - ringRadius - 38 * px,
                child: Container(
                  width: 76 * px,
                  height: 76 * px,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(leftLabel, style: TextStyle(fontSize: 15 * px, fontWeight: FontWeight.w600, color: AppColors.onEmberStrong)),
                ),
              ),
              Positioned(
                left: constraints.maxWidth / 2 + ringRadius - 38 * px,
                child: Container(
                  width: 76 * px,
                  height: 76 * px,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warmPageBackground,
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 26, offset: Offset(0, 10))],
                  ),
                  alignment: Alignment.center,
                  child: Text(rightInitials, style: TextStyle(fontSize: 21 * px, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HairlinePainter extends CustomPainter {
  final Color color;
  const _HairlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), Paint()..color = color..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _HairlinePainter oldDelegate) => oldDelegate.color != color;
}
