import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum ChatMessageKind { text, system, call, location }

@immutable
class ChatMessage {
  final String id;
  final String senderUid;
  final ChatMessageKind kind;
  final String text;
  /// Null while the server timestamp of a just-sent message is pending.
  final DateTime? sentAt;
  /// Only for [ChatMessageKind.call]: talk time, or null for a missed /
  /// declined call.
  final int? callSeconds;
  /// Only for [ChatMessageKind.location].
  final double? lat;
  final double? lng;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.kind,
    required this.text,
    required this.sentAt,
    this.callSeconds,
    this.lat,
    this.lng,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatMessage(
      id: doc.id,
      senderUid: data['sender_uid'] as String? ?? '',
      kind: switch (data['kind']) {
        'system' => ChatMessageKind.system,
        'call' => ChatMessageKind.call,
        'location' => ChatMessageKind.location,
        _ => ChatMessageKind.text,
      },
      text: data['text'] as String? ?? '',
      sentAt: (data['sent_at'] as Timestamp?)?.toDate(),
      callSeconds: data['call_seconds'] as int?,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
    );
  }
}

/// One row of the Messages inbox — a matched request seen from this user's
/// side. Built entirely from fields on the request doc (`last_message`,
/// `requester_read_at` / `donor_read_at`), so the inbox is one listener,
/// not one per conversation.
@immutable
class Conversation {
  final String requestId;
  final bool amRequester;
  final String peerUid;
  final String peerName;
  final String bloodGroup;
  final String status;
  final bool closedByBlock;
  final String? lastText;
  final String? lastSenderUid;
  final DateTime? lastAt;
  final DateTime? myReadAt;
  final DateTime? peerReadAt;
  final DateTime sortKey;

  const Conversation({
    required this.requestId,
    required this.amRequester,
    required this.peerUid,
    required this.peerName,
    required this.bloodGroup,
    required this.status,
    required this.closedByBlock,
    required this.lastText,
    required this.lastSenderUid,
    required this.lastAt,
    required this.myReadAt,
    required this.peerReadAt,
    required this.sortKey,
  });

  bool get isOpen => status == 'matched' && !closedByBlock;

  bool unreadFor(String myUid) =>
      lastAt != null && lastSenderUid != null && lastSenderUid != myUid && (myReadAt == null || lastAt!.isAfter(myReadAt!));

  static Conversation? fromRequest(String id, Map<String, dynamic> r, String myUid) {
    final donorUid = r['matched_donor_id'] as String?;
    final amRequester = r['requester_uid'] == myUid;
    if (!amRequester && donorUid != myUid) return null;
    // A request that never got a donor has no conversation. One that was
    // released (donor backed out) no longer names a donor, same result.
    if (donorUid == null) return null;
    final last = r['last_message'] as Map<String, dynamic>?;
    DateTime? ts(String key) => (r[key] as Timestamp?)?.toDate();
    final lastAt = (last?['sent_at'] as Timestamp?)?.toDate();
    return Conversation(
      requestId: id,
      amRequester: amRequester,
      peerUid: (amRequester ? donorUid : r['requester_uid']) as String? ?? '',
      peerName: (amRequester ? r['matched_donor_name'] : r['requester_name']) as String? ?? 'Donor',
      bloodGroup: r['blood_group'] as String? ?? '',
      status: r['status'] as String? ?? '',
      closedByBlock: r['chat_closed_by'] != null,
      lastText: last?['text'] as String?,
      lastSenderUid: last?['sender_uid'] as String?,
      lastAt: lastAt,
      myReadAt: ts(amRequester ? 'requester_read_at' : 'donor_read_at'),
      peerReadAt: ts(amRequester ? 'donor_read_at' : 'requester_read_at'),
      sortKey: lastAt ?? ts('matched_at') ?? ts('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Reasons offered on the report sheet — the same list the admin console
/// groups reports by.
const chatReportReasons = [
  'Asked for or offered money',
  'Harassment or abusive language',
  'Fake or misleading request',
  'Spam or unrelated messages',
  'Something else',
];

/// In-app chat between exactly the two people on a matched request — the
/// requester and the donor who accepted. There are no open DMs: a thread
/// only exists under `requests/{id}/messages`, and firestore.rules only
/// lets those two participants read it, and only lets them write while
/// the request is `matched` and nobody has closed the chat.
///
/// Every send is one batch: the message, plus `last_message` and the
/// sender's own read marker on the request doc (that's what powers the
/// inbox preview, unread badges and "Seen").
///
/// Spark plan: live only while the app is open (Firestore listeners). On
/// Blaze, an onCreate function on the messages collection sends the push —
/// nothing here changes.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// The chat currently on screen, so the in-app banner doesn't announce a
  /// message the user is already looking at. Set by ChatScreen.
  String? activeRequestId;

  DocumentReference<Map<String, dynamic>> _request(String requestId) => _db.collection('requests').doc(requestId);
  CollectionReference<Map<String, dynamic>> _messages(String requestId) => _request(requestId).collection('messages');

  static String _readField(bool amRequester) => amRequester ? 'requester_read_at' : 'donor_read_at';

  Stream<List<ChatMessage>> watchMessages(String requestId) => _messages(requestId)
      .orderBy('sent_at')
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());

  Future<void> _send(String requestId, bool amRequester, Map<String, dynamic> message, String preview) {
    final batch = _db.batch();
    batch.set(_messages(requestId).doc(), {
      ...message,
      'sender_uid': _uid,
      'sent_at': FieldValue.serverTimestamp(),
    });
    batch.update(_request(requestId), {
      'last_message': {'text': preview, 'sender_uid': _uid, 'sent_at': FieldValue.serverTimestamp()},
      _readField(amRequester): FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  Future<void> sendText(String requestId, String text, {required bool amRequester}) {
    var trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();
    if (trimmed.length > 1000) trimmed = trimmed.substring(0, 1000);
    return _send(requestId, amRequester, {'kind': 'text', 'text': trimmed}, trimmed);
  }

  /// A pin the other person can open in their maps app — the hospital, or
  /// where the sender is right now.
  Future<void> sendLocation(String requestId, {required double lat, required double lng, required String label, required bool amRequester}) {
    final text = label.trim().isEmpty ? 'Shared a location' : label.trim();
    return _send(requestId, amRequester, {'kind': 'location', 'text': text.length > 300 ? text.substring(0, 300) : text, 'lat': lat, 'lng': lng}, 'Location: $text');
  }

  /// A call-log row in the thread (written by the caller's side when a call
  /// finishes, so exactly one row is written per call).
  Future<void> logCall(String requestId, {required int? seconds, required String outcome}) async {
    final req = (await _request(requestId).get()).data();
    if (req == null) return;
    final amRequester = req['requester_uid'] == _uid;
    await _send(requestId, amRequester, {'kind': 'call', 'text': outcome, 'call_seconds': seconds}, outcome);
  }

  /// Moves this user's read marker to now. Cheap to call: ChatScreen only
  /// calls it when there's something unread from the other person.
  Future<void> markRead(String requestId, {required bool amRequester}) =>
      _request(requestId).update({_readField(amRequester): FieldValue.serverTimestamp()});

  /// Every conversation this user is part of, newest activity first — as
  /// requester (their own requests) and as donor (requests they accepted).
  Stream<List<Conversation>> watchConversations() {
    final uid = _uid;
    final controller = StreamController<List<Conversation>>();
    QuerySnapshot<Map<String, dynamic>>? mine;
    QuerySnapshot<Map<String, dynamic>>? accepted;
    void emit() {
      if (mine == null || accepted == null) return;
      final byId = <String, Conversation>{};
      for (final doc in [...mine!.docs, ...accepted!.docs]) {
        final c = Conversation.fromRequest(doc.id, doc.data(), uid);
        if (c != null) byId[doc.id] = c;
      }
      controller.add(byId.values.toList()..sort((a, b) => b.sortKey.compareTo(a.sortKey)));
    }

    final subs = <StreamSubscription<dynamic>>[];
    controller.onListen = () {
      subs.add(_db.collection('requests').where('requester_uid', isEqualTo: uid).snapshots().listen((s) {
        mine = s;
        emit();
      }, onError: controller.addError));
      subs.add(_db.collection('requests').where('matched_donor_id', isEqualTo: uid).snapshots().listen((s) {
        accepted = s;
        emit();
      }, onError: controller.addError));
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  Stream<int> watchUnreadCount() =>
      watchConversations().map((list) => list.where((c) => c.unreadFor(_uid)).length);

  /// Block: closes the conversation for both people. Calls and messages
  /// are refused from then on (rules check `chat_closed_by`).
  Future<void> closeChat(String requestId) => _request(requestId).update({
        'chat_closed_by': _uid,
        'chat_closed_at': FieldValue.serverTimestamp(),
      });

  Future<void> report({
    required String requestId,
    required String reportedUid,
    required String reason,
    String details = '',
  }) =>
      _db.collection('reports').add({
        'reporter_uid': _uid,
        'reported_uid': reportedUid,
        'request_id': requestId,
        'reason': reason,
        'details': details.trim(),
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });

  /// Used by account deletion — removes every message this user sent on
  /// one request's thread.
  Future<void> deleteMyMessages(String requestId) async {
    final mine = await _messages(requestId).where('sender_uid', isEqualTo: _uid).get();
    for (final doc in mine.docs) {
      await doc.reference.delete();
    }
  }
}
