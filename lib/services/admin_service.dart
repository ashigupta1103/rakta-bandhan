import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'backend.dart';

enum DonorVerificationStatus { pending, verified, banned }

class AdminDonorEntry {
  final String id;
  final String name;
  final String bloodGroup;
  final String phone;
  final DonorVerificationStatus status;
  final bool available;
  final String location;
  final String joinedOn;

  const AdminDonorEntry({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.phone,
    required this.status,
    required this.available,
    required this.location,
    required this.joinedOn,
  });
}

class AdminRequestEntry {
  final String id;
  final String bloodGroup;
  final String status; // open / matched / fulfilled / cancelled / expired
  final String urgency; // normal / urgent / critical
  final String location;
  final String time;
  final int units;
  final String distance;
  final String? matchedDonorName;

  const AdminRequestEntry({
    required this.id,
    required this.bloodGroup,
    required this.status,
    required this.urgency,
    required this.location,
    required this.time,
    required this.units,
    required this.distance,
    this.matchedDonorName,
  });

  String get statusLabel => switch (status) {
        'open' => 'Open',
        'matched' => 'Matched',
        'fulfilled' => 'Fulfilled',
        'cancelled' => 'Cancelled',
        'expired' => 'Expired',
        _ => status,
      };
}

class AdminHospitalEntry {
  final String id;
  final String name;
  final String address;

  const AdminHospitalEntry({required this.id, required this.name, required this.address});
}

class AdminAuditEntry {
  final String actor;
  final String text;
  final String time;

  const AdminAuditEntry({required this.actor, required this.text, required this.time});
}

String _timeAgo(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hour(s) ago';
  if (diff.inDays < 30) return '${diff.inDays} day(s) ago';
  return '${(diff.inDays / 30).floor()} month(s) ago';
}

/// Real, Firestore-backed admin console — same shape as the mock it
/// replaces (AdminMockService) so admin_dashboard_screen.dart and friends
/// only needed their data source swapped, not rebuilt. All mutating
/// methods are thin wrappers around Backend.admin* — the actual
/// authorization check lives in firestore.rules (isAdmin()), not here.
///
/// [init] must run only after the signed-in user has been confirmed as an
/// admin (AdminLoginScreen does this) — a broad `donors`/`requests` query
/// from a non-admin would be rejected outright by the rules, since those
/// collections aren't readable doc-by-doc by a stranger.
class AdminService extends ChangeNotifier {
  AdminService._();
  static final AdminService instance = AdminService._();

  final _db = FirebaseFirestore.instance;
  bool _started = false;

  List<AdminDonorEntry> donors = [];
  List<AdminRequestEntry> requests = [];
  List<AdminHospitalEntry> hospitals = [];
  List<AdminAuditEntry> auditLog = [];

  /// Fulfilment rate for each of the last 7 days (0.0–1.0), derived from
  /// the live `requests` cache — feeds the dashboard's bar chart.
  List<double> get weeklyFulfilmentRates {
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        _fulfilmentRateFor(DateTime(now.year, now.month, now.day).subtract(Duration(days: i))),
    ];
  }

  double _fulfilmentRateFor(DateTime day) {
    final dayEnd = day.add(const Duration(days: 1));
    final dayRequests = _requestDocs.where((d) {
      final createdAt = (d.data()['created_at'] as Timestamp?)?.toDate();
      return createdAt != null && !createdAt.isBefore(day) && createdAt.isBefore(dayEnd);
    }).toList();
    if (dayRequests.isEmpty) return 0;
    final fulfilled = dayRequests.where((d) => d.data()['status'] == 'fulfilled').length;
    return fulfilled / dayRequests.length;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _requestDocs = [];

  void init() {
    if (_started) return;
    _started = true;

    _db.collection('donors').snapshots().listen((snap) {
      donors = snap.docs.map(_toDonorEntry).toList();
      notifyListeners();
    });
    _db.collection('requests').orderBy('created_at', descending: true).snapshots().listen((snap) {
      _requestDocs = snap.docs;
      requests = snap.docs.map(_toRequestEntry).toList();
      notifyListeners();
    });
    _db.collection('hospitals').snapshots().listen((snap) {
      hospitals = snap.docs.map((d) => AdminHospitalEntry(id: d.id, name: d.data()['name'] ?? '', address: d.data()['address'] ?? '')).toList();
      notifyListeners();
    });
    _db.collection('audit_log').orderBy('at', descending: true).limit(50).snapshots().listen((snap) {
      auditLog = snap.docs.map(_toAuditEntry).toList();
      notifyListeners();
    });
  }

  AdminDonorEntry _toDonorEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = (d['is_banned'] as bool? ?? false)
        ? DonorVerificationStatus.banned
        : (d['is_verified'] as bool? ?? false)
            ? DonorVerificationStatus.verified
            : DonorVerificationStatus.pending;
    return AdminDonorEntry(
      id: doc.id,
      name: d['name'] as String? ?? 'Donor',
      bloodGroup: d['blood_group'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      status: status,
      available: d['is_available'] as bool? ?? false,
      location: (d['location_label'] as String?)?.isNotEmpty == true ? d['location_label'] as String : '—',
      joinedOn: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
    );
  }

  AdminRequestEntry _toRequestEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminRequestEntry(
      id: doc.id,
      bloodGroup: d['blood_group'] as String? ?? '',
      status: d['status'] as String? ?? 'open',
      urgency: d['urgency'] as String? ?? 'normal',
      location: (d['location_label'] as String?)?.isNotEmpty == true ? d['location_label'] as String : 'Blood request',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
      units: (d['units_needed'] as num?)?.toInt() ?? 1,
      distance: '—',
      matchedDonorName: d['matched_donor_name'] as String?,
    );
  }

  AdminAuditEntry _toAuditEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminAuditEntry(
      actor: d['actor_uid'] == Backend.instance.currentUser?.uid ? 'You' : 'Admin',
      text: '${d['action'] ?? ''} · ${d['target'] ?? ''}',
      time: _timeAgo((d['at'] as Timestamp?)?.toDate()),
    );
  }

  Future<void> verifyDonor(String id) => Backend.instance.adminVerifyDonor(id);
  Future<void> banDonor(String id) => Backend.instance.adminBanDonor(id);
  Future<void> unbanDonor(String id) => Backend.instance.adminUnbanDonor(id);

  Future<void> toggleAvailability(String id) {
    final donor = donors.firstWhere((d) => d.id == id);
    return Backend.instance.adminSetDonorAvailability(id, !donor.available);
  }

  Future<void> addHospital(String name, String address) => Backend.instance.adminAddHospital(name, address);
  Future<void> updateHospital(String id, String name, String address) => Backend.instance.adminUpdateHospital(id, name, address);
  Future<void> deleteHospital(String id) => Backend.instance.adminDeleteHospital(id);

  /// Not a real broadcast — see Backend.adminSendBroadcast: sending a push
  /// needs a server, which Spark can't run. Logged to the audit trail only.
  Future<void> sendBroadcast(String message, String audience) {
    if (message.trim().isEmpty) return Future.value();
    return Backend.instance.adminSendBroadcast(message, audience);
  }
}
