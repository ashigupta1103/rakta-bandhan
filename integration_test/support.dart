// Shared helpers for the on-device end-to-end tests (see app_flow_test.dart
// and requester_flow_test.dart). They drive the real app on an Android
// emulator against the local Firebase emulators:
//
//   firebase emulators:start --project rakta-bandhan2026 --only auth,firestore
//   bash tool/e2e_screenshots.sh              # donor side
//   bash tool/e2e_screenshots.sh build/e2e_requester integration_test/requester_flow_test.dart
//
// "The other person" in each story is written straight into the Firestore
// emulator over REST with the emulator's owner token, which bypasses the
// security rules — only the app's own writes are checked by them.

import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const host = '10.0.2.2';
const project = 'rakta-bandhan2026';
const fsBase = 'http://$host:8080/v1/projects/$project/databases/(default)/documents';
const ownerHeaders = {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'};

/// Near Chennai Central (the emulator's GPS is fixed to the station).
const hospital = (lat: 13.0610, lng: 80.2520);

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Prints `SNAP:<name>`; tool/e2e_screenshots.sh captures the screen.
Future<void> snap(WidgetTester t, String name) async {
  await pumpFor(t, const Duration(milliseconds: 1500));
  // ignore: avoid_print
  print('SNAP:$name');
  await pumpFor(t, const Duration(milliseconds: 2500)); // time for adb screencap
}

Future<void> waitFor(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 40), String? why}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  await snap(t, 'zz_timeout');
  throw TestFailure('Timed out waiting for ${why ?? f}');
}

Future<void> tapWhenReady(WidgetTester t, Finder f) async {
  await waitFor(t, f);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first);
  await t.pump();
}

/// Scrolls the visible list until [f] has been built (long lists only build
/// the rows near the screen), then taps it.
Future<void> scrollAndTap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 30);
  await t.pump();
  await t.tap(f.first);
  await t.pump();
}

/// The app draws its own back arrows, so pop routes directly.
Future<void> popToRoot(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) => r.isFirst);
  await pumpFor(t, const Duration(seconds: 1));
}

Future<void> popOnce(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).first).pop();
  await pumpFor(t, const Duration(seconds: 1));
}

// ------------------------------------------------------------ Firestore REST

Map<String, dynamic> _value(Object? v) => switch (v) {
      null => {'nullValue': null},
      bool b => {'booleanValue': b},
      int i => {'integerValue': '$i'},
      double d => {'doubleValue': d},
      DateTime dt => {'timestampValue': dt.toUtc().toIso8601String()},
      Map m => {
          'mapValue': {'fields': m.map((k, val) => MapEntry(k as String, _value(val)))}
        },
      _ => {'stringValue': '$v'},
    };

/// The emulated phone's route to the host (10.0.2.2) drops out for a moment
/// now and then ("Network is unreachable"); retry instead of failing a test
/// for something that is not the app.
Future<T> _retry<T>(Future<T> Function() call) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await call();
    } on SocketException {
      if (attempt >= 8) rethrow;
    } on http.ClientException {
      if (attempt >= 8) rethrow;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

Future<void> fsSet(String path, Map<String, Object?> data) async {
  final r = await _retry(() => http.patch(Uri.parse('$fsBase/$path'), headers: ownerHeaders, body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))})));
  if (r.statusCode != 200) throw TestFailure('seed $path failed: ${r.statusCode} ${r.body}');
}

Future<void> fsUpdate(String path, Map<String, Object?> data) async {
  final mask = data.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
  final r = await _retry(() => http.patch(Uri.parse('$fsBase/$path?$mask'), headers: ownerHeaders, body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))})));
  if (r.statusCode != 200) throw TestFailure('update $path failed: ${r.statusCode} ${r.body}');
}

Future<Map<String, dynamic>?> fsGet(String path) async {
  final r = await _retry(() => http.get(Uri.parse('$fsBase/$path'), headers: ownerHeaders));
  return r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
}

/// Every document of a collection (or sub-collection), as raw REST maps.
Future<List<Map<String, dynamic>>> fsList(String path) async {
  final r = await _retry(() => http.get(Uri.parse('$fsBase/$path?pageSize=100'), headers: ownerHeaders));
  if (r.statusCode != 200) return const [];
  return ((jsonDecode(r.body)['documents'] as List?) ?? const []).cast<Map<String, dynamic>>();
}

String? fsString(Map<String, dynamic>? doc, String field) => doc?['fields']?[field]?['stringValue'] as String?;

// ------------------------------------------------------------------- sign-up

/// Free-plan sign-in, start to finish: create an account, pass the (simulated)
/// email check, register a profile, pass the (simulated) phone check and the consent
/// screen. Ends on the main screen; returns the new account's uid.
Future<String> signUpAndRegister(
  WidgetTester t, {
  required String email,
  required String name,
  required String bloodGroup,
  String phone = '9876543210',
}) async {
  await waitFor(t, find.text('New here? Create an account'), why: 'login screen');
  await snap(t, '01_login');
  await tapWhenReady(t, find.text('New here? Create an account'));
  await t.enterText(find.byType(TextField).at(0), email);
  await t.enterText(find.byType(TextField).at(1), 'Passw0rd!e2e');
  await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Create account'));
  // The email check is a labelled simulation (code 123456); nothing is sent.
  await waitFor(t, find.text('Check your email'), why: 'email check');
  await snap(t, '02_email_check');
  await t.enterText(find.byType(TextField).first, '123456');
  await waitFor(t, find.text('Full name'), why: 'registration after the email check', timeout: const Duration(seconds: 60));
  expect(FirebaseAuth.instance.currentUser?.email, email);

  // Register near Chennai Central (the host fixes the GPS; fall back to the
  // map pin if the fix is slow).
  await t.enterText(find.byType(TextField).at(0), name);
  await t.enterText(find.byType(TextField).at(1), 'e2e${DateTime.now().millisecondsSinceEpoch % 10000000}');
  await t.enterText(find.byType(TextField).at(2), phone);
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(seconds: 1));
  final resolved = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(resolved) && find.textContaining('Location pinned').evaluate().isEmpty) {
    await t.pump(const Duration(milliseconds: 300));
  }
  if (find.textContaining('Location pinned').evaluate().isEmpty) {
    await tapWhenReady(t, find.text('Pin on map'));
    await waitFor(t, find.text('Use this area'));
    await snap(t, '03b_location_picker');
    await pumpFor(t, const Duration(seconds: 3));
    await tapWhenReady(t, find.text('Use this area'));
  }
  await snap(t, '03_registration');
  await tapWhenReady(t, find.text(bloodGroup));
  await pumpFor(t, const Duration(milliseconds: 500));
  await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Complete registration'));
  await snap(t, '03c_after_register_tap');

  // The phone check is a labelled simulation (code 246810).
  await waitFor(t, find.text('Check your number'), why: 'phone check', timeout: const Duration(seconds: 60));
  await snap(t, '03c2_phone_check');
  await t.enterText(find.byType(TextField).first, '246810');
  await waitFor(t, find.text('I agree, continue'), why: 'consent screen', timeout: const Duration(seconds: 30));
  await snap(t, '03d_consent');
  await tapWhenReady(t, find.byType(Checkbox));
  await tapWhenReady(t, find.text('I agree, continue'));
  // Location was granted during registration, so the separate location
  // screen is skipped; tolerate it if a device shows it anyway.
  final next = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(next) &&
      find.text('Continue to Rakta Bandhan').evaluate().isEmpty &&
      find.text('Not now').evaluate().isEmpty) {
    await t.pump(const Duration(milliseconds: 200));
  }
  if (find.text('Not now').evaluate().isNotEmpty) await tapWhenReady(t, find.text('Not now'));
  await waitFor(t, find.text('Continue to Rakta Bandhan'), why: 'verifying screen');
  await snap(t, '03e_welcome');
  await tapWhenReady(t, find.text('Continue to Rakta Bandhan'));
  await waitFor(t, find.text('My Page'), why: 'main navigation');
  return FirebaseAuth.instance.currentUser!.uid;
}
