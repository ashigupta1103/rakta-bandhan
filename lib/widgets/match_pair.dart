import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'blood_group_droplet.dart';
import 'rb_ui.dart';

/// Two people matched for a donation: "You" and the other person's disc,
/// side by side and slightly overlapping, with the blood group seated
/// between them. Replaces the old ring-and-line network diagram.
/// Drawn for the ember field.
class MatchPair extends StatelessWidget {
  final String peerName;
  final String bloodGroup;
  final double size;

  const MatchPair({super.key, required this.peerName, required this.bloodGroup, this.size = 88});

  @override
  Widget build(BuildContext context) {
    Widget disc(Widget child, Color bg) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.emberFieldStart, width: 4),
          ),
          alignment: Alignment.center,
          child: child,
        );
    return SizedBox(
      width: size * 2 - size * 0.18,
      height: size + size * 0.32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: disc(Text('You', style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w600, color: AppColors.onEmberStrong)), AppColors.onEmber.withValues(alpha: 0.16)),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: disc(
              Text(RbAvatar.initialsOf(peerName), style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
              AppColors.goldTint,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: AppColors.emberFieldStart, shape: BoxShape.circle),
              child: BloodGroupDroplet(label: bloodGroup, size: size * 0.38, color: AppColors.brandRed, textColor: AppColors.onEmberStrong, fontSize: size * 0.13, serif: true),
            ),
          ),
        ],
      ),
    );
  }
}
