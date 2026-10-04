import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Words from people who have donated or received blood through Rakta Bandhan. Our team reads each one before it appears.',
                      style: TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.45),
                    ),
                    // No Firebase app (widget tests, or an init failure) means
                    // no stream to build — fall back rather than throw on
                    // FirebaseFirestore.instance.
                    if (Firebase.apps.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const _ShareTestimonialButton(),
                    ],
                    const SizedBox(height: 18),
                    if (Firebase.apps.isEmpty)
                      _emptyState()
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: Backend.instance.testimonialsStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData && !snapshot.hasError) {
                            return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
                          }
                          final docs = snapshot.data?.docs ?? const [];
                          if (docs.isEmpty) return _emptyState();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final doc in docs) _publishedCard(doc.data()),
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

  /// A real testimonial, set as a quotation: opening and closing marks, the
  /// words, then the public @username. Never the registered name.
  Widget _publishedCard(Map<String, dynamic> data) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    final username = (data['username'] as String?)?.trim();
    final role = (data['role'] as String?)?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mark('“'),
          Text(data['quote'] as String? ?? '', style: AppTextStyles.display(fontSize: 18, color: AppColors.ink, height: 1.5)),
          Align(alignment: Alignment.centerRight, child: _mark('”')),
          const SizedBox(height: 2),
          Text(
            '— ${username != null && username.isNotEmpty ? '@$username' : 'Rakta Bandhan community'}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
          ),
          if ((role != null && role.isNotEmpty) || created != null)
            Text(
              [if (role != null && role.isNotEmpty) role, if (created != null) _timeAgo(created)].join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
        ],
      ),
    );
  }

  static Widget _mark(String glyph) => Text(glyph, style: AppTextStyles.display(fontSize: 44, color: AppColors.red300, height: 0.9));

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    return months < 12 ? '${months}mo ago' : '${(months / 12).floor()}y ago';
  }

  /// Editorial empty state: the quotation marks are the visual.
  Widget _emptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mark('“'),
        Text('No testimonials yet', style: AppTextStyles.display(fontSize: 21, color: AppColors.ink)),
        const SizedBox(height: 6),
        const Text(
          'Your story could be the first one shared with the community.',
          style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink2),
        ),
        Align(alignment: Alignment.centerRight, child: _mark('”')),
      ],
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
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: AppColors.brandRed,
        side: const BorderSide(color: AppColors.red300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
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
    final ready = length >= 1 && length <= 600 && _consent && !_sending;
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
            Text('Your testimonial', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'Share a few words about your experience. It is shown under your @username after our team has read it.',
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
              decoration: const InputDecoration(hintText: 'For example: Rakta Bandhan helped me find a donor.'),
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
                          child: Text('I agree to Rakta Bandhan publishing this with my @username.', style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4)),
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
