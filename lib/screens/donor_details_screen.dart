import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/identity_disc.dart';
import '../widgets/loading_button.dart';

/// Pre-match donor discovery screen — the final artifact's "Donor details"
/// section: "built around trust and disclosure". Deliberately has no
/// Call/WhatsApp actions — contact details are only real once a request is
/// accepted (see MatchContactScreen). Showing them here would be
/// fabricating access to sensitive donor information the donor hasn't
/// agreed to share yet.
///
/// The donation count and "updated" timestamp are read live from Firestore
/// (same real `matched_donor_id`/`status: fulfilled` count query already
/// used on DonorFoundScreen, and the donor's own real `updated_at` field) —
/// nothing on this screen is invented.
class DonorDetailsScreen extends StatefulWidget {
  final String donorId;
  final String name;
  final String initials;
  final String bloodGroup;
  final bool isVerified;
  final double? distanceKm;
  final bool isAvailable;

  const DonorDetailsScreen({
    super.key,
    required this.donorId,
    required this.name,
    required this.initials,
    required this.bloodGroup,
    required this.isVerified,
    required this.distanceKm,
    required this.isAvailable,
  });

  @override
  State<DonorDetailsScreen> createState() => _DonorDetailsScreenState();
}

class _DonorDetailsScreenState extends State<DonorDetailsScreen> {
  bool _isSending = false;

  Future<void> _sendRequest() async {
    setState(() => _isSending = true);
    try {
      final pos = await Backend.instance.currentPosition();
      await Backend.instance.createRequest(
        bloodGroup: widget.bloodGroup,
        unitsNeeded: 1,
        urgency: 'urgent',
        lat: pos.latitude,
        lng: pos.longitude,
        locationLabel: 'Requested via ${widget.name}\'s profile',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blood request sent — visible to nearby ${widget.bloodGroup} donors.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<int> _donationCount() async {
    final snap = await FirebaseFirestore.instance
        .collection('requests')
        .where('matched_donor_id', isEqualTo: widget.donorId)
        .where('status', isEqualTo: 'fulfilled')
        .count()
        .get();
    return snap.count ?? 0;
  }

  String _updatedLabel(Timestamp? updatedAt) {
    if (updatedAt == null) return '';
    final diff = DateTime.now().difference(updatedAt.toDate());
    if (diff.inHours < 24) return 'Profile updated today';
    if (diff.inDays < 7) return 'Profile updated ${diff.inDays}d ago';
    return 'Profile updated ${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Donor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  IdentityDisc(initials: widget.initials, size: 90, isPublic: true, bloodGroup: widget.bloodGroup),
                  const SizedBox(height: 14),
                  Text(widget.name, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 26, color: AppColors.ink)),
                  if (widget.isVerified) ...[
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.warmGreenBg),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.check, size: 10, color: AppColors.warmGreenText),
                        ),
                        const SizedBox(width: 7),
                        const Text('Verified by OTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warmGreenText)),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              FutureBuilder<int>(
                future: _donationCount(),
                builder: (context, snapshot) {
                  return Row(
                    children: [
                      _statTile(widget.bloodGroup, 'Group'),
                      const SizedBox(width: 10),
                      _statTile(widget.distanceKm == null ? '—' : widget.distanceKm!.toStringAsFixed(1), 'km away'),
                      const SizedBox(width: 10),
                      _statTile(snapshot.hasData ? '${snapshot.data}' : '—', 'donations'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isAvailable ? AppColors.successText : AppColors.mutedInk,
                        boxShadow: widget.isAvailable ? [BoxShadow(color: AppColors.successText.withValues(alpha: 0.16), blurRadius: 0, spreadRadius: 5)] : null,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('donors_public').doc(widget.donorId).get(),
                        builder: (context, snapshot) {
                          final updatedAt = snapshot.data?.data()?['updated_at'] as Timestamp?;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isAvailable ? 'Available to donate' : 'Not available right now',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.isAvailable ? AppColors.successText : AppColors.mutedInk),
                              ),
                              if (updatedAt != null) Text(_updatedLabel(updatedAt), style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text("WHAT WE SHOW, AND WHAT WE DON'T", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _disclosureRow('Group, distance band and availability', shown: true),
                    _disclosureRow('Community name and donation count', shown: true),
                    _disclosureRow('Real name and exact address', shown: false),
                    _disclosureRow('Phone number — unless they agree to a critical call', shown: false, isLast: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.goldTint,
                  border: const Border(left: BorderSide(color: AppColors.gold, width: 3)),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
                child: const Text(
                  "Age is shown only if the donor chose to expose it. This screen exposes nothing the current Firestore rules don't already allow.",
                  style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                ),
              ),
              const SizedBox(height: 22),
              if (widget.isAvailable) ...[
                LoadingButton(label: 'Send a request to $firstName', isLoading: _isSending, onPressed: _sendRequest),
                const SizedBox(height: 10),
                const Text("They'll be alerted in the app — no number is shared", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: AppColors.cardBorderWarm, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Text('Currently unavailable to donate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 10),
                Text('$firstName is not accepting requests right now.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.display(fontSize: 21, color: AppColors.ink, height: 1)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
          ],
        ),
      ),
    );
  }

  Widget _disclosureRow(String label, {required bool shown, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider))),
      child: Row(
        children: [
          Icon(shown ? LucideIcons.check : LucideIcons.x, size: 14, color: shown ? AppColors.successText : AppColors.disabledTint),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: shown ? AppColors.textPrimaryWarm : AppColors.ink2))),
        ],
      ),
    );
  }
}
