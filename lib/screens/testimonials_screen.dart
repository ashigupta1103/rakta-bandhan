import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/state_card.dart';
import '../widgets/rb_icon.dart';

/// Testimonials — curated and verified by Rakta Bandhan, distinct from the
/// anonymous-handle Community stories feed. Real quotes are published by an
/// admin from the console's Content tab into `testimonials`, a collection
/// only an admin can write (see firestore.rules) — that admin-only write
/// path is what makes "curated and verified" structural rather than a
/// claim. Until one is published the page shows an honest empty state.
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
                    IconButton(
                      tooltip: 'Back',icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
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
                    if (Firebase.apps.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _ShareTestimonialButton(),
                      const SizedBox(height: 6),
                      const Text(
                        'For people who have donated or received blood through Rakta Bandhan. Our team reviews every testimonial before it appears.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // No Firebase app (widget tests, or an init failure) means
                    // no stream to build — fall back rather than throw on
                    // FirebaseFirestore.instance.
                    if (Firebase.apps.isEmpty)
                      _productionEmptyState()
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: Backend.instance.testimonialsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
                          }
                          final docs = snapshot.data?.docs ?? const [];
                          if (docs.isEmpty) return _productionEmptyState();
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

  Widget _publishedCard(Map<String, dynamic> data) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    return _quoteCard(
      quote: '"${data['quote'] as String? ?? ''}"',
      name: data['name'] as String? ?? '',
      subtitle: (data['role'] as String?)?.trim().isNotEmpty == true ? data['role'] as String : 'Rakta Bandhan community',
      timeAgo: created == null ? '' : _timeAgo(created),
      avatarIcon: RbGlyph.quote,
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
        icon: RbGlyph.quote,
      ),
    );
  }

  Widget _quoteCard({required String quote, required String name, required String subtitle, required String timeAgo, required RbGlyph avatarIcon}) {
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
              Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.goldTint, shape: BoxShape.circle), alignment: Alignment.center, child: RbIcon(avatarIcon, size: 15, color: AppColors.goldDeep)),
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

/// "Share your testimonial" — a member offers a quote for this page. It is
/// published only after an admin reviews it, and only with the member's
/// explicit consent to use their name.
class _ShareTestimonialButton extends StatelessWidget {
  const _ShareTestimonialButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const TestimonialSheet(),
      ),
      icon: const RbIcon(RbGlyph.quote, size: 15),
      label: const Text('Add a testimonial'),
    );
  }
}

@visibleForTesting
class TestimonialSheet extends StatefulWidget {
  const TestimonialSheet({super.key});

  @override
  State<TestimonialSheet> createState() => _TestimonialSheetState();
}

class _TestimonialSheetState extends State<TestimonialSheet> {
  final _quote = TextEditingController();
  final _role = TextEditingController();
  bool _consent = false;
  bool _sending = false;

  @override
  void dispose() {
    _quote.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await Backend.instance.submitTestimonial(quote: _quote.text, role: _role.text);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Thank you! Our team will review it before it appears here.')));
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not send it. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final length = _quote.text.trim().length;
    final ready = length >= 10 && length <= 600 && _consent && !_sending;
    Widget fieldLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
        );
    // Scrolls as one piece, lifts above the keyboard, and keeps the button
    // clear of Android's navigation bar.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your testimonial', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'A few lines about what Rakta Bandhan meant to you. It is published under your registered name after review.',
              style: TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.45),
            ),
            const SizedBox(height: 20),
            fieldLabel('Your experience'),
            TextField(
              controller: _quote,
              minLines: 3,
              maxLines: 6,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'What happened, and how did it feel?'),
            ),
            const SizedBox(height: 12),
            fieldLabel('About you'),
            TextField(
              controller: _role,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. “Donor, Adyar” or “Patient’s son”'),
            ),
            const SizedBox(height: 12),
            // Testimonials are text-only today: there is no photo storage for
            // them, so the area says so instead of pretending to upload.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: EdgeInsets.only(top: 1), child: RbIcon(RbGlyph.photoOff, size: 18, color: AppColors.ink2)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photos can’t be added to testimonials yet. Our team may ask you for one when we review it.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              checked: _consent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _consent = !_consent),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _consent,
                          activeColor: AppColors.brandRed,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) => setState(() => _consent = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('I agree to Rakta Bandhan publishing this with my name.', style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(onPressed: ready ? _send : null, child: Text(_sending ? 'Sending…' : 'Send for review')),
            ),
          ],
        ),
      ),
    );
  }
}
