import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/backend.dart';
import '../services/urgent_alert_service.dart';
import '../theme/app_colors.dart';
import 'rb_ui.dart';
import 'brand_glyph.dart';

/// "Ring me for urgent requests" — the donor's opt-in to the full-screen,
/// sounding alert. Off by default. Turning it on first explains exactly
/// what will happen (so the OS permission prompt that follows isn't a
/// surprise), then asks for notification permission. Used on My Page and
/// in Settings; both read the same `donors/{uid}.urgent_alerts` field, so
/// they can never disagree.
class UrgentAlertToggle extends StatefulWidget {
  /// Settings renders it as a plain list row; My Page as a raised card.
  final bool asCard;

  const UrgentAlertToggle({super.key, this.asCard = true});

  @override
  State<UrgentAlertToggle> createState() => _UrgentAlertToggleState();
}

class _UrgentAlertToggleState extends State<UrgentAlertToggle> {
  bool _busy = false;

  Future<void> _turnOn() async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandGlyph(icon: LucideIcons.bell, size: 48),
              const SizedBox(height: 16),
              const Text('Ring me for urgent requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'When someone near you urgently needs a blood group you can give, your phone plays a chime and shows the request full-screen — like a ride request. You decide whether to accept.',
                style: TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.5),
              ),
              const SizedBox(height: 14),
              _point(LucideIcons.flame, 'Only urgent and critical requests'),
              _point(LucideIcons.mapPin, 'Only within ${UrgentAlertService.radiusKm.round()} km of your registered area'),
              _point(LucideIcons.bellOff, 'Never while you’re unavailable or already matched'),
              _point(LucideIcons.info, 'Rings while Rakta Bandhan is open. Alerts with the app closed arrive in an upcoming update.'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Turn on alerts')),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(sheet, false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final systemAllowed = await UrgentAlertService.instance.requestPushPermission();
      await Backend.instance.setUrgentAlerts(true);
      messenger.showSnackBar(SnackBar(
        content: Text(systemAllowed
            ? 'Urgent alerts are on.'
            : 'Urgent alerts are on in the app. System notifications are off — you can allow them in device settings.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not turn on alerts. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    setState(() => _busy = true);
    try {
      await Backend.instance.setUrgentAlerts(false);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: AppColors.brandRed)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    // Signed out (e.g. the preview gallery): nothing to toggle.
    if (Backend.instance.currentUser == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: Backend.instance.myDonorDocStream(),
      builder: (context, snap) {
        final on = snap.data?.data()?['urgent_alerts'] == true;
        final row = RbRow(
          icon: on ? LucideIcons.bellRing : LucideIcons.bellOff,
          tone: on ? RbTone.red : RbTone.neutral,
          title: 'Ring me for urgent requests',
          subtitle: on ? 'Full-screen alert with sound for urgent needs nearby' : 'Off — you’ll still see requests in the Requests tab',
          trailing: _busy
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : RbSwitch(value: on, onChanged: snap.hasData ? ((v) => v ? _turnOn() : _turnOff()) : null),
        );
        if (!widget.asCard) return row;
        return RbListGroup(children: [row]);
      },
    );
  }
}
