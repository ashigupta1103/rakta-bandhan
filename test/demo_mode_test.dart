import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/demo/demo.dart';

void main() {
  tearDown(() => Demo.instance.stop());

  test('demo is off until a session is started, and off again after exit', () {
    expect(Demo.on, isFalse);
    expect(Demo.isDemoId(Demo.requestId), isFalse, reason: 'demo ids mean nothing outside a session');
    Demo.instance.start(DemoRole.requester);
    expect(Demo.on, isTrue);
    expect(Demo.isDemoId(Demo.requestId), isTrue);
    expect(Demo.isDemoId('aB3dE5gH7jK9mN1pQ2rS'), isFalse, reason: 'real Firestore ids never match');
    Demo.instance.stop();
    expect(Demo.on, isFalse);
    expect(Demo.instance.request, isNull);
  });

  test('requester journey: request, match, two-sided completion', () {
    final d = Demo.instance..start(DemoRole.requester);
    d.createRequest(group: 'O+', units: 2, urgency: 'urgent', label: 'Test hospital');
    expect(d.request!['status'], 'open');
    expect(d.request!['units_needed'], 2);
    d.match();
    expect(d.request!['status'], 'matched');
    expect(d.request!['matched_donor_name'], Demo.donorName);
    expect(d.confirmMine(), isFalse, reason: 'one side alone does not complete it');
    expect(d.request!['status'], 'matched');
    d.confirmPeer();
    expect(d.request!['status'], 'fulfilled');
    expect(d.recoveryUntil, isNull, reason: 'the requester persona never enters recovery');
  });

  test('donor journey: completion starts recovery and adds to history once', () {
    final d = Demo.instance..start(DemoRole.donor);
    expect(d.request!['status'], 'open', reason: 'the donor starts with an incoming request');
    expect(d.donationRecords.length, Demo.donorPriorDonations);
    d.match();
    d.confirmPeer();
    expect(d.confirmMine(), isTrue);
    expect(d.request!['status'], 'fulfilled');
    expect(d.recoveryUntil, isNotNull);
    expect(d.myDonations, Demo.donorPriorDonations + 1);
    expect(d.donationRecords.length, Demo.donorPriorDonations + 1);
    expect(d.myProfile['is_available'], isFalse, reason: 'recovery pauses availability');
  });

  test('reset restores the journey start and clears local data only', () {
    final d = Demo.instance..start(DemoRole.requester);
    d.createRequest(group: 'A+', units: 1, urgency: 'normal', label: '');
    d.match();
    d.send('hello');
    d.addStory('A story', 'Gratitude');
    d.reset();
    expect(Demo.on, isTrue);
    expect(d.request, isNull);
    expect(d.messages, isEmpty);
    expect(d.stories, isEmpty);
  });

  test('demo codes are fixed and distinct', () {
    expect(Demo.emailCode, hasLength(6));
    expect(Demo.phoneOtp, hasLength(6));
    expect(Demo.emailCode, isNot(Demo.phoneOtp));
  });

  test('own stories can be edited and deleted; others are untouched', () {
    final d = Demo.instance..start(DemoRole.requester);
    d.addStory('First draft', 'Gratitude');
    d.addStory('Another story', 'Awareness');
    final id = d.stories.last['id'] as String;
    d.updateStory(id, body: 'Edited text', topic: 'My first donation');
    final edited = d.stories.firstWhere((st) => st['id'] == id);
    expect(edited['body'], 'Edited text');
    expect(edited['topic'], 'My first donation');
    expect(edited['edited_at'], isNotNull);
    d.deleteStory(id);
    expect(d.stories.where((st) => st['id'] == id), isEmpty);
    expect(d.stories, hasLength(1), reason: 'only the chosen story is removed');
  });
}
