import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Corporate partnerships — per the final artifact's "Trust & brand"
/// section. This screen IS specified in the design (it is not a
/// coming-soon placeholder); what's genuinely undecided is the commercial
/// side of it — sponsor names, tiers, pricing and the contact/lead-capture
/// flow behind "Start a conversation" — which the design itself says are
/// "yours to define" and explicitly not invented here.
class CorporatePartnershipsScreen extends StatelessWidget {
  const CorporatePartnershipsScreen({super.key});

  void _startConversation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No contact/lead-capture flow exists yet — this button has nowhere real to send a conversation.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('Partner with us', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FOR ORGANISATIONS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.goldDeep)),
                    const SizedBox(height: 10),
                    Text('Put your name behind something that saves lives', style: AppTextStyles.display(fontSize: 26, color: AppColors.ink, height: 1.2)),
                    const SizedBox(height: 12),
                    Text('Placeholder — partnership proposition copy to be supplied.', style: AppTextStyles.display(fontSize: 16, color: const Color(0xFF3D2523), height: 1.6)),
                    const SizedBox(height: 22),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _sponsorCard(LucideIcons.droplet, AppColors.red100, AppColors.brandRed, 'Sponsor a donation drive'),
                        _sponsorCard(LucideIcons.plus, AppColors.goldTint, AppColors.goldDeep, 'Sponsor a health initiative'),
                        _sponsorCard(LucideIcons.award, AppColors.orangeTint, AppColors.orangeDeep, 'Sponsor donor recognition'),
                        _sponsorCard(LucideIcons.users, AppColors.successBg, AppColors.successText, 'Corporate volunteering'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment(-0.3, -1), end: Alignment(0.3, 1), colors: [AppColors.emberFieldStart, AppColors.emberFieldMid]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('WHERE YOUR NAME APPEARS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.gold)),
                          const SizedBox(height: 10),
                          const Text(
                            'Camp materials, the initiative card in What\'s New, donor certificates and recognition moments. Never over a blood request, and never inside an emergency flow.',
                            style: TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xD9FBEDE6)),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0x66E0A030)), borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Text('Sponsor lockup slot · sizes defined in the system', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Color(0x99FBEDE6))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                      child: const Text(
                        'No sponsor, tier, price or benefit has been invented. This page establishes the experience; commercial terms are yours to define.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: () => _startConversation(context), child: const Text('Start a conversation')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sponsorCard(IconData icon, Color bg, Color fg, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Icon(icon, size: 16, color: fg)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        ],
      ),
    );
  }
}
