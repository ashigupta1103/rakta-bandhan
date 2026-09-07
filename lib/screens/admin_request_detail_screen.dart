import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';

class AdminRequestDetailScreen extends StatelessWidget {
  final AdminRequestEntry request;

  const AdminRequestDetailScreen({super.key, required this.request});

  (Color, Color) _statusStyle(String status) => switch (status) {
        'open' => (AppColors.statusUrgentBg, AppColors.statusUrgentText),
        'matched' => (AppColors.statusPendingBg, AppColors.statusPendingText),
        'fulfilled' => (AppColors.statusAvailableBg, AppColors.statusAvailableText),
        _ => (AppColors.cardBorderWarm, AppColors.textPrimaryWarm),
      };

  @override
  Widget build(BuildContext context) {
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
