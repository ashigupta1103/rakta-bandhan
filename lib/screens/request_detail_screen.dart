import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/loading_button.dart';
import 'accept_result_screen.dart';

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hour(s) ago';
  return '${diff.inDays} day(s) ago';
}

/// Request details + Accept. The "single active match" rule the prototype
/// enforces (blocked/claimed outcomes) isn't implemented in backend.dart —
/// it's checked here with a plain read query against the existing
/// `requests` collection, not a new backend capability.
class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Position? _position;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    Backend.instance.currentPosition().then((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<String?> _findExistingActiveMatch() async {
    final myUid = Backend.instance.currentUser?.uid;
    final snap = await FirebaseFirestore.instance
        .collection('requests')
        .where('matched_donor_id', isEqualTo: myUid)
        .where('status', isEqualTo: 'matched')
        .get();
    final other = snap.docs.where((d) => d.id != widget.requestId);
    return other.isEmpty ? null : other.first.id;
  }

  Future<void> _handleAccept() async {
    setState(() => _isAccepting = true);
    final activeMatchId = await _findExistingActiveMatch();
    if (activeMatchId != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AcceptResultScreen(outcome: AcceptOutcome.blocked, activeRequestId: activeMatchId),
        ),
      );
      setState(() => _isAccepting = false);
      return;
    }

    try {
      await Backend.instance.acceptRequest(widget.requestId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AcceptResultScreen(outcome: AcceptOutcome.success, activeRequestId: widget.requestId)),
      );
    } on RequestAlreadyClaimedException {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AcceptResultScreen(outcome: AcceptOutcome.claimed)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not accept. Please try again.')));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

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
        title: const Text('Request details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
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
            final urgency = data['urgency'] as String? ?? 'normal';
            final units = data['units_needed'] ?? 1;
            final location = (data['location_label'] as String?)?.isNotEmpty == true ? data['location_label'] as String : 'Blood request';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            final distance = (_position != null && lat != null && lng != null)
                ? '${distanceKm(_position!.latitude, _position!.longitude, lat, lng).toStringAsFixed(1)} km away'
                : '—';

            if (status != 'open') {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    switch (status) {
                      'matched' => 'This request has already been matched with a donor.',
                      'fulfilled' => 'This request has already been fulfilled. Thank you to everyone who helped.',
                      'cancelled' => 'This request was cancelled by the requester.',
                      'expired' => 'This request has expired.',
                      _ => 'This request is no longer open.',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return FutureBuilder<String?>(
              future: _findExistingActiveMatch(),
              builder: (context, matchSnap) {
                final blocked = matchSnap.data != null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.cardBorderWarm),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 14, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                BloodGroupDroplet(label: bloodGroup, size: 44, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 15, serif: true),
                                const SizedBox(width: 10),
                                if (urgency != 'normal')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(color: AppColors.gradientHeroEnd, borderRadius: BorderRadius.circular(9)),
                                    child: Text(
                                      urgency == 'critical' ? 'Critical' : 'Urgent',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.whiteTextOnPrimary),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(location, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              children: [
                                _metaChip(LucideIcons.mapPin, distance),
                                _metaChip(LucideIcons.hourglass, '$units unit(s)'),
                                _metaChip(LucideIcons.clock, createdAt == null ? '—' : _timeAgo(createdAt)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (blocked) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(color: AppColors.warmAmberBg, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.warmAmberText),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'You already have an active match — finish or cancel it before accepting another request.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF7A4A08), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      LoadingButton(
                        label: 'Accept & help',
                        isLoading: _isAccepting,
                        onPressed: blocked ? null : _handleAccept,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
