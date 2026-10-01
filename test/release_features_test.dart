// Checks for the release features that don't need a live Firebase project:
// sign-in form validation, the "area name, never coordinates" rules, the
// donation cooldown, push topics, and the community guidelines document.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/legal/legal_documents.dart';
import 'package:rakta_bandhan/screens/legal_reader_screen.dart';
import 'package:rakta_bandhan/screens/login_code_screen.dart';
import 'package:rakta_bandhan/screens/login_screen.dart';
import 'package:rakta_bandhan/services/backend.dart';
import 'package:rakta_bandhan/services/push_service.dart';

void main() {
  group('passwordless sign-in', () {
    testWidgets('asks only for an email — no password field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('password', findRichText: true), findsOneWidget); // "No password needed…"
      expect(find.text('Send me a code'), findsOneWidget);
    });

    testWidgets('rejects a malformed email before calling the server', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Send me a code'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('code screen shows the address, counts down, and needs all 6 digits', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginCodeScreen(email: 'donor@example.com', resendAfterSeconds: 30)));
      await tester.pump();
      expect(find.textContaining('donor@example.com', findRichText: true), findsOneWidget);
      expect(find.text('Resend code in 30s'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      // The digits show in the boxes.
      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.text('Verify and continue'));
      await tester.pump();
      expect(find.text('Enter all 6 digits of the code.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('the code field accepts digits only', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginCodeScreen(email: 'a@b.co')));
      await tester.enterText(find.byType(TextField), '1a2b');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '12');
    });
  });

  test('avatar initials ignore punctuation', () {
    expect(initialsOf('Priya (test)'), 'PT');
    expect(initialsOf('  meera  s '), 'MS');
    expect(initialsOf('PHF Rtn. Radhika Dhruv'), 'PR');
    expect(initialsOf('(  )'), '?');
    expect(initialsOf(''), '?');
  });

  group('place names', () {
    test('shortPlace never shows coordinates or PIN codes', () {
      expect(Backend.shortPlace('13.0827, 80.2707'), 'Location shared');
      expect(Backend.shortPlace(null, fallback: 'Blood request'), 'Blood request');
      expect(Backend.shortPlace('Apollo Hospital, Greams Road, Thousand Lights, Chennai, 600006, India'), 'Apollo Hospital, Greams Road');
      expect(Backend.shortPlace('600006, Adyar, Chennai'), 'Adyar, Chennai');
    });

    test('areaFromAddress picks locality + city', () {
      expect(Backend.areaFromAddress({'suburb': 'Adyar', 'city': 'Chennai', 'state': 'Tamil Nadu'}), 'Adyar, Chennai');
      expect(Backend.areaFromAddress({'village': 'Mahabalipuram', 'state_district': 'Chengalpattu'}), 'Mahabalipuram, Chengalpattu');
      expect(Backend.areaFromAddress({'city': 'Chennai'}), 'Chennai');
      expect(Backend.areaFromAddress({}), isNull);
    });
  });

  group('donation cooldown', () {
    test('is active only while reactivation is in the future', () {
      final future = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
      final past = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
      expect(Backend.onCooldown({'reactivation_scheduled_at': future}), isTrue);
      expect(Backend.onCooldown({'reactivation_scheduled_at': past}), isFalse);
      expect(Backend.onCooldown({}), isFalse);
      expect(Backend.onCooldown(null), isFalse);
    });

    test('the rest period is 90 days', () {
      expect(donorCooldownDays, 90);
    });
  });

  test('push topics match the Cloud Functions naming', () {
    // functions/src/geo.ts → bloodGroupTopic
    expect(PushService.bloodGroupTopic('A+'), 'bg_Apos');
    expect(PushService.bloodGroupTopic('AB-'), 'bg_ABneg');
    expect(PushService.bloodGroupTopic('O+'), 'bg_Opos');
  });

  group('community guidelines', () {
    test('cover the rules the stores and the team asked for', () {
      final ids = communityGuidelines.sections.map((s) => s.id).toList();
      expect(ids, containsAll(['respect', 'money', 'harassment', 'privacy', 'genuine', 'spam', 'report', 'action']));
    });

    testWidgets('open in the legal reader', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LegalReaderScreen.guidelines()));
      expect(find.text('Community guidelines'), findsWidgets);
      expect(find.textContaining('No commercial blood transactions'), findsWidgets);
    });
  });
}
