import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'backend.dart';

enum NotificationKind { request, match, cancellation, expiration, donationConfirmed }

@immutable
class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final String time;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
  });
}

/// A snapshot of the notification feed: whether notifications are enabled
/// (OS permission / user preference) and the items to show when they are.
@immutable
class NotificationsFeed {
  final bool enabled;
  final List<AppNotification> items;

  const NotificationsFeed({required this.enabled, required this.items});
}

/// Notification feed. No FCM/backend collection exists yet, so this is a
/// local mock — the backend developer replaces MockNotificationsService with
/// a real FCM + Firestore implementation behind this same interface.
abstract class NotificationsService {
  Stream<NotificationsFeed> watchNotifications();
}

class MockNotificationsService implements NotificationsService {
  static const _fixtures = <AppNotification>[
    AppNotification(
      id: 'n1',
      kind: NotificationKind.match,
      title: 'Rohan accepted your request',
      body: 'O+ · 2 units · Sneha Hospital, Koramangala',
      time: '2 min ago',
    ),
    AppNotification(
      id: 'n2',
      kind: NotificationKind.request,
      title: 'New compatible request nearby',
      body: 'A- needed · 1.8 km away',
      time: '18 min ago',
    ),
    AppNotification(
      id: 'n3',
      kind: NotificationKind.donationConfirmed,
      title: 'Thanks for donating!',
      body: "You've helped save a life. 90-day cooldown started.",
      time: '1 day ago',
    ),
    AppNotification(
      id: 'n4',
      kind: NotificationKind.expiration,
      title: 'Request expired',
      body: 'No donor found in time for your AB- request.',
      time: '2 days ago',
    ),
    AppNotification(
      id: 'n5',
      kind: NotificationKind.cancellation,
      title: 'Request cancelled',
      body: 'Your B+ request was cancelled.',
      time: '3 days ago',
    ),
  ];

  @override
  Stream<NotificationsFeed> watchNotifications() =>
      Stream.value(const NotificationsFeed(enabled: true, items: _fixtures));
}

/// Real feed, derived — not stored. There's no `notifications` collection
/// (that would need Cloud Functions to fan out writes to strangers'
/// subcollections, which Spark can't run); instead this merges the two
/// request streams the signed-in user already has read access to under
/// firestore.rules (their own requests as requester, and the requests
/// they're the matched donor on) and synthesizes entries from each doc's
/// status + timestamp fields. Only reacts to events relevant to the
/// *other* party — a user's own actions (creating, cancelling, accepting,
/// marking fulfilled) already have immediate on-screen feedback elsewhere
/// and aren't repeated here.
class FirestoreNotificationsService implements NotificationsService {
  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour(s) ago';
    return '${diff.inDays} day(s) ago';
  }

  (AppNotification, DateTime)? _fromRequesterDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = data['status'] as String?;
    final bloodGroup = data['blood_group'] as String? ?? '';
    final location = data['location_label'] as String? ?? '';
    switch (status) {
      case 'matched':
        final at = (data['matched_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${doc.id}_matched',
            kind: NotificationKind.match,
            title: '${data['matched_donor_name'] ?? 'A donor'} accepted your request',
            body: '$bloodGroup · $location',
            time: _timeAgo(at),
          ),
          at,
        );
      case 'fulfilled':
        final at = (data['fulfilled_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${doc.id}_fulfilled',
            kind: NotificationKind.donationConfirmed,
            title: 'Thanks for donating!',
            body: '${data['matched_donor_name'] ?? 'Your donor'} confirmed the donation.',
            time: _timeAgo(at),
          ),
          at,
        );
      case 'expired':
        final at = (data['expired_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${doc.id}_expired',
            kind: NotificationKind.expiration,
            title: 'Request expired',
            body: 'No donor found in time for your $bloodGroup request.',
            time: _timeAgo(at),
          ),
          at,
        );
      default:
        return null;
    }
  }

  (AppNotification, DateTime)? _fromDonorDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data['status'] != 'cancelled') return null;
    final at = (data['cancelled_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    return (
      AppNotification(
        id: '${doc.id}_cancelled',
        kind: NotificationKind.cancellation,
        title: 'Request cancelled',
        body: '${data['requester_name'] ?? 'The requester'} cancelled a ${data['blood_group'] ?? ''} request you accepted.',
        time: _timeAgo(at),
      ),
      at,
    );
  }

  @override
  Stream<NotificationsFeed> watchNotifications() async* {
    QuerySnapshot<Map<String, dynamic>>? asRequester;
    QuerySnapshot<Map<String, dynamic>>? asDonor;

    final controller = StreamController<NotificationsFeed>.broadcast();
    void emit() {
      if (asRequester == null || asDonor == null) return;
      final entries = [
        for (final doc in asRequester!.docs) _fromRequesterDoc(doc),
        for (final doc in asDonor!.docs) _fromDonorDoc(doc),
      ].whereType<(AppNotification, DateTime)>().toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      controller.add(NotificationsFeed(enabled: true, items: [for (final e in entries) e.$1]));
    }

    final subA = Backend.instance.myRequestsStream().listen((s) {
      asRequester = s;
      emit();
    }, onError: controller.addError);
    final subB = Backend.instance.myMatchedRequestsStream().listen((s) {
      asDonor = s;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };

    yield* controller.stream;
  }
}
