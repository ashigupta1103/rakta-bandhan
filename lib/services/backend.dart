import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

import 'geo_config.dart';

/// Recipient blood group -> donor groups that can give to it.
const bloodCompatibility = <String, List<String>>{
  'A+': ['A+', 'A-', 'O+', 'O-'],
  'A-': ['A-', 'O-'],
  'B+': ['B+', 'B-', 'O+', 'O-'],
  'B-': ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'AB-': ['A-', 'B-', 'AB-', 'O-'],
  'O+': ['O+', 'O-'],
  'O-': ['O-'],
};

const donorCooldownDays = 90;

/// Region the Cloud Functions are deployed to — must equal REGION in
/// functions/src/app.ts.
const kFunctionsRegion = 'asia-south1';
const requestExpiryHours = 6;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard interleaved-bits geohash encoder. Stored on donor/request docs;
/// `_geohashCellsAround`/`_geohashRangeStream` below use it for real range
/// queries (Geoflutterfire-style) in the proximity-search paths. The
/// blanket "browse everything" streams (`openRequestsStream`,
/// `availableDonorsStream`) still filter/sort by Haversine distance
/// client-side instead — narrowing those to a radius is a visibility
/// decision (would a request/donor outside the radius go unseen?), not
/// just a performance one, so it's left alone here.
String encodeGeohash(double lat, double lng, {int precision = 9}) {
  double latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  final buffer = StringBuffer();
  var isEven = true;
  var bit = 0;
  var ch = 0;

  while (buffer.length < precision) {
    if (isEven) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= (1 << (4 - bit));
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      buffer.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return buffer.toString();
}

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Reverses [encodeGeohash]'s bit-interleaving loop to recover the cell's
/// lat/lng bounding box — same alphabet, same isEven-starts-on-lng order,
/// so a hash this decodes is always one this file itself encoded.
(double, double, double, double) _decodeGeohashBounds(String hash) {
  double latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  var isEven = true;
  for (final char in hash.split('')) {
    final idx = _base32.indexOf(char);
    for (var mask = 16; mask != 0; mask >>= 1) {
      if (isEven) {
        final mid = (lngMin + lngMax) / 2;
        if (idx & mask != 0) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (idx & mask != 0) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isEven = !isEven;
    }
  }
  return (latMin, latMax, lngMin, lngMax);
}

/// The coarsest (most selective) geohash precision whose cell still spans
/// at least [radiusKm] in both directions at [lat] — picking the finest
/// precision that still comfortably contains the search radius keeps the
/// 3x3 neighbor grid below from missing anything a plain single-cell query
/// would (the classic geohash-query edge case: the search point sitting
/// near a cell boundary).
int _precisionForRadius(double lat, double radiusKm) {
  for (var precision = 9; precision >= 1; precision--) {
    final (latMin, latMax, lngMin, lngMax) = _decodeGeohashBounds(encodeGeohash(lat, 0, precision: precision));
    final latKm = (latMax - latMin) * 111.32;
    final lngKm = (lngMax - lngMin) * 111.32 * cos(lat * pi / 180).abs();
    if (latKm >= radiusKm && lngKm >= radiusKm) return precision;
  }
  return 1;
}

/// The center cell covering ([lat], [lng]) at [precision] plus its 8
/// neighbors — the standard 3x3 grid a Firestore geohash range query scans
/// (each cell becomes one `[cell, cell + '~']` prefix range in
/// [_geohashRangeStream]). The true radius cutoff still happens
/// client-side afterwards; this grid only bounds which documents Firestore
/// has to return in the first place.
List<String> _geohashCellsAround(double lat, double lng, int precision) {
  final center = encodeGeohash(lat, lng, precision: precision);
  final (latMin, latMax, lngMin, lngMax) = _decodeGeohashBounds(center);
  final latStep = latMax - latMin;
  final lngStep = lngMax - lngMin;
  final cells = <String>{center};
  for (final dLat in [-1, 0, 1]) {
    for (final dLng in [-1, 0, 1]) {
      if (dLat == 0 && dLng == 0) continue;
      final nLat = (lat + dLat * latStep).clamp(-90.0, 90.0);
      final nLng = ((lng + dLng * lngStep + 180) % 360 + 360) % 360 - 180;
      cells.add(encodeGeohash(nLat, nLng, precision: precision));
    }
  }
  return cells.toList();
}

/// Thrown when a donor tries to accept a request someone else already claimed.
class RequestAlreadyClaimedException implements Exception {
  const RequestAlreadyClaimedException();
  @override
  String toString() => 'Someone else already accepted this request.';
}

/// Thrown when a donor still inside their post-donation cooldown tries to
/// accept a request.
class DonorOnCooldownException implements Exception {
  const DonorOnCooldownException();
  @override
  String toString() => 'You donated recently. You can accept requests again once your 90-day rest period ends.';
}

/// Thrown when a donor tries to accept a second request while already
/// matched on another one. `request_detail_screen.dart` checks this
/// proactively (`_findExistingActiveMatch`) before calling acceptRequest;
/// this is the transactional backstop for the race that check can't cover.
class DonorAlreadyMatchedException implements Exception {
  const DonorAlreadyMatchedException();
  @override
  String toString() => 'You already have an active match. Finish or cancel it first.';
}

/// Firebase data layer for Rakta Bandhan.
///
/// No Cloud Functions run behind this (Spark plan, see backend/README.md)
/// — matching, accept-locking, contact reveal, admin verification/ban, and
/// the 90-day cooldown are all done here, client-side, backed by Firestore
/// transactions and security rules for the parts that need to stay honest
/// (see backend/firestore.rules).
class Backend {
  Backend._();
  static final Backend instance = Backend._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _analytics = FirebaseAnalytics.instance;

  /// Best-effort — a broken/offline Analytics call must never break the
  /// funnel step it's reporting on.
  void _logEvent(String name, [Map<String, Object>? parameters]) {
    _analytics.logEvent(name: name, parameters: parameters).catchError((_) {});
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();
  String get _uid => _auth.currentUser!.uid;

  // ------------------------------------------------------------ Sign-in
  //
  // Passwordless: a 6-digit code goes to the user's email
  // (requestLoginCode), and verifyLoginCode trades it for a Firebase custom
  // token — see functions/src/login.ts. The same email always lands on the
  // same account. Codes by SMS plug into the same two functions later
  // (channel: 'sms'). Firestore rules treat a code-login token as verified
  // (isVerifiedUser in firestore.rules).

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  /// Sends a sign-in code to [email]. Returns how many seconds to wait
  /// before offering "Resend".
  Future<int> requestLoginCode(String email) async {
    final result = await _functions.httpsCallable('requestLoginCode').call<Map<String, dynamic>>({
      'channel': 'email',
      'email': email.trim(),
    });
    _logEvent('login_code_requested', {'channel': 'email'});
    return (result.data['resendAfterS'] as num?)?.toInt() ?? 30;
  }

  /// Checks the code and signs in. Throws [FirebaseFunctionsException]
  /// with a human message on a wrong / expired code.
  Future<User> verifyLoginCode(String email, String code) async {
    final result = await _functions.httpsCallable('verifyLoginCode').call<Map<String, dynamic>>({
      'email': email.trim(),
      'code': code.trim(),
    });
    final cred = await _auth.signInWithCustomToken(result.data['token'] as String);
    _logEvent('login', {'method': 'email_code'});
    return cred.user!;
  }

  Future<void> signOut() => _auth.signOut();

  /// Last step of account deletion: the sign-in account itself, removed by
  /// a function (a passwordless account can't re-enter a password to
  /// satisfy Firebase's recent-login rule on the device).
  Future<void> deleteMyAuthAccount() => _functions.httpsCallable('deleteMyAuthAccount').call<Map<String, dynamic>>();

  /// Human wording for sign-in errors. The sign-in functions already send
  /// a readable message; anything else gets a generic one. Never echoes a
  /// raw exception.
  static String authErrorMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      final message = e.message ?? '';
      if (e.code == 'internal' || e.code == 'unknown' || message.isEmpty) {
        return 'Something went wrong. Check your connection and try again.';
      }
      if (e.code == 'unavailable' && message.toLowerCase() == 'unavailable') {
        return 'No internet connection. Check your network and try again.';
      }
      return message;
    }
    final code = e is FirebaseAuthException ? e.code : '';
    return switch (code) {
      'user-disabled' => 'This account has been disabled. Contact support.',
      'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
      'network-request-failed' => 'No internet connection. Check your network and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  /// Debug builds with `--dart-define=USE_EMULATORS=true` talk to the local
  /// Firebase emulators instead of the live project (from an Android
  /// emulator the host is 10.0.2.2). Called once from main().
  static Future<void> connectToEmulators(String host) async {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: kFunctionsRegion).useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  /// ~1.1 km precision. donors_public is readable by every signed-in user,
  /// and the consent screen promises donors are shown "approximately" —
  /// exact coordinates only ever live on the private donors/{uid} doc.
  static double _coarse(double degrees) => (degrees * 100).roundToDouble() / 100;

  Future<DocumentSnapshot<Map<String, dynamic>>> myDonorDoc() =>
      _db.collection('donors').doc(_uid).get();

  Stream<DocumentSnapshot<Map<String, dynamic>>> myDonorDocStream() =>
      _db.collection('donors').doc(_uid).snapshots();

  Future<bool> hasProfile() async => (await myDonorDoc()).exists;

  /// New donors start unverified and unbanned — `is_verified` is
  /// admin-only from here on (see backend/firestore.rules), matching the
  /// admin dashboard's verification queue. [locationLabel] is the free-text
  /// address the donor searched/picked at registration, shown back to
  /// admins in the console (donor docs otherwise only have raw lat/lng).
  Future<void> registerDonor({
    required String name,
    required String phone,
    required String bloodGroup,
    required double lat,
    required double lng,
    String? locationLabel,
  }) async {
    final geohash = encodeGeohash(lat, lng);
    final now = FieldValue.serverTimestamp();
    // Neighbourhood-level name ("Adyar, Chennai") for the public listing —
    // looked up from the already-coarsened point, so it can never be more
    // precise than the ~1 km the listing promises.
    final area = await reverseGeocodeArea(_coarse(lat), _coarse(lng)) ?? '';

    // A real transaction, not a batch: donors_public's create rule reads
    // donors/{uid} (get()) to confirm is_verified/is_available match —
    // that read is only guaranteed to see this write's own donors/{uid}
    // value within the same transaction, not necessarily within a plain
    // batch. See backend/firestore.rules.
    await _db.runTransaction((tx) async {
      tx.set(_db.collection('donors').doc(_uid), {
        'name': name,
        'phone': phone,
        'email': _auth.currentUser?.email ?? '',
        'blood_group': bloodGroup,
        'location_label': locationLabel ?? '',
        'geohash': geohash,
        'lat': lat,
        'lng': lng,
        'is_available': true,
        'is_verified': false,
        'is_banned': false,
        'active_request_id': null,
        'created_at': now,
      });
      tx.set(_db.collection('donors_public').doc(_uid), {
        'name': name,
        'blood_group': bloodGroup,
        'geohash': encodeGeohash(_coarse(lat), _coarse(lng), precision: 6),
        'lat': _coarse(lat),
        'lng': _coarse(lng),
        'area': area,
        'is_available': true,
        'is_verified': false,
        'updated_at': now,
      });
    });
    _logEvent('donor_registered', {'blood_group': bloodGroup});
  }

  /// The donor moved: new exact point on the private profile, and the
  /// coarse point + neighbourhood name on the public listing.
  Future<void> updateMyLocation({required double lat, required double lng, required String label}) async {
    final area = await reverseGeocodeArea(_coarse(lat), _coarse(lng)) ?? '';
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('donors').doc(_uid), {
        'lat': lat,
        'lng': lng,
        'geohash': encodeGeohash(lat, lng),
        'location_label': label,
      });
      tx.update(_db.collection('donors_public').doc(_uid), {
        'lat': _coarse(lat),
        'lng': _coarse(lng),
        'geohash': encodeGeohash(_coarse(lat), _coarse(lng), precision: 6),
        'area': area,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// True while the donor's post-donation cooldown is running.
  static bool onCooldown(Map<String, dynamic>? donor) {
    final until = (donor?['reactivation_scheduled_at'] as Timestamp?)?.toDate();
    return until != null && until.isAfter(DateTime.now());
  }

  /// Base64-encodes the donor's picked ID proof photo directly onto their
  /// private `donors/{uid}` doc (never `donors_public` — same visibility
  /// tier as phone). Cloud Storage now requires a Blaze billing account
  /// (Google policy change, no more free Spark bucket) — this stays on the
  /// free Firestore-only path instead. Caller (personal_information_
  /// screen.dart) constrains the picked image's resolution/quality so the
  /// encoded string comfortably fits Firestore's 1MiB document limit.
  /// Admins view it from AdminDonorDetailScreen before verifying.
  ///
  /// The image lives in its own document (`donors/{uid}/private/id_proof`),
  /// not inline on the profile: the profile is read on nearly every screen,
  /// and an inline ~200 KB image made every one of those reads download it.
  /// The profile keeps only a `has_id_proof` flag.
  Future<void> uploadIdProof(XFile file) async {
    final bytes = await file.readAsBytes();
    final batch = _db.batch();
    batch.set(_idProofRef(_uid), {
      'base64': base64Encode(bytes),
      'content_type': file.mimeType ?? 'image/jpeg',
      'uploaded_at': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('donors').doc(_uid), {
      'has_id_proof': true,
      'id_proof_base64': FieldValue.delete(),
      'id_proof_content_type': FieldValue.delete(),
    });
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _idProofRef(String uid) =>
      _db.collection('donors').doc(uid).collection('private').doc('id_proof');

  /// Owner/admin only (rules). Falls back to the legacy inline field for
  /// donors who uploaded before the image moved to its own document.
  Future<String?> fetchIdProof(String uid) async {
    final own = (await _idProofRef(uid).get()).data()?['base64'] as String?;
    if (own != null) return own;
    return (await _db.collection('donors').doc(uid).get()).data()?['id_proof_base64'] as String?;
  }

  /// Account deletion: the ID image document goes with the profile.
  Future<void> deleteMyIdProof() => _idProofRef(_uid).delete();

  Future<void> setAvailability(bool available) async {
    // The rules refuse this during the post-donation rest period anyway;
    // checking first gives the UI a clear reason instead of a denied write.
    if (available && onCooldown((await myDonorDoc()).data())) throw const DonorOnCooldownException();
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('donors').doc(_uid), {'is_available': available});
      tx.update(_db.collection('donors_public').doc(_uid), {
        'is_available': available,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Opt-in for the ringing urgent-request alert (see UrgentAlertService).
  /// Stored on the private profile so a future Blaze push function can
  /// honour the same preference server-side.
  Future<void> setUrgentAlerts(bool enabled) =>
      _db.collection('donors').doc(_uid).update({'urgent_alerts': enabled});

  /// FCM device token, for the Blaze-era push functions (urgent alerts,
  /// incoming calls, chat). Owner-only doc, so never visible to others.
  Future<void> savePushToken(String token) => _db.collection('donors').doc(_uid).update({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });

  /// Sign-out: this phone should stop getting pushes for this account.
  Future<void> clearPushToken() => _db.collection('donors').doc(_uid).update({'fcm_token': FieldValue.delete()});

  /// Client-side stand-in for scheduledReactivation.js — call on profile load.
  Future<void> maybeReactivate() async {
    final snap = await myDonorDoc();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['is_available'] == true) return;
    final reactivateAt = data['reactivation_scheduled_at'] as Timestamp?;
    if (reactivateAt == null || reactivateAt.toDate().isAfter(DateTime.now())) return;
    await setAvailability(true);
  }

  /// Whole-collection scan — reads every available donor. Kept for the
  /// admin/preview paths only; user-facing screens use NearbyDonors, whose
  /// cost scales with local density instead of total signups.
  Stream<QuerySnapshot<Map<String, dynamic>>> availableDonorsStream() =>
      _db.collection('donors_public').where('is_available', isEqualTo: true).snapshots();

  /// Real geohash range query (Geoflutterfire-style): scans only the 3x3
  /// grid of cells around ([lat], [lng]) sized to [radiusKm], instead of
  /// every available donor in the collection. Firestore can't OR multiple
  /// range queries together, so this merges up to 9 live per-cell
  /// snapshots streams client-side — still cheap, since each cell only
  /// reads the donors actually inside it. The grid over-covers slightly at
  /// its corners; callers should still apply the real `radiusKm` cutoff via
  /// [distanceKm] before treating a result as "nearby" (see
  /// find_donors_screen.dart).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> availableDonorsNearbyStream({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) {
    final precision = _precisionForRadius(lat, radiusKm);
    final cells = _geohashCellsAround(lat, lng, precision);
    return _geohashRangeStream(
      collection: 'donors_public',
      cells: cells,
      extraFilters: (q) => q.where('is_available', isEqualTo: true),
    );
  }

  /// Fans out one live query per geohash cell and combines their latest
  /// results into a single deduped stream (Firestore has no native
  /// multi-range OR query, so this is the client-side merge every
  /// geohash-query library — Geoflutterfire included — does under the hood).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _geohashRangeStream({
    required String collection,
    required List<String> cells,
    required Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>) extraFilters,
  }) {
    late final StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>> controller;
    final latest = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subs = <StreamSubscription>[];

    void emit() {
      final seen = <String>{};
      final merged = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final docs in latest.values) {
        for (final doc in docs) {
          if (seen.add(doc.id)) merged.add(doc);
        }
      }
      controller.add(merged);
    }

    controller = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        for (final cell in cells) {
          Query<Map<String, dynamic>> q = _db
              .collection(collection)
              .where('geohash', isGreaterThanOrEqualTo: cell)
              .where('geohash', isLessThan: '$cell~');
          q = extraFilters(q);
          subs.add(q.snapshots().listen((snap) {
            latest[cell] = snap.docs;
            emit();
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Open requests within [radiusKm] of a point, newest first — a bounded
  /// geohash-cell query (at most 9 × 60 documents), not every open request
  /// in the country. This is what the donor-facing feeds use: at 1 lakh
  /// users a nationwide listener re-bills every open request to every
  /// phone. Needs the (status, geohash) index.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> openRequestsNearStream(
    double lat,
    double lng, {
    double radiusKm = 50,
  }) {
    final cells = _geohashCellsAround(lat, lng, _precisionForRadius(lat, radiusKm));
    return _geohashRangeStream(
      collection: 'requests',
      cells: cells,
      extraFilters: (q) => q.where('status', isEqualTo: 'open').limit(60),
    ).map((docs) {
      final near = docs.where((d) {
        final r = d.data();
        final rLat = (r['lat'] as num?)?.toDouble();
        final rLng = (r['lng'] as num?)?.toDouble();
        return rLat != null && rLng != null && distanceKm(lat, lng, rLat, rLng) <= radiusKm;
      }).toList();
      // A just-created request has no server timestamp yet: newest.
      final pending = DateTime.now().millisecondsSinceEpoch + 60000;
      near.sort((a, b) {
        final ta = (a.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? pending;
        final tb = (b.data()['created_at'] as Timestamp?)?.millisecondsSinceEpoch ?? pending;
        return tb.compareTo(ta);
      });
      return near;
    });
  }

  /// Every open request, nationwide. Admin/preview use only — user-facing
  /// screens use [openRequestsNearStream].
  Stream<QuerySnapshot<Map<String, dynamic>>> openRequestsStream() => _db
      .collection('requests')
      .where('status', isEqualTo: 'open')
      .orderBy('created_at', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myRequestsStream() => _db
      .collection('requests')
      .where('requester_uid', isEqualTo: _uid)
      .orderBy('created_at', descending: true)
      .snapshots();

  List<String> compatibleRecipientGroups(String donorBloodGroup) => bloodCompatibility.entries
      .where((e) => e.value.contains(donorBloodGroup))
      .map((e) => e.key)
      .toList();

  /// Denormalizes the requester's own name/phone onto the request at
  /// creation time — the matched donor then reads contact info straight
  /// off this doc (see MatchContactScreen) instead of needing a second,
  /// separately-authorized read of `donors/{requester_uid}`.
  Future<String> createRequest({
    required String bloodGroup,
    required int unitsNeeded,
    required String urgency,
    required double lat,
    required double lng,
    required String locationLabel,
  }) async {
    final requester = (await myDonorDoc()).data();
    final geohash = encodeGeohash(lat, lng);
    final ref = await _db.collection('requests').add({
      'requester_uid': _uid,
      'requester_name': requester?['name'] ?? 'Requester',
      'requester_phone': requester?['phone'] ?? '',
      'blood_group': bloodGroup,
      'units_needed': unitsNeeded,
      'urgency': urgency,
      'location_label': locationLabel,
      'geohash': geohash,
      'lat': lat,
      'lng': lng,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: requestExpiryHours)),
      ),
    });
    _logEvent('request_created', {'blood_group': bloodGroup, 'urgency': urgency});
    return ref.id;
  }

  Future<void> cancelRequest(String requestId) => _db.collection('requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
      });

  /// Lazy stand-in for the Blaze-only expireOldRequests scheduled function
  /// — call opportunistically wherever a request doc is already being
  /// read (list/detail/tracking screens). A no-op unless it's genuinely
  /// still `open` and past its `expires_at`; safe to call on every doc a
  /// screen renders.
  Future<void> expireIfStale(String requestId, Map<String, dynamic> data) async {
    if (data['status'] != 'open') return;
    final expiresAt = data['expires_at'] as Timestamp?;
    if (expiresAt == null || expiresAt.toDate().isAfter(DateTime.now())) return;
    try {
      await _db.collection('requests').doc(requestId).update({
        'status': 'expired',
        'expired_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Already transitioned by someone else / no longer open — fine.
    }
  }

  /// Donor accepts an open request. A Firestore transaction still
  /// serializes concurrent accepts correctly even without a Cloud
  /// Function — only one donor's write wins; the loser gets this thrown.
  /// Also enforces "one active match per donor" transactionally: the
  /// donor's own `active_request_id` is the lock, self-healed here if it
  /// points at a request that's no longer actually active (matched
  /// elsewhere finished/cancelled without this donor's client seeing it).
  Future<void> acceptRequest(String requestId) async {
    await _db.runTransaction((tx) async {
      final donorRef = _db.collection('donors').doc(_uid);
      final donorSnap = await tx.get(donorRef);
      if (!donorSnap.exists) throw StateError('No donor profile.');
      final donor = donorSnap.data()!;
      if (onCooldown(donor)) throw const DonorOnCooldownException();

      final activeId = donor['active_request_id'] as String?;
      if (activeId != null && activeId != requestId) {
        final activeSnap = await tx.get(_db.collection('requests').doc(activeId));
        final stillActive = activeSnap.exists && activeSnap.data()?['status'] == 'matched';
        if (stillActive) throw const DonorAlreadyMatchedException();
      }

      final reqRef = _db.collection('requests').doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists || reqSnap.data()!['status'] != 'open') {
        throw const RequestAlreadyClaimedException();
      }

      tx.update(reqRef, {
        'status': 'matched',
        'matched_donor_id': _uid,
        'matched_donor_name': donor['name'],
        'matched_donor_phone': donor['phone'],
        'matched_at': FieldValue.serverTimestamp(),
      });
      tx.update(donorRef, {'active_request_id': requestId});
    });
    _logEvent('request_matched', {'request_id': requestId});
  }

  /// The matched donor backs out ("I can't make it"). The request goes
  /// back to `open` with a fresh expiry window so other donors can accept
  /// it, and the donor's lock is freed. Their name/phone come off the doc.
  Future<void> releaseMatch(String requestId) async {
    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('requests').doc(requestId);
      final reqSnap = await tx.get(reqRef);
      final data = reqSnap.data();
      if (data == null || data['status'] != 'matched' || data['matched_donor_id'] != _uid) return;
      tx.update(reqRef, {
        'status': 'open',
        'matched_donor_id': null,
        'matched_donor_name': null,
        'matched_donor_phone': null,
        'matched_at': null,
        'released_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: requestExpiryHours))),
      });
      tx.update(_db.collection('donors').doc(_uid), {'active_request_id': null});
    });
    _logEvent('request_released', {'request_id': requestId});
  }

  /// Donation completion is confirmed by BOTH people. The donor's "I've
  /// donated" writes their history record and starts their own 90-day
  /// cooldown straight away (only the donor can write their profile, and
  /// they're the one who knows they donated); the request only becomes
  /// `fulfilled` once the requester has confirmed too — whichever side
  /// confirms second closes it. An admin can still confirm on either's
  /// behalf (adminConfirmDonation). Returns true if this closed it.
  Future<bool> donorConfirmDonation(String requestId) async {
    final reactivateAt = DateTime.now().add(const Duration(days: donorCooldownDays));
    var closed = false;
    var alreadyConfirmed = false;

    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('requests').doc(requestId);
      final req = (await tx.get(reqRef)).data();
      if (req == null || req['status'] != 'matched' || req['matched_donor_id'] != _uid) {
        throw StateError('This request is no longer active.');
      }
      alreadyConfirmed = req['donor_confirmed_at'] != null;
      if (alreadyConfirmed) return;
      closed = req['requester_confirmed_at'] != null;
      tx.update(reqRef, {
        'donor_confirmed_at': FieldValue.serverTimestamp(),
        if (closed) 'status': 'fulfilled',
        if (closed) 'fulfilled_at': FieldValue.serverTimestamp(),
      });
      tx.update(_db.collection('donors').doc(_uid), {
        'last_donation_date': FieldValue.serverTimestamp(),
        'is_available': false,
        'active_request_id': null,
        'reactivation_scheduled_at': Timestamp.fromDate(reactivateAt),
      });
      tx.update(_db.collection('donors_public').doc(_uid), {
        'is_available': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      tx.set(_db.collection('donation_history').doc(), {
        'donor_id': _uid,
        'request_id': requestId,
        'donation_date': FieldValue.serverTimestamp(),
        'confirmed_by': 'self',
        'hospital': req['location_label'] ?? '',
        'blood_group': req['blood_group'] ?? '',
      });
    });
    if (alreadyConfirmed) return false;
    await _bumpImpactCounter();
    _logEvent('donation_confirmed', {'request_id': requestId, 'by': 'donor'});
    return closed;
  }

  /// The requester's half of [donorConfirmDonation]: "I received the
  /// donation". Closes the request if the donor already confirmed.
  Future<bool> requesterConfirmDonation(String requestId) async {
    var closed = false;
    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('requests').doc(requestId);
      final req = (await tx.get(reqRef)).data();
      if (req == null || req['status'] != 'matched' || req['requester_uid'] != _uid) {
        throw StateError('This request is no longer active.');
      }
      if (req['requester_confirmed_at'] != null) return;
      closed = req['donor_confirmed_at'] != null;
      tx.update(reqRef, {
        'requester_confirmed_at': FieldValue.serverTimestamp(),
        if (closed) 'status': 'fulfilled',
        if (closed) 'fulfilled_at': FieldValue.serverTimestamp(),
      });
    });
    _logEvent('donation_confirmed', {'request_id': requestId, 'by': 'requester'});
    return closed;
  }

  /// Public, signed-in-readable donation counter for the Community → Impact
  /// tab. Needed because `requests` can't be queried by `status ==
  /// 'fulfilled'` from a normal user (the rules only expose *open* requests
  /// plus your own, precisely so phone numbers on closed requests stay
  /// private) — so the aggregate is maintained here instead. Rules cap each
  /// write at +1, which is all a real donation can ever be.
  Future<void> _bumpImpactCounter() async {
    final ref = _db.collection('public_stats').doc('impact');
    final monthKey = _currentMonthKey();
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, {
            'month_key': monthKey,
            'donations_this_month': 1,
            'updated_at': FieldValue.serverTimestamp(),
          });
          return;
        }
        final sameMonth = snap.data()?['month_key'] == monthKey;
        tx.update(ref, {
          'month_key': monthKey,
          'donations_this_month': sameMonth ? (snap.data()?['donations_this_month'] as num? ?? 0).toInt() + 1 : 1,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      // A failed counter bump must never fail the donation itself.
    }
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Live "donations this month" for the Community Impact tab.
  Stream<int> impactThisMonthStream() =>
      _db.collection('public_stats').doc('impact').snapshots().map((snap) {
        if (!snap.exists) return 0;
        final data = snap.data()!;
        if (data['month_key'] != _currentMonthKey()) return 0;
        return (data['donations_this_month'] as num? ?? 0).toInt();
      });

  Future<int> myDonationCount() async {
    final snap = await _db
        .collection('requests')
        .where('matched_donor_id', isEqualTo: _uid)
        .where('status', isEqualTo: 'fulfilled')
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Requests this donor has been matched to (any status) — the other
  /// half of "my requests" alongside [myRequestsStream], used to derive
  /// the notifications feed (see FirestoreNotificationsService) without a
  /// separate notifications collection.
  Stream<QuerySnapshot<Map<String, dynamic>>> myMatchedRequestsStream() =>
      _db.collection('requests').where('matched_donor_id', isEqualTo: _uid).snapshots();

  // ------------------------------------------------------------- Admin
  //
  // No custom-claims roles (that needs the Admin SDK / a Cloud Function).
  // A doc's existence at admins/{uid} is the admin flag; firestore.rules
  // enforces that only an admin can write it, verify/ban a donor, or
  // manage hospitals — these methods don't re-check isAdmin() themselves,
  // the rules do, so a non-admin's write here fails at Firestore, not
  // silently.

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final snap = await _db.collection('admins').doc(user.uid).get();
    return snap.exists;
  }

  Future<void> _logAdminAction(String action, String target) =>
      _db.collection('audit_log').add({
        'actor_uid': _uid,
        'action': action,
        'target': target,
        'at': FieldValue.serverTimestamp(),
      });

  /// Verifying also deletes the ID-proof photo: once an admin has checked
  /// it, keeping a copy of someone's ID only adds risk (and storage). The
  /// profile records that it was checked, and when.
  Future<void> adminVerifyDonor(String donorId) async {
    await _db.runTransaction((tx) async {
      tx.delete(_idProofRef(donorId));
      tx.update(_db.collection('donors').doc(donorId), {
        'is_verified': true,
        'has_id_proof': false,
        'id_proof_checked_at': FieldValue.serverTimestamp(),
        'id_proof_base64': FieldValue.delete(),
        'id_proof_content_type': FieldValue.delete(),
      });
      tx.update(_db.collection('donors_public').doc(donorId), {
        'is_verified': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
    await _logAdminAction('verify_donor', donorId);
  }

  Future<void> adminBanDonor(String donorId) async {
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('donors').doc(donorId), {'is_banned': true, 'is_available': false});
      tx.update(_db.collection('donors_public').doc(donorId), {
        'is_available': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
    await _logAdminAction('ban_donor', donorId);
  }

  Future<void> adminUnbanDonor(String donorId) async {
    await _db.collection('donors').doc(donorId).update({'is_banned': false});
    await _logAdminAction('unban_donor', donorId);
  }

  Future<void> adminSetDonorAvailability(String donorId, bool available) async {
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('donors').doc(donorId), {'is_available': available});
      tx.update(_db.collection('donors_public').doc(donorId), {
        'is_available': available,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
    await _logAdminAction(available ? 'mark_available' : 'mark_unavailable', donorId);
  }

  /// Admin-side counterpart to [markFulfilled] — for when the donation is
  /// confirmed by an admin (e.g. hospital-reported) rather than self-
  /// reported by the donor. Same effects: request -> fulfilled, the
  /// matched donor's 90-day cooldown starts, an immutable history record
  /// is written. Reads the request first (unlike markFulfilled, which
  /// trusts the caller is the matched donor) since the admin isn't
  /// necessarily acting on their own uid.
  Future<void> adminConfirmDonation(String requestId) async {
    final reactivateAt = DateTime.now().add(const Duration(days: donorCooldownDays));
    late String donorId;
    var donorAlreadyConfirmed = false;

    await _db.runTransaction((tx) async {
      final reqRef = _db.collection('requests').doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw StateError('Request not found.');
      final req = reqSnap.data()!;
      if (req['status'] != 'matched') throw StateError('Request is not currently matched.');
      donorId = req['matched_donor_id'] as String;
      donorAlreadyConfirmed = req['donor_confirmed_at'] != null;

      tx.update(reqRef, {
        'status': 'fulfilled',
        'fulfilled_at': FieldValue.serverTimestamp(),
        'fulfilled_by': _uid,
      });
      // The donor's own confirmation already started their cooldown and
      // wrote the history record — don't restart or duplicate either.
      if (donorAlreadyConfirmed) return;
      tx.update(_db.collection('donors').doc(donorId), {
        'last_donation_date': FieldValue.serverTimestamp(),
        'is_available': false,
        'active_request_id': null,
        'reactivation_scheduled_at': Timestamp.fromDate(reactivateAt),
      });
      tx.update(_db.collection('donors_public').doc(donorId), {
        'is_available': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
      tx.set(_db.collection('donation_history').doc(), {
        'donor_id': donorId,
        'request_id': requestId,
        'donation_date': FieldValue.serverTimestamp(),
        'confirmed_by': 'admin',
        'verified_by': _uid,
        'hospital': req['location_label'] ?? '',
        'blood_group': req['blood_group'] ?? '',
      });
    });
    if (!donorAlreadyConfirmed) await _bumpImpactCounter();
    await _logAdminAction('confirm_donation', requestId);
    _logEvent('donation_fulfilled', {'request_id': requestId, 'confirmed_by': 'admin'});
  }

  Future<void> adminLogStoryRemoval(String storyId) => _logAdminAction('remove_story', storyId);

  // ------------------------------------------- Admin-managed app content
  //
  // Everything the Community tab, the Testimonials page and the Impact
  // counter show is now a real Firestore collection an admin edits from the
  // console's Content tab — nothing on those screens is hardcoded copy any
  // more. `announcements` and `testimonials` have no user-write path at
  // all (rules: admin-only write, signed-in read), which is what keeps
  // "curated" honest.

  /// Community → What's New. Newest first; read by any signed-in user.
  Stream<QuerySnapshot<Map<String, dynamic>>> announcementsStream() => _db
      .collection('announcements')
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots();

  /// More → Testimonials. Curated, admin-authored quotes.
  Stream<QuerySnapshot<Map<String, dynamic>>> testimonialsStream() => _db
      .collection('testimonials')
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots();

  /// Create (id == null) or edit an announcement. `created_at` is only set
  /// on create so editing a post doesn't jump it back to the top of the feed.
  Future<void> adminSaveAnnouncement({String? id, required String title, required String body}) async {
    final data = {
      'title': title.trim(),
      'body': body.trim(),
      'updated_at': FieldValue.serverTimestamp(),
      'author_uid': _uid,
    };
    if (id == null) {
      final ref = await _db.collection('announcements').add({...data, 'created_at': FieldValue.serverTimestamp()});
      await _logAdminAction('publish_announcement', ref.id);
    } else {
      await _db.collection('announcements').doc(id).update(data);
      await _logAdminAction('edit_announcement', id);
    }
  }

  Future<void> adminDeleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
    await _logAdminAction('delete_announcement', id);
  }

  Future<void> adminSaveTestimonial({
    String? id,
    required String quote,
    required String name,
    required String role,
  }) async {
    final data = {
      'quote': quote.trim(),
      'name': name.trim(),
      'role': role.trim(),
      'updated_at': FieldValue.serverTimestamp(),
      'author_uid': _uid,
    };
    if (id == null) {
      final ref = await _db.collection('testimonials').add({...data, 'created_at': FieldValue.serverTimestamp()});
      await _logAdminAction('publish_testimonial', ref.id);
    } else {
      await _db.collection('testimonials').doc(id).update(data);
      await _logAdminAction('edit_testimonial', id);
    }
  }

  /// A member offers their own testimonial. It goes to a private queue
  /// (`testimonial_submissions`, admin-read only) and appears on the
  /// Testimonials page only after an admin approves it — with the member's
  /// explicit consent to publish it under their name.
  Future<void> submitTestimonial({required String quote, required String role}) async {
    final donor = (await myDonorDoc()).data();
    await _db.collection('testimonial_submissions').add({
      'author_uid': _uid,
      'name': donor?['name'] ?? '',
      'quote': quote.trim(),
      'role': role.trim(),
      'consent_to_publish': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> testimonialSubmissionsStream() => _db
      .collection('testimonial_submissions')
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots();

  /// Publishes a member's submission as a testimonial and clears it from
  /// the queue, in one batch.
  Future<void> adminApproveTestimonialSubmission(String id, Map<String, dynamic> data) async {
    final batch = _db.batch();
    final ref = _db.collection('testimonials').doc();
    batch.set(ref, {
      'quote': (data['quote'] as String? ?? '').trim(),
      'name': (data['name'] as String? ?? '').trim(),
      'role': (data['role'] as String? ?? '').trim(),
      'author_uid': data['author_uid'],
      'submitted_by_member': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.collection('testimonial_submissions').doc(id));
    await batch.commit();
    await _logAdminAction('approve_testimonial', ref.id);
  }

  Future<void> adminRejectTestimonialSubmission(String id) async {
    await _db.collection('testimonial_submissions').doc(id).delete();
    await _logAdminAction('reject_testimonial', id);
  }

  Future<void> adminDeleteTestimonial(String id) async {
    await _db.collection('testimonials').doc(id).delete();
    await _logAdminAction('delete_testimonial', id);
  }

  /// Overrides the Community Impact figure for the current month. The
  /// +1-only rule that guards a normal donor's bump doesn't apply to an
  /// admin — this is the correction path for a miscount, or for donations
  /// confirmed outside the app.
  Future<void> adminSetImpactCount(int count) async {
    await _db.collection('public_stats').doc('impact').set({
      'month_key': _currentMonthKey(),
      'donations_this_month': count,
      'updated_at': FieldValue.serverTimestamp(),
      'set_by_admin': _uid,
    });
    await _logAdminAction('set_impact_count', '$count');
  }

  /// Triage state for an inbox submission — `new`, `in_progress` or
  /// `resolved`, plus an internal note only admins can read.
  Future<void> adminSetIssueStatus(String id, String status, {String? note}) async {
    await _db.collection('issue_reports').doc(id).update({
      'status': status,
      if (note != null) 'admin_note': note.trim(),
      'handled_by': _uid,
      'handled_at': FieldValue.serverTimestamp(),
    });
    await _logAdminAction('issue_$status', id);
  }

  Future<void> adminDeleteIssueReport(String id) async {
    await _db.collection('issue_reports').doc(id).delete();
    await _logAdminAction('delete_issue_report', id);
  }

  Future<void> adminSetPartnershipStatus(String id, String status, {String? note}) async {
    await _db.collection('partnership_inquiries').doc(id).update({
      'status': status,
      if (note != null) 'admin_note': note.trim(),
      'handled_by': _uid,
      'handled_at': FieldValue.serverTimestamp(),
    });
    await _logAdminAction('inquiry_$status', id);
  }

  Future<void> adminDeletePartnershipInquiry(String id) async {
    await _db.collection('partnership_inquiries').doc(id).delete();
    await _logAdminAction('delete_partnership_inquiry', id);
  }

  /// Chat/call abuse reports (ChatService.report) — same triage shape as
  /// the other inboxes, but rules give admins update only, never delete;
  /// a report always stays on record.
  Future<void> adminSetReportStatus(String id, String status, {String? note}) async {
    await _db.collection('reports').doc(id).update({
      'status': status,
      if (note != null) 'admin_note': note.trim(),
      'handled_by': _uid,
      'handled_at': FieldValue.serverTimestamp(),
    });
    await _logAdminAction('report_$status', id);
  }

  /// Reversible moderation: the Community feed filters hidden stories out
  /// client-side, so an admin can take a post down without destroying it.
  Future<void> adminSetStoryHidden(String id, bool hidden) async {
    await _db.collection('community_stories').doc(id).update({
      'is_hidden': hidden,
      'moderated_by': _uid,
      'moderated_at': FieldValue.serverTimestamp(),
    });
    await _logAdminAction(hidden ? 'hide_story' : 'unhide_story', id);
  }

  Future<void> adminAddHospital(String name, String address) async {
    final ref = await _db.collection('hospitals').add({'name': name, 'address': address});
    await _logAdminAction('add_hospital', ref.id);
  }

  Future<void> adminUpdateHospital(String id, String name, String address) async {
    await _db.collection('hospitals').doc(id).update({'name': name, 'address': address});
    await _logAdminAction('update_hospital', id);
  }

  Future<void> adminDeleteHospital(String id) async {
    await _db.collection('hospitals').doc(id).delete();
    await _logAdminAction('delete_hospital', id);
  }

  /// Removes a donor's profile (`donors` + `donors_public`) entirely — for
  /// spam signups, duplicates, or a takedown request. This only deletes the
  /// Firestore profile: the underlying Firebase Auth account still exists
  /// and can sign back in, since disabling/deleting another user's Auth
  /// account needs the Admin SDK (Blaze-only). `is_banned` (adminBanDonor)
  /// is the Spark-compatible way to actually lock someone out; use delete
  /// only when the record itself, not just access, needs to go.
  Future<void> adminDeleteDonor(String donorId) async {
    await _db.collection('donors_public').doc(donorId).delete();
    await _db.collection('donors').doc(donorId).delete();
    await _logAdminAction('delete_donor', donorId);
  }

  /// Removes a request outright — spam, duplicate or test postings. Rules
  /// allow this independently of the status-transition checks that gate
  /// `update`, since a delete isn't a transition.
  Future<void> adminDeleteRequest(String requestId) async {
    await _db.collection('requests').doc(requestId).delete();
    await _logAdminAction('delete_request', requestId);
  }

  /// Push to every phone, or to one blood group's donors. Writing the
  /// `broadcasts` doc is the whole API: the onBroadcast Cloud Function
  /// delivers it to the matching FCM topic and stamps the result back.
  /// [audience] is "All donors" or a blood group ("A+").
  Future<void> adminSendBroadcast(String message, String audience, {String title = 'Rakta Bandhan'}) async {
    final group = bloodCompatibility.containsKey(audience) ? audience : null;
    final ref = await _db.collection('broadcasts').add({
      'title': title.trim().isEmpty ? 'Rakta Bandhan' : title.trim(),
      'body': message.trim().length > 300 ? message.trim().substring(0, 300) : message.trim(),
      'blood_group': group,
      'created_by': _uid,
      'created_at': FieldValue.serverTimestamp(),
      'status': 'queued',
    });
    await _logAdminAction('broadcast[${group ?? 'all'}]', ref.id);
  }

  /// Edit the donor's own name / phone. `is_verified` and `is_banned` stay
  /// untouched here — the rules reject an owner write that changes either.
  Future<void> updateProfile({required String name, required String phone}) async {
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('donors').doc(_uid), {'name': name.trim(), 'phone': phone.trim()});
      tx.update(_db.collection('donors_public').doc(_uid), {
        'name': name.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Community stories ("Share an experience"). Public to signed-in users,
  /// authored under the poster's own uid; admins can moderate/remove.
  ///
  /// An optional photo goes to Cloud Storage at `community/{uid}/{postId}`
  /// (storage.rules: own folder, images only, < 2 MB). The caller passes an
  /// already-downscaled image (image_picker maxWidth/imageQuality), ~150–300
  /// KB. Deleting the post deletes the photo (onStoryDeleted function).
  Future<void> submitCommunityStory({
    required String topic,
    required String body,
    String? bloodGroup,
    String? locationLabel,
    XFile? photo,
  }) async {
    final donor = (await myDonorDoc()).data();
    final ref = _db.collection('community_stories').doc();
    String? imageUrl;
    String? imagePath;
    double? imageAspect;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      final contentType = switch (photo.mimeType) {
        'image/png' => 'image/png',
        'image/webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final ext = contentType.split('/').last.replaceAll('jpeg', 'jpg');
      imagePath = 'community/$_uid/${ref.id}.$ext';
      final storageRef = FirebaseStorage.instance.ref(imagePath);
      await storageRef.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public, max-age=604800'));
      imageUrl = await storageRef.getDownloadURL();
      try {
        final image = await decodeImageFromList(bytes);
        if (image.height > 0) imageAspect = image.width / image.height;
        image.dispose();
      } catch (_) {}
    }
    await ref.set({
      'author_uid': _uid,
      'author_name': donor?['name'] ?? 'A donor',
      'topic': topic,
      'body': body.trim(),
      'blood_group': bloodGroup,
      'location_label': locationLabel,
      'image_url': ?imageUrl,
      'image_path': ?imagePath,
      'image_aspect': ?imageAspect,
      'created_at': FieldValue.serverTimestamp(),
    });
    _logEvent('story_posted', {'has_photo': photo != null ? 1 : 0});
  }

  /// The author removes their own post (the photo goes with it).
  Future<void> deleteMyStory(String storyId) => _db.collection('community_stories').doc(storyId).delete();

  /// Report a community post for review (Apple guideline 1.2 — user
  /// content must be reportable). Admins see it in the reports inbox.
  Future<void> reportStory(String storyId, {required String reason}) => _db.collection('reports').add({
        'reporter_uid': _uid,
        'reason': reason,
        'kind': 'story',
        'story_id': storyId,
        'status': 'new',
        'created_at': FieldValue.serverTimestamp(),
      });

  /// The neighbourhood name shown on this donor's public listing
  /// ("Adyar, Chennai") — safe to tag on a post.
  Future<String?> myPublicArea() async {
    final area = (await _db.collection('donors_public').doc(_uid).get()).data()?['area'] as String?;
    return (area == null || area.trim().isEmpty) ? null : area.trim();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> communityStoriesStream() => _db
      .collection('community_stories')
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots();

  /// "Report an issue" (Help & support). One-way — admins read it in the
  /// console, nothing writes back to the reporter.
  Future<void> submitIssueReport({required String reason, String? details}) =>
      _db.collection('issue_reports').add({
        'reporter_uid': _uid,
        'reason': reason,
        'details': details?.trim() ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

  /// "Start a conversation" (Partner with us). Same one-way pattern as
  /// submitIssueReport.
  Future<void> submitPartnershipInquiry({
    required String orgName,
    required String contactName,
    required String workEmail,
    required String interest,
    String? message,
  }) =>
      _db.collection('partnership_inquiries').add({
        'requester_uid': _uid,
        'org_name': orgName.trim(),
        'contact_name': contactName.trim(),
        'work_email': workEmail.trim(),
        'interest': interest,
        'message': message?.trim() ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

  /// The device's real position, or null — never an invented place.
  ///
  /// High accuracy with a 12 s budget (a cold GPS start routinely needs
  /// more than the old 5 s); if the fix times out, the OS's last known
  /// position is used when there is one. Anything that is *stored* — a
  /// donor's registered area, a request's location, a location shared in
  /// chat — must come from here, a search result, or the map picker.
  Future<Position?> preciseLocation({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
        );
      } on TimeoutException {
        if (kIsWeb) return null;
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }

  /// Where to *centre a map* when there's no real fix: the device position
  /// if available, else the demo city. Display only — this used to feed
  /// registration and request creation too, which silently put anyone with
  /// slow GPS in Thiruvananthapuram. Check [isFallback] before trusting it.
  Future<Position> currentPosition() async => await preciseLocation() ?? _fallbackPosition();

  static bool isFallback(Position p) => p.accuracy == 0 && p.latitude == 8.5241 && p.longitude == 76.9366;

  /// Address lookups are a nicety — never let a slow geocoding server hold
  /// up registration or a request (callers fall back to no label).
  static const _geocodeTimeout = Duration(seconds: 8);

  Uri _geocodeUri(String path, Map<String, String> params) => kLocationIqKey.isEmpty
      ? Uri.https('nominatim.openstreetmap.org', path, params)
      : Uri.https('us1.locationiq.com', '/v1$path', {...params, 'key': kLocationIqKey});

  /// Address search (LocationIQ with a key, else public Nominatim), limited
  /// to India and biased towards [near] when given — so "City Hospital"
  /// means the one in your city. Returns {label, lat, lng}.
  Future<List<Map<String, dynamic>>> searchAddress(String query, {({double lat, double lng})? near}) async {
    if (query.trim().length < 3) return [];
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': '6',
        'addressdetails': '1',
        'countrycodes': kGeocodeCountryCodes,
      };
      if (near != null) {
        // ~50 km box around the user; results inside rank first, but
        // anything in India can still match ("bounded" is not set).
        const d = 0.45;
        params['viewbox'] = '${near.lng - d},${near.lat + d},${near.lng + d},${near.lat - d}';
      }
      final response = await http.get(_geocodeUri('/search', params), headers: {'User-Agent': 'RaktaBandhan/1.0'}).timeout(_geocodeTimeout);
      if (response.statusCode != 200) return [];
      final List results = jsonDecode(response.body);
      return results
          .map((r) => {
                'label': r['display_name'] as String,
                'lat': double.parse(r['lat'].toString()),
                'lng': double.parse(r['lon'].toString()),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocoding — turns a GPS fix or a dropped pin into a readable
  /// address. Returns null if the lookup fails (callers show coordinates or
  /// a generic label instead).
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await http.get(
        _geocodeUri('/reverse', {'lat': lat.toString(), 'lon': lng.toString(), 'format': 'json', 'zoom': '18'}),
        headers: {'User-Agent': 'RaktaBandhan/1.0'},
      ).timeout(_geocodeTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Neighbourhood + city ("Adyar, Chennai") for a point — what other
  /// people are shown instead of coordinates or a street address.
  Future<String?> reverseGeocodeArea(double lat, double lng) async {
    try {
      final response = await http.get(
        _geocodeUri('/reverse', {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'zoom': '14',
          'addressdetails': '1',
        }),
        headers: {'User-Agent': 'RaktaBandhan/1.0'},
      ).timeout(_geocodeTimeout);
      if (response.statusCode != 200) return null;
      final address = (jsonDecode(response.body) as Map<String, dynamic>)['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      return areaFromAddress(address);
    } catch (_) {
      return null;
    }
  }

  /// Picks the most useful locality + city pair out of a Nominatim /
  /// LocationIQ `address` object.
  static String? areaFromAddress(Map<String, dynamic> address) {
    String? first(List<String> keys) {
      for (final k in keys) {
        final v = (address[k] as String?)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final local = first(['suburb', 'neighbourhood', 'quarter', 'village', 'hamlet', 'residential', 'city_district']);
    final city = first(['city', 'town', 'municipality', 'county', 'state_district', 'state']);
    final parts = [?local, if (city != null && city != local) city];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Short display form of a stored free-text address: the first two
  /// comma-separated parts ("Apollo Hospital, Greams Road"), so cards never
  /// show a raw coordinate or a six-line Nominatim string.
  static String shortPlace(String? label, {String fallback = 'Location shared'}) {
    final text = label?.trim() ?? '';
    if (text.isEmpty || RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(text)) return fallback;
    final parts = text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p)).toList();
    return parts.take(2).join(', ');
  }

  Position _fallbackPosition() => Position(
        latitude: 8.5241,
        longitude: 76.9366,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}
