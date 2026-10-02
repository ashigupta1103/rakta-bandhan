import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'backend.dart';
import 'push_service.dart';
import 'chat_service.dart';

/// The user's data rights in-app: a full export (DPDP right to access) and
/// account deletion (App Store guideline 5.1.1(v) and Google Play's
/// account-deletion policy both require deletion to be startable inside
/// the app, not just by email).
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String get _uid => _auth.currentUser!.uid;

  /// Everything stored against this account, as pretty-printed JSON. The
  /// ID-proof image is reported as present/absent rather than inlined — it
  /// can be megabytes of base64.
  Future<String> exportMyData() async {
    final donor = (await _db.collection('donors').doc(_uid).get()).data() ?? {};
    if (donor.containsKey('id_proof_base64')) {
      donor['id_proof_base64'] = '[image on file — ask us for a copy]';
    }
    final asRequester = await _db.collection('requests').where('requester_uid', isEqualTo: _uid).get();
    final asDonor = await _db.collection('requests').where('matched_donor_id', isEqualTo: _uid).get();
    final history = await _db.collection('donation_history').where('donor_id', isEqualTo: _uid).get();

    final export = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'account_id': _uid,
      'profile': donor,
      'requests_you_raised': [for (final d in asRequester.docs) {'id': d.id, ...d.data()}],
      'requests_you_accepted': [for (final d in asDonor.docs) {'id': d.id, ...d.data()}],
      'donation_history': [for (final d in history.docs) {'id': d.id, ...d.data()}],
    };
    return JsonEncoder.withIndent('  ', (value) {
      if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
      if (value is GeoPoint) return {'lat': value.latitude, 'lng': value.longitude};
      return value.toString();
    }).convert(export);
  }

  /// Permanently deletes the account. Order matters: everything that needs
  /// the user's own auth to pass firestore.rules runs first, the auth user
  /// itself last.
  ///
  /// What happens to shared records:
  /// - own open/matched requests are cancelled, then the requester's name
  ///   and phone are scrubbed off them;
  /// - a match this user accepted is released back to `open` so the
  ///   requester can still find someone, and the donor's name/phone are
  ///   removed from it;
  /// - every chat message this user sent is deleted;
  /// - donation_history rows stay (they only hold the now-orphaned uid —
  ///   an anonymous count, not personal data).
  Future<void> deleteMyAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final asRequester = await _db.collection('requests').where('requester_uid', isEqualTo: _uid).get();
    for (final doc in asRequester.docs) {
      final status = doc.data()['status'];
      if (status == 'open' || status == 'matched') {
        await doc.reference.update({'status': 'cancelled', 'cancelled_at': FieldValue.serverTimestamp()});
      }
      await ChatService.instance.deleteMyMessages(doc.id).catchError((_) {});
      await doc.reference.update({'requester_name': 'Deleted user', 'requester_username': FieldValue.delete(), 'requester_phone': FieldValue.delete(), 'requester_deleted': true, 'last_message': FieldValue.delete()});
    }

    final asDonor = await _db.collection('requests').where('matched_donor_id', isEqualTo: _uid).get();
    for (final doc in asDonor.docs) {
      await ChatService.instance.deleteMyMessages(doc.id).catchError((_) {});
      if (doc.data()['status'] == 'matched') {
        await Backend.instance.releaseMatch(doc.id);
      } else {
        await doc.reference.update({'matched_donor_name': 'Deleted user', 'matched_donor_username': FieldValue.delete(), 'matched_donor_phone': FieldValue.delete(), 'matched_donor_deleted': true, 'last_message': FieldValue.delete()});
      }
    }

    await PushService.instance.unregisterDevice();
    await Backend.instance.deleteMyIdProof();
    await Backend.instance.removeProfilePhoto(keepProfileField: true).catchError((_) {});
    final username = (await _db.collection('donors').doc(_uid).get()).data()?['username'] as String?;
    final removal = _db.batch();
    if (username != null) removal.delete(_db.collection('usernames').doc(username));
    removal.delete(_db.collection('donors_public').doc(_uid));
    removal.delete(_db.collection('donors').doc(_uid));
    await removal.commit();
    // The sign-in account goes last, server-side (deleteMyAuthAccount). If
    // this step fails the user can simply retry: every step above is safe
    // to repeat.
    await Backend.instance.deleteMyAuthAccount();
    await Backend.instance.signOut();
  }
}
