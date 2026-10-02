// Donor side of the story on an Android emulator (see support.dart for how
// to run it): sign up → register → accept a nearby request → an in-app call →
// both people confirm the donation → certificate. The requester is written
// into the Firestore emulator over REST; everything the app does goes
// through the real security rules.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rakta_bandhan/main.dart' as app;
import 'package:rakta_bandhan/services/backend.dart' show encodeGeohash;
import 'package:rakta_bandhan/services/push_service.dart';

import 'support.dart';

// Requester side of the story, near Chennai Central.
const _reqId = 'e2e_request_1';
const _requesterUid = 'e2e_requester';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('donor journey: sign in → register → accept → call → donate → certificate', (t) async {
    await app.main();
    final email = 'e2e-donor-${DateTime.now().millisecondsSinceEpoch}@example.com';

    // 1-2. Create an account, confirm the email, register as an O+ donor.
    await signUpAndRegister(t, email: email, name: 'Test Donor', bloodGroup: 'O+');
    final me = FirebaseAuth.instance.currentUser!.uid;

    // 3. Someone nearby needs A+ (an O+ donor can give).
    final now = DateTime.now();
    await fsSet('requests/$_reqId', {
      'requester_uid': _requesterUid,
      'requester_name': 'Priya (test)',
      'blood_group': 'A+',
      'units_needed': 1,
      'urgency': 'urgent',
      'location_label': 'Apollo Hospital, Greams Road, Thousand Lights, Chennai, 600006, India',
      'geohash': encodeGeohash(hospital.lat, hospital.lng),
      'lat': hospital.lat,
      'lng': hospital.lng,
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
    await waitFor(t, find.text('See request & help'), why: 'nearby request card');
    await snap(t, '04_requests_near_you');
    await tapWhenReady(t, find.text('See request & help'));
    await waitFor(t, find.text('Accept & help'));
    await snap(t, '05_request_detail');
    await tapWhenReady(t, find.text('Accept & help'));
    await waitFor(t, find.text('View contact details'), why: 'accept success');
    await snap(t, '06_accepted');
    await tapWhenReady(t, find.text('View contact details'));
    await waitFor(t, find.text('I’ve donated — confirm'), why: 'match contact screen');
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

    // 6. Both sides confirm the donation: the donor first...
    await tapWhenReady(t, find.text('I’ve donated — confirm'));
    await tapWhenReady(t, find.text('Yes, I donated'));
    await waitFor(t, find.textContaining('Your confirmation is saved'), why: 'donor confirmation saved');
    await snap(t, '10_donor_confirmed');
    var req = await fsGet('requests/$_reqId');
    expect(req?['fields']?['status']?['stringValue'], 'matched', reason: 'still waiting for the requester');
    expect(req?['fields']?['donor_confirmed_at'], isNotNull);
    // ...then the requester, which completes it. The donor's screen is still
    // open, so it applies the rest period and the record and says thank you.
    await fsUpdate('requests/$_reqId', {
      'requester_confirmed_at': DateTime.now(),
      'status': 'fulfilled',
      'fulfilled_at': DateTime.now(),
    });
    req = await fsGet('requests/$_reqId');
    expect(req?['fields']?['status']?['stringValue'], 'fulfilled');
    await waitFor(t, find.text('Done'), why: 'thank-you screen once the requester confirmed', timeout: const Duration(seconds: 60));
    await snap(t, '10b_donation_recorded');
    expect(await fsGet('donation_history/$_reqId'), isNotNull, reason: 'the donation record was written');
    expect((await fsGet('donors/$me'))?['fields']?['reactivation_scheduled_at'], isNotNull, reason: 'the rest period started');
    await tapWhenReady(t, find.text('Done'));
    await snap(t, '11_cooldown');

    // 7. My Page: availability locked, certificate from donation history.
    await popToRoot(t);
    await tapWhenReady(t, find.text('My Page'));
    await waitFor(t, find.textContaining('Paused during your recovery'), why: 'locked availability');
    await snap(t, '12_profile_cooldown');
    final toggle = t.widget<Switch>(find.byType(Switch).first);
    expect(toggle.onChanged, isNull, reason: 'availability is locked during the rest period');
    await tapWhenReady(t, find.textContaining('Donation history'));
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
    await waitFor(t, find.textContaining('Share your donation story'));
    await snap(t, '15_community');
  });
}
