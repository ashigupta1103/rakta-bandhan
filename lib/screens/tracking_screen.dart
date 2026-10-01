import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/identity_disc.dart';
import '../widgets/step_tracker.dart';
import 'call_screen.dart';
import 'cancel_confirm_screen.dart';
import 'chat_screen.dart';
import 'create_request_screen.dart';

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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this request. Please try again.')));
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
      peerPhone: request['matched_donor_phone'] as String? ?? '',
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
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your request', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return const Center(child: Text('Request not found.', style: TextStyle(color: AppColors.textSecondary)));
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
              const TrackerStep(label: 'Submitted', sub: 'Request created', status: StepStatus.done, icon: LucideIcons.send),
              TrackerStep(
                label: 'Donor found',
                sub: isTerminalBad ? (status == 'cancelled' ? 'Cancelled before a match was found' : 'No donor found in time') : (isMatched ? '${donorName ?? 'A donor'} accepted' : 'Searching nearby donors'),
                status: isTerminalBad ? StepStatus.pending : (isMatched ? StepStatus.done : StepStatus.current),
                icon: LucideIcons.search,
              ),
              TrackerStep(
                label: 'Matched',
                sub: isMatched ? '${donorName ?? 'A donor'} accepted your request' : 'Waiting for a donor to accept',
                status: isTerminalBad ? StepStatus.pending : (isFulfilled ? StepStatus.done : (isMatched ? StepStatus.current : StepStatus.pending)),
                icon: LucideIcons.handshake,
              ),
              TrackerStep(
                label: 'Completed',
                sub: isFulfilled
                    ? 'Donation completed — thank you'
                    : iConfirmed
                        ? 'You confirmed · waiting for ${donorName ?? 'the donor'}'
                        : donorConfirmed
                            ? '${donorName ?? 'The donor'} says they donated · please confirm'
                            : 'Completed once you and the donor both confirm',
                status: isFulfilled ? StepStatus.done : StepStatus.pending,
                icon: LucideIcons.checkCircle,
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
                            Text(Backend.shortPlace(location, fallback: 'Blood request'), style: AppTextStyles.display(fontSize: 22, color: AppColors.ink, height: 1.2)),
                            const SizedBox(height: 3),
                            Text(
                              '$units unit(s) · $urgency${createdAt == null ? '' : ' · raised ${_timeAgo(createdAt)}'}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.ink2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))],
                    ),
                    child: StepTracker(steps: steps),
                  ),
                  if (isMatched && donorName != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          IdentityDisc(initials: _initials(donorName), size: 40, isPublic: true),
                          const SizedBox(width: 12),
                          Expanded(child: Text(donorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))),
                          IconButton(
                            tooltip: 'Message',
                            icon: const Icon(LucideIcons.messageSquare, size: 18, color: AppColors.ink),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId))),
                          ),
                          if (status == 'matched')
                            IconButton(
                              tooltip: 'Voice call',
                              style: IconButton.styleFrom(backgroundColor: AppColors.brandRed),
                              icon: const Icon(LucideIcons.phone, size: 16, color: Colors.white),
                              onPressed: () => _call(data),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'matched' && donorName != null && !iConfirmed) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _confirming ? null : () => _confirmReceived(donorName),
                      icon: _confirming
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.checkCircle, size: 16),
                      label: Text(donorConfirmed ? 'Confirm donation received' : 'Mark donation received'),
                    ),
                  ],
                  if (isTerminalBad) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const Icon(LucideIcons.alertTriangle, size: 15, color: AppColors.textSecondary),
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
                    const SizedBox(height: 20),
                    const Text('If something changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: _cancelling ? null : _cancel,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Text(
                                _cancelling ? 'Cancelling…' : 'Cancel this request',
                                style: const TextStyle(fontSize: 14, color: AppColors.red700, fontWeight: FontWeight.w600),
                              ),
                              if (_cancelling) ...[
                                const SizedBox(width: 10),
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              ],
                            ],
                          ),
                        ),
                      ),
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

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
