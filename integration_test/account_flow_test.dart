// Account lifecycle on an Android emulator (see support.dart for how to run
// it), with the free-plan email + password sign-in: sign up → register →
// log out → log back in → download my data → delete the account (password
// asked again) → the profile and the sign-in account are really gone.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rakta_bandhan/main.dart' as app;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('account journey: register → log out → log in → export → delete', (t) async {
    await app.main();
    final email = 'e2e-account-${DateTime.now().millisecondsSinceEpoch}@example.com';
    final uid = await signUpAndRegister(t, email: email, name: 'Test Account', bloodGroup: 'B+');
    final profile = await fsGet('donors/$uid');
    expect(profile, isNotNull, reason: 'the private profile exists');
    final username = fsString(profile, 'username')!;
    expect(await fsGet('usernames/$username'), isNotNull, reason: 'the username is claimed');
    expect(await fsGet('donors_public/$uid'), isNotNull, reason: 'the public listing exists');

    // Log out from Settings, then sign back in with the same password.
    await tapWhenReady(t, find.text('My Page'));
    await scrollAndTap(t, find.text('Settings, your data & account'));
    await waitFor(t, find.text('Settings & privacy'), why: 'settings');
    await snap(t, '30_settings');
    await scrollAndTap(t, find.text('Log out'));
    await tapWhenReady(t, find.widgetWithText(TextButton, 'Log out'));
    await waitFor(t, find.text('Sign in'), why: 'login screen after log out');
    expect(FirebaseAuth.instance.currentUser, isNull);

    await t.enterText(find.byType(TextField).at(0), email);
    await t.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Sign in'));
    await waitFor(t, find.text('Incorrect email or password.'), why: 'wrong password message');
    await snap(t, '31_wrong_password');

    await t.enterText(find.byType(TextField).at(1), 'Passw0rd!e2e');
    await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Sign in'));
    // Verified and registered: straight into the app.
    await waitFor(t, find.text('My Page'), why: 'main navigation after log in', timeout: const Duration(seconds: 60));
    expect(FirebaseAuth.instance.currentUser?.uid, uid);

    // Download my data.
    await tapWhenReady(t, find.text('My Page'));
    await scrollAndTap(t, find.text('Settings, your data & account'));
    await scrollAndTap(t, find.text('Download my data'));
    await waitFor(t, find.text('Copy all'), why: 'data export sheet');
    await snap(t, '32_export');
    expect(find.textContaining(email, findRichText: true), findsWidgets);
    await t.tapAt(const Offset(10, 60)); // dismiss the sheet
    await pumpFor(t, const Duration(seconds: 1));

    // Delete the account: a wrong password stops it before anything is removed.
    await scrollAndTap(t, find.text('Delete my account'));
    await tapWhenReady(t, find.text('Delete my account').last);
    await waitFor(t, find.text('Enter your password'), why: 'password prompt');
    await t.enterText(find.byType(TextField).last, 'not-my-password');
    await tapWhenReady(t, find.text('Delete account'));
    await waitFor(t, find.text('Incorrect email or password.'), why: 'wrong password on delete');
    expect(await fsGet('donors/$uid'), isNotNull, reason: 'nothing was deleted');

    await scrollAndTap(t, find.text('Delete my account'));
    await tapWhenReady(t, find.text('Delete my account').last);
    await waitFor(t, find.text('Enter your password'), why: 'password prompt');
    await t.enterText(find.byType(TextField).last, 'Passw0rd!e2e');
    await tapWhenReady(t, find.text('Delete account'));
    await waitFor(t, find.text('Sign in'), why: 'login screen after deletion', timeout: const Duration(seconds: 60));
    await snap(t, '33_deleted');

    expect(await fsGet('donors/$uid'), isNull, reason: 'private profile removed');
    expect(await fsGet('donors_public/$uid'), isNull, reason: 'public listing removed');
    expect(await fsGet('usernames/$username'), isNull, reason: 'username released');
    expect(FirebaseAuth.instance.currentUser, isNull, reason: 'signed out');

    // The sign-in account is gone too.
    await t.enterText(find.byType(TextField).at(0), email);
    await t.enterText(find.byType(TextField).at(1), 'Passw0rd!e2e');
    await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Sign in'));
    await waitFor(t, find.text('Incorrect email or password.'), why: 'sign-in after deletion fails');
  });
}
