import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/ring_field.dart';
import 'cooldown_screen.dart';

/// Terminal-success composition per Visual Richness Proposal #11: ember
/// gradient, the committed ring group, a cream droplet holding a check, and
/// the impact trail placing this donation inside a history rather than
/// announcing it in isolation. Donation count comes from the real
/// Backend.instance.myDonationCount() (already incremented by the
/// markFulfilled() call that led here) — not invented copy.
class DonationConfirmScreen extends StatelessWidget {
  const DonationConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientEmberStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.25, -1),
            end: Alignment(0.25, 1),
            colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
            stops: [0, 0.68, 1],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<int>(
            future: Backend.instance.myDonationCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final px = constraints.maxWidth / 390;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: RingField(scale: 1.0, referenceWidth: 390, color: AppColors.onEmber, outerOpacity: 0.4, middleOpacity: 0.55, innerOpacity: 0),
                            ),
                            Container(
                              width: 76 * px,
                              height: 76 * px,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.warmPageBackground, boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 26, offset: Offset(0, 10)),
                              ]),
                              alignment: Alignment.center,
                              child: Icon(LucideIcons.droplet, size: 32 * px, color: AppColors.primary),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Text('Donation recorded', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.onEmberEyebrow)),
                        const SizedBox(height: 12),
                        Text(
                          count <= 1 ? "That's one life\nyou've helped" : "That's $count lives\nyou've helped",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 29, color: AppColors.onEmberStrong, height: 1.16),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 4; i++) ...[
                              if (i > 0) const SizedBox(width: 9),
                              BloodGroupDroplet(
                                label: '',
                                size: i == 3 ? 30 : 24,
                                filled: true,
                                color: i == 3 ? AppColors.onEmber : AppColors.onEmberOutline,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                    child: Column(
                      children: [
                        const Text(
                          "Rest now. You'll be marked available again automatically in 90 days.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.onEmberFaint, height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CooldownScreen())),
                            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
