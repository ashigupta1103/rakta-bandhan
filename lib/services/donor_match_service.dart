import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'backend.dart';

@immutable
class DonorMatch {
  final String name;
  final String initials;
  final String bloodGroup;
  final String distance;

  const DonorMatch({required this.name, required this.initials, required this.bloodGroup, required this.distance});
}

abstract class DonorMatchService {
  Future<DonorMatch> fetchMatch(String requestId);
}

class MockDonorMatchService implements DonorMatchService {
  @override
  Future<DonorMatch> fetchMatch(String requestId) async {
    return const DonorMatch(name: 'Rohan Mehta', initials: 'RM', bloodGroup: 'O+', distance: '2.1 km away');
  }
}

/// Real matched-donor lookup: `matched_donor_name` is already written onto
/// `requests/{id}` by `Backend.acceptRequest`; blood group + coordinates
/// (to compute distance, same as find_donors_screen.dart) come from the
/// already-public `donors_public/{matched_donor_id}` mirror — no new
/// fields or rules needed.
class FirestoreDonorMatchService implements DonorMatchService {
  final _db = FirebaseFirestore.instance;

  String _initialsOf(String name) =>
      name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

  @override
  Future<DonorMatch> fetchMatch(String requestId) async {
    final reqSnap = await _db.collection('requests').doc(requestId).get();
    final req = reqSnap.data();
    if (req == null) {
      return const DonorMatch(name: 'Your donor', initials: '?', bloodGroup: '', distance: '');
    }

    final name = req['matched_donor_name'] as String? ?? 'Your donor';
    final donorId = req['matched_donor_id'] as String?;
    final reqLat = (req['lat'] as num?)?.toDouble();
    final reqLng = (req['lng'] as num?)?.toDouble();

    String bloodGroup = '';
    String distance = '';
    if (donorId != null) {
      final publicSnap = await _db.collection('donors_public').doc(donorId).get();
      final donor = publicSnap.data();
      if (donor != null) {
        bloodGroup = donor['blood_group'] as String? ?? '';
        final donorLat = (donor['lat'] as num?)?.toDouble();
        final donorLng = (donor['lng'] as num?)?.toDouble();
        if (reqLat != null && reqLng != null && donorLat != null && donorLng != null) {
          distance = '${distanceKm(reqLat, reqLng, donorLat, donorLng).toStringAsFixed(1)} km away';
        }
      }
    }

    return DonorMatch(name: name, initials: _initialsOf(name), bloodGroup: bloodGroup, distance: distance);
  }
}
