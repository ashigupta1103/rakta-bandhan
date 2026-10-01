// Checks for the release features that don't need a live Firebase project:
// sign-in form validation, the "area name, never coordinates" rules, the
// donation cooldown, push topics, and the community guidelines document.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/legal/legal_documents.dart';
import 'package:rakta_bandhan/screens/legal_reader_screen.dart';
import 'package:rakta_bandhan/screens/login_screen.dart';
import 'package:rakta_bandhan/services/backend.dart';
import 'package:rakta_bandhan/services/push_service.dart';

void main() {
  group('sign-in form', () {
    testWidgets('rejects a malformed email before calling Firebase', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(1), 'whatever1');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('create account needs a strong, confirmed password', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      final toggle = find.widgetWithText(TextButton, 'Create account');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.text('Create your account'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'donor@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.enterText(find.byType(TextField).at(2), 'short');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();
      expect(find.textContaining('at least 8 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'longenough1');
      await tester.enterText(find.byType(TextField).at(2), 'different22');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();
      expect(find.text('The two passwords don’t match.'), findsOneWidget);
    });
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
