import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/testimonials_screen.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';

/// Bottom sheets on a small phone with an Android navigation bar: every
/// control must lay out without overflow and stay reachable by scrolling.
/// No Firebase app exists in tests, so the sheet is opened directly.
void main() {
  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48); // status + nav bar
    addTearDown(tester.view.reset);
  }

  testWidgets('testimonial sheet scrolls to a fully visible submit button', (tester) async {
    smallPhone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => const TestimonialSheet(),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final submit = find.text('Send for review');
    await tester.scrollUntilVisible(submit, 120, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    final bottom = tester.getRect(submit).bottom;
    expect(bottom, lessThanOrEqualTo(568 - 48), reason: 'submit must clear the navigation bar');
  });

  testWidgets('testimonials never show community-story edit or delete controls', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const TestimonialsScreen()));
    await tester.pump();
    expect(find.text('Edit story'), findsNothing);
    expect(find.text('Delete story'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
