// End-to-end walk through the real app on an Android emulator, against the
// local Firebase emulators (auth, firestore, functions, storage):
//
//   firebase emulators:start --project rakta-bandhan2026 --only auth,firestore,functions,storage
//   flutter test integration_test/app_flow_test.dart -d emulator-5554 \
//     --dart-define=USE_EMULATORS=true
//
// Plays both sides: the app is the donor; the "other person" (a requester)
// is written straight into the Firestore emulator over REST with the
// emulator's owner token. Prints `SNAP:<name>` at each screen worth a
// screenshot — tool/e2e_screenshots.sh captures them with adb.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:rakta_bandhan/main.dart' as app;
import 'package:rakta_bandhan/services/backend.dart';
import 'package:rakta_bandhan/services/push_service.dart';

const _host = '10.0.2.2';
const _project = 'rakta-bandhan2026';
const _fs = 'http://$_host:8080/v1/projects/$_project/databases/(default)/documents';
const _owner = {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'};

// Requester side of the story, near Chennai Central.
const _reqId = 'e2e_request_1';
const _requesterUid = 'e2e_requester';
const _hospital = (lat: 13.0610, lng: 80.2520);

Future<void> snap(WidgetTester t, String name) async {
  await pumpFor(t, const Duration(milliseconds: 1500));
  // ignore: avoid_print
  print('SNAP:$name');
  await pumpFor(t, const Duration(milliseconds: 2500)); // time for adb screencap
}

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
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

/// The app draws its own back arrows, so pop routes directly.
Future<void> popToRoot(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) => r.isFirst);
  await pumpFor(t, const Duration(seconds: 1));
}

Future<void> popOnce(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).first).pop();
  await pumpFor(t, const Duration(seconds: 1));
}

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

Future<void> fsSet(String path, Map<String, Object?> data) async {
  final r = await http.patch(Uri.parse('$_fs/$path'), headers: _owner, body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))}));
  if (r.statusCode != 200) throw TestFailure('seed $path failed: ${r.statusCode} ${r.body}');
}

Future<void> fsUpdate(String path, Map<String, Object?> data) async {
  final mask = data.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
  final r = await http.patch(Uri.parse('$_fs/$path?$mask'), headers: _owner, body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))}));
  if (r.statusCode != 200) throw TestFailure('update $path failed: ${r.statusCode} ${r.body}');
}

Future<Map<String, dynamic>?> fsGet(String path) async {
  final r = await http.get(Uri.parse('$_fs/$path'), headers: _owner);
  return r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
}

/// The newest code the login function stored (emulator-only `dev_code`).
Future<String> latestLoginCode() async {
  final r = await http.get(Uri.parse('$_fs/login_codes'), headers: _owner);
  final docs = (jsonDecode(r.body)['documents'] as List? ?? const []).cast<Map<String, dynamic>>();
  docs.sort((a, b) => int.parse(b['fields']['last_sent_ms']['integerValue'] as String)
      .compareTo(int.parse(a['fields']['last_sent_ms']['integerValue'] as String)));
  final code = docs.firstOrNull?['fields']?['dev_code']?['stringValue'] as String?;
  if (code == null) throw TestFailure('no login code found in the emulator');
  return code;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('donor journey: sign in → register → accept → call → donate → certificate', (t) async {
    await app.main();
    final email = 'e2e-donor-${DateTime.now().millisecondsSinceEpoch}@example.com';

    // 1. Sign in with an emailed code.
    await waitFor(t, find.text('Send me a code'), why: 'login screen');
    await snap(t, '01_login');
    await t.enterText(find.byType(TextField).first, email);
    await tapWhenReady(t, find.text('Send me a code'));
    await waitFor(t, find.text('Enter your code'), why: 'code screen');
    await snap(t, '02_code');
    final code = await latestLoginCode();
    await t.enterText(find.byType(TextField).first, code);
    await waitFor(t, find.text('Complete registration'), why: 'registration after code');
    expect(FirebaseAuth.instance.currentUser?.email, email);

    // 2. Register as an O+ donor near Chennai (GPS fixed by the host to
    //    Chennai Central; fall back to the map pin if GPS is slow).
    await t.enterText(find.byType(TextField).at(0), 'Test Donor');
    await t.enterText(find.byType(TextField).at(1), '9876543210');
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
    await tapWhenReady(t, find.text('O+'));
    await pumpFor(t, const Duration(milliseconds: 500));
    await tapWhenReady(t, find.widgetWithText(ElevatedButton, 'Complete registration'));
    await snap(t, '03c_after_register_tap');
    await waitFor(t, find.text('I agree, continue'), why: 'consent screen', timeout: const Duration(seconds: 60));
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
    final me = FirebaseAuth.instance.currentUser!.uid;

    // 3. Someone nearby needs A+ (an O+ donor can give).
    final now = DateTime.now();
    await fsSet('requests/$_reqId', {
      'requester_uid': _requesterUid,
      'requester_name': 'Priya (test)',
      'requester_phone': '9000000001',
      'blood_group': 'A+',
      'units_needed': 1,
      'urgency': 'urgent',
      'location_label': 'Apollo Hospital, Greams Road, Thousand Lights, Chennai, 600006, India',
      'geohash': encodeGeohash(_hospital.lat, _hospital.lng),
      'lat': _hospital.lat,
      'lng': _hospital.lng,
      'status': 'open',
      'created_at': now,
      'expires_at': now.add(const Duration(hours: 6)),
    });
    for (final (i, (name, group, lat, lng, area)) in const [
      ('Arjun K', 'B+', 13.0700, 80.2600, 'Egmore, Chennai'),
      ('Meera S', 'O-', 13.0500, 80.2500, 'Nungambakkam, Chennai'),
      ('Ravi T', 'A+', 13.0900, 80.2800, 'Park Town, Chennai'),
    ].indexed) {
      await fsSet('donors_public/e2e_donor_$i', {
        'name': name,
        'blood_group': group,
        'lat': lat,
        'lng': lng,
        'geohash': encodeGeohash(lat, lng, precision: 6),
        'area': area,
        'is_available': true,
        'is_verified': i != 1,
        'updated_at': now,
      });
    }

    await tapWhenReady(t, find.text('Request'));
    await tapWhenReady(t, find.text('Received'));
    await waitFor(t, find.text('View request'), why: 'nearby request card');
    await snap(t, '04_requests_received');
    await tapWhenReady(t, find.text('View request'));
    await waitFor(t, find.text('Accept & help'));
    await snap(t, '05_request_detail');
    await tapWhenReady(t, find.text('Accept & help'));
    await waitFor(t, find.text('View contact details'), why: 'accept success');
    await snap(t, '06_accepted');
    await tapWhenReady(t, find.text('View contact details'));
    await waitFor(t, find.text('Mark as donated'), why: 'match contact screen');
    await snap(t, '07_match_contact');

    // 4. The requester calls — in-app ringing screen while the app is open.
    await fsSet('requests/$_reqId/calls/e2e_call_1', {
      'caller_uid': _requesterUid,
      'callee_uid': me,
      'caller_name': 'Priya (test)',
      'status': 'ringing',
      'offer': {'type': 'offer', 'sdp': 'v=0'},
      'created_at': DateTime.now(),
    });
    await waitFor(t, find.text('Incoming voice call'), why: 'in-app incoming call');
    await snap(t, '08_incoming_call_in_app');
    await tapWhenReady(t, find.text('Decline'));
    await pumpFor(t, const Duration(seconds: 2));
    final call = await fsGet('requests/$_reqId/calls/e2e_call_1');
    expect(call?['fields']?['status']?['stringValue'], 'declined');

    // 5. The native ringing screen used when the app is closed (what the
    //    call push triggers), shown directly here.
    await PushService.showIncomingCall({
      'requestId': _reqId,
      'callId': 'e2e_call_native',
      'callerUid': _requesterUid,
      'callerName': 'Priya (test)',
    });
    await pumpFor(t, const Duration(seconds: 4)); // native activity / heads-up
    await snap(t, '09_incoming_call_native');
    await PushService.endNativeCall('e2e_call_native');
    await pumpFor(t, const Duration(seconds: 2));

    // 6. Both sides confirm the donation.
    await tapWhenReady(t, find.text('Mark as donated'));
    await tapWhenReady(t, find.text('Yes, I donated'));
    await waitFor(t, find.text('Done'), why: 'donation recorded');
    await snap(t, '10_donation_recorded');
    var req = await fsGet('requests/$_reqId');
    expect(req?['fields']?['status']?['stringValue'], 'matched', reason: 'still waiting for the requester');
    await fsUpdate('requests/$_reqId', {
      'requester_confirmed_at': DateTime.now(),
      'status': 'fulfilled',
      'fulfilled_at': DateTime.now(),
    });
    req = await fsGet('requests/$_reqId');
    expect(req?['fields']?['status']?['stringValue'], 'fulfilled');
    await tapWhenReady(t, find.text('Done'));
    await snap(t, '11_cooldown');

    // 7. My Page: availability locked, certificate from donation history.
    await popToRoot(t);
    await tapWhenReady(t, find.text('My Page'));
    await waitFor(t, find.textContaining('Resting after your donation'), why: 'locked availability');
    await snap(t, '12_profile_cooldown');
    final toggle = t.widget<Switch>(find.byType(Switch).first);
    expect(toggle.onChanged, isNull, reason: 'availability is locked during the rest period');
    await tapWhenReady(t, find.text('Donation history'));
    await tapWhenReady(t, find.text('View certificate'));
    await waitFor(t, find.text('Certificate of donation'));
    await snap(t, '13_certificate');
    await popToRoot(t);

    // 8. Find: the donor map with neighbourhood names.
    await tapWhenReady(t, find.text('Find'));
    await pumpFor(t, const Duration(seconds: 8)); // map tiles
    await snap(t, '14_find_map');

    // 9. Community.
    await tapWhenReady(t, find.text('Community'));
    await waitFor(t, find.text('Share your experience'));
    await snap(t, '15_community');
  });
}
