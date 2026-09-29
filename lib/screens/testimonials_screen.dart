import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../preview_mode.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/state_card.dart';

/// Testimonials — curated and verified by Rakta Bandhan, distinct from the
/// anonymous-handle Community stories feed. Real quotes are published by an
/// admin from the console's Content tab into `testimonials`, a collection
/// only an admin can write (see firestore.rules) — that admin-only write
/// path is what makes "curated and verified" structural rather than a
/// claim. Until one is published the page shows an honest empty state; in
/// preview builds, clearly-fictional samples stand in for the layout, with
/// one subtle "Preview data" tag for the whole section.
class TestimonialsScreen extends StatelessWidget {
  const TestimonialsScreen({super.key});

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
                    const Text('Testimonials', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stories we\'ve been given permission to tell', style: AppTextStyles.display(fontSize: 25, color: AppColors.ink, height: 1.25)),
                    const SizedBox(height: 8),
                    const Text('Curated and verified by Rakta Bandhan. Member stories live in Community.', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                    const SizedBox(height: 20),
                    // No Firebase app (widget tests, or an init failure) means
                    // no stream to build — fall back rather than throw on
                    // FirebaseFirestore.instance.
                    if (Firebase.apps.isEmpty)
                      _fallbackContent()
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: Backend.instance.testimonialsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
                          }
                          final docs = snapshot.data?.docs ?? const [];
                          // Samples only stand in while nothing real is
                          // published — a preview build with real
                          // testimonials shows the real ones.
                          if (docs.isEmpty) return _fallbackContent();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final doc in docs) ...[
                                _publishedCard(doc.data()),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
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

  List<Widget> _previewContent() {
    return [
      Row(
        children: [
          const Icon(LucideIcons.eye, size: 13, color: AppColors.goldDeep),
          const SizedBox(width: 6),
          const Text('Preview data — sample layout, not real testimonials', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.goldDeep)),
        ],
      ),
      const SizedBox(height: 14),
      _quoteCard(
        quote: '"I got a call within twenty minutes of raising a request for my father. The app showed me exactly who accepted and how to reach them — I didn\'t have to call a single stranger myself."',
        name: 'Demo Recipient 02',
        subtitle: 'Requester · sample content',
        timeAgo: '2 weeks ago · sample',
        avatarIcon: LucideIcons.heartHandshake,
      ),
      const SizedBox(height: 12),
      _quoteCard(
        quote: '"I keep my availability on so I show up when someone nearby needs my blood group. Knowing my number is only shared once I actually accept a request made it an easy yes."',
        name: 'Demo Donor 01',
        subtitle: 'Donor · sample content',
        timeAgo: '1 month ago · sample',
        avatarIcon: LucideIcons.droplet,
      ),
      const SizedBox(height: 12),
      _quoteCard(
        quote: '"Our hospital posted an urgent need and had a compatible donor confirmed before the shift changed. Being able to see status update in real time made a stressful night a lot calmer."',
        name: 'Demo Requester 03',
        subtitle: 'Hospital coordinator · sample content',
        timeAgo: '3 weeks ago · sample',
        avatarIcon: LucideIcons.building2,
      ),
      const SizedBox(height: 10),
      const Text(
        'These cards are fictional sample content for demonstrating the layout — not real people, and not written by or attributed to any real donor, recipient or partner.',
        style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint, height: 1.4),
      ),
    ];
  }

  /// Shown when nothing is published yet (or there is no backend to ask).
  Widget _fallbackContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kEnablePreviewUi ? _previewContent() : [_productionEmptyState()],
      );

  Widget _publishedCard(Map<String, dynamic> data) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    return _quoteCard(
      quote: '"${data['quote'] as String? ?? ''}"',
      name: data['name'] as String? ?? '',
      subtitle: (data['role'] as String?)?.trim().isNotEmpty == true ? data['role'] as String : 'Rakta Bandhan community',
      timeAgo: created == null ? '' : _timeAgo(created),
      avatarIcon: LucideIcons.quote,
    );
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    return months < 12 ? '${months}mo ago' : '${(months / 12).floor()}y ago';
  }

  Widget _productionEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: StateCard.empty(
        title: 'Approved testimonials will appear here',
        icon: LucideIcons.quote,
      ),
    );
  }

  Widget _quoteCard({required String quote, required String name, required String subtitle, required String timeAgo, required IconData avatarIcon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quote, style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.55)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(avatarIcon, size: 15, color: AppColors.goldDeep)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                  ],
                ),
              ),
              Text(timeAgo, style: const TextStyle(fontSize: 10.5, color: AppColors.disabledTint)),
            ],
          ),
        ],
      ),
    );
  }
}
