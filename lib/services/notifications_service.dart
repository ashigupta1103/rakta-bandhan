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

  /// The request this notification is about, so "View request" can open it.
  /// Null for the mock fixtures, which have no real document behind them.
  final String? requestId;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.requestId,
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

/// Notification feed (see [FirestoreNotificationsService]).
abstract class NotificationsService {
  Stream<NotificationsFeed> watchNotifications();
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

  (AppNotification, DateTime)? _fromRequesterDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => requesterEntry(doc.id, doc.data(), _timeAgo);

  /// What the requester's feed shows for one of their requests (pure, so it
  /// can be tested without Firestore).
  @visibleForTesting
  static (AppNotification, DateTime)? requesterEntry(String docId, Map<String, dynamic> data, String Function(DateTime) timeAgo) {
    final status = data['status'] as String?;
    final bloodGroup = data['blood_group'] as String? ?? '';
    final location = data['location_label'] as String? ?? '';
    switch (status) {
      case 'matched':
        // The donor says they've donated and the requester hasn't confirmed
        // yet: tell the requester (no donor details beyond "a donor").
        final donorDoneAt = (data['donor_confirmed_at'] as Timestamp?)?.toDate();
        if (donorDoneAt != null && data['requester_confirmed_at'] == null) {
          return (
            AppNotification(
              id: '${docId}_donor_confirmed',
              kind: NotificationKind.donationConfirmed,
              title: 'Donation confirmed',
              body: 'A donor has confirmed the donation for your blood request.',
              time: timeAgo(donorDoneAt),
              requestId: docId,
            ),
            donorDoneAt,
          );
        }
        final at = (data['matched_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${docId}_matched',
            kind: NotificationKind.match,
            title: '${data['matched_donor_name'] ?? 'A donor'} accepted your request',
            body: '$bloodGroup · $location',
            time: timeAgo(at),
            requestId: docId,
          ),
          at,
        );
      case 'fulfilled':
        final at = (data['fulfilled_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${docId}_fulfilled',
            kind: NotificationKind.donationConfirmed,
            title: 'Thanks for donating!',
            body: '${data['matched_donor_name'] ?? 'Your donor'} confirmed the donation.',
            time: timeAgo(at),
            requestId: docId,
          ),
          at,
        );
      case 'expired':
        final at = (data['expired_at'] as Timestamp?)?.toDate() ?? DateTime.now();
        return (
          AppNotification(
            id: '${docId}_expired',
            kind: NotificationKind.expiration,
            title: 'Request expired',
            body: 'No donor found in time for your $bloodGroup request.',
            time: timeAgo(at),
            requestId: docId,
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
        requestId: doc.id,
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
