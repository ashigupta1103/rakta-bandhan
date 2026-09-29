import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import 'brand_glyph.dart';

/// Shared icon + message (+ optional action) card for empty/error/permission
/// states — the prototype repeats this exact shape across map, notifications,
/// requests, and the offline Welcome screen.
class StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StateCard({
    super.key,
    required this.icon,
    required this.title,
    this.iconBackground = AppColors.cardBorderWarm,
    this.iconColor = AppColors.textMuted,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  factory StateCard.empty({required String title, IconData icon = LucideIcons.checkCircle}) => StateCard(
        icon: icon,
        title: title,
        iconBackground: AppColors.statusAvailableBg,
        iconColor: AppColors.statusAvailableText,
      );

  factory StateCard.error({required String title, String? message, VoidCallback? onRetry}) => StateCard(
        icon: LucideIcons.wifiOff,
        title: title,
        message: message,
        iconBackground: AppColors.primaryLightTint,
        iconColor: AppColors.primary,
        actionLabel: onRetry == null ? null : 'Retry',
        onAction: onRetry,
      );

  factory StateCard.permission({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) =>
      StateCard(
        icon: LucideIcons.mapPin,
        title: title,
        message: message,
        iconBackground: AppColors.primaryLightTint,
        iconColor: AppColors.primary,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandGlyph(icon: icon, size: 56, background: iconBackground, foreground: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}
