import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';

/// Certificate object per the final artifact's "Donation complete →
/// certificate" section. All fields are real: donor name (Backend's own
/// donor doc), and hospital/date/blood group/donation number from the real
/// [DonationRecord] passed in. The certificate wording itself is copied
/// verbatim from the design artifact, which states it is a placeholder pending
/// official approval — no new legal/medical language is invented here, and
/// no download/share action is offered since neither PDF export nor a real
/// Community-posting capability exists yet.
class CertificateScreen extends StatelessWidget {
  final DonationRecord record;
  final int donationNumber;

  const CertificateScreen({super.key, required this.record, required this.donationNumber});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime? d) {
    if (d == null) return 'an unrecorded date';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
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
            stops: [0, 0.6, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(LucideIcons.x, color: Color(0xFFFBEDE6)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                  child: Column(
                    children: [
                      const Text(
                        '✓ DONATION COMPLETE',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 2, color: Color(0xFF8FCF86)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You helped someone today',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(fontSize: 28, height: 1.2, color: const Color(0xFFFBEDE6)),
                      ),
                      const SizedBox(height: 22),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: Backend.instance.myDonorDoc().then((d) => d.data()),
                        builder: (context, snapshot) {
                          final name = snapshot.data?['name'] as String? ?? 'A Rakta Bandhan donor';
                          return _certificateCard(name);
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Certificate wording is a placeholder. Any official or legal phrasing must be supplied and approved — nothing here is invented.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0x998FEDE6), height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _certificateCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 44, offset: Offset(0, 18))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEFCE8C)), borderRadius: BorderRadius.circular(8))),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.brandRed, AppColors.vermilion, AppColors.gold]),
              ),
            ),
          ),
          Column(
            children: [
              Image.asset('assets/branding/final-logo-transparent.png', width: 108),
              const SizedBox(height: 10),
              const Text('CERTIFICATE OF DONATION', style: TextStyle(fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
              Container(height: 1, color: const Color(0xFFEFCE8C), margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
              const Text('This certifies that', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
              const SizedBox(height: 4),
              Text(name, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 26, color: AppColors.ink, height: 1.2)),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.6),
                  children: [
                    const TextSpan(text: 'donated one unit of '),
                    TextSpan(text: record.bloodGroup, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' blood\nat ${record.hospital}\non ${_formatDate(record.date)}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    BloodGroupDroplet(label: '', size: 15, filled: true, color: AppColors.brandRed),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Text('${_ordinal(donationNumber)} donation', style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
              Container(height: 1, color: const Color(0xFFEFCE8C), margin: const EdgeInsets.fromLTRB(24, 16, 24, 12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.goldTint),
                      alignment: Alignment.center,
                      child: const Text('✷', style: TextStyle(fontSize: 12, color: AppColors.goldDeep)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: RichText(
                        textAlign: TextAlign.left,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.ink2),
                          children: [
                            TextSpan(text: 'An initiative of\n'),
                            TextSpan(text: 'Rotary Club of Madras Cosmos', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}
