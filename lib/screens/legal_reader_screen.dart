import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One reader component for every legal document — Privacy policy and
/// Terms of use both use this same screen with different content, per the
/// final artifact ("One component, two documents"). Clause text is an
/// explicit placeholder; real legal copy must be supplied and approved.
class LegalReaderScreen extends StatelessWidget {
  final String title;
  final List<(String heading, String body)> sections;

  const LegalReaderScreen({super.key, required this.title, required this.sections});

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
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.display(fontSize: 21, color: AppColors.ink, height: 1.2)),
                      const SizedBox(height: 4),
                      const Text('Last updated — to be supplied', style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
                      Container(height: 1, color: AppColors.warmDivider, margin: const EdgeInsets.symmetric(vertical: 14)),
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        Text('${i + 1} · ${sections[i].$1}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.goldDeep)),
                        const SizedBox(height: 7),
                        Text(sections[i].$2, style: AppTextStyles.display(fontSize: 15.5, color: const Color(0xFF3D2523), height: 1.65)),
                      ],
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

const kPrivacyPolicySections = <(String, String)>[
  ('WHAT WE COLLECT', 'Placeholder clause text. Legal copy must be supplied and approved — none is drafted here.'),
  ('HOW WE USE IT', 'Placeholder clause text.'),
];

const kTermsOfUseSections = <(String, String)>[
  ('ACCEPTANCE OF TERMS', 'Placeholder clause text. Legal copy must be supplied and approved — none is drafted here.'),
  ('USE OF THE SERVICE', 'Placeholder clause text.'),
];
