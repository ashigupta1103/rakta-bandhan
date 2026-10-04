import 'package:flutter/material.dart';

import '../screens/main_navigation_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The user's confirmed-donation count with one line of context. The only
/// number shown is the real count — no units, people helped or milestones,
/// which the data doesn't provide. A small rail marks "the start of a
/// journey": hollow at zero, filled once there is a donation.
class DonationJourney extends StatelessWidget {
  final int count;
  final String message;

  const DonationJourney({super.key, required this.count, required this.message});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: count > 0 ? AppColors.brandRed : Colors.transparent,
                    border: Border.all(color: AppColors.brandRed, width: 2),
                  ),
                ),
                Expanded(child: Container(width: 2, margin: const EdgeInsets.only(top: 4), color: AppColors.dividerWarm)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$count', style: AppTextStyles.display(fontSize: 36, color: AppColors.textPrimaryWarm, height: 1.1)),
                    const SizedBox(width: 8),
                    Text(count == 1 ? 'donation' : 'donations', style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact secondary action to the main app (where open requests are listed).
class SeeWhoNeedsHelpButton extends StatelessWidget {
  const SeeWhoNeedsHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: AppColors.brandRed,
        side: const BorderSide(color: AppColors.red300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onPressed: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      ),
      child: const Text('See who needs help'),
    );
  }
}
