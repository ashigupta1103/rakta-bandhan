// Regression check for the More-menu back-navigation bug: opening a
// destination from the header's ellipsis "More" sheet and then going back
// (in-app back button or Android system back — both route through
// Navigator.pop on the current Navigator, so popping programmatically here
// exercises the same mechanism either trigger would use) must return to the
// More sheet, not fall straight through to the screen underneath it.
//
// The fix lives in lib/widgets/app_header.dart's _moreGroup: destinations
// are pushed with Navigator.push using the sheet's own context, on top of
// the still-open ModalBottomSheetRoute, instead of popping the sheet first.
// Every destination shares that one code path, so this test parametrizes
// across all six rather than only checking Testimonials.
//
// Route stack identity (via a NavigatorObserver), not widget-text presence,
// is what's asserted: an obscured route stays mounted in the tree (it is
// not wrapped in an actual Offstage), so find.text(...findsNothing) on a
// screen "behind" another one is not a reliable signal either way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rakta_bandhan/theme/app_theme.dart';
import 'package:rakta_bandhan/widgets/app_header.dart';

const _destinations = [
  'About Rakta Bandhan',
  'Testimonials',
  'Corporate partnerships',
  'Help & support',
  'Privacy policy',
  'Terms of use',
];

class _RouteLog extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (stack.isNotEmpty) stack.removeLast();
  }
}

void main() {
  for (final label in _destinations) {
    testWidgets('back from "$label" returns to the More menu route, not the underlying screen', (tester) async {
      final log = _RouteLog();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: [log],
        home: Scaffold(
          appBar: AppHeader(title: 'Community'),
          body: const Center(child: Text('UNDERLYING SCREEN MARKER')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'AppHeader must not overflow its own preferredSize');

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      expect(find.text('More'), findsOneWidget, reason: 'the More sheet should have opened');
      final sheetRoute = log.stack.last;

      // The sheet is a SingleChildScrollView -- on a narrower/shorter test
      // viewport the last couple of rows need scrolling into view first,
      // same as a real user would on a small device.
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final destinationRoute = log.stack.last;
      expect(identical(destinationRoute, sheetRoute), isFalse,
          reason: 'tapping "$label" must push a new route on top of the sheet');

      log.stack.last.navigator!.pop();
      await tester.pumpAndSettle();

      expect(identical(log.stack.last, sheetRoute), isTrue,
          reason: 'back from "$label" must land back on the More sheet route, not skip past it to the underlying screen');
      expect(find.text('More'), findsOneWidget,
          reason: 'the More sheet must be visibly showing again after back from "$label"');
    });
  }
}
