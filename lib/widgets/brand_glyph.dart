import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum GlyphTone { red, gold, success, neutral }

/// The app's own icon mount: a line icon seated in the brand droplet (the
/// same tilted-teardrop silhouette as the "Need blood yourself?" CTA),
/// instead of the generic pastel circle every template app uses. The
/// circle-chip-with-icon is the single most "AI-made" repeated shape in
/// the old UI — it reads like an emoji sticker. The droplet ties the icon
/// back to what this app is about.
class BrandGlyph extends StatelessWidget {
  final IconData icon;
  final GlyphTone tone;
  final double size;
  /// Explicit colours override [tone] — for callers (StateCard) that
  /// already carry their own background/foreground pair.
  final Color? background;
  final Color? foreground;

  const BrandGlyph({super.key, required this.icon, this.tone = GlyphTone.red, this.size = 52, this.background, this.foreground});

  (Color, Color) get _colors => switch (tone) {
        GlyphTone.red => (AppColors.red100, AppColors.brandRed),
        GlyphTone.gold => (AppColors.goldTint, AppColors.goldDeep),
        GlyphTone.success => (AppColors.successBg, AppColors.successText),
        GlyphTone.neutral => (AppColors.sand, AppColors.ink2),
      };

  @override
  Widget build(BuildContext context) {
    final (toneBg, toneFg) = _colors;
    final bg = background ?? toneBg;
    final fg = foreground ?? toneFg;
    final r = Radius.circular(size / 2);
    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        // Sharp corner rotated to the top — a droplet, point up.
        angle: math.pi / 4,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(size * 0.08), topRight: r, bottomLeft: r, bottomRight: r),
          ),
          alignment: Alignment.center,
          child: Transform.rotate(angle: -math.pi / 4, child: Icon(icon, size: size * 0.42, color: fg)),
        ),
      ),
    );
  }
}
