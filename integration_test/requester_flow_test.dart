// Requester side of the story on an Android emulator (see support.dart for
// how to run it): sign up → raise a request → a donor accepts → chat → both
// people confirm the donation. The donor is written into the Firestore
// emulator over REST; everything the app does goes through the real
// security rules.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rakta_bandhan/main.dart' as app;
import 'package:rakta_bandhan/services/backend.dart' show encodeGeohash;
import 'package:rakta_bandhan/services/call_service.dart';
import 'package:rakta_bandhan/widgets/pressable.dart';

import 'support.dart';

const _donorUid = 'e2e_donor_arjun';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('requester journey: sign up → request → donor accepts → chat → both confirm', (t) async {
    await app.main();
    final email = 'e2e-requester-${DateTime.now().millisecondsSinceEpoch}@example.com';
    final me = await signUpAndRegister(t, email: email, name: 'Test Requester', bloodGroup: 'A+');

    // A compatible donor (O+) nearby, so the search has someone to find.
    final now = DateTime.now();
    await fsSet('donors_public/$_donorUid', {
      'name': 'Arjun K',
      'username': 'arjun_k',
      'blood_group': 'O+',
      'lat': 13.0700,
      'lng': 80.2600,
      'geohash': encodeGeohash(13.0700, 80.2600, precision: 6),
      'area': 'Egmore, Chennai',
      'is_available': true,
      'is_verified': true,
      'updated_at': now,
    });

    // 1. Raise a request from the Requests tab.
    await tapWhenReady(t, find.text('Request'));
    await tapWhenReady(t, find.text('Need blood yourself?'));
    await waitFor(t, find.text('Who needs blood?'), why: 'new request form');
    await tapWhenReady(t, find.text('A+'));
    await tapWhenReady(t, find.text('Urgent'));
    // The location fills in from GPS; the button enables once it has.
    final submit = find.widgetWithText(ElevatedButton, 'Alert nearby donors');
    final ready = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(ready) && (submit.evaluate().isEmpty || t.widget<ElevatedButton>(submit).onPressed == null)) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await snap(t, '20_new_request');
    await tapWhenReady(t, submit);
    await waitFor(t, find.text('Keep waiting in background'), why: 'matching screen', timeout: const Duration(seconds: 60));
    await snap(t, '21_matching');

    // The request is stored without any phone number.
    final mine = (await fsList('requests')).where((d) => fsString(d, 'requester_uid') == me).toList();
    expect(mine, hasLength(1), reason: 'exactly one request was created');
    final reqPath = 'requests/${(mine.single['name'] as String).split('/').last}';
    expect(fsString(mine.single, 'status'), 'open');
    expect((mine.single['fields'] as Map).containsKey('requester_phone'), isFalse, reason: 'no phone number on a request');

    // 2. The donor accepts (written as that donor would, owner token).
    await fsUpdate(reqPath, {
      'status': 'matched',
      'matched_donor_id': _donorUid,
      'matched_donor_name': 'Arjun K',
      'matched_donor_username': 'arjun_k',
      'matched_at': DateTime.now(),
    });
    await fsSet('donors/$_donorUid', {'active_request_id': reqPath.split('/').last, 'name': 'Arjun K'});
    await waitFor(t, find.text('Track request'), why: 'donor found screen', timeout: const Duration(seconds: 60));
    await snap(t, '22_donor_found');
    await tapWhenReady(t, find.text('Track request'));
    await waitFor(t, find.text('Message'), why: 'tracking screen with a donor');
    await snap(t, '23_tracking_matched');

    // 3. Chat: the message must reach Firestore through the rules.
    await tapWhenReady(t, find.text('Message'));
    await waitFor(t, find.byType(TextField), why: 'chat composer');
    await t.enterText(find.byType(TextField).last, 'Hello Arjun, thank you for helping.');
    await t.pump();
    await tapWhenReady(t, find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == 'Send'));
    await pumpFor(t, const Duration(seconds: 3));
    await snap(t, '24_chat');
    final messages = await fsList('$reqPath/messages');
    expect(messages.map((m) => fsString(m, 'text')), contains('Hello Arjun, thank you for helping.'));
    final request = await fsGet(reqPath);
    expect(request?['fields']?['last_message'], isNotNull, reason: 'the inbox preview was written with the message');
    await popOnce(t);

    // 4. Call: the ringing call document must be accepted by the rules.
    await tapWhenReady(t, find.text('Call in app'));
    List<Map<String, dynamic>> calls = const [];
    final ringing = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(ringing) && calls.isEmpty) {
      await pumpFor(t, const Duration(seconds: 1));
      calls = await fsList('$reqPath/calls');
    }
    await snap(t, '24b_calling');
    expect(calls, hasLength(1), reason: 'the app created one call document');
    expect(fsString(calls.single, 'caller_uid'), me);
    expect(fsString(calls.single, 'callee_uid'), _donorUid);
    expect(fsString(calls.single, 'status'), 'ringing');
    await CallService.instance.active?.hangUp();
    await pumpFor(t, const Duration(seconds: 3));
    expect(fsString((await fsList('$reqPath/calls')).single, 'status'), 'missed', reason: 'cancelled before anyone answered');
    await waitFor(t, find.text('Mark donation received'), why: 'back on the tracking screen after the call');

    // 5. The requester confirms first; the request stays open until the donor does too.
    await tapWhenReady(t, find.text('Mark donation received'));
    await tapWhenReady(t, find.text('Yes, donation received'));
    await pumpFor(t, const Duration(seconds: 3));
    expect(fsString(await fsGet(reqPath), 'status'), 'matched', reason: 'waiting for the donor');
    await snap(t, '25_requester_confirmed');

    // 6. The donor confirms, which completes it.
    await fsUpdate(reqPath, {'donor_confirmed_at': DateTime.now(), 'status': 'fulfilled', 'fulfilled_at': DateTime.now()});
    await waitFor(t, find.text('Donation received'), why: 'completed request', timeout: const Duration(seconds: 60));
    await snap(t, '26_fulfilled');
  });
}
