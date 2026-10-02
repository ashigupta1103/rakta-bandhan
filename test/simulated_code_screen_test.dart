import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/simulated_code_screen.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';
import 'package:rakta_bandhan/widgets/rb_icon.dart';

void main() {
  testWidgets('only the simulated code continues, and Skip always does', (tester) async {
    var continued = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: SimulatedCodeScreen(
        icon: RbGlyph.mail,
        title: 'Check your email',
        intro: 'We would email a 6-digit code to',
        target: 'a@b.co',
        channel: 'Emails',
        code: '123456',
        doneMessage: 'done',
        onContinue: () async {
          continued++;
        },
      ),
    ));
    await tester.pump();
    expect(find.textContaining('Simulation', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    expect(find.textContaining('the code is 123456'), findsOneWidget);
    expect(continued, 0);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(continued, 1);

    await tester.tap(find.text('Skip for now'));
    await tester.pump();
    expect(continued, 2);
  });
}
