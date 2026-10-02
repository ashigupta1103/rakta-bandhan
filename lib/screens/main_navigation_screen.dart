import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/chat_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/live_events_host.dart';
import 'community_screen.dart';
import 'find_donors_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import '../widgets/rb_icon.dart';

/// The four-tab consumer shell from the final artifact ("The four-tab
/// shell"): Request / Find / Community / My Page — replacing the previous
/// Home / Requests / Profile shell. Home's content is absorbed into the
/// Request tab (the ranked "you can help" / "yours" list already lived in
/// RequestsScreen); Home itself is left in place, unreferenced, rather than
/// deleted.
class MainNavigationScreen extends StatefulWidget {
  /// Tab to open on (0 Request, 1 Find, 2 Community, 3 My Page).
  final int initialTab;

  const MainNavigationScreen({super.key, this.initialTab = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // Push token + topics for this signed-in phone (asks for notification
    // permission the first time). Needs the blood group for its topic.
    Backend.instance.myDonorDoc().then((snap) {
      PushService.instance.registerDevice(bloodGroup: snap.data()?['blood_group'] as String?);
    }).catchError((_) {});
  }

  final List<Widget> _screens = const [
    RequestsScreen(),
    FindDonorsScreen(showBackButton: false),
    CommunityScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (icon: RbGlyph.droplet, label: 'Request'),
    (icon: RbGlyph.radar, label: 'Find'),
    (icon: RbGlyph.community, label: 'Community'),
    (icon: RbGlyph.person, label: 'My Page'),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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

    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One indicator only: a tinted pill behind the active icon.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 56,
              height: 30,
              decoration: BoxDecoration(color: isActive ? AppColors.red100 : Colors.transparent, borderRadius: BorderRadius.circular(999)),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RbIcon(tab.icon, size: 21, color: isActive ? AppColors.brandRed : AppColors.ink2),
                  if (showUnreadDot)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.ink : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
