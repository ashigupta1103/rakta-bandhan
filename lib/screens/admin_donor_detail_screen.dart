import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/status_badge.dart';

class AdminDonorDetailScreen extends StatelessWidget {
  final String donorId;

  const AdminDonorDetailScreen({super.key, required this.donorId});

  (Color, Color, String) _statusStyle(DonorVerificationStatus status) => switch (status) {
        DonorVerificationStatus.pending => (AppColors.warmAmberBg, AppColors.warmAmberText, 'Pending verification'),
        DonorVerificationStatus.verified => (AppColors.warmGreenBg, AppColors.warmGreenText, 'Verified'),
        DonorVerificationStatus.banned => (AppColors.statusUrgentBg, AppColors.primary, 'Banned'),
      };

  @override
  Widget build(BuildContext context) {
    final service = AdminService.instance;
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
        title: const Text('Donor details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final donor = service.donors.firstWhere((d) => d.id == donorId);
            final (statusBg, statusText, statusLabel) = _statusStyle(donor.status);
            final initials = donor.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: AvatarBadge(initials: initials, size: 72, fontSize: 22)),
                  const SizedBox(height: 12),
                  Text(donor.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusBadge.bloodGroup(donor.bloodGroup),
                      const SizedBox(width: 8),
                      StatusBadge(label: statusLabel, background: statusBg, textColor: statusText),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _row('Phone', donor.phone),
                        const Divider(height: 24, color: AppColors.cardBorderWarm),
                        _row('Location', donor.location),
                        const Divider(height: 24, color: AppColors.cardBorderWarm),
                        _row('Joined', donor.joinedOn),
                        const Divider(height: 24, color: AppColors.cardBorderWarm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Availability', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: donor.available ? AppColors.warmGreenText : AppColors.textMuted),
                                ),
                                Text(donor.available ? 'Available' : 'Unavailable', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (donor.status != DonorVerificationStatus.verified)
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmGreenText),
                            onPressed: () => service.verifyDonor(donor.id),
                            child: const Text('Verify'),
                          ),
                        ),
                      if (donor.status != DonorVerificationStatus.verified) const SizedBox(width: 8),
                      Expanded(
                        child: donor.status == DonorVerificationStatus.banned
                            ? OutlinedButton(onPressed: () => service.unbanDonor(donor.id), child: const Text('Unban'))
                            : OutlinedButton(onPressed: () => service.banDonor(donor.id), child: const Text('Ban')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => service.toggleAvailability(donor.id),
                    child: Text(donor.available ? 'Mark unavailable' : 'Mark available'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
      ],
    );
  }
}
