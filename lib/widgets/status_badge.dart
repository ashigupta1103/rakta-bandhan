import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Blood-group / status pill badge — shared across Home, Requests, Find
/// donors, Donor details, Admin so badge styling doesn't drift per screen.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double radius;

  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.textColor,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
    this.radius = 8,
  });

  factory StatusBadge.bloodGroup(String group) => StatusBadge(
        label: group,
        background: AppColors.primaryLightTint,
        textColor: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  /// The full-radius status pill from the final artifact's component
  /// specimens ("Status, pulse, connector") — the five states a request or
  /// donor card carries: critical / urgent / normal / matched / pending.
  factory StatusBadge.pill(String state) {
    final (bg, fg, label) = switch (state) {
      'critical' => (AppColors.red100, AppColors.red700, 'Critical'),
      'urgent' => (AppColors.orangeTint, AppColors.orangeDeep, 'Urgent'),
      'matched' => (AppColors.successBg, AppColors.successText, 'Matched'),
      'pending' => (AppColors.goldTint, AppColors.goldDeep, 'Pending'),
      _ => (AppColors.sand, AppColors.ink2, 'Normal'),
    };
    return StatusBadge(label: label, background: bg, textColor: fg, fontSize: 12, fontWeight: FontWeight.w600, radius: 999);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: textColor)),
    );
  }
}

/// Corner-ribbon "URGENT" tag. Must be used inside a Stack — anchors itself
/// to the top-right corner via Positioned.
class UrgentRibbon extends StatelessWidget {
  final String label;

  const UrgentRibbon({super.key, this.label = 'URGENT'});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -1,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const BoxDecoration(
          color: AppColors.gradientHeroEnd,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.whiteTextOnPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
