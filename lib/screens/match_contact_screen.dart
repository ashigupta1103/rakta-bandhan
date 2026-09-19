import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/heart_connector.dart';
import 'donation_confirm_screen.dart';

/// Shows the requester's contact info for a request this donor accepted.
/// The requester's name/phone aren't stored on the request doc itself
/// (backend.dart's createRequest() never writes them there) — but since
/// every requester is also a registered donor, their real name/phone are
/// read from their own `donors/{requester_uid}` doc. Real data, composed
/// from two existing reads; no schema change, no mock identity needed.
///
/// A normal-urgency request never exposes the requester's phone number —
/// the donor stays in-app. A critical request's number is masked until the
/// donor explicitly taps to reveal it (there is no persisted per-request
/// consent field to gate on instead, since that would mean changing the
/// Firestore schema, which this phase does not do).
class MatchContactScreen extends StatefulWidget {
  final String requestId;

  const MatchContactScreen({super.key, required this.requestId});

  @override
  State<MatchContactScreen> createState() => _MatchContactScreenState();
}

class _MatchContactScreenState extends State<MatchContactScreen> {
  bool _markingDonated = false;
  bool _numberRevealed = false;

  void _placeholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon.')));
  }

  Future<void> _markDonated() async {
    setState(() => _markingDonated = true);
    try {
      await Backend.instance.markFulfilled(widget.requestId);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DonationConfirmScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingDonated = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this request. Please try again.')));
    }
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
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).get(),
            builder: (context, requestSnap) {
              if (!requestSnap.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
              }
              final request = requestSnap.data!.data();
              if (request == null) {
                return const Center(child: Text('Request not found.', style: TextStyle(color: Colors.white70)));
              }
              final requesterUid = request['requester_uid'] as String?;
              final bloodGroup = request['blood_group'] as String? ?? '';
              final urgency = request['urgency'] as String? ?? 'normal';
              final isCritical = urgency == 'critical';
              final location = (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'the requester';

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: requesterUid == null ? null : FirebaseFirestore.instance.collection('donors').doc(requesterUid).get(),
                builder: (context, donorSnap) {
                  final requesterData = donorSnap.data?.data() ?? {};
                  final name = requesterData['name'] as String? ?? 'Requester';
                  final phone = requesterData['phone'] as String? ?? '—';
                  final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

                  return Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              // "You" is the donor here, so the donor role
                              // (public/gold) sits on the left and the
                              // requester (private/burgundy) on the right —
                              // the same two roles as Donor Accepted, mirrored.
                              HeartConnector(
                                leftInitials: 'You',
                                rightInitials: initials,
                                leftIsPublic: true,
                                rightIsPublic: false,
                                discSize: 68,
                              ),
                              const SizedBox(height: 26),
                              const Text("YOU'RE CONNECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFFE0A8AF))),
                              const SizedBox(height: 12),
                              Text(
                                '$name needs your help',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display(fontSize: 30, color: const Color(0xFFFFF9F5), height: 1.15),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$bloodGroup needed · $location',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14.5, color: Color(0xFFE9BFC4), height: 1.5),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                        child: Column(
                          children: [
                            if (!isCritical) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                                child: const Text(
                                  'Normal requests stay in-app — no phone number is shared. Agree on a time here, then mark it done once you\'ve donated.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFFE9BFC4), height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ] else if (!_numberRevealed) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFBE6E8), side: const BorderSide(color: Color(0x8CFBE6E8)), padding: const EdgeInsets.symmetric(vertical: 15)),
                                  onPressed: () => setState(() => _numberRevealed = true),
                                  icon: const Icon(LucideIcons.phone, size: 16),
                                  label: const Text('Show number to call'),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('This is a critical request — the number is shown only once you ask.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Color(0xFFD9AFB4))),
                              const SizedBox(height: 10),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: const Color(0xFF5C0C14), padding: const EdgeInsets.symmetric(vertical: 15)),
                                  onPressed: () => _placeholder('Call'),
                                  icon: const Icon(LucideIcons.phone, size: 16),
                                  label: Text('Call · $phone', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            TextButton(
                              onPressed: _markingDonated ? null : _markDonated,
                              child: _markingDonated
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Mark as donated', style: TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
