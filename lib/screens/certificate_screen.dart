import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../demo/demo.dart';
import '../services/backend.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import 'about_screen.dart';
import '../widgets/rb_icon.dart';

/// Donation certificate, opened from Donation history. Every field is real:
/// the donor's name (their profile), and hospital/date/blood group/donation
/// number from the [DonationRecord]. "Save" writes a high-resolution PNG to
/// the photo gallery; "Share" opens the phone's share sheet with the same
/// image.
class CertificateScreen extends StatefulWidget {
  final DonationRecord record;
  final int donationNumber;

  const CertificateScreen({super.key, required this.record, required this.donationNumber});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final _certificateKey = GlobalKey();
  bool _busy = false;

  DonationRecord get record => widget.record;
  int get donationNumber => widget.donationNumber;

  /// The card as a PNG at 3× its on-screen size — sharp enough to print.
  Future<Uint8List> _renderPng() async {
    final boundary = _certificateKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  /// Records carry a "D Month YYYY" date; only today's donation says "today".
  bool get _isToday {
    final n = DateTime.now();
    return record.date == '${n.day} ${_months[n.month - 1]} ${n.year}';
  }

  String get _fileName => 'rakta-bandhan-certificate-$donationNumber';

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await _renderPng();
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(png, mimeType: 'image/png', name: '$_fileName.png')],
          ),
        );
      } else {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        await Gal.putImageBytes(png, name: _fileName);
        messenger.showSnackBar(const SnackBar(content: Text('Certificate saved to your photos.')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t save the certificate. Allow photo access in Settings, or use Share.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _renderPng();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: '$_fileName.png')],
          text: 'I donated blood through Rakta Bandhan. Find a donor — or become one: ${AboutScreen.shareUrl}',
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t open sharing. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
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
                    tooltip: 'Close',
                    icon: const RbIcon(RbGlyph.close, color: AppColors.onEmberWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RbIcon(RbGlyph.checkCircle, size: 15, color: AppColors.onEmberSuccess),
                        SizedBox(width: 7),
                        Text(
                          'Donation complete',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.onEmberSuccess),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isToday ? 'You helped someone today' : 'Thank you for donating',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(fontSize: 26, height: 1.2, color: AppColors.onEmberWarm),
                    ),
                  ],
                ),
              ),
              // The certificate keeps its portrait (A4-like) proportions and
              // scales as a whole to the space left — never stretched to the
              // phone's width, never pushing the buttons off screen.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _cardSize.width / _cardSize.height,
                      child: FittedBox(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: Demo.on ? Future.value(Demo.instance.myProfile) : Backend.instance.myDonorDoc().then((d) => d.data()),
                          builder: (context, snapshot) {
                            final name = snapshot.data?['name'] as String? ?? 'A Rakta Bandhan donor';
                            return RepaintBoundary(key: _certificateKey, child: _certificateCard(name));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _action(RbGlyph.download, 'Save', _save)),
                        const SizedBox(width: 12),
                        Expanded(child: _action(RbGlyph.share, 'Share', _share)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Issued by Rakta Bandhan from the donation recorded in the app. It is not a medical record.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.onEmberFaint, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fixed design size of the certificate (≈ A4 portrait, 1 : 1.414).
  static const _cardSize = Size(360, 510);

  /// Save and Share: same height, outline and weight, side by side.
  Widget _action(RbGlyph glyph, String label, VoidCallback onTap) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: AppColors.onEmberStrong,
      side: const BorderSide(color: AppColors.onEmberOutline),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    onPressed: _busy ? null : onTap,
    icon: RbIcon(glyph, size: 18),
    label: Text(label),
  );

  Widget _certificateCard(String name) {
    return Container(
      width: _cardSize.width,
      height: _cardSize.height,
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
                width: _cardSize.width - 40,
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
                    if (Demo.on) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Demo certificate — sample data, not issued',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.goldDeep),
                      ),
                    ],
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
