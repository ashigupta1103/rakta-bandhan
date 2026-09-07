import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/two_person_connection.dart';
import 'match_contact_screen.dart';

enum AcceptOutcome { success, claimed, blocked }

/// Result of a real Backend.instance.acceptRequest() call (success/claimed),
/// or of the frontend's own single-active-match guard (blocked) — see
/// RequestDetailScreen. No new backend logic here, just presenting the
/// outcome already determined there.
///
/// The success case is one of the app's emotional-peak "Matched" moments
/// per Rakta Bandhan Mobile's isAcceptResult/acceptSuccess reference — same
/// ember/ring/two-avatar grammar as Donor Found and Match Contact. Claimed
/// and blocked stay on the quiet cream ground, matching that same reference.
class AcceptResultScreen extends StatelessWidget {
  final AcceptOutcome outcome;
  final String? activeRequestId;

  const AcceptResultScreen({super.key, required this.outcome, this.activeRequestId});

  void _goHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    if (outcome == AcceptOutcome.success) return _SuccessConnection(requestId: activeRequestId!);

    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (outcome == AcceptOutcome.claimed) ..._claimed(context),
              if (outcome == AcceptOutcome.blocked) ..._blocked(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _claimed(BuildContext context) => [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(LucideIcons.xCircle, size: 28, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Text('Already accepted', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        const SizedBox(height: 8),
        const Text(
          "Someone else got there first. Thank you for being ready to help — there'll be another request soon.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _goHome(context), child: const Text('Back to home'))),
      ];

  List<Widget> _blocked(BuildContext context) => [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.warmAmberBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(LucideIcons.alertTriangle, size: 28, color: AppColors.warmAmberText),
        ),
        const SizedBox(height: 16),
        const Text('You already have an active match', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        const SizedBox(height: 8),
        const Text(
          'You can only hold one active match at a time. Finish or cancel your current match before accepting a new request.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MatchContactScreen(requestId: activeRequestId!)),
            ),
            child: const Text('View my active match'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _goHome(context), child: const Text('Back to home'))),
      ];
}

class _SuccessConnection extends StatelessWidget {
  final String requestId;

  const _SuccessConnection({required this.requestId});

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
            future: FirebaseFirestore.instance.collection('requests').doc(requestId).get(),
            builder: (context, requestSnap) {
              if (!requestSnap.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
              }
              final request = requestSnap.data!.data() ?? {};
              final bloodGroup = request['blood_group'] as String? ?? '';
              final units = request['units_needed'] ?? 1;
              final location = (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'the requester';
              // requester_name is denormalized onto the request doc at
              // creation (see Backend.createRequest) specifically so this
              // screen never needs to read donors/{requester_uid} directly
              // — under firestore.rules that doc is owner/admin-only.
              final name = request['requester_name'] as String? ?? 'the requester';
              final initials = name.trim().isEmpty || name == 'the requester'
                  ? '?'
                  : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

              return Column(
                children: [
                  const SizedBox(height: 48),
                  Expanded(child: TwoPersonConnection(leftLabel: 'You', rightInitials: initials)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Text("YOU'RE CONNECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFFE0A8AF))),
                        const SizedBox(height: 12),
                        Text(
                          '${name == 'the requester' ? 'The requester' : name} is\nexpecting you',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 28, color: const Color(0xFFFFF9F5), height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$bloodGroup · $units unit${units == 1 ? '' : 's'} · $location',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4), height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MatchContactScreen(requestId: requestId)),
                        ),
                        child: const Text('View contact details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
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
