import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_hero_card.dart';
import '../widgets/step_tracker.dart';
import 'create_request_screen.dart';

/// Real request-status timeline. Watches the actual Firestore request
/// document created by CreateRequestScreen directly (same pattern already
/// used elsewhere in this codebase, e.g. requests_screen.dart) — not a mock.
/// Status here can genuinely change if another donor accepts/fulfils it
/// through the existing real Backend flows.
class TrackingScreen extends StatelessWidget {
  final String requestId;

  const TrackingScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return const Center(child: Text('Request not found.', style: TextStyle(color: AppColors.textSecondary)));
            }
            Backend.instance.expireIfStale(requestId, data);
            final status = data['status'] as String? ?? 'open';
            final bloodGroup = data['blood_group'] as String? ?? '';
            final location = (data['location_label'] as String?)?.isNotEmpty == true ? data['location_label'] as String : 'Blood request';

            final isMatched = status == 'matched' || status == 'fulfilled';
            final isFulfilled = status == 'fulfilled';
            final isTerminalBad = status == 'cancelled' || status == 'expired';

            final steps = [
              const TrackerStep(label: 'Submitted', sub: 'Request created', status: StepStatus.done, icon: LucideIcons.send),
              TrackerStep(
                label: 'Finding donor',
                sub: isTerminalBad ? (status == 'cancelled' ? 'Cancelled before a match was found' : 'No donor found in time') : (isMatched ? 'Donor found' : 'Searching nearby donors'),
                status: isTerminalBad ? StepStatus.pending : (isMatched ? StepStatus.done : StepStatus.current),
                icon: LucideIcons.search,
              ),
              TrackerStep(
                label: 'Matched',
                sub: isMatched ? '${data['matched_donor_name'] ?? 'A donor'} accepted your request' : 'Waiting for a donor to accept',
                status: isTerminalBad ? StepStatus.pending : (isFulfilled ? StepStatus.done : (isMatched ? StepStatus.current : StepStatus.pending)),
                icon: LucideIcons.handshake,
              ),
              TrackerStep(
                label: 'Fulfilled',
                sub: isFulfilled ? 'Donation completed — thank you' : 'Marked once the donor confirms',
                status: isFulfilled ? StepStatus.done : StepStatus.pending,
                icon: LucideIcons.checkCircle,
              ),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradientHeroCard(
                    showRing: false,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(16),
                    shadowColor: AppColors.shadowHero,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.whiteTextOnPrimary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
                          child: Text(bloodGroup, style: const TextStyle(color: AppColors.whiteTextOnPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFFF9F5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.cardBorderWarm),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: StepTracker(steps: steps),
                  ),
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
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
