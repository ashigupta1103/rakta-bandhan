import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'backend.dart';

@immutable
class DonationRecord {
  final String hospital;
  final String date;
  final String bloodGroup;

  const DonationRecord({required this.hospital, required this.date, required this.bloodGroup});
}

abstract class DonationHistoryService {
  Future<List<DonationRecord>> fetchHistory();
}

class MockDonationHistoryService implements DonationHistoryService {
  @override
  Future<List<DonationRecord>> fetchHistory() async => const [
        DonationRecord(hospital: 'Fortis Hospital, Cunningham Rd', date: '14 May 2026', bloodGroup: 'O+'),
        DonationRecord(hospital: "St. John's Medical College", date: '2 Feb 2026', bloodGroup: 'O+'),
        DonationRecord(hospital: 'Apollo Hospital, Bannerghatta', date: '9 Nov 2025', bloodGroup: 'O+'),
      ];
}

const _months = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Real `donation_history` query, joined against the matched request for
/// hospital/blood-group context (donation_history itself only stores
/// donor_id/request_id — see backend/README.md schema table).
class FirestoreDonationHistoryService implements DonationHistoryService {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<DonationRecord>> fetchHistory() async {
    final uid = Backend.instance.currentUser?.uid;
    if (uid == null) return [];

    final historySnap = await _db
        .collection('donation_history')
        .where('donor_id', isEqualTo: uid)
        .orderBy('donation_date', descending: true)
        .get();

    final records = <DonationRecord>[];
    for (final doc in historySnap.docs) {
      final data = doc.data();
      final date = (data['donation_date'] as Timestamp?)?.toDate();
      final requestId = data['request_id'] as String?;
      var hospital = 'Blood donation';
      var bloodGroup = '';
      if (requestId != null) {
        final reqSnap = await _db.collection('requests').doc(requestId).get();
        final req = reqSnap.data();
        if (req != null) {
          final label = req['location_label'] as String?;
          if (label != null && label.isNotEmpty) hospital = label;
          bloodGroup = req['blood_group'] as String? ?? '';
        }
      }
      records.add(DonationRecord(
        hospital: hospital,
        date: date == null ? '' : '${date.day} ${_months[date.month]} ${date.year}',
        bloodGroup: bloodGroup,
      ));
    }
    return records;
  }
}
