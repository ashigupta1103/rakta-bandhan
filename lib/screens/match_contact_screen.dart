import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/contact_actions.dart';
import '../widgets/two_person_connection.dart';
import 'chat_screen.dart';
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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
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
              final phone = request['requester_phone'] as String? ?? '';
              final requesterUid = request['requester_uid'] as String? ?? '';
              final status = request['status'] as String? ?? 'matched';
              final isLive = status == 'matched' && request['matched_donor_id'] == Backend.instance.currentUser?.uid;
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
                        Text(
                          switch (status) {
                            'cancelled' => 'Request cancelled',
                            'fulfilled' => 'Donation recorded',
                            _ => "You're connected",
                          },
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$name needs your help',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 26, color: AppColors.onEmberStrong, height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$bloodGroup needed · $location. Reach out and agree a time.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        BloodGroupDroplet(label: bloodGroup, size: 34, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: isLive
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ContactActions(requestId: widget.requestId, peerUid: requesterUid, peerName: name, peerPhone: phone),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: _markingDonated || _releasing ? null : _markDonated,
                                    child: _markingDonated
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Mark as donated', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.onEmberMuted)),
                                  ),
                                  Container(width: 1, height: 14, color: AppColors.onEmber.withValues(alpha: 0.2)),
                                  TextButton(
                                    onPressed: _markingDonated || _releasing ? null : _release,
                                    child: Text(_releasing ? 'Releasing…' : "Can't make it", style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberFaint)),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                status == 'cancelled'
                                    ? '$name no longer needs this donation. Thank you for stepping up.'
                                    : 'This match is finished. Your conversation is kept as a record.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppColors.onEmberMuted, height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.onEmber, side: const BorderSide(color: AppColors.onEmberOutline)),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(requestId: widget.requestId))),
                                icon: const Icon(LucideIcons.messageSquare, size: 15),
                                label: const Text('View conversation'),
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
