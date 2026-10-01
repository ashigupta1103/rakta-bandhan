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
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _nearbyOpen;
  String? _nearbyKey;

  /// Open requests near the donor's registered area, rebuilt only when that
  /// area changes — not on every profile update.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _nearbyFor(double? lat, double? lng) {
    if (lat == null || lng == null) return Stream.value(const []);
    final key = '$lat,$lng';
    if (key != _nearbyKey || _nearbyOpen == null) {
      _nearbyKey = key;
      _nearbyOpen = Backend.instance.openRequestsNearStream(lat, lng);
    }
    return _nearbyOpen!;
  }

  static int _urgencyRank(String? u) => switch (u) { 'critical' => 0, 'urgent' => 1, _ => 2 };

  @override
  void initState() {
    super.initState();
    Backend.instance.preciseLocation().then((p) {
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
                            Text(_greeting(), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.textSecondary)),
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
                  const Text('Someone needs you', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _nearbyFor((donor['lat'] as num?)?.toDouble(), (donor['lng'] as num?)?.toDouble()),
                    builder: (context, snapshot) {
                      final myUid = Backend.instance.currentUser?.uid;
                      final canGiveTo = bloodGroup == null ? const <String>[] : Backend.instance.compatibleRecipientGroups(bloodGroup);
                      final myLat = _position?.latitude ?? (donor['lat'] as num?)?.toDouble();
                      final myLng = _position?.longitude ?? (donor['lng'] as num?)?.toDouble();
                      double kmTo(Map<String, dynamic> r) => myLat == null || myLng == null
                          ? 0
                          : distanceKm(myLat, myLng, (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
                      // Only requests this donor can actually give to, most
                      // urgent first, then nearest.
                      final docs = (snapshot.data ?? const [])
                          .where((d) => d.data()['requester_uid'] != myUid && canGiveTo.contains(d.data()['blood_group']))
                          .toList()
                        ..sort((a, b) {
                          final byUrgency = _urgencyRank(a.data()['urgency'] as String?).compareTo(_urgencyRank(b.data()['urgency'] as String?));
                          return byUrgency != 0 ? byUrgency : kmTo(a.data()).compareTo(kmTo(b.data()));
                        });
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
                      final distance = myLat == null ? null : kmTo(request);
                      final createdAt = (request['created_at'] as Timestamp?)?.toDate();
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
                                      BloodGroupDroplet(label: group, size: 52, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 20, serif: true),
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
                                                  Text(urgency == 'critical' ? 'Critical' : 'Urgent', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.primary)),
                                                ],
                                              ),
                                            const SizedBox(height: 5),
                                            Text(
                                              Backend.shortPlace(request['location_label'] as String?, fallback: 'Blood request'),
                                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text('${request['units_needed'] ?? 1} ${request['units_needed'] == 1 ? 'unit' : 'units'} · ${_ago(createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  const Text('Your record', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.textSecondary)),
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

  String _ago(DateTime? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  int _eligibleInDays(DateTime reactivateAt) {
    final remaining = reactivateAt.difference(DateTime.now());
    return remaining.inDays < 0 ? 0 : remaining.inDays + 1;
  }
}
