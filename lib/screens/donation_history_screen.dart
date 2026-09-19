import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/impact_trail.dart';
import '../widgets/state_card.dart';
import 'certificate_screen.dart';

/// Donation history — the final artifact's "same trail, same horizon"
/// section: a real vertical timeline, the same [ImpactTrail] component used
/// on My Page, and a real per-donation certificate link on the most recent
/// row. Every record comes from [FirestoreDonationHistoryService] — real
/// fulfilled `requests` documents, nothing mocked.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  final DonationHistoryService _service = FirestoreDonationHistoryService();
  late Future<List<DonationRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchHistory();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dayMonth(DateTime? date) => date == null ? 'Undated' : '${date.day} ${_months[date.month - 1]}';

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
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Donation history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DonationRecord>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: StateCard.error(title: "Couldn't load donation history", onRetry: () => setState(() => _future = _service.fetchHistory())),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final history = snapshot.data!;
                  final count = history.length;
                  final milestone = 10;
                  final toMilestone = (milestone - count).clamp(0, milestone);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ImpactTrail(
                          count: count,
                          numberFontSize: 44,
                          dropletSize: 20,
                          caption: '${count == 1 ? 'unit given' : 'units given'} · ${count == 1 ? '1 person' : '$count people'} helped',
                        ),
                        if (toMilestone > 0) ...[
                          const SizedBox(height: 4),
                          Text('$toMilestone more and you reach the $milestone-unit mark', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                        Container(height: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.symmetric(vertical: 22)),
                        if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: StateCard.empty(icon: LucideIcons.history, title: 'No donations recorded yet.'),
                          )
                        else
                          for (var i = 0; i < history.length; i++)
                            _timelineRow(history[i], isFirst: i == 0, isLast: i == history.length - 1, donationNumber: history.length - i),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(DonationRecord record, {required bool isFirst, required bool isLast, required int donationNumber}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: isLast ? AppColors.gold : AppColors.primary, shape: BoxShape.circle),
                ),
                if (!isLast) Expanded(child: Container(width: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.only(top: 4))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(record.hospital, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                      ),
                      Text(_dayMonth(record.date), style: AppTextStyles.display(fontSize: 14.5, color: AppColors.textPrimaryWarm)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${record.bloodGroup} · ${record.units} unit${record.units == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  if (isFirst) ...[
                    const SizedBox(height: 9),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CertificateScreen(record: record, donationNumber: donationNumber)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.award, size: 14, color: AppColors.goldDeep),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Certificate available', style: TextStyle(fontSize: 12.5, color: AppColors.textPrimaryWarm))),
                            const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.red700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (isLast) ...[
                    const SizedBox(height: 7),
                    const Text('Your first donation', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
