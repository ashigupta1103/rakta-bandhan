import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/donor_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/contact_actions.dart';
import '../widgets/two_person_connection.dart';

/// Terminal screen of the matching ladder's "donor found" outcome — the
/// "Matched" emotional peak per Product Art Direction: two avatars joined
/// by a hairline on a dark ember field, the committed ring group at 0.90x
/// recentred on the connection itself, both discs seated on the middle
/// ring's own radius. The donor identity comes from
/// FirestoreDonorMatchService, reading the real match written by
/// Backend.acceptRequest (see donor_match_service.dart).
class DonorFoundScreen extends StatelessWidget {
  final String requestId;
  final DonorMatchService _service = FirestoreDonorMatchService();

  DonorFoundScreen({super.key, required this.requestId});

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          child: FutureBuilder<DonorMatch>(
            future: _service.fetchMatch(requestId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
              }
              final donor = snapshot.data!;
              return Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                        onPressed: () => _goHome(context),
                      ),
                    ),
                  ),
                  Expanded(child: TwoPersonConnection(leftLabel: 'You', rightInitials: donor.initials)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Text("You're connected", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow)),
                        const SizedBox(height: 12),
                        Text(
                          '${donor.name.split(' ').first} is ready\nto help you',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 28, color: AppColors.onEmberStrong, height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${[donor.bloodGroup, donor.distance, if (donor.isVerified) 'verified donor'].where((p) => p.isNotEmpty).join(' · ')}. Reach out and agree a time.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        BloodGroupDroplet(label: donor.bloodGroup, size: 34, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ContactActions(requestId: requestId, peerUid: donor.uid, peerName: donor.name),
                        const SizedBox(height: 6),
                        const Text('They mark it as donated afterwards.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.onEmberFaint)),
                        TextButton(
                          onPressed: () => _goHome(context),
                          child: const Text('Back to home', style: TextStyle(fontSize: 13, color: AppColors.onEmberMuted)),
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
