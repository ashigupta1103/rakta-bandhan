import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Help & support — an accordion FAQ using the same grouped-row component
/// used everywhere else in the app. The OTP-only verification answer is
/// real (it's already how this app's auth works, per backend.dart); every
/// other answer is an explicit placeholder — support contact route and
/// hours are undecided and not invented here, per the design.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expanded = 0;

  static const _faqs = [
    ('How does verification work?', 'We verify your phone number with a one-time code. We never ask for a document, an ID or a blood report.'),
    ('Who can see my number?', 'Placeholder answer — to be supplied.'),
    ('Why am I in a 90-day cooldown?', 'Placeholder answer — to be supplied.'),
    ('How do I change my community name?', 'Placeholder answer — to be supplied.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('Help & support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [Icon(LucideIcons.search, size: 15, color: AppColors.disabledTint), SizedBox(width: 9), Text('Search help', style: TextStyle(fontSize: 14, color: AppColors.disabledTint))]),
                    ),
                    const SizedBox(height: 20),
                    const Text('COMMON QUESTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < _faqs.length; i++)
                            InkWell(
                              onTap: () => setState(() => _expanded = _expanded == i ? null : i),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(border: i < _faqs.length - 1 ? const Border(bottom: BorderSide(color: AppColors.warmDivider)) : null),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(_faqs[i].$1, style: TextStyle(fontSize: 14.5, fontWeight: _expanded == i ? FontWeight.w600 : FontWeight.w500, color: AppColors.textPrimaryWarm))),
                                        Icon(_expanded == i ? LucideIcons.minus : LucideIcons.plus, size: 15, color: AppColors.disabledTint),
                                      ],
                                    ),
                                    if (_expanded == i) ...[
                                      const SizedBox(height: 10),
                                      Text(_faqs[i].$2, style: AppTextStyles.display(fontSize: 15, height: 1.55, color: const Color(0xFF3D2523))),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                      child: const Text(
                        'Answer copy is placeholder apart from the OTP-only fact, which is already true of the build. Support contact route and hours are undecided and not invented here.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
