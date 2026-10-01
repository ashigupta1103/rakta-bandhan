import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/impact_trail.dart';
import '../widgets/urgent_alert_toggle.dart';
import '../widgets/logout_flow.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/rb_ui.dart';
import 'cooldown_screen.dart';
import 'donation_history_screen.dart';
import 'emergency_contact_screen.dart';
import 'notifications_screen.dart';
import 'personal_information_screen.dart';
import 'settings_screen.dart';

/// My Page — the donor's own identity and the one place availability is
/// switched. Order follows what a donor checks: who I am (photo, name,
/// blood group, verification, approximate area), whether I'm available,
/// what I've given, then account destinations.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<String?> _publicArea = Backend.instance.myPublicArea();
  bool _photoBusy = false;
  bool _loggingOut = false;
  bool? _pendingAvailability;

  @override
  void initState() {
    super.initState();
    // A donation the requester completed while this app was closed: start
    // the recovery period now if the server hasn't already.
    Backend.instance.completeMyDonationIfConfirmed().catchError((_) => false);
    // Client-side stand-in for scheduledReactivation.js — flips
    // is_available back on if the 90-day cooldown has already elapsed.
    Backend.instance.maybeReactivate();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logOut() => confirmAndLogOut(
        context,
        isLoading: _loggingOut,
        setLoading: (v) => setState(() => _loggingOut = v),
      );

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
  }

  // ------------------------------------------------------------- photo

  Future<void> _changePhoto({required bool hasPhoto}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.warmGround,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(LucideIcons.camera, size: 20), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
              ListTile(leading: const Icon(LucideIcons.image, size: 20), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(LucideIcons.trash2, size: 20, color: AppColors.red700),
                  title: const Text('Remove photo', style: TextStyle(color: AppColors.red700)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      await _runPhotoAction(() => Backend.instance.removeProfilePhoto(), 'Photo removed.');
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final save = await _previewPhoto(bytes);
    if (save != true || !mounted) return;
    await _runPhotoAction(() => Backend.instance.uploadProfilePhoto(picked), 'Profile photo updated.');
  }

  Future<bool?> _previewPhoto(Uint8List bytes) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.warmGround,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Use this photo?', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(child: Image.memory(bytes, width: 160, height: 160, fit: BoxFit.cover)),
              const SizedBox(height: 12),
              const Text('Only you see this photo, on your own My Page.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save photo')),
          ],
        ),
      );

  Future<void> _runPhotoAction(Future<Object?> Function() action, String done) async {
    setState(() => _photoBusy = true);
    try {
      await action();
      _showSnackBar(done);
    } catch (_) {
      _showSnackBar('Couldn’t update your photo. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _setAvailability(bool value) async {
    setState(() => _pendingAvailability = value);
    try {
      await Backend.instance.setAvailability(value);
      _showSnackBar(value ? 'You’re available to donate' : 'You’re marked as not available');
    } on DonorOnCooldownException catch (e) {
      _showSnackBar(e.toString());
    } catch (_) {
      _showSnackBar('Couldn’t update your availability. Please try again.');
    } finally {
      if (mounted) setState(() => _pendingAvailability = null);
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        title: 'My page',
        onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: Backend.instance.myDonorDocStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message(LucideIcons.cloudOff, 'Couldn’t load your profile', 'Check your connection and try again.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            final data = snapshot.data!.data() ?? {};
            final name = (data['name'] as String? ?? '').trim();
            final bloodGroup = data['blood_group'] as String?;
            final isVerified = data['is_verified'] as bool? ?? false;
            final isAvailable = _pendingAvailability ?? (data['is_available'] as bool? ?? false);
            final reactivateAt = (data['reactivation_scheduled_at'] as Timestamp?)?.toDate();
            final resting = Backend.onCooldown(data);
            final photoUrl = data['photo_url'] as String?;

            return FutureBuilder<int>(
              future: Backend.instance.myDonationCount(),
              builder: (context, donationSnap) {
                final donationCount = donationSnap.data ?? 0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _identityCard(
                      name: name,
                      bloodGroup: bloodGroup,
                      isVerified: isVerified,
                      photoUrl: photoUrl,
                      locationLabel: data['location_label'] as String?,
                    ),
                    const RbSectionLabel('Availability'),
                    RbListGroup(
                      children: [
                        _availabilityCard(isAvailable: isAvailable, resting: resting, reactivateAt: reactivateAt),
                        const UrgentAlertToggle(asCard: false),
                      ],
                    ),
                    const RbSectionLabel('Your impact'),
                    ImpactTrail(
                      count: donationCount,
                      caption: donationCount == 0
                          ? 'No donations recorded yet'
                          : '${donationCount == 1 ? '1 donation' : '$donationCount donations'} recorded through Rakta Bandhan',
                    ),
                    if (reactivateAt != null && reactivateAt.isAfter(DateTime.now())) ...[
                      const SizedBox(height: 14),
                      _cooldownRow(reactivateAt),
                    ],
                    const RbSectionLabel('Account'),
                    RbListGroup(
                      children: [
                        RbRow(icon: LucideIcons.user, title: 'Personal information', onTap: () => _push(const PersonalInformationScreen())),
                        RbRow(icon: LucideIcons.history, title: 'Donation history & certificates', onTap: () => _push(const DonationHistoryScreen())),
                        RbRow(icon: LucideIcons.heartHandshake, title: 'Emergency contact', onTap: () => _push(const EmergencyContactScreen())),
                        RbRow(icon: LucideIcons.slidersHorizontal, title: 'Settings & privacy', onTap: () => _push(const SettingsScreen())),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.ink2, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12)),
                        onPressed: _loggingOut ? null : _logOut,
                        icon: _loggingOut
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.logOut, size: 17),
                        label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _identityCard({
    required String name,
    required String? bloodGroup,
    required bool isVerified,
    required String? photoUrl,
    required String? locationLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _avatar(name: name, photoUrl: photoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Your profile' : name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.display(fontSize: 24, color: AppColors.ink, height: 1.15)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (bloodGroup != null)
                      _chip(
                        leading: BloodGroupDroplet(label: '', size: 12, filled: true, color: AppColors.brandRed, textColor: Colors.white),
                        text: '$bloodGroup donor',
                        bg: AppColors.red100,
                        fg: AppColors.red700,
                      ),
                    _chip(
                      leading: Icon(isVerified ? LucideIcons.badgeCheck : LucideIcons.clock, size: 13, color: isVerified ? AppColors.successText : AppColors.goldDeep),
                      text: isVerified ? 'Verified' : 'Verification pending',
                      bg: isVerified ? AppColors.warmGreenBg : AppColors.goldTint,
                      fg: isVerified ? AppColors.successText : AppColors.goldDeep,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<String?>(
                  future: _publicArea,
                  builder: (context, snap) {
                    final area = snap.data;
                    final text = area != null ? 'Approx. area: $area' : Backend.shortPlace(locationLabel, fallback: 'Area not set');
                    return Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 14, color: AppColors.ink2),
                        const SizedBox(width: 6),
                        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.ink2))),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({required String name, required String? photoUrl}) {
    final initials = Container(
      color: AppColors.red100,
      alignment: Alignment.center,
      child: Text(_initials(name), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.brandRed)),
    );
    return Semantics(
      button: true,
      label: photoUrl == null ? 'Add a profile photo' : 'Change profile photo',
      child: GestureDetector(
        onTap: _photoBusy ? null : () => _changePhoto(hasPhoto: photoUrl != null),
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: photoUrl == null
                      ? initials
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null
                              ? child
                              : Container(color: AppColors.sand, alignment: Alignment.center, child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                          errorBuilder: (context, error, stack) => initials,
                        ),
                ),
              ),
              if (_photoBusy)
                ClipOval(
                  child: Container(
                    width: 84,
                    height: 84,
                    color: AppColors.ink.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({required Widget leading, required String text, required Color bg, required Color fg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      );

  Widget _availabilityCard({required bool isAvailable, required bool resting, required DateTime? reactivateAt}) {
    final saving = _pendingAvailability != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: isAvailable ? AppColors.successBg : AppColors.sand, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: PulsingDot(color: isAvailable ? AppColors.successText : AppColors.mutedInk, size: 9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available to donate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  resting && reactivateAt != null
                      ? 'Resting after your donation · you can turn this on in ${_eligibleInDays(reactivateAt)} days'
                      : isAvailable
                          ? 'On — nearby requesters can find you and alerts can reach you'
                          : 'Off — you’re hidden from the donor map and alerts',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.35),
                ),
              ],
            ),
          ),
          if (saving) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8)),
          // Locked off during the 90-day rest period.
          RbSwitch(value: isAvailable, onChanged: resting || saving ? null : _setAvailability),
        ],
      ),
    );
  }

  Widget _cooldownRow(DateTime reactivateAt) => Material(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CooldownScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                const Icon(LucideIcons.hourglass, size: 16, color: AppColors.goldDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Recovering · eligible again in ${_eligibleInDays(reactivateAt)} days',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.goldDeep),
              ],
            ),
          ),
        ),
      );

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _message(IconData icon, String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: AppColors.ink2),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
              const SizedBox(height: 6),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2)),
            ],
          ),
        ),
      );

  int _eligibleInDays(DateTime reactivateAt) {
    final remaining = reactivateAt.difference(DateTime.now());
    return remaining.inDays < 0 ? 0 : remaining.inDays + 1;
  }
}
