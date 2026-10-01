import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
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
                    IconButton(icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
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
                    if (Firebase.apps.isNotEmpty || Demo.on) ...[
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
                    if (Firebase.apps.isEmpty || Demo.on)
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
          const RbIcon(RbGlyph.eye, size: 13, color: AppColors.goldDeep),
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
        avatarIcon: RbGlyph.community,
      ),
      const SizedBox(height: 12),
      _quoteCard(
        quote: '"I keep my availability on so I show up when someone nearby needs my blood group. Knowing my number is only shared once I actually accept a request made it an easy yes."',
        name: 'Demo Donor 01',
        subtitle: 'Donor · sample content',
        timeAgo: '1 month ago · sample',
        avatarIcon: RbGlyph.droplet,
      ),
      const SizedBox(height: 12),
      _quoteCard(
        quote: '"Our hospital posted an urgent need and had a compatible donor confirmed before the shift changed. Being able to see status update in real time made a stressful night a lot calmer."',
        name: 'Demo Requester 03',
        subtitle: 'Hospital coordinator · sample content',
        timeAgo: '3 weeks ago · sample',
        avatarIcon: RbGlyph.building,
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
        // Sample testimonials exist only inside a client demo session.
        children: Demo.on ? _previewContent() : [_productionEmptyState()],
      );

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
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const _TestimonialSheet(),
      ),
      icon: const RbIcon(RbGlyph.quote, size: 15),
      label: const Text('Add a testimonial'),
    );
  }
}

class _TestimonialSheet extends StatefulWidget {
  const _TestimonialSheet();

  @override
  State<_TestimonialSheet> createState() => _TestimonialSheetState();
}

class _TestimonialSheetState extends State<_TestimonialSheet> {
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
    if (Demo.on) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Demo · nothing was sent. In the app, our team reviews it before it appears.')));
      return;
    }
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your testimonial', style: AppTextStyles.display(fontSize: 21, color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text('A few lines about what Rakta Bandhan meant to you. It is published under your registered name after review.', style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.45)),
          const SizedBox(height: 14),
          TextField(
            controller: _quote,
            minLines: 3,
            maxLines: 6,
            maxLength: 600,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'What happened, and how did it feel?'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _role,
            maxLength: 60,
            decoration: const InputDecoration(hintText: 'Who you are, e.g. “Donor, Adyar” or “Patient’s son”'),
          ),
          // Testimonials are text-only today: there is no photo storage for
          // them, so the area says so instead of pretending to upload.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                RbIcon(RbGlyph.photoOff, size: 18, color: AppColors.ink2),
                SizedBox(width: 10),
                Expanded(child: Text('Photos can’t be added to testimonials yet. Our team may ask you for one when we review it.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4))),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text('I agree to Rakta Bandhan publishing this with my name.', style: TextStyle(fontSize: 13, color: AppColors.ink)),
          ),
          const SizedBox(height: 6),
          ElevatedButton(onPressed: ready ? _send : null, child: Text(_sending ? 'Sending…' : 'Send for review')),
        ],
      ),
    );
  }
}
