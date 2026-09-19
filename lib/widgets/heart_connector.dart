import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import 'identity_disc.dart';

/// The "AG ── ♡ ── RD" connector from the Donor-found moment: two identity
/// discs joined by a hairline that resolves into a heart at the midpoint.
/// Used by donor_found_screen.dart and match_contact_screen.dart.
class HeartConnector extends StatelessWidget {
  final String leftInitials;
  final String rightInitials;
  final bool leftIsPublic;
  final bool rightIsPublic;
  final String? rightBloodGroup;
  final double discSize;

  const HeartConnector({
    super.key,
    required this.leftInitials,
    required this.rightInitials,
    this.leftIsPublic = false,
    this.rightIsPublic = true,
    this.rightBloodGroup,
    this.discSize = 68,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IdentityDisc(initials: leftInitials, size: discSize, isPublic: leftIsPublic),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 1.6, color: AppColors.gold.withValues(alpha: 0.55)),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.warmGround, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.heart, size: 16, color: AppColors.gold),
              ),
            ],
          ),
        ),
        IdentityDisc(
          initials: rightInitials,
          size: discSize,
          isPublic: rightIsPublic,
          bloodGroup: rightBloodGroup,
        ),
      ],
    );
  }
}
