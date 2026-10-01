import 'package:flutter/material.dart';

import '../preview_mode.dart';
import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/cooldown_screen.dart';
import '../services/call_service.dart';
import '../screens/donation_confirm_screen.dart';
import '../screens/donation_history_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/preview_gallery_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/rb_icon.dart';
import '../widgets/rb_ui.dart';
import 'demo.dart';

/// Entry point for a client presentation. Reachable only from the sign-in
/// screen of a preview build (see [kEnablePreviewUi]); every journey runs
/// the real screens on local demo state ([Demo]) and writes nothing.
class DemoHubScreen extends StatelessWidget {
  const DemoHubScreen({super.key});

  /// Replaces the whole stack, so "back" inside a journey never lands on a
  /// half-finished earlier one.
  static void _launch(BuildContext context, Widget Function() screen, {List<Widget Function()> then = const []}) {
    final nav = Navigator.of(context);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen()), (r) => false);
    for (final s in then) {
      nav.push(MaterialPageRoute(builder: (_) => s()));
    }
  }

  static void _completedDonation() {
    Demo.instance.start(DemoRole.donor);
    Demo.instance.match();
    Demo.instance.confirmPeer();
    Demo.instance.confirmMine();
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnablePreviewUi) return const SizedBox.shrink();
    final journeys = <(RbGlyph, String, String, VoidCallback)>[
      (RbGlyph.person, 'New user registration', 'Email code → details → phone code → consent', () {
        Demo.instance.start(DemoRole.requester, registered: false);
        _launch(context, () => const LoginScreen());
      }),
      (RbGlyph.mail, 'Existing user sign-in', 'Email → 6-digit code → home', () {
        Demo.instance.start(DemoRole.requester);
        _launch(context, () => const LoginScreen());
      }),
      (RbGlyph.droplet, 'Request blood', 'Raise a request → search → donor accepts → track', () {
        Demo.instance.start(DemoRole.requester);
        _launch(context, () => const MainNavigationScreen());
      }),
      (RbGlyph.heart, 'Donor receives a request', 'See the request → accept → contact → donate', () {
        Demo.instance.start(DemoRole.donor);
        _launch(context, () => const MainNavigationScreen());
      }),
    ];
    final scenes = <(RbGlyph, String, VoidCallback)>[
      (RbGlyph.message, 'Chat', () {
        Demo.instance.start(DemoRole.requester);
        Demo.instance.match();
        _launch(context, () => const MainNavigationScreen(), then: [() => const ChatScreen(requestId: Demo.requestId)]);
      }),
      (RbGlyph.phone, 'In-app call', () {
        Demo.instance.start(DemoRole.requester);
        Demo.instance.match();
        _launch(context, () => const MainNavigationScreen(), then: [
          () => const IncomingCallScreen(
                incoming: IncomingCall(requestId: Demo.requestId, callId: 'demo-call', callerUid: Demo.donorUid, callerName: Demo.donorName),
              ),
        ]);
      }),
      (RbGlyph.checkCircle, 'Donation completed', () {
        _completedDonation();
        _launch(context, () => const MainNavigationScreen(), then: [() => const DonationConfirmScreen()]);
      }),
      (RbGlyph.certificate, 'Donation history & certificate', () {
        _completedDonation();
        _launch(context, () => const MainNavigationScreen(), then: [() => const DonationHistoryScreen()]);
      }),
      (RbGlyph.hourglass, 'Recovery & word riddle', () {
        _completedDonation();
        _launch(context, () => const MainNavigationScreen(), then: [() => const CooldownScreen()]);
      }),
      (RbGlyph.community, 'Community & testimonial', () {
        _completedDonation();
        _launch(context, () => const MainNavigationScreen(initialTab: 2));
      }),
    ];

    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(tooltip: 'Back', icon: const RbIcon(RbGlyph.back, color: AppColors.ink), onPressed: () => Navigator.pop(context)),
        title: const Text('Client demo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text('Walk through Rakta Bandhan', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text(
            'Every journey runs the real app screens on simulated, local data. Nothing is sent or saved — no emails, SMS, Firebase records or calls. '
            'People shown (${Demo.requesterName}, ${Demo.donorName}) are fictional demo personas.',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.5),
          ),
          const RbSectionLabel('Full journeys'),
          RbListGroup(
            children: [
              for (final (glyph, title, sub, go) in journeys) RbRow(icon: glyph, title: title, subtitle: sub, onTap: go),
            ],
          ),
          const RbSectionLabel('Jump to a scene'),
          RbListGroup(
            children: [
              for (final (glyph, title, go) in scenes) RbRow(icon: glyph, tone: RbTone.neutral, title: title, onTap: go),
            ],
          ),
          const RbSectionLabel('Screen gallery'),
          RbListGroup(
            children: [
              RbRow(
                icon: RbGlyph.page,
                tone: RbTone.neutral,
                title: 'Browse every screen',
                subtitle: 'Static layouts with sample data, for design review',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreviewGalleryScreen())),
              ),
            ],
          ),
          const RbSectionLabel('Demo codes'),
          const RbCard(
            color: AppColors.goldTint,
            child: Text(
              'Email ${Demo.email} · sign-in code ${Demo.emailCode}\nPhone code during registration ${Demo.phoneOtp}\n'
              'While a demo runs, the small “Preview” tab on the left edge resets it, moves the story forward, or exits.',
              style: TextStyle(fontSize: 13, color: AppColors.goldDeepest, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
