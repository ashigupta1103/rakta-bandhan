import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/place_link.dart';
import '../widgets/rb_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/identity_disc.dart';
import '../widgets/step_tracker.dart';
import 'call_screen.dart';
import 'cancel_confirm_screen.dart';
import 'chat_screen.dart';
import 'create_experience_screen.dart';
import 'testimonials_screen.dart';
import 'create_request_screen.dart';
import '../widgets/rb_icon.dart';

/// Real request-status timeline. Watches the actual Firestore request
/// document created by CreateRequestScreen directly (same pattern already
/// used elsewhere in this codebase, e.g. requests_screen.dart) — not a mock.
/// Status here can genuinely change if another donor accepts/fulfils it
/// through the existing real Backend flows. The tracker card is the one
/// raised object on the ground plane — no gradient hero above it, per the
/// final artifact ("the gradient hero card the redesign removed from Home
/// is retired here too").
class TrackingScreen extends StatefulWidget {
  final String requestId;

  const TrackingScreen({super.key, required this.requestId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _cancelling = false;
  bool _confirming = false;
  Stream<Map<String, dynamic>?> get _doc => Backend.instance.requestStream(widget.requestId);

  /// Requester's half of the two-sided completion ("I received it").
  Future<void> _confirmReceived(String donorName) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Did $donorName donate?',
      message: 'Confirm once the donation has happened at the hospital or blood bank. The request is marked completed when you both confirm.',
      confirmLabel: 'Yes, donation received',
      cancelLabel: 'Not yet',
    );
    if (!confirmed || !mounted) return;
    setState(() => _confirming = true);
    try {
      final closed = await Backend.instance.requesterConfirmDonation(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(closed ? 'Donation completed. Thank you for using Rakta Bandhan.' : 'Thanks. We’ve asked $donorName to confirm as well.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_confirmError(e))));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Cancel this request?',
      message: 'Donors will stop seeing it, and a donor who already accepted will be told it was cancelled.',
      confirmLabel: 'Cancel request',
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Backend.instance.cancelRequest(widget.requestId);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CancelConfirmScreen(requestId: widget.requestId)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel this request. Please try again.')));
    }
  }

  Future<void> _call(Map<String, dynamic> request) async {
    final me = (await Backend.instance.myDonorDoc()).data();
    if (!mounted) return;
    await startCallFlow(
      context,
      requestId: widget.requestId,
      peerUid: request['matched_donor_id'] as String? ?? '',
      peerName: request['matched_donor_name'] as String? ?? 'Your donor',
      myName: me?['name'] as String? ?? 'Rakta Bandhan user',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your request', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _doc,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  RbStatePanel.error(
                    title: 'Couldn’t load your request',
                    message: 'Check your connection and try again.',
                    onRetry: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: widget.requestId))),
                  ),
                ],
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) return const RbLoading(height: 240);
            final data = snapshot.data;
            if (data == null) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [RbStatePanel(icon: RbGlyph.search, title: 'Request not found', message: 'It may have been removed. Your other requests are on the Requests tab.')],
              );
            }
            Backend.instance.expireIfStale(widget.requestId, data);
            final status = data['status'] as String? ?? 'open';
            final bloodGroup = data['blood_group'] as String? ?? '';
            final units = data['units_needed'] ?? 1;
            final urgency = data['urgency'] as String? ?? 'normal';
            final location = (data['location_label'] as String?)?.isNotEmpty == true ? data['location_label'] as String : 'Blood request';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();
            final donorName = data['matched_donor_name'] as String?;
            final donorConfirmed = data['donor_confirmed_at'] != null;
            final iConfirmed = data['requester_confirmed_at'] != null;

            final isMatched = status == 'matched' || status == 'fulfilled';
            final isFulfilled = status == 'fulfilled';
            final isTerminalBad = status == 'cancelled' || status == 'expired';
            final canCancel = status == 'open' || status == 'matched';

            final steps = [
              const TrackerStep(label: 'Submitted', sub: 'Request created', status: StepStatus.done, icon: RbGlyph.send),
              TrackerStep(
                label: 'Searching',
                sub: isTerminalBad ? (status == 'cancelled' ? 'Cancelled before a donor accepted' : 'No donor accepted in time') : (isMatched ? 'Compatible donors nearby were alerted' : 'Alerting compatible donors nearby'),
                status: isTerminalBad ? StepStatus.pending : (isMatched ? StepStatus.done : StepStatus.current),
                icon: RbGlyph.radar,
              ),
              TrackerStep(
                label: 'Donor accepted',
                sub: isMatched ? '${donorName ?? 'A donor'} accepted · message or call in the app' : 'Waiting for a donor to accept',
                status: isTerminalBad ? StepStatus.pending : (isFulfilled ? StepStatus.done : (isMatched ? StepStatus.current : StepStatus.pending)),
                icon: RbGlyph.connect,
              ),
              TrackerStep(
                label: 'Donation completed',
                sub: isFulfilled
                    ? 'Donation completed — thank you'
                    : iConfirmed
                        ? 'You confirmed · waiting for ${donorName ?? 'the donor'}'
                        : donorConfirmed
                            ? '${donorName ?? 'The donor'} says they donated · please confirm'
                            : 'Completed once you and the donor both confirm',
                status: isFulfilled ? StepStatus.done : StepStatus.pending,
                icon: RbGlyph.checkCircle,
              ),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BloodGroupDroplet(label: bloodGroup, size: 48, filled: true, color: AppColors.brandRed, textColor: AppColors.whiteTextOnPrimary, fontSize: 16, serif: true),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlaceLink(label: Backend.shortPlace(location, fallback: 'Blood request'), lat: (data['lat'] as num?)?.toDouble(), lng: (data['lng'] as num?)?.toDouble(), style: AppTextStyles.display(fontSize: 22, color: AppColors.ink, height: 1.2)),
                            const SizedBox(height: 3),
                            Text(
                              '$units ${units == 1 ? 'unit' : 'units'} · $urgency${createdAt == null ? '' : ' · raised ${_timeAgo(createdAt)}'}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: _statusPill(status)),
                  const SizedBox(height: 22),
                  RbCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: StepTracker(steps: steps),
                  ),
                  if (isMatched && donorName != null) ...[
                    const RbSectionLabel('Your donor'),
                    RbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IdentityDisc(initials: _initials(donorName), size: 44, isPublic: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(donorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
                                    Text(
                                      isFulfilled ? 'Donated for this request' : (donorConfirmed ? 'Says they have donated' : 'Accepted your request'),
                                      style: const TextStyle(fontSize: 13, color: AppColors.ink2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId))),
                                  icon: const RbIcon(RbGlyph.message, size: 16),
                                  label: const Text('Message'),
                                ),
                              ),
                              if (status == 'matched') ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _call(data),
                                    icon: const RbIcon(RbGlyph.phone, size: 16),
                                    label: const Text('Call in app'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'matched' && donorName != null && !iConfirmed) ...[
                    const SizedBox(height: 12),
                    if (donorConfirmed)
                      ElevatedButton.icon(
                        onPressed: _confirming ? null : () => _confirmReceived(donorName),
                        icon: _confirming
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const RbIcon(RbGlyph.verified, size: 16),
                        label: const Text('Confirm donation received'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _confirming ? null : () => _confirmReceived(donorName),
                        icon: _confirming
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const RbIcon(RbGlyph.verified, size: 16),
                        label: const Text('Mark donation received'),
                      ),
                  ],
                  if (isFulfilled) ...[
                    const SizedBox(height: 16),
                    RbCard(
                      color: AppColors.successBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const RbIcon(RbGlyph.heart, size: 26, color: AppColors.successText),
                          const SizedBox(height: 10),
                          Text('Donation received', style: AppTextStyles.display(fontSize: 21, color: AppColors.ink)),
                          const SizedBox(height: 4),
                          Text(
                            'You and ${donorName ?? 'your donor'} both confirmed it. If you’d like, tell others what this meant to you.',
                            style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.45),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestimonialsScreen())),
                            icon: const RbIcon(RbGlyph.quote, size: 16),
                            label: const Text('Add a testimonial'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateExperienceScreen())),
                            icon: const RbIcon(RbGlyph.pen, size: 16),
                            label: const Text('Share in Community'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                            child: const Text('Go home'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isTerminalBad) ...[
                    const SizedBox(height: 14),
                    RbCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const RbIcon(RbGlyph.alert, size: 15, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              status == 'cancelled'
                                  ? 'You cancelled this request.'
                                  : 'No donor was found in time — matching stopped. You can create a new request.',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CreateRequestScreen())),
                      child: const Text('Create a new request'),
                    ),
                  ] else if (canCancel) ...[
                    const RbSectionLabel('If something changes'),
                    RbListGroup(
                      children: [
                        RbRow(
                          icon: RbGlyph.closeCircle,
                          destructive: true,
                          title: _cancelling ? 'Cancelling…' : 'Cancel this request',
                          subtitle: 'Donors stop seeing it straight away',
                          onTap: _cancelling ? null : _cancel,
                          trailing: _cancelling ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// One unmistakable word for where the request is.
  Widget _statusPill(String status) => switch (status) {
        'open' => const RbChip('Searching for a donor', icon: RbGlyph.radar, tone: RbTone.orange),
        'matched' => const RbChip('Donor accepted', icon: RbGlyph.connect, tone: RbTone.red),
        'fulfilled' => const RbChip('Completed', icon: RbGlyph.checkCircle, tone: RbTone.success),
        'cancelled' => const RbChip('Cancelled', icon: RbGlyph.closeCircle, tone: RbTone.neutral),
        'expired' => const RbChip('Expired', icon: RbGlyph.hourglass, tone: RbTone.neutral),
        _ => RbChip(status),
      };

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return initialsOf(trimmed);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Honest failure text for a confirmation that didn't save.
String _confirmError(Object e) => e is StateError
    ? e.message
    : 'Your confirmation wasn’t saved. Check your connection and try again.';
