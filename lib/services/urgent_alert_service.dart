import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'call_service.dart';

@immutable
class UrgentAlert {
  final String requestId;
  final String bloodGroup;
  final int units;
  final String urgency;
  final String locationLabel;
  final double distanceKm;

  const UrgentAlert({
    required this.requestId,
    required this.bloodGroup,
    required this.units,
    required this.urgency,
    required this.locationLabel,
    required this.distanceKm,
  });
}

/// The opt-in "ring me for urgent requests" alert — the ride-hailing style
/// full-screen ping with sound, for donors who want it.
///
/// Fires only when every one of these holds, so it stays rare and worth
/// answering:
/// - the donor opted in (`donors/{uid}.urgent_alerts`), is available, not
///   banned, and not already matched on another request;
/// - the request is `urgent` or `critical`, blood-compatible, not their
///   own, within [radiusKm], raised in the last [freshFor];
/// - this device hasn't already alerted for that request.
///
/// While the app is open this is a live Firestore listener over nearby
/// open requests. When the app is in the background or closed, the
/// `onRequestCreated` Cloud Function (functions/src/index.ts) applies the
/// same filter server-side and pushes to the token saved by
/// [requestPushPermission].
class UrgentAlertService {
  UrgentAlertService._();
  static final UrgentAlertService instance = UrgentAlertService._();

  static const radiusKm = 25.0;
  static const freshFor = Duration(minutes: 20);
  static const _seenKey = 'rb_urgent_alert_seen_ids';

  Stream<UrgentAlert> watch() {
    final controller = StreamController<UrgentAlert>();
    Map<String, dynamic>? donor;
    final seen = <String>{};
    StreamSubscription<dynamic>? donorSub;
    StreamSubscription<dynamic>? requestSub;
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? lastRequests;
    String? watchingArea;

    Future<void> remember(String id) async {
      seen.add(id);
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = seen.toList();
        await prefs.setStringList(_seenKey, list.length > 100 ? list.sublist(list.length - 100) : list);
      } catch (_) {}
    }

    // Evaluates the whole open-request set every time (the seen-set makes
    // it idempotent), so requests that arrived before the donor profile
    // loaded aren't lost.
    void evaluate(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
      lastRequests = docs;
      final me = donor;
      if (me == null) return;
      final optedIn = me['urgent_alerts'] == true;
      final eligible = me['is_available'] == true &&
          me['is_banned'] != true &&
          me['active_request_id'] == null &&
          !Backend.onCooldown(me);
      if (!optedIn || !eligible || CallService.instance.active != null) return;

      final myGroup = me['blood_group'] as String?;
      final myLat = (me['lat'] as num?)?.toDouble();
      final myLng = (me['lng'] as num?)?.toDouble();
      if (myGroup == null || myLat == null || myLng == null) return;
      final canGiveTo = Backend.instance.compatibleRecipientGroups(myGroup);
      final myUid = Backend.instance.currentUser?.uid;

      for (final doc in docs) {
        final data = doc.data();
        if (seen.contains(doc.id)) continue;
        if (data['requester_uid'] == myUid) continue;
        final urgency = data['urgency'] as String? ?? 'normal';
        if (urgency != 'urgent' && urgency != 'critical') continue;
        if (!canGiveTo.contains(data['blood_group'])) continue;
        final created = (data['created_at'] as Timestamp?)?.toDate();
        if (created != null && DateTime.now().difference(created) > freshFor) continue;
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final km = distanceKm(myLat, myLng, lat, lng);
        if (km > radiusKm) continue;

        remember(doc.id);
        controller.add(UrgentAlert(
          requestId: doc.id,
          bloodGroup: data['blood_group'] as String? ?? '',
          units: (data['units_needed'] as num?)?.toInt() ?? 1,
          urgency: urgency,
          locationLabel: data['location_label'] as String? ?? '',
          distanceKm: km,
        ));
      }
    }

    controller.onListen = () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        seen.addAll(prefs.getStringList(_seenKey) ?? const []);
      } catch (_) {}
      donorSub = Backend.instance.myDonorDocStream().listen((s) {
        donor = s.data();
        // Watch only requests around the donor's registered area; re-aim
        // the listener if they move it.
        final lat = (donor?['lat'] as num?)?.toDouble();
        final lng = (donor?['lng'] as num?)?.toDouble();
        final area = lat == null || lng == null ? null : '$lat,$lng';
        if (area != null && area != watchingArea) {
          watchingArea = area;
          requestSub?.cancel();
          requestSub = Backend.instance
              .openRequestsNearStream(lat!, lng!, radiusKm: radiusKm)
              .listen(evaluate, onError: (_) {});
        }
        final last = lastRequests;
        if (last != null) evaluate(last);
      }, onError: (_) {});
    };
    controller.onCancel = () async {
      await donorSub?.cancel();
      await requestSub?.cancel();
    };
    return controller.stream;
  }

  /// Turning the toggle on: asks the OS for notification permission where
  /// the platform has one, and registers this device's push token for the
  /// Blaze-era server push. Returns whether system notifications are
  /// allowed — the in-app ring works either way.
  Future<bool> requestPushPermission() async {
    final supported = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!supported) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, sound: true, badge: false);
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted && !kIsWeb) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await Backend.instance.savePushToken(token);
      }
      return granted;
    } catch (_) {
      return false;
    }
  }
}
