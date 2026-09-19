import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';

/// Read-only view of the donor record.
///
/// Reads the real Firestore document via Backend.myDonorDocStream() — no
/// mock involved. Editing is deliberately NOT offered: `Backend` exposes
/// registerDonor() and setAvailability() only, with no profile-update
/// method, and inventing one would mean writing Firestore fields the
/// backend contract does not define. The footer states this plainly rather
/// than showing a disabled Edit button that implies otherwise.
class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Personal information',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: Backend.instance.myDonorDocStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final data = snapshot.data!.data() ?? {};
                  final name = data['name'] as String? ?? '—';
                  final phone = data['phone'] as String? ?? '—';
                  final bloodGroup = data['blood_group'] as String? ?? '—';
                  final isVerified = data['is_verified'] as bool? ?? false;
                  final createdAt = data['created_at'] as Timestamp?;
                  final lat = data['lat'] as num?;
                  final lng = data['lng'] as num?;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text(_initials(name), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ),
                                if (bloodGroup != '—')
                                  Positioned(
                                    right: -6,
                                    bottom: -4,
                                    child: BloodGroupDroplet(label: bloodGroup, size: 26, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 9),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.isEmpty ? '—' : name, style: AppTextStyles.display(fontSize: 20, color: AppColors.textPrimaryWarm)),
                                  const SizedBox(height: 4),
                                  Text(phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _card([
                          _row(LucideIcons.droplet, 'Blood group', bloodGroup, emphasise: true),
                          _row(LucideIcons.phone, 'Phone number', phone),
                          _row(
                            LucideIcons.calendar,
                            'Member since',
                            createdAt == null ? '—' : _formatDate(createdAt.toDate()),
                            isLast: true,
                          ),
                        ]),
                        const SizedBox(height: 18),
                        _sectionLabel('Verification'),
                        _card([
                          _row(
                            isVerified ? LucideIcons.badgeCheck : LucideIcons.clock,
                            'Status',
                            isVerified ? 'Verified' : 'Pending review',
                            valueColor: isVerified ? AppColors.warmGreenText : AppColors.warmAmberText,
                            iconBg: isVerified ? AppColors.warmGreenBg : AppColors.warmAmberBg,
                            iconColor: isVerified ? AppColors.warmGreenText : AppColors.warmAmberText,
                            isLast: true,
                          ),
                        ]),
                        const SizedBox(height: 18),
                        _sectionLabel('Location'),
                        _card([
                          _row(
                            LucideIcons.mapPin,
                            'Approximate area',
                            lat == null || lng == null
                                ? 'Not set'
                                : '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}',
                            isLast: true,
                          ),
                        ]),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Other people only ever see your distance, never these coordinates or your address.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMutedWarm, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.dividerWarm,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Editing your details is not available yet — the profile-update endpoint is still to be built. Contact an administrator if something here is wrong.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMutedWarm,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorderWarm),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _row(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
    bool emphasise = false,
    Color? valueColor,
    Color iconBg = AppColors.dividerWarm,
    Color iconColor = AppColors.textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.dividerWarm)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          emphasise
              ? Text(value, style: AppTextStyles.display(fontSize: 17, color: AppColors.primary))
              : Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimaryWarm,
                  ),
                ),
        ],
      ),
    );
  }
}
