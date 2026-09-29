import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
const requestExpiryHours = 6;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard interleaved-bits geohash encoder. Stored on donor/request docs
/// for schema parity with the Cloud Functions upgrade path (geofire-common
/// on the server side); the live app itself never runs a geohash range
/// query — dataset is demo-scale, so donor/request lists are just filtered
/// and sorted by Haversine distance client-side.
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

/// Thrown when a donor tries to accept a request someone else already claimed.
class RequestAlreadyClaimedException implements Exception {
  const RequestAlreadyClaimedException();
  @override
  String toString() => 'Someone else already accepted this request.';
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

  static const _fakeAuthPassword = 'RaktaBandhan#2026Demo';
  static const _fakeAuthEmailDomain = 'phone.raktabandhan.local';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();
  String get _uid => _auth.currentUser!.uid;

  String _emailForPhone(String phone) => 'p$phone@$_fakeAuthEmailDomain';

  /// Fake OTP: any correctly-formatted 6-digit code is accepted client-side
  /// (see otp_screen.dart) — this just signs in/up a stable account keyed
  /// by phone number, so the same phone always lands on the same profile.
  Future<User> verifyFakeOtp(String phone) async {
    final email = _emailForPhone(phone);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _fakeAuthPassword,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: _fakeAuthPassword,
        );
        return cred.user!;
      }
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Firebase requires a fresh sign-in before destructive account actions
  /// (user.delete()). With the fake-OTP scheme the credential is derivable
  /// from the session itself; once real phone auth lands this becomes a
  /// fresh OTP round-trip instead.
  Future<void> reauthenticateForSensitiveAction() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: _fakeAuthPassword),
    );
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

    // A real transaction, not a batch: donors_public's create rule reads
    // donors/{uid} (get()) to confirm is_verified/is_available match —
    // that read is only guaranteed to see this write's own donors/{uid}
    // value within the same transaction, not necessarily within a plain
    // batch. See backend/firestore.rules.
    await _db.runTransaction((tx) async {
      tx.set(_db.collection('donors').doc(_uid), {
        'name': name,
        'phone': phone,
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
        'is_available': true,
        'is_verified': false,
        'updated_at': now,
      });
    });
    _logEvent('donor_registered', {'blood_group': bloodGroup});
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

  /// Open requests, newest first. Blood-group compatibility is filtered
  /// client-side (see note on encodeGeohash above) to avoid needing an
  /// extra composite index for a demo-scale dataset.
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

  /// Matched donor self-reports the donation done, writes the immutable
  /// history record, and starts their own 90-day cooldown (admin
  /// confirmation of the same donation is also possible — see
  /// AdminService — but self-report is the only path the app's own UI
  /// drives today).
  Future<void> markFulfilled(String requestId) async {
    final reactivateAt = DateTime.now().add(const Duration(days: donorCooldownDays));

    await _db.runTransaction((tx) async {
      tx.update(_db.collection('requests').doc(requestId), {
        'status': 'fulfilled',
        'fulfilled_at': FieldValue.serverTimestamp(),
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
      });
    });
    _logEvent('donation_fulfilled', {'request_id': requestId});
  }

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

  /// Not a real broadcast — sending a push needs a server (Cloud Function
  /// + FCM Admin SDK), which is exactly what Spark doesn't allow. This
  /// just records the intent in the audit trail so the admin UI's
  /// broadcast action isn't silently dead; see backend/README.md.
  Future<void> adminSendBroadcast(String message, String audience) =>
      _logAdminAction('broadcast[$audience]', message);

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
      final response = await http.get(_geocodeUri('/search', params), headers: {'User-Agent': 'RaktaBandhan/1.0'});
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
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['display_name'] as String?;
    } catch (_) {
      return null;
    }
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
