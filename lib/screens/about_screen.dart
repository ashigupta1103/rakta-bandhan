import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/rb_ui.dart';
import 'legal_reader_screen.dart';

/// About Rakta Bandhan — mission, vision, the project's story and team, as
/// supplied by the Rakta Bandhan / Rotary team. Team photographs are still
/// to come: set `photo` on a [_Member] once the image is in assets/team/;
/// until then each member shows their initials.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Public share page with a social preview card (tool/make_share_page.py);
  /// it links on to the store listing.
  static const shareUrl = 'https://rakta-bandhan2026.web.app/app/';

  static const _missionPoints = [
    (LucideIcons.users, 'Empower', 'patients and caregivers with access to nearby blood donors.'),
    (LucideIcons.zap, 'Enable', 'donors to respond swiftly, safely and meaningfully.'),
    (LucideIcons.building2, 'Engage', 'hospitals, blood banks and communities to build a responsive donor network.'),
    (LucideIcons.repeat, 'Encourage', 'responsible repeat donation through reminders and appropriate scheduling.'),
  ];

  static const _team = [
    _Member(
      name: 'PHF Rtn. Radhika Dhruv',
      photo: null, // 'assets/team/radhika-dhruv.jpg' once supplied
      role: 'Project Chairman · Visionary & Principal Sponsor',
      detail: 'Immediate Past President, Rotary Club of Madras Cosmos',
      bio: 'Radhika Dhruv conceptualised Rakta Bandhan from the thought that reaching a blood donor should be faster and more seamless in an emergency. Her vision has driven the development of the platform, and the app’s development has been majorly sponsored by her.',
    ),
    _Member(
      name: 'CSK',
      photo: null, // 'assets/team/csk.jpg' once supplied
      role: 'Management Trustee',
      detail: 'Rakta Bandhan project trust',
      bio: 'As Management Trustee, CSK oversees the governance of the project on behalf of the partner trusts — making sure Rakta Bandhan is run responsibly, transparently and in the service of donors and patients.',
    ),
    _Member(
      name: 'Adarsh Betala',
      photo: null, // 'assets/team/adarsh-betala.jpg' once supplied
      role: 'President',
      detail: 'Rakta Bandhan',
      bio: 'As President, Adarsh Betala leads the day-to-day direction of Rakta Bandhan — bringing together the clubs, volunteers, hospitals and the technology team so that every request reaches willing donors quickly.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    const Expanded(child: Text('About', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm))),
                    IconButton(
                      tooltip: 'Share Rakta Bandhan',
                      icon: const Icon(LucideIcons.share2, size: 19, color: AppColors.textPrimaryWarm),
                      onPressed: () => SharePlus.instance.share(ShareParams(
                        text: 'Rakta Bandhan helps people who urgently need blood reach willing donors nearby. Find your Bloodmate here: $shareUrl',
                      )),
                    ),
                  ],
                ),
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
                          Text('Find your Bloodmate here.', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 24, color: AppColors.onEmberWarm).copyWith(fontStyle: FontStyle.italic)),
                          const SizedBox(height: 6),
                          const Text('Your match is a call away.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted)),
                          const SizedBox(height: 14),
                          const Text.rich(
                            TextSpan(
                              text: 'A service project of\n',
                              style: TextStyle(fontSize: 12.5, color: AppColors.onEmberMuted, height: 1.5),
                              children: [
                                TextSpan(text: 'Rotary Club of Madras Cosmos & Rotary Club of Chennai Capital', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Our mission'),
                          _body(
                            'To create a real-time, GPS-enabled platform that bridges the gap between urgent blood requirements and willing donors — fostering timely giving, responsible donation and lifesaving action.',
                          ),
                          const SizedBox(height: 14),
                          for (final (icon, verb, rest) in _missionPoints) _missionRow(icon, verb, rest),
                          const SizedBox(height: 22),
                          _label('Our vision'),
                          _body('A future where finding a blood donor is as quick and seamless as ordering a ride or a meal — powered by technology, humanity and trust.'),
                          const SizedBox(height: 26),
                          _label('About Rakta Bandhan'),
                          _body(
                            'Rakta Bandhan is a technology-enabled blood donor platform created to bridge the critical gap between people who urgently need blood and willing donors.',
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: AppColors.goldTint,
                              border: const Border(left: BorderSide(color: AppColors.gold, width: 3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '“When food and groceries can be delivered in minutes, finding a blood donor should not take hours.”',
                              style: AppTextStyles.display(fontSize: 16, color: AppColors.goldDeepest, height: 1.5).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _paragraph(
                            'Rakta Bandhan uses location-enabled technology to help identify suitable, available blood donors in the vicinity of an urgent requirement. It connects patients, caregivers and hospitals with blood donors, enabling faster communication and helping turn an emergency blood requirement into timely community action.',
                          ),
                          const SizedBox(height: 12),
                          _paragraph(
                            'The initiative is a collaborative service project of Madras Cosmos Charitable Trust, managed by Rotary Club of Madras Cosmos, and Chennai Capital Trust, managed by Rotary Club of Chennai Capital, with support from Rotary International District 3233.',
                          ),
                          const SizedBox(height: 12),
                          _paragraph(
                            'The project was conceptualised by PHF Rtn. Radhika Dhruv, Immediate Past President of Rotary Club of Madras Cosmos, with the app’s development majorly sponsored by her.',
                          ),
                          const SizedBox(height: 22),
                          _label('Our belief'),
                          Text('Every drop counts. Every donor matters. Every minute matters.', style: AppTextStyles.display(fontSize: 18, color: AppColors.brandRed, height: 1.4)),
                          const SizedBox(height: 28),
                          _label('Our team'),
                          const SizedBox(height: 4),
                          for (final m in _team) _teamCard(m),
                          const SizedBox(height: 22),
                          _label('Community & legal'),
                          RbListGroup(
                            children: [
                              for (final (icon, label, page) in [
                                (LucideIcons.heartHandshake, 'Community guidelines', () => const LegalReaderScreen.guidelines()),
                                (LucideIcons.shieldCheck, 'Privacy policy', () => const LegalReaderScreen.privacy()),
                                (LucideIcons.fileText, 'Terms of use', () => const LegalReaderScreen.terms()),
                              ])
                                RbRow(icon: icon, tone: RbTone.neutral, title: label, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page()))),
                            ],
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppColors.ink2)),
      );

  Widget _body(String text) => Text(text, style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.55));

  Widget _paragraph(String text) => Text(text, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.6));

  Widget _missionRow(IconData icon, String verb, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.primaryLightTint, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.45),
                  children: [
                    TextSpan(text: '$verb ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: rest),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamCard(_Member m) {
    final initials = m.name
        .replaceAll(RegExp(r'^(PHF\s+)?(Rtn\.\s+)?'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final initialsDisc = Container(
      color: AppColors.red100,
      alignment: Alignment.center,
      child: Text(initials, style: AppTextStyles.display(fontSize: 22, color: AppColors.brandRed)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: m.photo == null
                        ? initialsDisc
                        : Image.asset(m.photo!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => initialsDisc),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink, height: 1.2)),
                      const SizedBox(height: 3),
                      Text(m.role, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandRed, height: 1.3)),
                      Text(m.detail, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(m.bio, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.55)),
          ],
        ),
      ),
    );
  }

}

@immutable
class _Member {
  final String name;
  final String role;
  final String detail;
  final String bio;
  /// Asset path of the member's photograph, e.g. 'assets/team/radhika-dhruv.jpg'
  /// (also list it under `flutter: assets:` in pubspec.yaml). Null shows
  /// initials.
  final String? photo;
  const _Member({required this.name, required this.role, required this.detail, required this.bio, this.photo});
}
