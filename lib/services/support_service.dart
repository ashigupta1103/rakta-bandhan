import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A private inbox for admins plus a safe copy for its author. Internal notes
/// never enter support_submissions or support_replies.
class SupportService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Map<String, dynamic> _summary(String source, String id, Map<String, dynamic> data, String uid) {
    final title = (data['reason'] ?? data['org_name'] ?? 'Support request').toString();
    final body = (data['details'] ?? data['message'] ?? '').toString();
    return {
      'source_collection': source, 'source_id': id, 'reporter_uid': uid,
      'title': title.length > 120 ? title.substring(0, 120) : title,
      'body': body.length > 2000 ? body.substring(0, 2000) : body,
      'status': data['status'] == 'resolved' ? 'resolved' : data['status'] == 'in_progress' ? 'in_progress' : 'new',
      'created_at': data['created_at'] ?? FieldValue.serverTimestamp(),
    };
  }

  static Future<void> submit(String source, Map<String, dynamic> fields) async {
    final ref = _db.collection(source).doc();
    final ownerField = source == 'partnership_inquiries' ? 'requester_uid' : 'reporter_uid';
    final data = {...fields, ownerField: _uid, 'created_at': FieldValue.serverTimestamp()};
    final batch = _db.batch();
    batch.set(ref, data);
    batch.set(_db.collection('support_submissions').doc(ref.id), _summary(source, ref.id, data, _uid));
    await batch.commit();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> mySubmissions() => _db.collection('support_submissions')
      .where('reporter_uid', isEqualTo: _uid).orderBy('created_at', descending: true).limit(50).snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> myReplies() => _db.collection('support_replies')
      .where('to_uid', isEqualTo: _uid).orderBy('created_at', descending: true).limit(100).snapshots();

  static Future<void> reply(String source, String id, String body) async {
    if (body.trim().isEmpty || body.trim().length > 2000) {
      throw FirebaseFunctionsException(code: 'invalid-argument', message: 'Write a reply of 1–2000 characters.');
    }
    final data = (await _db.collection(source).doc(id).get()).data();
    final owner = data?['reporter_uid'] ?? data?['requester_uid'];
    if (owner is! String || owner.isEmpty) throw FirebaseFunctionsException(code: 'not-found', message: 'This submission is no longer available.');
    final batch = _db.batch();
    batch.set(_db.collection('support_submissions').doc(id), _summary(source, id, data!, owner));
    batch.set(_db.collection('support_replies').doc(), {
      'source_collection': source, 'source_id': id, 'to_uid': owner,
      'body': body.trim(), 'created_by': _uid, 'created_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> mirrorStatus(String id, String status) async {
    final ref = _db.collection('support_submissions').doc(id);
    if ((await ref.get()).exists) await ref.update({'status': status});
  }
}
