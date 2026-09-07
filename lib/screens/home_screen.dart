import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/distance_connector.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/state_card.dart';
import 'create_request_screen.dart';
import 'find_donors_screen.dart';
import 'notifications_screen.dart';
import 'request_detail_screen.dart';

/// Home — rebuilt to the Product Art Direction / Visual Richness Proposal
/// spec: one raised object (the live nearby request, with a face, a group
/// and a distance), everything else on the ground. The old gradient "Need
/// blood, right now?" hero card is gone — it competed with the actual
/// request; creating one's own request is now the quiet link at the bottom.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _position;
  int _donationCount = 0;

  @override
  void initState() {
    super.initState();
    Backend.instance.currentPosition().then((p) {
      if (mounted) setState(() => _position = p);
    });
    Backend.instance.myDonationCount().then((c) {
      if (mounted) setState(() => _donationCount = c);
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: Backend.instance.myDonorDocStream(),
          builder: (context, donorSnap) {
            final donor = donorSnap.data?.data() ?? {};
            final name = donor['name'] as String? ?? '';
            final bloodGroup = donor['blood_group'] as String?;
            final isVerified = donor['is_verified'] as bool? ?? false;
            final isAvailable = donor['is_available'] as bool? ?? false;
            final reactivateAt = (donor['reactivation_scheduled_at'] as Timestamp?)?.toDate();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: AppColors.textSecondary)),
                            Text(
                              name.isEmpty ? 'Welcome' : name.split(' ').first,
                              style: AppTextStyles.display(fontSize: 30, color: AppColors.textPrimaryWarm, height: 1.1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          if (bloodGroup != null && bloodGroup.isNotEmpty) ...[
                            BloodGroupDroplet(label: bloodGroup, size: 34, filled: true, color: AppColors.primaryLightTint, textColor: AppColors.primary, fontSize: 12),
                            const SizedBox(width: 12),
                          ],
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(LucideIcons.bell, size: 21, color: AppColors.textPrimaryWarm),
                                  Positioned(
                                    top: 0,
                                    right: -2,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.warmPageBackground, width: 2))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      PulsingDot(color: isAvailable ? AppColors.warmGreenText : AppColors.textMutedWarm),
                      const SizedBox(width: 7),
                      Text(
                        isAvailable ? 'Available to donate' : 'Not available',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isAvailable ? AppColors.warmGreenText : AppColors.textSecondary),
                      ),
                      Text(isVerified ? ' · verified' : ' · verification pending', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                  Container(height: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.only(top: 20)),
                  const SizedBox(height: 20),
                  const Text('SOMEONE NEEDS YOU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: Backend.instance.openRequestsStream(),
                    builder: (context, snapshot) {
                      final myUid = Backend.instance.currentUser?.uid;
                      final docs = (snapshot.data?.docs ?? []).where((d) => d.data()['requester_uid'] != myUid).toList();
                      // Lazy stand-in for the Blaze-only expireOldRequests
                      // scheduled function — sweep stale docs whenever this
                      // list is rendered (no-op unless genuinely past due).
                      for (final d in docs) {
                        Backend.instance.expireIfStale(d.id, d.data());
                      }

                      if (!snapshot.hasData) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      if (docs.isEmpty) {
                        return StateCard.empty(title: "You're all caught up — no nearby requests right now.");
                      }

                      final doc = docs.first;
                      final request = doc.data();
                      final distance = _position == null
                          ? null
                          : distanceKm(_position!.latitude, _position!.longitude, (request['lat'] as num).toDouble(), (request['lng'] as num).toDouble());
                      final urgency = request['urgency'] as String? ?? 'normal';
                      final isUrgent = urgency != 'normal';
                      final group = request['blood_group'] as String? ?? '';

                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(height: 4, color: isUrgent ? AppColors.primary : AppColors.dividerWarm),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      BloodGroupDroplet(label: group, size: 52, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 20, serif: true),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (isUrgent)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(LucideIcons.flame, size: 13, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(urgency == 'critical' ? 'CRITICAL' : 'URGENT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: AppColors.primary)),
                                                ],
                                              ),
                                            const SizedBox(height: 5),
                                            Text(
                                              (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'Blood request',
                                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text('${request['units_needed'] ?? 1} units · just now', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 15),
                                    padding: const EdgeInsets.only(top: 14),
                                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.dividerWarm))),
                                    child: DistanceConnector(distanceLabel: distance == null ? '—' : '${distance.toStringAsFixed(1)} km'),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailScreen(requestId: doc.id))),
                                    child: const Text('Accept & help'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, color: AppColors.dividerWarm),
                  const SizedBox(height: 20),
                  const Text('YOUR RECORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_donationCount', style: AppTextStyles.display(fontSize: 44, color: AppColors.textPrimaryWarm, height: 0.9)),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            for (var i = 0; i < 5; i++) ...[
                              if (i > 0) const SizedBox(width: 3),
                              BloodGroupDroplet(
                                label: '',
                                size: 16,
                                filled: i < _donationCount,
                                color: i < _donationCount ? AppColors.primary : AppColors.dividerWarm,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reactivateAt != null && !isAvailable
                        ? '${_donationCount == 1 ? 'One life' : '$_donationCount lives'} helped · eligible again in ${_eligibleInDays(reactivateAt)} days'
                        : '${_donationCount == 1 ? 'One life' : '$_donationCount lives'} helped',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 26),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRequestScreen())),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.droplet, size: 14, color: AppColors.primary),
                        SizedBox(width: 7),
                        Text('Need blood yourself?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FindDonorsScreen())),
                    child: const Text('Or browse donors on the map', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _eligibleInDays(DateTime reactivateAt) {
    final remaining = reactivateAt.difference(DateTime.now());
    return remaining.inDays < 0 ? 0 : remaining.inDays + 1;
  }
}
