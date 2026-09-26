import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../widgets/live_events_host.dart';
import 'community_screen.dart';
import 'find_donors_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';

/// The four-tab consumer shell from the final artifact ("The four-tab
/// shell"): Request / Find / Community / My Page — replacing the previous
/// Home / Requests / Profile shell. Home's content is absorbed into the
/// Request tab (the ranked "you can help" / "yours" list already lived in
/// RequestsScreen); Home itself is left in place, unreferenced, rather than
/// deleted.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    RequestsScreen(),
    FindDonorsScreen(showBackButton: false),
    CommunityScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (icon: LucideIcons.droplet, label: 'Request'),
    (icon: LucideIcons.radar, label: 'Find'),
    (icon: LucideIcons.heartHandshake, label: 'Community'),
    (icon: LucideIcons.user, label: 'My Page'),
  ];

  // No unread-activity source exists yet (Community has no backend feed in
  // this phase) — the gold dot capability is wired but stays off.
  static const _communityHasUnread = false;

  // The ~430px mobile-width centering on wide viewports lives in
  // MaterialApp.builder (main.dart) so it covers every route, not just this
  // tab shell — see the comment there.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // LiveEventsHost: incoming in-app calls and opted-in urgent alerts
      // interrupt from here, whichever tab or pushed screen is showing.
      body: LiveEventsHost(child: IndexedStack(index: _currentIndex, children: _screens)),
      // Unread messages put a dot on the Request tab (where the Messages
      // inbox lives), so a reply is noticed from any tab.
      bottomNavigationBar: StreamBuilder<int>(
        stream: _unread,
        builder: (context, snap) => _bottomNav(requestHasUnread: (snap.data ?? 0) > 0),
      ),
    );
  }

  late final Stream<int> _unread = ChatService.instance.watchUnreadCount();

  Widget _bottomNav({required bool requestHasUnread}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.warmBorder)),
        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) Expanded(child: _tabButton(index: i, requestHasUnread: requestHasUnread)),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({required int index, required bool requestHasUnread}) {
    final isActive = _currentIndex == index;
    final tab = _tabs[index];
    final showUnreadDot = (index == 2 && _communityHasUnread && !isActive) || (index == 0 && requestHasUnread);
    final dotColor = index == 0 ? AppColors.brandRed : AppColors.gold;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.red100 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 3,
              width: 20,
              child: isActive
                  ? DecoratedBox(decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(999)))
                  : null,
            ),
            const SizedBox(height: 3),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(tab.icon, size: 22, color: isActive ? AppColors.brandRed : AppColors.ink2),
                if (showUnreadDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.brandRed : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
