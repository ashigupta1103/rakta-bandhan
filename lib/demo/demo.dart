import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:flutter/foundation.dart';

import '../preview_mode.dart';
import '../services/chat_service.dart' show ChatMessage, ChatMessageKind;
import '../services/donation_history_service.dart' show DonationRecord;
import '../services/usernames.dart' show demoUsername;

/// Client-demo simulation: local, in-memory state that lets the REAL
/// screens walk through the whole product journey without the backend —
/// no email or phone code delivery, no second phone to accept a request,
/// no GPS, no Firestore reads or writes.
///
/// Isolation rules:
/// - [on] is false unless the build has preview UI enabled
///   ([kEnablePreviewUi]: debug/profile, or a release built with
///   `--dart-define=ENABLE_PREVIEW_UI=true`) AND someone started a session
///   from the hidden demo hub. A normal production release can never turn
///   it on, so demo codes, people and records can't appear there.
/// - Nothing here touches Firebase. Every screen that supports the demo
///   checks [on] at its data seam and reads from this object instead; the
///   production path below that check is unchanged.
/// - Every value is a fixture defined in this file, and the people are
///   clearly fictional demo personas.
enum DemoRole { requester, donor }

class Demo extends ChangeNotifier {
  Demo._();
  static final Demo instance = Demo._();

  /// True only while a client-demo session is running in a preview build.
  static bool get on => kEnablePreviewUi && instance._active;

  /// Demo ids never collide with real Firestore ids (those are 20 chars of
  /// base62, no dash).
  static bool isDemoId(String? id) => on && id != null && id.startsWith('demo-');

  /// A request document's fields, live. A demo id reads the local demo
  /// request; any other id is the unchanged Firestore listener, mapped to
  /// its data (null when the document doesn't exist).
  static Stream<Map<String, dynamic>?> requestDoc(String id) => isDemoId(id)
      ? instance.watch(() => instance.request)
      : FirebaseFirestore.instance.collection('requests').doc(id).snapshots().map((s) => s.data());

  // ------------------------------------------------------------ fixtures

  static const email = 'demo@raktabandhan.example';
  static const emailCode = '123456';
  static const phoneOtp = '246810';
  static const requestId = 'demo-request';
  static const requesterUid = 'demo-meera';
  static const donorUid = 'demo-aarav';
  static const requesterName = 'Meera Iyer';
  static const donorName = 'Aarav Mehta';
  static const bloodGroup = 'O+';
  static const hospital = 'City General Hospital (demo)';
  static const area = 'Demo Nagar';
  static const donorDistanceKm = 2.4;
  static const donorPriorDonations = 2;
  static const demoPhone = '9800012210';
  // A fixed demo point (central Chennai) — never anyone's real location.
  static const lat = 13.0604;
  static const lng = 80.2496;

  // ------------------------------------------------------------- session

  bool _active = false;
  DemoRole role = DemoRole.requester;
  bool registered = true;
  Map<String, dynamic>? _request;
  final List<ChatMessage> _messages = [];
  int myDonations = 0;
  DateTime? recoveryUntil;
  final List<Map<String, dynamic>> stories = [];
  bool riddleStarted = false;
  bool _available = true;
  bool _newUser = false;
  bool urgentAlerts = true;

  void setUrgentAlerts(bool v) {
    urgentAlerts = v;
    notifyListeners();
  }

  void setAvailable(bool v) {
    _available = v;
    notifyListeners();
  }

  String get myName => role == DemoRole.requester ? requesterName : donorName;
  String get myUid => role == DemoRole.requester ? requesterUid : donorUid;
  String get peerName => role == DemoRole.requester ? donorName : requesterName;
  String get peerUid => role == DemoRole.requester ? donorUid : requesterUid;

  /// Starts (or restarts) a session in [role]. [registered] false walks
  /// the new-user registration first.
  void start(DemoRole r, {bool registered = true}) {
    role = r;
    _reset();
    this.registered = registered;
    _newUser = !registered;
    _active = true;
    if (r == DemoRole.donor) _request = _incomingRequest();
    notifyListeners();
  }

  void stop() {
    _reset();
    _active = false;
    notifyListeners();
  }

  /// Back to the start of the current journey. Local state only.
  void reset() => start(role, registered: registered);

  void _reset() {
    _request = null;
    _messages.clear();
    myDonations = role == DemoRole.donor ? donorPriorDonations : 0;
    recoveryUntil = null;
    stories.clear();
    riddleStarted = false;
    _available = true;
    _replyTimer?.cancel();
    _peerTimer?.cancel();
  }

  // ------------------------------------------------------------- streams

  /// Emits [read] now and after every change — the shape every screen's
  /// StreamBuilder already expects.
  Stream<T> watch<T>(T Function() read) => Stream.multi((c) {
        void push() => c.add(read());
        push();
        addListener(push);
        c.onCancel = () => removeListener(push);
      });

  // ------------------------------------------------------------- request

  /// The request in the same field shape as `requests/{id}` in Firestore,
  /// so screens parse it with their normal code.
  Map<String, dynamic>? get request => _request == null ? null : Map.of(_request!);

  Map<String, dynamic> _base({required String status}) => {
        'status': status,
        'blood_group': bloodGroup,
        'units_needed': 1,
        'urgency': 'urgent',
        'location_label': hospital,
        'lat': lat,
        'lng': lng,
        'requester_uid': requesterUid,
        'requester_name': requesterName,
        'requester_phone': demoPhone,
        'created_at': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 4))),
        'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 6))),
      };

  Map<String, dynamic> _incomingRequest() => _base(status: 'open');

  /// Requester journey: the request form "submits" here.
  void createRequest({required String group, required int units, required String urgency, required String label}) {
    _request = _base(status: 'open')
      ..['blood_group'] = group
      ..['units_needed'] = units
      ..['urgency'] = urgency
      ..['location_label'] = label.isEmpty ? hospital : label
      ..['created_at'] = Timestamp.now();
    notifyListeners();
  }

  /// The simulated donor accepts (requester journey) or the demo donor
  /// taps Accept (donor journey). Same end state either way.
  void match() {
    final r = _request ?? _base(status: 'open');
    _request = r
      ..['status'] = 'matched'
      ..['matched_donor_id'] = donorUid
      ..['matched_donor_name'] = donorName
      ..['matched_donor_phone'] = demoPhone
      ..['matched_at'] = Timestamp.now();
    if (_messages.isEmpty) {
      _messages.add(_msg(requesterUid, 'Hi, thank you for responding.', minutesAgo: 1));
    }
    notifyListeners();
  }

  void cancel() {
    _request?['status'] = 'cancelled';
    notifyListeners();
  }

  /// Marks this side's confirmation; the simulated other side confirms
  /// a moment later so the two-sided completion plays out on screen.
  /// Returns true when the donation is now complete.
  bool confirmMine() {
    final r = _request;
    if (r == null) return false;
    final mine = role == DemoRole.donor ? 'donor_confirmed_at' : 'requester_confirmed_at';
    r[mine] = Timestamp.now();
    final done = _maybeComplete();
    notifyListeners();
    // The other person confirms a few seconds later, so the two-sided
    // completion plays out on screen without a second phone.
    if (!done) {
      _peerTimer?.cancel();
      _peerTimer = Timer(const Duration(seconds: 4), () {
        if (_active && _request?['status'] == 'matched') confirmPeer();
      });
    }
    return done;
  }

  void confirmPeer() {
    final r = _request;
    if (r == null) return;
    final theirs = role == DemoRole.donor ? 'requester_confirmed_at' : 'donor_confirmed_at';
    r[theirs] = Timestamp.now();
    _maybeComplete();
    notifyListeners();
  }

  bool _maybeComplete() {
    final r = _request!;
    if (r['donor_confirmed_at'] == null || r['requester_confirmed_at'] == null) return false;
    if (r['status'] != 'fulfilled') {
      r['status'] = 'fulfilled';
      r['fulfilled_at'] = Timestamp.now();
      if (role == DemoRole.donor) {
        myDonations += 1;
        recoveryUntil = DateTime.now().add(const Duration(days: 90));
      }
    }
    return true;
  }

  // ---------------------------------------------------------------- chat

  Timer? _replyTimer;
  Timer? _peerTimer;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int _msgSeq = 0;

  ChatMessage _msg(String from, String text, {int minutesAgo = 0, ChatMessageKind kind = ChatMessageKind.text, double? lat, double? lng, int? callSeconds}) => ChatMessage(
        id: 'demo-msg-${_msgSeq++}',
        senderUid: from,
        kind: kind,
        text: text,
        sentAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        lat: lat,
        lng: lng,
        callSeconds: callSeconds,
      );

  /// Scripted replies, in order, from whoever the demo user is talking to.
  static const _requesterLines = ['Thank you so much.', 'I’ll be at the blood bank counter on the ground floor.'];
  static const _donorLines = ['Of course. I’m on my way.', 'Reaching in about 20 minutes.'];
  int _replyIndex = 0;

  void send(String text) {
    _messages.add(_msg(myUid, text));
    notifyListeners();
    final lines = role == DemoRole.requester ? _donorLines : _requesterLines;
    if (_replyIndex >= lines.length) return;
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!_active) return;
      _messages.add(_msg(peerUid, lines[_replyIndex++]));
      notifyListeners();
    });
  }

  void sendLocation(String label, double lat, double lng) {
    _messages.add(_msg(myUid, label, kind: ChatMessageKind.location, lat: lat, lng: lng));
    notifyListeners();
  }

  /// A finished demo call appears in the thread like a real one.
  void logCall(int? seconds) {
    _messages.add(_msg(myUid, seconds == null ? 'Missed voice call' : 'Voice call', kind: ChatMessageKind.call, callSeconds: seconds));
    notifyListeners();
  }

  // ------------------------------------------------------------ community

  int _storySeq = 0;

  void addStory(String body, String topic, {Uint8List? photo, bool showBloodGroup = true, bool showArea = false}) {
    stories.insert(0, {
      'id': 'demo-story-${_storySeq++}',
      'image_bytes': ?photo,
      'author_uid': myUid,
      'author_name': myName,
      'author_username': demoUsername,
      'topic': topic,
      'body': body,
      'blood_group': showBloodGroup ? bloodGroup : null,
      'location_label': showArea ? area : null,
      'created_at': Timestamp.now(),
      'is_demo': true,
    });
    notifyListeners();
  }

  /// Edits the demo user's own story in place (photo kept unless replaced).
  void updateStory(String id, {required String body, required String topic, Uint8List? photo}) {
    final i = stories.indexWhere((st) => st['id'] == id);
    if (i < 0) return;
    stories[i] = {
      ...stories[i],
      'body': body,
      'topic': topic,
      'image_bytes': ?photo ?? stories[i]['image_bytes'],
      'edited_at': Timestamp.now(),
    };
    notifyListeners();
  }

  void deleteStory(String id) {
    stories.removeWhere((st) => st['id'] == id);
    notifyListeners();
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// The demo user's donation history, newest first: today's simulated
  /// donation (once completed) and, for the donor persona, two earlier
  /// fixture donations. Only ever shown inside a demo session.
  List<DonationRecord> get donationRecords {
    final now = DateTime.now();
    final done = _request?['status'] == 'fulfilled' && role == DemoRole.donor;
    return [
      if (done) DonationRecord(hospital: hospital, date: _date(now), bloodGroup: bloodGroup),
      if (role == DemoRole.donor) ...[
        DonationRecord(hospital: 'Demo Blood Bank', date: _date(now.subtract(const Duration(days: 240))), bloodGroup: bloodGroup),
        DonationRecord(hospital: 'Demo Community Camp', date: _date(now.subtract(const Duration(days: 470))), bloodGroup: bloodGroup),
      ],
    ];
  }

  /// Donor profile as `donors/{uid}` would hold it, for My Page.
  Map<String, dynamic> get myProfile => {
        'name': myName,
        'blood_group': bloodGroup,
        // A brand-new demo registration is still awaiting verification.
        'is_verified': !_newUser,
        'is_available': _available && recoveryUntil == null,
        'location_label': area,
        'phone': demoPhone,
        'urgent_alerts': urgentAlerts,
        if (recoveryUntil != null) 'reactivation_scheduled_at': Timestamp.fromDate(recoveryUntil!),
        if (recoveryUntil != null) 'last_donation_date': Timestamp.now(),
      };
}
