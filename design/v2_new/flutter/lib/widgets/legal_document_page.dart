import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

@immutable
class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

/// Shared scaffold for Terms, Privacy Policy and Data Usage.
///
/// One implementation so the three documents cannot drift apart
/// typographically. Every document currently ships with
/// [isPlaceholder] = true, which renders a visible banner making clear the
/// copy is product-descriptive placeholder text pending legal review — the
/// app must never present unreviewed text as an authoritative policy.
class LegalDocumentPage extends StatelessWidget {
  final String title;
  final String intro;
  final String lastUpdated;
  final List<LegalSection> sections;
  final bool isPlaceholder;

  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.intro,
    required this.lastUpdated,
    required this.sections,
    this.isPlaceholder = true,
  });

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
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryWarm,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.display(fontSize: 24, color: AppColors.textPrimaryWarm)),
                    const SizedBox(height: 6),
                    Text(
                      'Last updated $lastUpdated',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMutedWarm),
                    ),
                    const SizedBox(height: 16),
                    if (isPlaceholder) ...[
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.warmAmberBg,
                          border: Border.all(color: AppColors.warmAmberBorder),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.warmAmberText),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Placeholder content. This text describes how the product works today and has NOT been reviewed or approved by a legal advisor. It is not a binding policy.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warmAmberText,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      intro,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 14,
                            margin: const EdgeInsets.only(top: 3, right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              sections[i].heading,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryWarm,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        sections[i].body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
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
