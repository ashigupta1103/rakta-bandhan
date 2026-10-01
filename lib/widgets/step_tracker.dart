import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'rb_icon.dart';

enum StepStatus { done, current, pending }

class TrackerStep {
  final String label;
  final String sub;
  final StepStatus status;
  final RbGlyph icon;

  const TrackerStep({
    required this.label,
    required this.sub,
    required this.status,
    this.icon = RbGlyph.clock,
  });
}

/// Vertical step list with connecting line — Request tracking screen's
/// done/current/pending progress indicator.
class StepTracker extends StatelessWidget {
  final List<TrackerStep> steps;

  const StepTracker({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) _buildStep(steps[i], i < steps.length - 1),
      ],
    );
  }

  Widget _buildStep(TrackerStep step, bool showLine) {
    late final Widget circle;
    switch (step.status) {
      case StepStatus.done:
        circle = Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: AppColors.statusAvailableText, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const RbIcon(RbGlyph.check, size: 14, color: Colors.white),
        );
      case StepStatus.current:
        circle = Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primaryLightTint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: RbIcon(step.icon, size: 13, color: AppColors.primary),
        );
      case StepStatus.pending:
        circle = Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.cardBorderWarm, width: 2)),
          alignment: Alignment.center,
          child: RbIcon(step.icon, size: 13, color: AppColors.borderStrong),
        );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              circle,
              if (showLine)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.status == StepStatus.done ? AppColors.statusAvailableText : AppColors.cardBorderWarm,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  const SizedBox(height: 2),
                  Text(step.sub, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
