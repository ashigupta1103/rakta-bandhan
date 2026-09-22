// Regression check for the registration-screen black-screen bug:
// RegistrationScreen is always reached via Navigator.pushAndRemoveUntil
// right after OTP verification (otp_screen.dart), so it is the stack
// root with nothing beneath it. The back arrow must never call a plain
// Navigator.pop() on that root — it must fall back to LoginScreen instead
// of popping into an empty Navigator (see registration_screen.dart's
// _handleBack).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rakta_bandhan/screens/login_screen.dart';
import 'package:rakta_bandhan/screens/registration_screen.dart';

void main() {
  testWidgets('back arrow on a root RegistrationScreen falls back to Login instead of leaving a black screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen(phoneNumber: '9999999999')));
    await tester.pump();

    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(Navigator.canPop(tester.element(find.byType(RegistrationScreen))), isFalse, reason: 'this screen is always a fresh stack root in the real app');

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget, reason: 'backing out of a rootless registration screen must land on Login, not a black/empty screen');
    expect(find.byType(RegistrationScreen), findsNothing);
  });

  testWidgets('rapid repeated taps on the back arrow do not double-navigate', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen(phoneNumber: '9999999999')));
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget, reason: 'a second rapid tap must be a no-op, not a second navigation attempt');
  });
}
