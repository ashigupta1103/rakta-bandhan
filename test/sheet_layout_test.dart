import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/demo/demo.dart';
import 'package:rakta_bandhan/demo/demo_overlay.dart';
import 'package:rakta_bandhan/screens/testimonials_screen.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';

/// Bottom sheets on a small phone with an Android navigation bar: every
/// control must lay out without overflow and stay reachable by scrolling.
/// Both run inside a demo session, so nothing touches Firebase.
void main() {
  setUp(() => Demo.instance.start(DemoRole.donor));
  tearDown(() => Demo.instance.stop());

  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48); // status + nav bar
    addTearDown(tester.view.reset);
  }

  testWidgets('testimonial sheet scrolls to a fully visible submit button', (tester) async {
    smallPhone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const TestimonialsScreen()));
    await tester.tap(find.text('Add a testimonial'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final submit = find.text('Send for review');
    await tester.scrollUntilVisible(submit, 120, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    final bottom = tester.getRect(submit).bottom;
    expect(bottom, lessThanOrEqualTo(568 - 48), reason: 'submit must clear the navigation bar');
  });

  testWidgets('client preview sheet keeps its last row above the navigation bar', (tester) async {
    smallPhone(tester);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      navigatorKey: key,
      builder: (context, child) => DemoOverlay(navigatorKey: key, child: child!),
      home: const Scaffold(body: SizedBox.expand()),
    ));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final exit = find.text('Exit demo');
    await tester.scrollUntilVisible(exit, 120, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.getRect(exit).bottom, lessThanOrEqualTo(568 - 48));
  });

  testWidgets('testimonials never show community-story edit or delete controls', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const TestimonialsScreen()));
    await tester.pump();
    expect(find.text('Edit story'), findsNothing);
    expect(find.text('Delete story'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
