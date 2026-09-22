// Regression check for the Help & Support search field: guards against the
// "double rounded box" bug (a second fill/border painted inside the outer
// container by the global InputDecorationTheme) coming back silently.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/theme/app_theme.dart';
import 'package:rakta_bandhan/screens/help_support_screen.dart';

void main() {
  testWidgets('Help & Support search field is wrapped by exactly one rounded container and paints no theme fill', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const HelpSupportScreen()));
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget, reason: 'Help & Support should have exactly one search TextField');

    final roundedAncestors = find.ancestor(
      of: textFieldFinder,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius != null,
      ),
    );
    expect(
      roundedAncestors,
      findsOneWidget,
      reason: 'Exactly one rounded container should wrap the search field — more than one means the double-box bug is back',
    );

    final field = tester.widget<TextField>(textFieldFinder);
    expect(field.decoration?.filled, isFalse, reason: 'filled must stay false or the global InputDecorationTheme paints a second fill rectangle');
  });

  testWidgets('Help & Support search field actually filters the FAQ list end to end', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const HelpSupportScreen()));
    await tester.pumpAndSettle();

    // Full list before typing anything.
    expect(find.text('Why am I in a 90-day cooldown?'), findsOneWidget);
    expect(find.text('Who can see my number?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cooldown');
    await tester.pumpAndSettle();

    expect(find.text('Why am I in a 90-day cooldown?'), findsOneWidget, reason: 'the matching question must stay visible while typing');
    expect(find.text('Who can see my number?'), findsNothing, reason: 'non-matching questions must be filtered out, not just visually covered');

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('Who can see my number?'), findsOneWidget, reason: 'clearing the search must restore the full FAQ list');
  });
}
