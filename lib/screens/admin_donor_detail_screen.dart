import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_service.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/status_badge.dart';
import 'admin_content_tab.dart' show confirmAdminDelete;

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
                  Text('ID proof', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  const SizedBox(height: 8),
                  _IdProofView(donorId: donor.id),
                  if (donor.status == DonorVerificationStatus.pending) ...[
                    const SizedBox(height: 20),
                    _VerificationChecklist(
                      donorName: donor.name,
                      phone: donor.phone,
                      onVerify: () => service.verifyDonor(donor.id),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
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
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                    onPressed: () async {
                      final deleted = await confirmAdminDelete(
                        context,
                        what: '${donor.name}\'s profile',
                        detail: 'This removes their profile from Firestore. Their sign-in stays active — use Ban to actually lock them out.',
                        onConfirm: () => service.deleteDonor(donor.id),
                      );
                      if (deleted && context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Delete profile'),
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

/// Verification is a checklist, not a single tap: each step must be ticked
/// before "Verify donor" unlocks, so every admin checks the same things.
/// Verifying deletes the ID photo (Backend.adminVerifyDonor) — we keep only
/// the fact and date it was checked.
class _VerificationChecklist extends StatefulWidget {
  final String donorName;
  final String phone;
  final Future<void> Function() onVerify;
  const _VerificationChecklist({required this.donorName, required this.phone, required this.onVerify});

  @override
  State<_VerificationChecklist> createState() => _VerificationChecklistState();
}

class _VerificationChecklistState extends State<_VerificationChecklist> {
  static const _steps = [
    ('ID photo is clear and readable', 'Aadhaar, PAN, driving licence, voter ID or passport'),
    ('Name on the ID matches the profile', 'Minor spelling differences are fine'),
    ('Donor is 18 or older', 'Check the date of birth on the ID'),
    ('Phone number answered and confirmed', 'Call or WhatsApp the number and confirm they registered'),
    ('Blood group confirmed with the donor', 'Ask how they know it — donor card, lab report or earlier donation'),
  ];
  final _checked = List<bool>.filled(_steps.length, false);
  bool _busy = false;

  Future<void> _verify() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onVerify();
      messenger.showSnackBar(SnackBar(content: Text('${widget.donorName} is verified. Their ID photo has been deleted.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not verify. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _checked.every((c) => c);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorderWarm), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Verification steps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              ),
              Text('${_checked.where((c) => c).length}/${_steps.length}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _steps.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.warmGreenText,
              value: _checked[i],
              onChanged: (v) => setState(() => _checked[i] = v ?? false),
              title: Text(_steps[i].$1, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimaryWarm)),
              subtitle: Text(_steps[i].$2, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ),
          if (widget.phone.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: widget.phone)),
                icon: const Icon(LucideIcons.phone, size: 15),
                label: Text('Call ${widget.phone}'),
              ),
            ),
          const SizedBox(height: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmGreenText),
            onPressed: allDone && !_busy ? _verify : null,
            child: Text(_busy ? 'Verifying…' : (allDone ? 'Verify donor' : 'Complete every step to verify')),
          ),
        ],
      ),
    );
  }
}

/// Loads the ID image once, from its own document (see
/// Backend.uploadIdProof) — admins open one donor at a time, so the donor
/// list itself never downloads images.
class _IdProofView extends StatefulWidget {
  final String donorId;
  const _IdProofView({required this.donorId});

  @override
  State<_IdProofView> createState() => _IdProofViewState();
}

class _IdProofViewState extends State<_IdProofView> {
  late final Future<String?> _proof = Backend.instance.fetchIdProof(widget.donorId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _proof,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final b64 = snap.data;
        if (b64 == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.dividerWarm, borderRadius: BorderRadius.circular(14)),
            child: const Text('Not uploaded yet.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          );
        }
        final bytes = base64Decode(b64);
        return GestureDetector(
          onTap: () => showDialog(context: context, builder: (context) => Dialog(child: InteractiveViewer(child: Image.memory(bytes)))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(bytes, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
