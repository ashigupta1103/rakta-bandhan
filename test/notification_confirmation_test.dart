import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/services/notifications_service.dart';

String ago(DateTime _) => 'now';

void main() {
  final base = {'status': 'matched', 'blood_group': 'O+', 'matched_donor_name': 'Asha K', 'matched_at': Timestamp.now()};

  test('donor confirmed -> requester sees a privacy-safe "Donation confirmed"', () {
    final e = FirestoreNotificationsService.requesterEntry('r1', {...base, 'donor_confirmed_at': Timestamp.now()}, ago)!.$1;
    expect(e.kind, NotificationKind.donationConfirmed);
    expect(e.title, 'Donation confirmed');
    expect(e.body, 'A donor has confirmed the donation for your blood request.');
    expect(e.body.contains('Asha'), isFalse);
    expect(e.id, 'r1_donor_confirmed', reason: 'stable id, so repeated snapshots never duplicate it');
    expect(e.requestId, 'r1');
  });

  test('matched with no confirmation still shows the acceptance', () {
    final e = FirestoreNotificationsService.requesterEntry('r1', base, ago)!.$1;
    expect(e.kind, NotificationKind.match);
  });

  test('both sides confirmed (request fulfilled) -> existing "Thanks for donating!", not the donor-confirmed item', () {
    final both = {
      ...base,
      'status': 'fulfilled',
      'fulfilled_at': Timestamp.now(),
      'donor_confirmed_at': Timestamp.now(),
      'requester_confirmed_at': Timestamp.now(),
    };
    final e = FirestoreNotificationsService.requesterEntry('r1', both, ago)!.$1;
    expect(e.id, 'r1_fulfilled');
    expect(e.title, 'Thanks for donating!');
    expect(e.id, isNot('r1_donor_confirmed'));
  });

  test('requester confirmed, donor not yet -> normal matched item', () {
    final e = FirestoreNotificationsService.requesterEntry('r1', {...base, 'requester_confirmed_at': Timestamp.now()}, ago)!.$1;
    expect(e.kind, NotificationKind.match);
    expect(e.id, 'r1_matched');
  });

  test('both confirmed timestamps but status still matched -> never the donor-confirmed item', () {
    final e = FirestoreNotificationsService.requesterEntry(
      'r1',
      {...base, 'donor_confirmed_at': Timestamp.now(), 'requester_confirmed_at': Timestamp.now()},
      ago,
    )!.$1;
    expect(e.id, isNot('r1_donor_confirmed'));
  });
}
