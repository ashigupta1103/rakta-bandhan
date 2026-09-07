import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../services/donation_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/state_card.dart';

/// Donation history — rebuilt per Visual Richness Proposal #09: "a real
/// vertical timeline replaces the date column... the impact trail at the
/// top shows [donations] given against a ten-unit horizon."
///
/// Total-donations count comes from Backend.instance.myDonationCount();
/// the per-donation list comes from FirestoreDonationHistoryService,
/// which reads the real `donation_history` collection.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  final DonationHistoryService _service = FirestoreDonationHistoryService();
  late final Future<(int, List<DonationRecord>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(int, List<DonationRecord>)> _load() async {
    final count = await Backend.instance.myDonationCount();
    final history = await _service.fetchHistory();
    return (count, history);
  }

  /// DonationRecord.date is formatted "D Month YYYY" by the mock service —
  /// split into day/month for the timeline's serif date badge (drops the
  /// year, which the design doesn't show per row).
  (String, String) _dayMonth(String date) {
    final parts = date.split(' ');
    return parts.length >= 2 ? (parts[0], parts[1]) : (date, '');
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
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Donation history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<(int, List<DonationRecord>)>(
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
                  final (count, history) = snapshot.data!;
                  final milestone = 10;
                  final toMilestone = (milestone - count).clamp(0, milestone);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$count', style: AppTextStyles.display(fontSize: 44, color: AppColors.textPrimaryWarm, height: 0.88)),
                            const SizedBox(width: 14),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${count == 1 ? 'unit given' : 'units given'} ·\n${count == 1 ? '1 person' : '$count people'} helped',
                                style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            for (var i = 0; i < milestone; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              BloodGroupDroplet(label: '', size: 22, filled: i < count, color: i < count ? AppColors.primary : AppColors.dividerWarm),
                            ],
                          ],
                        ),
                        if (toMilestone > 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            '$toMilestone more and you reach the $milestone-unit mark',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                        Container(height: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.symmetric(vertical: 22)),
                        if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: StateCard.empty(icon: LucideIcons.history, title: 'No donations recorded yet.'),
                          )
                        else
                          for (var i = 0; i < history.length; i++) _timelineRow(history[i], isLast: i == history.length - 1),
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

  Widget _timelineRow(DonationRecord record, {required bool isLast}) {
    final (day, month) = _dayMonth(record.date);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(width: 11, height: 11, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
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
                      Text('$day $month', style: AppTextStyles.display(fontSize: 14.5, color: AppColors.textPrimaryWarm)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(record.bloodGroup, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
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
