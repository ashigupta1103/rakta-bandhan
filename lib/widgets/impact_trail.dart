import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'blood_group_droplet.dart';

/// "Impact trail — one horizon, everywhere" from the final artifact's
/// component library: a real donation count against a fixed 10-unit
/// horizon, filled droplets for units given and hollow ones for the rest.
/// The same instance is used on My Page and Donation history so the
/// "three different progress systems" the design doc calls out collapses
/// into one.
class ImpactTrail extends StatelessWidget {
  final int count;
  final double numberFontSize;
  final double dropletSize;
  final int milestone;
  final String caption;

  const ImpactTrail({
    super.key,
    required this.count,
    required this.caption,
    this.numberFontSize = 48,
    this.dropletSize = 18,
    this.milestone = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$count', style: AppTextStyles.display(fontSize: numberFontSize, color: AppColors.textPrimaryWarm, height: 0.88)),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var i = 0; i < milestone; i++)
                      BloodGroupDroplet(label: '', size: dropletSize, filled: i < count, color: i < count ? AppColors.primary : AppColors.dividerWarm),
                  ],
                ),
                const SizedBox(height: 8),
                Text(caption, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
