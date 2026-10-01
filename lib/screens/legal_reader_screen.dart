import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../legal/legal_config.dart';
import '../legal/legal_documents.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/pressable.dart';

/// One reader for every legal document (Privacy policy, Terms of use).
///
/// Reading order, designed for someone who will only skim: title and
/// dates → a draft banner until counsel signs off (kLegalApproved) →
/// "In short", the five lines that actually matter → a numbered contents
/// list that jumps to a section → the full text, set like a document
/// (serif section heads, 15px/1.6 body, dash bullets) rather than a stack
/// of cards → who to contact → a link to the sibling document.
class LegalReaderScreen extends StatefulWidget {
  final String title;

  const LegalReaderScreen({super.key, required this.title});

  const LegalReaderScreen.privacy({super.key}) : title = 'Privacy policy';
  const LegalReaderScreen.terms({super.key}) : title = 'Terms of use';
  const LegalReaderScreen.guidelines({super.key}) : title = 'Community guidelines';

  LegalDocument get document => switch (title.toLowerCase()) {
        final t when t.startsWith('terms') => termsOfUse,
        final t when t.startsWith('community') => communityGuidelines,
        _ => privacyPolicy,
      };

  @override
  State<LegalReaderScreen> createState() => _LegalReaderScreenState();
}

class _LegalReaderScreenState extends State<LegalReaderScreen> {
  final _scroll = ScrollController();
  late final Map<String, GlobalKey> _keys = {for (final s in widget.document.sections) s.id: GlobalKey()};
  bool _scrolledPastTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final past = _scroll.offset > 80;
      if (past != _scrolledPastTitle) setState(() => _scrolledPastTitle = past);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Scrollable.ensureVisible(
      ctx,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final isPrivacy = identical(doc, privacyPolicy);
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Title only fades into the bar once the big title has scrolled away.
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.warmPageBackground,
                border: Border(bottom: BorderSide(color: _scrolledPastTitle ? AppColors.warmDivider : Colors.transparent)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  AnimatedOpacity(
                    opacity: _scrolledPastTitle ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Text(doc.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rakta Bandhan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandRed)),
                    const SizedBox(height: 6),
                    Text(doc.title, style: AppTextStyles.display(fontSize: 34, color: AppColors.ink, height: 1.1)),
                    const SizedBox(height: 10),
                    const Text(
                      'Version $kLegalVersion · Effective $kLegalEffectiveDate',
                      style: TextStyle(fontSize: 12.5, color: AppColors.ink2, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    if (!kLegalApproved) ...[
                      const SizedBox(height: 16),
                      const _DraftBanner(),
                    ],
                    const SizedBox(height: 20),
                    Text(doc.intro, style: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.6)),
                    const SizedBox(height: 22),
                    _InShort(points: doc.summary),
                    const SizedBox(height: 28),
                    const Text('Contents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < doc.sections.length; i++)
                      _ContentsRow(index: i + 1, label: doc.sections[i].heading, onTap: () => _jumpTo(doc.sections[i].id)),
                    const SizedBox(height: 12),
                    for (var i = 0; i < doc.sections.length; i++)
                      _Section(key: _keys[doc.sections[i].id], index: i + 1, section: doc.sections[i]),
                    const SizedBox(height: 32),
                    const _ContactCard(),
                    const SizedBox(height: 16),
                    Pressable(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => isPrivacy ? const LegalReaderScreen.terms() : const LegalReaderScreen.privacy()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(isPrivacy ? LucideIcons.fileText : LucideIcons.shield, size: 17, color: AppColors.ink2),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(isPrivacy ? 'Read the Terms of use' : 'Read the Privacy policy', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                            ),
                            const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.chevronMuted),
                          ],
                        ),
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

class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.goldTint2)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.fileClock, size: 15, color: AppColors.goldDeep)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Draft awaiting legal review. It describes how the app works today, but is not yet the final, approved policy.',
                style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.45),
              ),
            ),
          ],
        ),
      );
}

class _InShort extends StatelessWidget {
  final List<String> points;
  const _InShort({required this.points});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warmBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In short', style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
            const SizedBox(height: 6),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.check, size: 15, color: AppColors.brandRed)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _ContentsRow extends StatelessWidget {
  final int index;
  final String label;
  final VoidCallback onTap;
  const _ContentsRow({required this.index, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.mutedInk, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, color: AppColors.ink))),
              const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.chevronMuted),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  final int index;
  final LegalSection section;
  const _Section({super.key, required this.index, required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: AppColors.warmDivider),
          const SizedBox(height: 22),
          Text(
            index.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandRed, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(section.heading, style: AppTextStyles.display(fontSize: 22, color: AppColors.ink, height: 1.2)),
          const SizedBox(height: 10),
          for (final line in section.body)
            if (line.startsWith('- '))
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 8, height: 1.5, margin: const EdgeInsets.only(top: 11, right: 11), color: AppColors.brandRed),
                    Expanded(child: Text(line.substring(2), style: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.6))),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(line, style: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.6)),
              ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final hasContact = kLegalContactEmail.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions, requests or complaints', style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
          const SizedBox(height: 8),
          const Text('$kLegalEntity · $kLegalCity', style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.5)),
          if (kGrievanceOfficerName.isNotEmpty)
            const Text('Grievance Officer: $kGrievanceOfficerName', style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.5)),
          const SizedBox(height: 4),
          Text(
            hasContact
                ? 'Email $kLegalContactEmail. We reply within 30 days, and sooner for account or safety issues.'
                : 'A contact address and Grievance Officer will be listed here before public launch.',
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.5),
          ),
        ],
      ),
    );
  }
}
