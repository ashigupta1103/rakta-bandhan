import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'community_screen.dart';
import 'word_riddle_screen.dart';
import '../widgets/rb_icon.dart';

/// Real cooldown status — `donors/{uid}`'s `last_donation_date` and
/// `reactivation_scheduled_at` are already written by the existing
/// Backend.markFulfilled(); nothing here is mocked.
class CooldownScreen extends StatelessWidget {
  const CooldownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const Text('Donation recovery', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: Demo.on ? Demo.instance.watch(() => Demo.instance.myProfile) : Backend.instance.myDonorDocStream().map((s) => s.data() ?? {}),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Couldn’t load your recovery details. Check your connection and try again.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final data = snapshot.data!;
                  final reactivateAt = (data['reactivation_scheduled_at'] as Timestamp?)?.toDate();
                  final lastDonation = (data['last_donation_date'] as Timestamp?)?.toDate();
                  final isAvailable = data['is_available'] as bool? ?? true;

                  if (isAvailable || reactivateAt == null) {
                    return _eligibleState();
                  }

                  final remaining = reactivateAt.difference(DateTime.now());
                  final remainingDays = remaining.inDays < 0 ? 0 : remaining.inDays + 1;
                  final totalDays = donorCooldownDays;
                  final elapsedDays = lastDonation == null ? 0 : DateTime.now().difference(lastDonation).inDays;
                  final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);

                  final eligibleOn = _formatDate(reactivateAt);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.warmBorder.withValues(alpha: 0.7)),
                            boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 18, offset: Offset(0, 6))],
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 176,
                                height: 176,
                                child: CustomPaint(
                                  painter: _CooldownRingPainter(progress: progress),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('$remainingDays', style: AppTextStyles.display(fontSize: 44, color: AppColors.textPrimaryWarm, height: 1)),
                                        const SizedBox(height: 2),
                                        Text(remainingDays == 1 ? 'day to go' : 'days to go', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "You've already helped.\nNow let your body recover.",
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display(fontSize: 21, height: 1.25, color: AppColors.textPrimaryWarm),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "We'll turn your availability back on automatically and let you know — you don't have to remember.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                              ),
                              Container(height: 1, color: AppColors.warmDivider, margin: const EdgeInsets.symmetric(vertical: 16)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const RbIcon(RbGlyph.clock, size: 14, color: AppColors.goldDeep),
                                  const SizedBox(width: 8),
                                  Text.rich(
                                    TextSpan(
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      children: [
                                        const TextSpan(text: 'Eligible again on '),
                                        TextSpan(text: eligibleOn, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('While you recover', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WordRiddleScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(12)),
                                  alignment: Alignment.center,
                                  child: const RbIcon(RbGlyph.pen, size: 19, color: AppColors.goldDeep),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Word riddles', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                                      Text('Six short stages about blood and community. Nothing to win.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.chevronMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(12)),
                                  alignment: Alignment.center,
                                  child: const RbIcon(RbGlyph.community, size: 19, color: AppColors.brandRed),
                                ),
                                const SizedBox(width: 13),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Read community stories', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                                      Text('See what other donors have shared', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.chevronMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  Widget _eligibleState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.warmGreenBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const RbIcon(RbGlyph.checkCircle, size: 24, color: AppColors.warmGreenText),
          ),
          const SizedBox(height: 16),
          const Text("You're eligible to donate again", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 8),
          const Text(
            'Your cooldown period is over. Turn your availability back on from Profile whenever you\'re ready.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// The single "90-day arc" ring component the final artifact calls for,
/// replacing the three separate progress systems that previously existed
/// across Cooldown, My Page and Donation history — this is the only one
/// left, drawn with a conic sweep matching the design's ring token.
class _CooldownRingPainter extends CustomPainter {
  final double progress;

  const _CooldownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final trackPaint = Paint()
      ..color = AppColors.dividerWarm
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 6.5, trackPaint);

    final progressPaint = Paint()
      ..color = AppColors.vermilion
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 6.5), startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CooldownRingPainter oldDelegate) => oldDelegate.progress != progress;
}
