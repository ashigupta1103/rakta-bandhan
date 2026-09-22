import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One reader component for every legal document — Privacy policy and
/// Terms of use both use this same screen. No clause text is drafted here:
/// real legal copy must be supplied and approved by the Rotary
/// Club/Rakta Bandhan team, so this shows one polished pending-content
/// state rather than placeholder clauses that could be mistaken for a
/// thin real policy.
class LegalReaderScreen extends StatelessWidget {
  final String title;

  const LegalReaderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.fileClock, size: 22, color: AppColors.goldDeep),
                      ),
                      const SizedBox(height: 16),
                      Text(title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 21, color: AppColors.ink, height: 1.2)),
                      const SizedBox(height: 10),
                      const Text(
                        'This document is awaiting approved content.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The final wording must be reviewed and approved by the Rotary Club/Rakta Bandhan team before production release — nothing shown here yet is real legal text.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
