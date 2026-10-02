import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/contact_actions.dart';
import '../widgets/place_link.dart';
import '../widgets/match_pair.dart';
import 'chat_screen.dart';
import 'donation_confirm_screen.dart';
import '../widgets/rb_icon.dart';

/// Shows the requester's contact info for a request this donor accepted.
/// `createRequest()` denormalizes `requester_name`/`requester_phone` onto
/// the request doc itself at creation time specifically so this screen
/// never needs to read `donors/{requester_uid}` directly — under
/// firestore.rules that doc is owner/admin-only, and the accepting donor
/// is neither.
class MatchContactScreen extends StatefulWidget {
  final String requestId;

  const MatchContactScreen({super.key, required this.requestId});

  @override
  State<MatchContactScreen> createState() => _MatchContactScreenState();
}

class _MatchContactScreenState extends State<MatchContactScreen> {
  bool _markingDonated = false;
  Stream<Map<String, dynamic>?> get _doc => Backend.instance.requestStream(widget.requestId);
  bool _releasing = false;

  /// Donor backs out. The request reopens for other donors instead of
  /// leaving the requester waiting on someone who isn't coming.
  Future<void> _release() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: "Can't make it anymore?",
      message: 'The request goes back to nearby donors so someone else can accept it. Please send a quick message first if you can.',
      confirmLabel: 'Release this request',
      cancelLabel: 'I can still go',
    );
    if (!confirmed || !mounted) return;
    setState(() => _releasing = true);
    try {
      await Backend.instance.releaseMatch(widget.requestId);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Released. The request is open to other donors again.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _releasing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not release this request. Please try again.')));
    }
  }

  Future<void> _markDonated() async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Did you donate for this request?',
      message: 'Confirm only after you have donated. The requester confirms too — once you both have, the donation is recorded and your availability pauses for 90 days.',
      confirmLabel: 'Yes, I donated',
      cancelLabel: 'Not yet',
    );
    if (!confirmed || !mounted) return;
    setState(() => _markingDonated = true);
    try {
      final completed = await Backend.instance.donorConfirmDonation(widget.requestId);
      if (!mounted) return;
      if (completed) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DonationConfirmScreen()));
        return;
      }
      // Recorded; the request completes when the requester confirms too.
      setState(() => _markingDonated = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you. Your confirmation is saved — we’ve asked the requester to confirm too.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingDonated = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_confirmError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientEmberStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.25, -1),
            end: Alignment(0.25, 1),
            colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
            stops: [0, 0.68, 1],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Map<String, dynamic>?>(
            stream: _doc,
            builder: (context, requestSnap) {
              if (requestSnap.hasError) {
                return _centerNote('Couldn’t load this request. Check your connection and go back to try again.');
              }
              if (requestSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onEmberAccent));
              }
              final request = requestSnap.data;
              if (request == null) return _centerNote('This request no longer exists.');
              final bloodGroup = request['blood_group'] as String? ?? '';
              final name = request['requester_name'] as String? ?? 'Requester';
              final first = name.trim().isEmpty ? 'The requester' : name.trim().split(RegExp(r'\s+')).first;
              final requesterUid = request['requester_uid'] as String? ?? '';
              final status = request['status'] as String? ?? 'matched';
              final myUid = Backend.instance.currentUser?.uid;
              final isLive = status == 'matched' && request['matched_donor_id'] == myUid;
              final iConfirmed = request['donor_confirmed_at'] != null;
              final theyConfirmed = request['requester_confirmed_at'] != null;
              final busy = _markingDonated || _releasing;

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const RbIcon(RbGlyph.back, color: AppColors.onEmberStrong),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(child: MatchPair(peerName: name, bloodGroup: bloodGroup)),
                  const SizedBox(height: 8),
                  Text(
                    switch (status) {
                      'cancelled' => 'Request cancelled',
                      'fulfilled' => 'Donation recorded',
                      _ => 'You’re connected',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status == 'matched' ? '$name needs your help' : name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 26, color: AppColors.onEmberStrong, height: 1.2),
                  ),
                  const SizedBox(height: 18),
                  _requestPanel(request, bloodGroup),
                  const SizedBox(height: 18),
                  if (isLive) ...[
                    ContactActions(requestId: widget.requestId, peerUid: requesterUid, peerName: name),
                    const SizedBox(height: 22),
                    _confirmTracker(first: first, iConfirmed: iConfirmed, theyConfirmed: theyConfirmed),
                    const SizedBox(height: 12),
                    if (!iConfirmed)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onEmberStrong,
                          side: const BorderSide(color: AppColors.onEmberOutline),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: busy ? null : _markDonated,
                        icon: _markingDonated
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onEmber))
                            : const RbIcon(RbGlyph.verified, size: 16),
                        label: Text(theyConfirmed ? 'Confirm my donation' : 'I’ve donated — confirm'),
                      ),
                    if (!iConfirmed)
                      TextButton(
                        onPressed: busy ? null : _release,
                        child: Text(_releasing ? 'Releasing…' : 'I can’t make it', style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberFaint)),
                      ),
                  ] else ...[
                    Text(
                      status == 'cancelled'
                          ? '$first no longer needs this donation. Thank you for stepping up.'
                          : 'This match is finished. Your conversation is kept as a record.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.onEmber, side: const BorderSide(color: AppColors.onEmberOutline)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId))),
                      icon: const RbIcon(RbGlyph.message, size: 15),
                      label: const Text('View conversation'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _centerNote(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.onEmberMuted, height: 1.5)),
        ),
      );

  /// What the donor agreed to: group, units, where. The place opens in
  /// Google Maps; coordinates are never printed.
  Widget _requestPanel(Map<String, dynamic> request, String bloodGroup) {
    final units = (request['units_needed'] as num?)?.toInt() ?? 1;
    final urgency = request['urgency'] as String?;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.onEmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.onEmber.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BloodGroupDroplet(label: bloodGroup, size: 36, color: AppColors.brandRed, textColor: AppColors.onEmberStrong, fontSize: 11.5),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    '$units unit${units == 1 ? '' : 's'} of $bloodGroup',
                    if (urgency == 'critical') 'critical' else if (urgency == 'urgent') 'urgent',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.onEmberStrong),
                ),
                const SizedBox(height: 4),
                PlaceLink(
                  label: Backend.shortPlace(request['location_label'] as String?, fallback: 'Location not shared'),
                  lat: (request['lat'] as num?)?.toDouble(),
                  lng: (request['lng'] as num?)?.toDouble(),
                  iconColor: AppColors.onEmberAccent,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Two-sided completion, shown as the two steps it really is.
  Widget _confirmTracker({required String first, required bool iConfirmed, required bool theyConfirmed}) {
    Widget step(String label, bool done) => Expanded(
          child: Row(
            children: [
              RbIcon(done ? RbGlyph.checkCircle : RbGlyph.clock, size: 16, color: done ? AppColors.onEmberSuccess : AppColors.onEmberFaint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: done ? AppColors.onEmberStrong : AppColors.onEmberMuted)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('After the donation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow)),
        const SizedBox(height: 8),
        Row(children: [step('You confirm', iConfirmed), const SizedBox(width: 10), step('$first confirms', theyConfirmed)]),
        const SizedBox(height: 8),
        Text(
          iConfirmed
              ? 'Saved. Waiting for $first to confirm they received it.'
              : theyConfirmed
                  ? '$first confirmed they received your donation. Confirm yours to complete it.'
                  : 'Both of you confirm once the donation is done. Your 90-day rest starts only then.',
          style: TextStyle(fontSize: 12.5, color: theyConfirmed && !iConfirmed ? AppColors.onEmberSuccess : AppColors.onEmberMuted, height: 1.4),
        ),
      ],
    );
  }
}

/// Honest failure text for a confirmation that didn't save.
String _confirmError(Object e) => e is StateError
    ? e.message
    : 'Your confirmation wasn’t saved. Check your connection and try again.';
