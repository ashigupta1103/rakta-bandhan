import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../widgets/certificate_card.dart';
import '../widgets/donation_journey.dart';
import '../widgets/pressable.dart';
import '../widgets/rb_ui.dart';
import '../widgets/state_card.dart';
import 'certificate_screen.dart';
import '../widgets/rb_icon.dart';

/// Donation history — rebuilt per Visual Richness Proposal #09: "a real
/// vertical timeline replaces the date column... the impact trail at the
/// top shows [donations] given against a ten-unit horizon."
///
/// Total-donations count comes from Backend.instance.myDonationCount();
/// the per-donation list comes from FirestoreDonationHistoryService,
/// which reads the real `donation_history` collection.
class DonationHistoryScreen extends StatefulWidget {
  /// Replaces the Firestore loads — widget tests run without Firebase.
  @visibleForTesting
  final Future<(int, List<DonationRecord>, String)> Function()? loader;

  const DonationHistoryScreen({super.key, this.loader});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  late final DonationHistoryService _service = FirestoreDonationHistoryService();
  // Not final: "Try again" replaces it.
  late Future<(int, List<DonationRecord>, String)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(int, List<DonationRecord>, String)> _load() async {
    if (widget.loader != null) return widget.loader!();
    final count = await Backend.instance.myDonationCount();
    final history = await _service.fetchHistory();
    // Same name the certificate screen prints, so the preview matches it.
    final name = (await Backend.instance.myDonorDoc()).data()?['name'] as String?;
    return (count, history, name ?? 'A Rakta Bandhan donor');
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
                  IconButton(
                    tooltip: 'Back',
                    icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Donation history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<(int, List<DonationRecord>, String)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: StateCard.error(title: "Couldn't load donation history", onRetry: () => setState(() => _future = _load())),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final (count, history, name) = snapshot.data!;
                  return ListView(
                    padding: kRbPagePadding,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Your journey', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                      ),
                      DonationJourney(
                        count: count,
                        message: count == 0
                            ? 'Your first confirmed donation will start your history here.'
                            : 'Every confirmed donation is listed below.',
                      ),
                      const SizedBox(height: 14),
                      if (history.isEmpty)
                        _empty()
                      else
                        for (var i = 0; i < history.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: AppColors.dividerWarm),
                          _row(history[i], name: name, donationNumber: history.length - i),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact and top-aligned: no icon, no vertical centring.
  Widget _empty() => const Padding(
        padding: EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No donations recorded yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
            SizedBox(height: 6),
            Text(
              'After your first confirmed donation, your donation date, hospital and certificate will appear here.',
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
            ),
            SizedBox(height: 14),
            SeeWhoNeedsHelpButton(),
          ],
        ),
      );

  /// Thumbnail = the real certificate, whole and in its own proportions.
  Widget _thumb(DonationRecord record, String name, int donationNumber) {
    const w = 58.0;
    final h = w * DonationCertificateCard.size.height / DonationCertificateCard.size.width;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.warmBorder)),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        child: ExcludeSemantics(
          child: DonationCertificateCard(record: record, donationNumber: donationNumber, name: name),
        ),
      ),
    );
  }

  Widget _row(DonationRecord record, {required String name, required int donationNumber}) {
    final meta = [if (record.date.isNotEmpty) record.date, if (record.bloodGroup.isNotEmpty) record.bloodGroup].join(' · ');
    return Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CertificateScreen(record: record, donationNumber: donationNumber))),
      semanticLabel: 'View certificate, donation at ${record.hospital}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _thumb(record, name, donationNumber),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.hospital, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 6),
                  const Text('View certificate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
            const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.chevronMuted),
          ],
        ),
      ),
    );
  }
}
