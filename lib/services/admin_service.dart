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

/// Triage state shared by both inbox collections. `new` is the implicit
/// state of anything submitted before triage existed — a missing `status`
/// field reads as new rather than as an error.
enum InboxStatus { isNew, inProgress, resolved }

InboxStatus _inboxStatus(String? raw) => switch (raw) {
      'in_progress' => InboxStatus.inProgress,
      'resolved' => InboxStatus.resolved,
      _ => InboxStatus.isNew,
    };

String inboxStatusKey(InboxStatus s) => switch (s) {
      InboxStatus.isNew => 'new',
      InboxStatus.inProgress => 'in_progress',
      InboxStatus.resolved => 'resolved',
    };

String inboxStatusLabel(InboxStatus s) => switch (s) {
      InboxStatus.isNew => 'New',
      InboxStatus.inProgress => 'In progress',
      InboxStatus.resolved => 'Resolved',
    };

class AdminIssueReportEntry {
  final String id;
  final String reason;
  final String details;
  final String time;
  final InboxStatus status;
  final String adminNote;

  const AdminIssueReportEntry({
    required this.id,
    required this.reason,
    required this.details,
    required this.time,
    this.status = InboxStatus.isNew,
    this.adminNote = '',
  });
}

/// A chat/call abuse report (`reports/{id}`, see chat_service.dart's
/// `report()`). Admin-read-only; the rules give admins `update` but not
/// `delete`, so triage sets `status` the same way the other inboxes do,
/// and there is no separate remove action.
class AdminReportEntry {
  final String id;
  final String reporterUid;
  final String reportedUid;
  final String requestId;
  /// Set for a reported community post (Backend.reportStory) instead of a
  /// chat/call.
  final String storyId;
  final String reason;
  final String details;
  final String time;
  final InboxStatus status;
  final String adminNote;

  /// What the report is about, for the inbox subtitle.
  String get subject => storyId.isNotEmpty ? 'Community post $storyId' : 'Reported user $reportedUid · request $requestId';

  const AdminReportEntry({
    required this.id,
    required this.reporterUid,
    required this.reportedUid,
    required this.requestId,
    this.storyId = '',
    required this.reason,
    required this.details,
    required this.time,
    this.status = InboxStatus.isNew,
    this.adminNote = '',
  });
}

class AdminStoryEntry {
  final String id;
  final String authorName;
  final String topic;
  final String body;
  final String time;
  final bool isHidden;

  const AdminStoryEntry({
    required this.id,
    required this.authorName,
    required this.topic,
    required this.body,
    required this.time,
    this.isHidden = false,
  });
}

class AdminPartnershipEntry {
  final String id;
  final String orgName;
  final String contactName;
  final String workEmail;
  final String interest;
  final String message;
  final String time;
  final InboxStatus status;
  final String adminNote;

  const AdminPartnershipEntry({
    required this.id,
    required this.orgName,
    required this.contactName,
    required this.workEmail,
    required this.interest,
    required this.message,
    required this.time,
    this.status = InboxStatus.isNew,
    this.adminNote = '',
  });
}

/// Community → What's New. Admin-authored, no user-write path.
class AdminAnnouncementEntry {
  final String id;
  final String title;
  final String body;
  final String time;

  const AdminAnnouncementEntry({required this.id, required this.title, required this.body, required this.time});
}

/// More → Testimonials. Curated copy the team has permission to publish —
/// deliberately not the same thing as a community story.
class AdminTestimonialEntry {
  final String id;
  final String quote;
  final String name;
  final String role;
  final String time;

  const AdminTestimonialEntry({
    required this.id,
    required this.quote,
    required this.name,
    required this.role,
    required this.time,
  });
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
  List<AdminIssueReportEntry> issueReports = [];
  List<AdminReportEntry> reports = [];
  List<AdminPartnershipEntry> partnershipInquiries = [];
  List<AdminStoryEntry> stories = [];
  List<AdminAnnouncementEntry> announcements = [];
  List<AdminTestimonialEntry> testimonials = [];

  /// Live Community Impact counter for the current month — null until the
  /// first snapshot lands, 0 once it has and the month has no donations.
  int? impactThisMonth;

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

    // Newest 200 of each — a live listener on the whole collection re-read
    // every donor (and, before the ID image moved out, every ID photo) on
    // each admin session. Older records are reached via search.
    _db.collection('donors').orderBy('created_at', descending: true).limit(200).snapshots().listen((snap) {
      donors = snap.docs.map(_toDonorEntry).toList();
      notifyListeners();
    });
    _db.collection('requests').orderBy('created_at', descending: true).limit(300).snapshots().listen((snap) {
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
    _db.collection('issue_reports').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      issueReports = snap.docs.map(_toIssueReportEntry).toList();
      notifyListeners();
    });
    // Chat/call abuse reports (ChatService.report) — the one inbox the
    // branch that added in-app chat left for the admin console to pick up.
    _db.collection('reports').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      reports = snap.docs.map(_toReportEntry).toList();
      notifyListeners();
    });
    _db.collection('partnership_inquiries').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      partnershipInquiries = snap.docs.map(_toPartnershipEntry).toList();
      notifyListeners();
    });
    _db.collection('community_stories').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      stories = snap.docs.map(_toStoryEntry).toList();
      notifyListeners();
    });
    _db.collection('announcements').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      announcements = snap.docs.map(_toAnnouncementEntry).toList();
      notifyListeners();
    });
    _db.collection('testimonials').orderBy('created_at', descending: true).limit(100).snapshots().listen((snap) {
      testimonials = snap.docs.map(_toTestimonialEntry).toList();
      notifyListeners();
    });
    Backend.instance.impactThisMonthStream().listen((value) {
      impactThisMonth = value;
      notifyListeners();
    });
  }

  AdminAnnouncementEntry _toAnnouncementEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminAnnouncementEntry(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
    );
  }

  AdminTestimonialEntry _toTestimonialEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminTestimonialEntry(
      id: doc.id,
      quote: d['quote'] as String? ?? '',
      name: d['name'] as String? ?? '',
      role: d['role'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
    );
  }

  AdminStoryEntry _toStoryEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminStoryEntry(
      id: doc.id,
      authorName: d['author_name'] as String? ?? 'A donor',
      topic: d['topic'] as String? ?? '',
      body: d['body'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
      isHidden: d['is_hidden'] as bool? ?? false,
    );
  }

  /// Moderation: rules allow only an admin to delete a story.
  Future<void> deleteStory(String id) async {
    await Backend.instance.deleteMyStory(id);
    await Backend.instance.adminLogStoryRemoval(id);
  }

  /// The reversible half of story moderation — the Community feed filters
  /// hidden stories out, so nothing is destroyed.
  Future<void> setStoryHidden(String id, bool hidden) => Backend.instance.adminSetStoryHidden(id, hidden);

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

  AdminIssueReportEntry _toIssueReportEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminIssueReportEntry(
      id: doc.id,
      reason: d['reason'] as String? ?? '',
      details: d['details'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
      status: _inboxStatus(d['status'] as String?),
      adminNote: d['admin_note'] as String? ?? '',
    );
  }

  AdminReportEntry _toReportEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminReportEntry(
      id: doc.id,
      reporterUid: d['reporter_uid'] as String? ?? '',
      reportedUid: d['reported_uid'] as String? ?? '',
      requestId: d['request_id'] as String? ?? '',
      storyId: d['story_id'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      details: d['details'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
      status: _inboxStatus(d['status'] as String?),
      adminNote: d['admin_note'] as String? ?? '',
    );
  }

  AdminPartnershipEntry _toPartnershipEntry(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminPartnershipEntry(
      id: doc.id,
      orgName: d['org_name'] as String? ?? '',
      contactName: d['contact_name'] as String? ?? '',
      workEmail: d['work_email'] as String? ?? '',
      interest: d['interest'] as String? ?? '',
      message: d['message'] as String? ?? '',
      time: _timeAgo((d['created_at'] as Timestamp?)?.toDate()),
      status: _inboxStatus(d['status'] as String?),
      adminNote: d['admin_note'] as String? ?? '',
    );
  }

  Future<void> verifyDonor(String id) => Backend.instance.adminVerifyDonor(id);
  Future<void> banDonor(String id) => Backend.instance.adminBanDonor(id);
  Future<void> unbanDonor(String id) => Backend.instance.adminUnbanDonor(id);

  Future<void> toggleAvailability(String id) {
    final donor = donors.firstWhere((d) => d.id == id);
    return Backend.instance.adminSetDonorAvailability(id, !donor.available);
  }

  Future<void> confirmDonation(String requestId) => Backend.instance.adminConfirmDonation(requestId);

  /// Deletes the donor's Firestore profile only — see
  /// Backend.adminDeleteDonor for why the Auth account can't come with it
  /// on Spark. Use banDonor for an actual access lock.
  Future<void> deleteDonor(String id) => Backend.instance.adminDeleteDonor(id);
  Future<void> deleteRequest(String id) => Backend.instance.adminDeleteRequest(id);

  // ---------------------------------------------------- Inbox triage
  Future<void> setIssueStatus(String id, InboxStatus status, {String? note}) =>
      Backend.instance.adminSetIssueStatus(id, inboxStatusKey(status), note: note);
  Future<void> deleteIssueReport(String id) => Backend.instance.adminDeleteIssueReport(id);
  Future<void> setPartnershipStatus(String id, InboxStatus status, {String? note}) =>
      Backend.instance.adminSetPartnershipStatus(id, inboxStatusKey(status), note: note);
  Future<void> deletePartnershipInquiry(String id) => Backend.instance.adminDeletePartnershipInquiry(id);

  /// Chat/call abuse reports are admin-`update`-only in the rules — no
  /// delete, so they stay a permanent trail regardless of outcome.
  Future<void> setReportStatus(String id, InboxStatus status, {String? note}) =>
      Backend.instance.adminSetReportStatus(id, inboxStatusKey(status), note: note);

  // ------------------------------------------- App content (Content tab)
  Future<void> saveAnnouncement({String? id, required String title, required String body}) =>
      Backend.instance.adminSaveAnnouncement(id: id, title: title, body: body);
  Future<void> deleteAnnouncement(String id) => Backend.instance.adminDeleteAnnouncement(id);

  Future<void> saveTestimonial({String? id, required String quote, required String name, required String role}) =>
      Backend.instance.adminSaveTestimonial(id: id, quote: quote, name: name, role: role);
  Future<void> deleteTestimonial(String id) => Backend.instance.adminDeleteTestimonial(id);

  Future<void> setImpactCount(int count) => Backend.instance.adminSetImpactCount(count);

  Future<void> addHospital(String name, String address) => Backend.instance.adminAddHospital(name, address);
  Future<void> updateHospital(String id, String name, String address) => Backend.instance.adminUpdateHospital(id, name, address);
  Future<void> deleteHospital(String id) => Backend.instance.adminDeleteHospital(id);

  /// Push notification to every phone or one blood group (see
  /// Backend.adminSendBroadcast — delivered by the onBroadcast function).
  Future<void> sendBroadcast(String message, String audience) {
    if (message.trim().isEmpty) return Future.value();
    return Backend.instance.adminSendBroadcast(message, audience);
  }
}
