import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'backend.dart';

@immutable
class DonationRecord {
  final String requestId;
  final String hospital;
  final DateTime? date;
  final String bloodGroup;
  final int units;

  const DonationRecord({
    required this.requestId,
    required this.hospital,
    required this.date,
    required this.bloodGroup,
    required this.units,
  });
}

abstract class DonationHistoryService {
  Future<List<DonationRecord>> fetchHistory();
}

/// Real per-donation history: every `requests` document this donor
/// fulfilled, already written by the existing `Backend.markFulfilled()` —
/// nothing here is mocked.
///
/// Sorted client-side rather than via Firestore `orderBy` deliberately: a
/// two-equality-filter query (`matched_donor_id` + `status`) combined with
/// `orderBy('fulfilled_at')` needs a composite index, and nothing in this
/// project's existing patterns (the same two filters back `myDonationCount`
/// and `DonorFoundScreen`'s fulfilled-count query, both `.count()` only)
/// establishes one exists. Matching the already-proven filter shape and
/// sorting after fetch avoids depending on Firestore index config this
/// phase has no visibility into or permission to change.
class FirestoreDonationHistoryService implements DonationHistoryService {
  @override
  Future<List<DonationRecord>> fetchHistory() async {
    final uid = Backend.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await FirebaseFirestore.instance
        .collection('requests')
        .where('matched_donor_id', isEqualTo: uid)
        .where('status', isEqualTo: 'fulfilled')
        .get();

    final records = snap.docs.map((doc) {
      final data = doc.data();
      final label = data['location_label'] as String?;
      return DonationRecord(
        requestId: doc.id,
        hospital: (label?.isNotEmpty ?? false) ? label! : 'Blood donation',
        date: (data['fulfilled_at'] as Timestamp?)?.toDate(),
        bloodGroup: data['blood_group'] as String? ?? '',
        units: (data['units_needed'] as num?)?.toInt() ?? 1,
      );
    }).toList()
      ..sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
    return records;
  }
}
