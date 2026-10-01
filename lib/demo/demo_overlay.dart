import 'package:flutter/material.dart';

import '../screens/donation_confirm_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/call_screen.dart';
import '../services/call_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/rb_icon.dart';
import '../widgets/rb_ui.dart';
import 'demo.dart';
import 'demo_hub_screen.dart';

/// The presenter's controls while a client demo runs: a small "Demo" tab at
/// the top right of every screen. It opens a sheet that moves the story
/// forward (the other person accepts / confirms / calls), restarts the
/// journey, or leaves the demo. Rendered from MaterialApp.builder; nothing
/// shows unless [Demo.on].
class DemoOverlay extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const DemoOverlay({super.key, required this.child, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Demo.instance,
      builder: (context, _) => Stack(
        children: [
          child,
          if (Demo.on)
            Positioned(
              // Top centre: clear of back buttons (left) and header
              // actions (right).
              top: MediaQuery.paddingOf(context).top + 2,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                color: AppColors.goldDeepest,
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _openControls(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Text('Demo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.goldTint)),
                  ),
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }

  void _openControls() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.warmGround,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => _DemoControls(navigatorKey: navigatorKey),
    );
  }
}

class _DemoControls extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const _DemoControls({required this.navigatorKey});

  NavigatorState get _nav => navigatorKey.currentState!;

  void _home(BuildContext sheet, {int tab = 0}) {
    Navigator.pop(sheet);
    _nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => MainNavigationScreen(initialTab: tab)), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final d = Demo.instance;
    final r = d.request;
    final status = r?['status'];
    final requester = d.role == DemoRole.requester;
    final peerConfirmed = r?[requester ? 'donor_confirmed_at' : 'requester_confirmed_at'] != null;
    final steps = <(RbGlyph, String, VoidCallback)>[
      if (requester && status == 'open')
        (RbGlyph.connect, '${Demo.donorName} accepts now', () {
          Navigator.pop(context);
          d.match();
        }),
      if (status == 'matched' && !peerConfirmed)
        (RbGlyph.checkCircle, '${d.peerName} confirms the donation', () {
          Navigator.pop(context);
          d.confirmPeer();
        }),
      if (status == 'matched')
        (RbGlyph.phone, 'Incoming call from ${d.peerName}', () {
          Navigator.pop(context);
          _nav.push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallScreen(
              incoming: IncomingCall(requestId: Demo.requestId, callId: 'demo-call', callerUid: d.peerUid, callerName: d.peerName),
            ),
          ));
        }),
      if (status == 'fulfilled' && !requester)
        (RbGlyph.heart, 'Show the thank-you screen', () {
          Navigator.pop(context);
          _nav.push(MaterialPageRoute(builder: (_) => const DonationConfirmScreen()));
        }),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Demo controls', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              'Playing as ${d.myName} (${requester ? 'needs blood' : 'donor'}). Simulated data — nothing is sent or saved.',
              style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.4),
            ),
            if (steps.isNotEmpty) ...[
              const RbSectionLabel('Move the story forward', padding: EdgeInsets.fromLTRB(2, 16, 2, 8)),
              RbListGroup(children: [for (final (g, t, go) in steps) RbRow(icon: g, title: t, onTap: go)]),
            ],
            const RbSectionLabel('Session', padding: EdgeInsets.fromLTRB(2, 16, 2, 8)),
            RbListGroup(
              children: [
                RbRow(icon: RbGlyph.home, tone: RbTone.neutral, title: 'Go to home', onTap: () => _home(context)),
                RbRow(
                  icon: RbGlyph.retry,
                  tone: RbTone.neutral,
                  title: 'Reset demo',
                  subtitle: 'Back to the start of this journey. Local demo data only.',
                  onTap: () {
                    d.reset();
                    _home(context);
                  },
                ),
                RbRow(
                  icon: RbGlyph.more,
                  tone: RbTone.neutral,
                  title: 'All demo journeys',
                  onTap: () {
                    Navigator.pop(context);
                    _nav.push(MaterialPageRoute(builder: (_) => const DemoHubScreen()));
                  },
                ),
                RbRow(
                  icon: RbGlyph.logout,
                  destructive: true,
                  title: 'Exit demo',
                  onTap: () {
                    d.stop();
                    Navigator.pop(context);
                    _nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
