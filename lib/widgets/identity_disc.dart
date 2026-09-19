import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'blood_group_droplet.dart';
import 'pulsing_dot.dart';

/// The shared identity-disc component from the final artifact's component
/// specimens ("Droplet & identity disc"): an initials circle tinted red for
/// a private identity or gold for a public/community one, with an optional
/// blood-group droplet badge at the corner (shown only when that donor has
/// opted to expose their group) and an optional live-availability dot.
///
/// Wraps [BloodGroupDroplet] and [PulsingDot] rather than redrawing either,
/// so the droplet shape and the live pulse stay the single implementation
/// used everywhere else.
class IdentityDisc extends StatelessWidget {
  final String initials;
  final double size;
  final bool isPublic;
  final String? bloodGroup;
  final bool showAvailabilityDot;
  final bool isAvailable;

  const IdentityDisc({
    super.key,
    required this.initials,
    this.size = 48,
    this.isPublic = false,
    this.bloodGroup,
    this.showAvailabilityDot = false,
    this.isAvailable = false,
  });

  Color get _background => isPublic ? AppColors.goldTint : AppColors.red200;
  Color get _foreground => isPublic ? AppColors.goldDeep : AppColors.red700;

  @override
  Widget build(BuildContext context) {
    final dropletSize = size * 0.42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: _background, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w600, color: _foreground),
            ),
          ),
          if (bloodGroup != null && bloodGroup!.isNotEmpty)
            Positioned(
              right: -dropletSize * 0.18,
              bottom: -dropletSize * 0.1,
              child: Container(
                padding: EdgeInsets.all(size * 0.04),
                decoration: BoxDecoration(color: AppColors.warmGround, shape: BoxShape.circle),
                child: BloodGroupDroplet(
                  label: bloodGroup!,
                  size: dropletSize,
                  filled: true,
                  color: AppColors.brandRed,
                  textColor: AppColors.whiteTextOnPrimary,
                  fontSize: dropletSize * 0.34,
                ),
              ),
            ),
          if (showAvailabilityDot)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: AppColors.warmGround, shape: BoxShape.circle),
                child: PulsingDot(color: isAvailable ? AppColors.successText : AppColors.mutedInk, size: size * 0.2),
              ),
            ),
        ],
      ),
    );
  }
}
