import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/notifications_service.dart';
import '../services/urgent_alert_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/rb_ui.dart';
import 'match_contact_screen.dart';
import 'tracking_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsService _service = FirestoreNotificationsService();
  int _retryToken = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: StreamBuilder<NotificationsFeed>(
        key: ValueKey(_retryToken),
        stream: _service.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                RbStatePanel.error(
                  title: "Couldn't load notifications",
                  message: 'Check your connection and try again.',
                  onRetry: () => setState(() => _retryToken++),
                ),
              ],
            );
          }
          if (!snapshot.hasData) return const RbLoading(height: 240);
          final feed = snapshot.data!;

          // Exactly one actionable item earns the only card and the only
          // button — the first request-kind notification.
          final actionableIndex = feed.items.indexWhere((n) => n.kind == NotificationKind.request);
          final actionable = actionableIndex == -1 ? null : feed.items[actionableIndex];
          final rest = [for (var i = 0; i < feed.items.length; i++) if (i != actionableIndex) feed.items[i]];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              if (!feed.enabled) _disabledBanner(),
              if (feed.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: RbStatePanel(
                    icon: LucideIcons.bell,
                    title: 'You’re all caught up',
                    message: 'Matches, messages and updates on your requests will appear here.',
                  ),
                ),
              if (actionable != null) ...[
                const RbSectionLabel('Needs you now', padding: EdgeInsets.fromLTRB(2, 8, 2, 10)),
                _actionableCard(actionable),
              ],
              if (rest.isNotEmpty) ...[
                const RbSectionLabel('Earlier'),
                RbListGroup(children: [for (final n in rest) _archivalRow(n)]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _disabledBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: RbCard(
        color: AppColors.goldTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.bellOff, size: 18, color: AppColors.goldDeep),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications are off', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.goldDeepest)),
                      SizedBox(height: 2),
                      Text('Turn them on to hear about nearby requests and messages straight away.', style: TextStyle(fontSize: 13, color: AppColors.goldDeep, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final allowed = await UrgentAlertService.instance.requestPushPermission();
                messenger.showSnackBar(SnackBar(
                  content: Text(allowed ? 'Notifications are on.' : 'Notifications are still off — allow them in your device settings.'),
                ));
              },
              child: const Text('Turn on notifications'),
            ),
          ],
        ),
      ),
    );
  }

  /// The one actionable item: red-edge card, group droplet, primary button.
  /// Feed ids are `<requestId>_<event>` (see FirestoreNotificationsService),
  /// so the request is recoverable without widening AppNotification.
  void _openRequest(AppNotification n) {
    final sep = n.id.lastIndexOf('_');
    if (sep <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is sample data in preview mode.')));
      return;
    }
    final requestId = n.id.substring(0, sep);
    // A cancellation is the donor-side event; everything else in the feed
    // is about the requester's own request.
    final screen = n.kind == NotificationKind.cancellation ? MatchContactScreen(requestId: requestId) : TrackingScreen(requestId: requestId);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _actionableCard(AppNotification n) {
    return RbCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: AppColors.brandRed),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BloodGroupDroplet(label: '', size: 40, centerIcon: Icon(LucideIcons.droplet, size: 16, color: AppColors.onEmber)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.25)),
                          const SizedBox(height: 3),
                          Text(n.body, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(n.time, style: const TextStyle(fontSize: 12, color: AppColors.mutedInk)),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton(onPressed: () => _openRequest(n), child: const Text('View request')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Earlier events: green droplet for positive ones (match / donation
  /// confirmed), a neutral bell otherwise.
  Widget _archivalRow(AppNotification n) {
    final isPositive = n.kind == NotificationKind.match || n.kind == NotificationKind.donationConfirmed;
    return RbRow(
      icon: isPositive ? LucideIcons.droplet : (n.kind == NotificationKind.cancellation ? LucideIcons.circleX : LucideIcons.bell),
      tone: isPositive ? RbTone.success : RbTone.neutral,
      title: n.title,
      subtitle: n.body,
      trailing: Text(n.time, style: const TextStyle(fontSize: 12, color: AppColors.mutedInk)),
    );
  }
}
