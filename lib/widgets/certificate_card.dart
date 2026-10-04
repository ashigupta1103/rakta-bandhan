import 'package:flutter/material.dart';

import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'blood_group_droplet.dart';
import 'rb_icon.dart';

/// The donation certificate itself — one design, used full-size on the
/// certificate screen (and exported as the saved/shared PNG) and scaled down
/// as the preview thumbnail in Donation history.
class DonationCertificateCard extends StatelessWidget {
  /// Fixed design size (≈ A4 portrait, 1 : 1.414).
  static const size = Size(360, 510);

  final DonationRecord record;
  final int donationNumber;
  final String name;

  const DonationCertificateCard({super.key, required this.record, required this.donationNumber, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFEFCE8C)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.brandRed, AppColors.vermilion, AppColors.gold])),
            ),
          ),
          // A long name or hospital scales the content down as a unit
          // instead of overflowing the fixed card.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: size.width - 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/branding/final-logo-transparent.png', width: 84),
                    const SizedBox(height: 10),
                    const Text(
                      'Certificate of donation',
                      style: TextStyle(fontSize: 12, letterSpacing: 0.1, fontWeight: FontWeight.w600, color: AppColors.goldDeep),
                    ),
                    Container(height: 1, color: const Color(0xFFEFCE8C), margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
                    const Text('This certifies that', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTextStyles.display(fontSize: 26, color: AppColors.ink, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.6),
                        children: [
                          const TextSpan(text: 'voluntarily donated '),
                          TextSpan(
                            text: record.bloodGroup.isEmpty ? 'blood' : '${record.bloodGroup} blood',
                            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '\nat ${record.hospital}${record.date.isEmpty ? '' : '\non ${record.date}'}'),
                          const TextSpan(text: ',\nanswering a request made through Rakta Bandhan.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const BloodGroupDroplet(label: '', size: 18, filled: true, color: AppColors.brandRed),
                    const SizedBox(height: 7),
                    Text('${_ordinal(donationNumber)} donation', style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
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
                            child: const RbIcon(RbGlyph.certificate, size: 14, color: AppColors.goldDeep),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: RichText(
                              textAlign: TextAlign.left,
                              text: const TextSpan(
                                style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.ink2),
                                children: [
                                  TextSpan(text: 'A service project of\n'),
                                  TextSpan(
                                    text: 'Rotary Club of Madras Cosmos &\nRotary Club of Chennai Capital',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Platform by Almmatix', style: TextStyle(fontSize: 10, color: AppColors.mutedInk)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
