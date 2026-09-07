import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/notifications_service.dart';
import '../theme/app_colors.dart';
import '../widgets/blood_group_droplet.dart';

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
                    'Notifications',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<NotificationsFeed>(
                  key: ValueKey(_retryToken),
                  stream: _service.watchNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: _errorState(() => setState(() => _retryToken++)),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final feed = snapshot.data!;
                    if (!feed.enabled) return _disabledState();
                    if (feed.items.isEmpty) return _emptyState();

                    // Exactly one actionable item earns the only card and
                    // the only button — the first request-kind notification.
                    final actionableIndex = feed.items.indexWhere((n) => n.kind == NotificationKind.request);
                    final actionable = actionableIndex == -1 ? null : feed.items[actionableIndex];
                    final rest = [for (var i = 0; i < feed.items.length; i++) if (i != actionableIndex) feed.items[i]];

                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        if (actionable != null) ...[
                          const Text('NEEDS YOU NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          _actionableCard(actionable),
                          const SizedBox(height: 22),
                        ],
                        if (rest.isNotEmpty) ...[
                          const Text('EARLIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: AppColors.textSecondary)),
                          for (var i = 0; i < rest.length; i++) _archivalRow(rest[i], showDivider: i < rest.length - 1),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disabledState() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.warmAmberBg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.bellOff, size: 17, color: AppColors.warmAmberText),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications are off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A4A08))),
                    SizedBox(height: 2),
                    Text('Turn them on to hear about nearby requests instantly.', style: TextStyle(fontSize: 12, color: Color(0xFF8A7350))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permissions coming soon')),
            ),
            child: const Text('Enable notifications'),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.cardBorderWarm)),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.bell, size: 20, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            const Text('No notifications yet.', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.wifiOff, size: 20, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text("Couldn't load notifications", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
          const SizedBox(height: 4),
          const Text('Check your connection and try again.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// The one actionable item: red-edge card, group droplet, primary button.
  Widget _actionableCard(AppNotification n) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: AppColors.primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BloodGroupDroplet(label: '', size: 40, filled: true, color: AppColors.primary, textColor: Color(0xFFFBE6E8), centerIcon: Icon(LucideIcons.droplet, size: 16, color: Color(0xFFFBE6E8))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                          const SizedBox(height: 2),
                          Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ElevatedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening request — coming soon.'))),
                  child: const Text('View request'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Archival items sit on the ground with a hairline divider — a plain
  /// grey dot for neutral events, a small green droplet for positive ones
  /// (match / donation confirmed) per the approved device vocabulary.
  Widget _archivalRow(AppNotification n, {required bool showDivider}) {
    final isPositive = n.kind == NotificationKind.match || n.kind == NotificationKind.donationConfirmed;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: showDivider ? const Border(bottom: BorderSide(color: AppColors.dividerWarm)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: isPositive
                ? const Icon(LucideIcons.droplet, size: 14, color: AppColors.warmGreenText)
                : Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.chevronMuted, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                const SizedBox(height: 3),
                Text(n.body, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(n.time, style: const TextStyle(fontSize: 11, color: AppColors.textMutedWarm)),
        ],
      ),
    );
  }
}
