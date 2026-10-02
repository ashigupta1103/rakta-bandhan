// The free-plan demo APK (--dart-define=DEMO_SIGNIN=true): an email typed on the
// normal sign-in screen goes through the simulated code and lands on
// registration, with no Firebase call. Skipped in a normal build; run it with
//   flutter test --dart-define=DEMO_SIGNIN=true test/demo_signin_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/demo/demo.dart';
import 'package:rakta_bandhan/preview_mode.dart';
import 'package:rakta_bandhan/screens/login_screen.dart';
import 'package:rakta_bandhan/screens/registration_screen.dart';

void main() {
  tearDown(() => Demo.instance.stop());

  testWidgets('any email signs in through the simulated code, no backend', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(find.byType(TextField), 'someone@gmail.com');
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your code'), findsOneWidget, reason: 'the code screen, not the "Sign-in isn’t available" error');
    expect(find.textContaining(Demo.emailCode), findsOneWidget, reason: 'the demo note tells the tester the code');

    await tester.enterText(find.byType(TextField), Demo.emailCode);
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationScreen), findsOneWidget, reason: 'a new demo user goes on to registration (then the simulated phone code)');
  }, skip: !kDemoSignIn);
}
