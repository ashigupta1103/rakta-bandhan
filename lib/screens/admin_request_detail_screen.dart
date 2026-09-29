import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';
import 'admin_content_tab.dart' show confirmAdminDelete;

class AdminRequestDetailScreen extends StatefulWidget {
  final AdminRequestEntry request;

  const AdminRequestDetailScreen({super.key, required this.request});

  @override
  State<AdminRequestDetailScreen> createState() => _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends State<AdminRequestDetailScreen> {
  bool _confirming = false;

  Future<void> _confirmDonation() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await AdminService.instance.confirmDonation(widget.request.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not confirm this donation. Please try again.')),
      );
    }
  }

  (Color, Color) _statusStyle(String status) => switch (status) {
        'open' => (AppColors.statusUrgentBg, AppColors.statusUrgentText),
        'matched' => (AppColors.statusPendingBg, AppColors.statusPendingText),
        'fulfilled' => (AppColors.statusAvailableBg, AppColors.statusAvailableText),
        _ => (AppColors.cardBorderWarm, AppColors.textPrimaryWarm),
      };

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final (statusBg, statusText) = _statusStyle(request.status);
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
        title: const Text('Request details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge.bloodGroup(request.bloodGroup),
                        const SizedBox(width: 8),
                        StatusBadge(label: request.statusLabel, background: statusBg, textColor: statusText),
                        if (request.urgency != 'normal') ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: request.urgency == 'critical' ? 'Critical' : 'Urgent',
                            background: AppColors.gradientHeroEnd,
                            textColor: AppColors.whiteTextOnPrimary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(request.location, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _meta(LucideIcons.mapPin, request.distance),
                        const SizedBox(width: 14),
                        _meta(LucideIcons.hourglass, '${request.units} unit(s)'),
                        const SizedBox(width: 14),
                        _meta(LucideIcons.clock, request.time),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Matched donor', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                    Text(
                      request.matchedDonorName ?? 'Not matched yet',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: request.matchedDonorName == null ? AppColors.textMuted : AppColors.textPrimaryWarm),
                    ),
                  ],
                ),
              ),
              if (request.status == 'matched') ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _confirming ? null : _confirmDonation,
                  child: _confirming
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteTextOnPrimary))
                      : const Text('Confirm donation completed'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                onPressed: () async {
                  final deleted = await confirmAdminDelete(
                    context,
                    what: 'this request',
                    detail: 'Removes it outright — for spam, duplicates or test postings. Use Cancel from the requester\'s side for a normal withdrawal.',
                    onConfirm: () => AdminService.instance.deleteRequest(request.id),
                  );
                  if (deleted && context.mounted) Navigator.pop(context);
                },
                child: const Text('Delete request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
