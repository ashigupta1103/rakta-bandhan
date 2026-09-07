import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/donor_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
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

  void _placeholderAction(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon.')));
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
                        const Text("YOU'RE CONNECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Color(0xFFE0A8AF))),
                        const SizedBox(height: 12),
                        Text(
                          '${donor.name.split(' ').first} is ready\nto help you',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(fontSize: 28, color: const Color(0xFFFFF9F5), height: 1.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${donor.bloodGroup} · ${donor.distance} · verified donor. Reach out and agree a time.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFFE9BFC4), height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        BloodGroupDroplet(label: donor.bloodGroup, size: 34, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 12),
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
                            onPressed: () => _placeholderAction(context, 'Call'),
                            icon: const Icon(LucideIcons.phone, size: 16),
                            label: const Text('Call', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFBE6E8), side: const BorderSide(color: Color(0x8CFBE6E8))),
                            onPressed: () => _placeholderAction(context, 'WhatsApp'),
                            icon: const Icon(LucideIcons.messageSquare, size: 15),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Mark as donated afterwards', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Color(0xFFD9AFB4))),
                        TextButton(
                          onPressed: () => _goHome(context),
                          child: const Text('Back to home', style: TextStyle(fontSize: 13, color: Color(0xFFE9BFC4))),
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
