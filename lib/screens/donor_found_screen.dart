import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/heart_connector.dart';
import 'tracking_screen.dart';

class _MatchedDonor {
  final String name;
  final String initials;
  final String bloodGroup;
  final bool isVerified;
  final double? distanceKm;
  final int donationCount;

  const _MatchedDonor({
    required this.name,
    required this.initials,
    required this.bloodGroup,
    required this.isVerified,
    required this.distanceKm,
    required this.donationCount,
  });
}

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
}

/// The Donor Accepted emotional-peak screen, final approved composition:
/// two identity discs joined by the single Heart Connector, no ring field,
/// no radar. Every value shown — donor name, blood group, verification,
/// distance, donation count — is read from the real matched request and
/// the real `donors_public` document; nothing here is a mock donor.
class DonorFoundScreen extends StatelessWidget {
  final String requestId;

  const DonorFoundScreen({super.key, required this.requestId});

  void _goHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<_MatchedDonor?> _load() async {
    final requestSnap = await FirebaseFirestore.instance.collection('requests').doc(requestId).get();
    final request = requestSnap.data();
    if (request == null) return null;
    final donorId = request['matched_donor_id'] as String?;
    final donorName = request['matched_donor_name'] as String? ?? 'Your donor';
    if (donorId == null) return null;

    final donorSnap = await FirebaseFirestore.instance.collection('donors_public').doc(donorId).get();
    final donor = donorSnap.data() ?? {};
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final isVerified = donor['is_verified'] as bool? ?? false;

    double? distance;
    final reqLat = (request['lat'] as num?)?.toDouble();
    final reqLng = (request['lng'] as num?)?.toDouble();
    final donorLat = (donor['lat'] as num?)?.toDouble();
    final donorLng = (donor['lng'] as num?)?.toDouble();
    if (reqLat != null && reqLng != null && donorLat != null && donorLng != null) {
      distance = distanceKm(reqLat, reqLng, donorLat, donorLng);
    }

    final fulfilledCount = await FirebaseFirestore.instance
        .collection('requests')
        .where('matched_donor_id', isEqualTo: donorId)
        .where('status', isEqualTo: 'fulfilled')
        .count()
        .get();

    return _MatchedDonor(
      name: donorName,
      initials: _initialsOf(donorName),
      bloodGroup: bloodGroup,
      isVerified: isVerified,
      distanceKm: distance,
      donationCount: fulfilledCount.count ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A050B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.4, -0.9),
            radius: 1.5,
            colors: [Color(0xFF8C1420), Color(0xFF5C0C14), Color(0xFF3A050B)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_MatchedDonor?>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
              }
              final donor = snapshot.data;
              if (donor == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text('This match could not be loaded.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                  ),
                );
              }
              return _DonorAcceptedBody(requestId: requestId, donor: donor, onHome: () => _goHome(context));
            },
          ),
        ),
      ),
    );
  }
}

class _DonorAcceptedBody extends StatefulWidget {
  final String requestId;
  final _MatchedDonor donor;
  final VoidCallback onHome;

  const _DonorAcceptedBody({required this.requestId, required this.donor, required this.onHome});

  @override
  State<_DonorAcceptedBody> createState() => _DonorAcceptedBodyState();
}

class _DonorAcceptedBodyState extends State<_DonorAcceptedBody> {
  // The accepting donor's own explicit "Accept & help" action is the
  // consent already given to be reachable on a critical request — there is
  // no persisted per-request consent field in the schema to gate a second
  // time, and this phase does not add one. Actually dialling needs a
  // telephony launcher this project doesn't yet depend on (no url_launcher
  // precedent anywhere in the codebase), so — like every other not-yet-wired
  // action in this app — it surfaces honestly rather than pretending to
  // place a call.
  void _requestCall() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling from the app — coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final donor = widget.donor;
    final firstName = donor.name.split(RegExp(r'\s+')).first;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).get(),
      builder: (context, reqSnap) {
        final urgency = reqSnap.data?.data()?['urgency'] as String? ?? 'normal';
        final location = (reqSnap.data?.data()?['location_label'] as String?)?.isNotEmpty == true
            ? reqSnap.data!.data()!['location_label'] as String
            : null;
        final canCall = urgency == 'critical';

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: widget.onHome),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    HeartConnector(
                      leftInitials: 'You',
                      rightInitials: donor.initials,
                      leftIsPublic: false,
                      rightIsPublic: true,
                      rightBloodGroup: donor.bloodGroup,
                      discSize: 68,
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                      decoration: BoxDecoration(color: const Color(0xFF26421A), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(color: Color(0xFF33A63F), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Icon(Icons.check, size: 13, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Text('A DONOR ACCEPTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFFEFE6DC))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.display(fontSize: 40, height: 1.08),
                        children: [
                          TextSpan(text: '$firstName is\n', style: const TextStyle(color: Color(0xFFFDF6F0))),
                          const TextSpan(text: 'on the way', style: TextStyle(color: Color(0xFFF26A61))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          [
                            if (donor.bloodGroup.isNotEmpty) donor.bloodGroup,
                            if (donor.distanceKm != null) '${donor.distanceKm!.toStringAsFixed(1)} km${location != null ? ' from $location' : ''}',
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15.5, color: Color(0xFFFDF6F0)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${donor.isVerified ? 'Verified donor' : 'Donor'} · ${donor.donationCount} donation${donor.donationCount == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4)),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Column(
                children: [
                  if (canCall)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDFAF6), foregroundColor: AppColors.brandRed, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _requestCall,
                        icon: const Icon(LucideIcons.phone, size: 18),
                        label: Text('Call $firstName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrackingScreen(requestId: widget.requestId))),
                    child: const Text('Track this request', style: TextStyle(fontSize: 14.5, color: Color(0xFFE9BFC4), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
