// Regression check for the "Log out" consolidation: Settings and My Page
// must share one confirmation dialog and one sign-out call
// (lib/widgets/logout_flow.dart), not two different behaviors — and
// neither may sign a user out on the first tap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/widgets/logout_flow.dart';

void main() {
  Widget harness(bool isLoading, ValueChanged<bool> setLoading) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => confirmAndLogOut(context, isLoading: isLoading, setLoading: setLoading),
              child: const Text('Log out'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping Log out opens a confirmation dialog, not an immediate sign-out', (tester) async {
    await tester.pumpWidget(harness(false, (_) {}));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget, reason: 'confirmation dialog must appear');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Log out'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog without starting sign-out', (tester) async {
    var loadingCalls = <bool>[];
    await tester.pumpWidget(harness(false, loadingCalls.add));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing, reason: 'dialog must be dismissed');
    expect(loadingCalls, isEmpty, reason: 'Cancel must never trigger the sign-out loading state');
  });

  testWidgets('confirming Log out enters the loading state and attempts the real sign-out flow', (tester) async {
    var loadingCalls = <bool>[];
    await tester.pumpWidget(harness(false, loadingCalls.add));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pump();

    expect(loadingCalls.first, isTrue, reason: 'confirming must flip the caller\'s loading state on before attempting sign-out');
    await tester.pumpAndSettle();
  });

  testWidgets('a second tap while already logging out is a no-op (duplicate-tap guard)', (tester) async {
    var loadingCalls = <bool>[];
    await tester.pumpWidget(harness(true, loadingCalls.add));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing, reason: 'a second tap while isLoading is already true must not reopen the dialog');
    expect(loadingCalls, isEmpty);
  });
}
