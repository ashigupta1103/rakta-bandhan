import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// About Rakta Bandhan — per the final artifact's "Trust & brand" section.
/// Copy, figures and the team roster are explicitly marked as placeholders
/// in the design itself ("copy and people = placeholders") — the three
/// impact figures render as "—" because the design's own canonical frame
/// shows dashes, not invented numbers, pending confirmation of a real
/// source for them.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                  const Text('About', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment(-0.3, -1), end: Alignment(0.3, 1), colors: [AppColors.emberFieldStart, AppColors.emberFieldMid, AppColors.emberFieldEnd]),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 128,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Image.asset('assets/branding/final-logo-transparent.png', fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 18),
                          Text('Find your blood mate.', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: const Color(0xFFFBEDE6)).copyWith(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 12),
                          const Text.rich(
                            TextSpan(
                              text: 'An initiative of\n',
                              style: TextStyle(fontSize: 12.5, color: Color(0xB3FBEDE6)),
                              children: [TextSpan(text: 'Rotary Club of Madras Cosmos', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold))],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OUR MISSION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
                          const SizedBox(height: 10),
                          Text(
                            'Placeholder — the mission statement is to be supplied by the Rakta Bandhan team. It is deliberately not written here.',
                            style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.6),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _statTile('donors'),
                              const SizedBox(width: 10),
                              _statTile('donations'),
                              const SizedBox(width: 10),
                              _statTile('camps'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Figures read from existing records once confirmed — none invented', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.disabledTint)),
                          const SizedBox(height: 24),
                          const Text('THE TEAM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.ink2)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                _teamRow('Adarsh', isLast: false),
                                _teamRow('Sathish Kumar', isLast: false),
                                _teamRow('Radhika', isLast: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(color: AppColors.goldTint, border: const Border(left: BorderSide(color: AppColors.gold, width: 3)), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
                            child: const Text(
                              'No biography, title or credential has been written for anyone. Photographs use the empty-frame treatment until real ones are supplied.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                            ),
                          ),
                        ],
                      ),
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

  Widget _statTile(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('—', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
          ],
        ),
      ),
    );
  }

  Widget _teamRow(String name, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.warmDivider))),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.sand, shape: BoxShape.circle, border: Border.all(color: AppColors.warmBorder, style: BorderStyle.solid)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.display(fontSize: 16.5, color: AppColors.ink)),
                const Text('Role — to be supplied', style: TextStyle(fontSize: 11.5, color: AppColors.disabledTint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
