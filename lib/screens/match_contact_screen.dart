import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/two_person_connection.dart';
import 'donation_confirm_screen.dart';

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
              final bloodGroup = request['blood_group'] as String? ?? '';
              final location = (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'the requester';
              final name = request['requester_name'] as String? ?? 'Requester';
              final phone = request['requester_phone'] as String? ?? '—';
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
                  Expanded(child: TwoPersonConnection(leftLabel: 'You', rightInitials: initials)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Text("YOU'RE CONNECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFFE0A8AF))),
                        const SizedBox(height: 12),
                        Text(
                          '$name needs your help',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 26, color: const Color(0xFFFFF9F5), height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$bloodGroup needed · $location. Reach out and agree a time.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4), height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        BloodGroupDroplet(label: bloodGroup, size: 34, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
                            onPressed: () => _placeholder('Call'),
                            icon: const Icon(LucideIcons.phone, size: 16),
                            label: Text('Call · $phone', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFBE6E8), side: const BorderSide(color: Color(0x8CFBE6E8))),
                            onPressed: () => _placeholder('WhatsApp'),
                            icon: const Icon(LucideIcons.messageSquare, size: 15),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: _markingDonated ? null : _markDonated,
                          child: _markingDonated
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Mark as donated', style: TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4))),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
