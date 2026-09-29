import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'backend.dart';

/// Available donors around a point — the bounded replacement for scanning
/// the whole `donors_public` collection.
///
/// Queries the ~4.9 km geohash cell (precision 5) containing the point plus
/// its eight neighbours: a ~15 km square, matching the app's own "no donor
/// within 15 km" search radius. Firestore bills one read per donor returned,
/// so cost now scales with local density instead of total signups — at
/// 5,000 signups/month a full scan would be ~30,000 reads per map open by
/// month six. Stays client-side (no Cloud Function), per the Spark-first
/// architecture; needs the (is_available, geohash) index.
///
/// Owned by one screen: create it, listen to [stream] as often as needed
/// (every new listener immediately gets the latest list), and [dispose] it.
class NearbyDonors {
  /// One precision-5 geohash cell is 360/2^13 = 0.0439° wide and
  /// 180/2^12 = 0.0439° tall.
  static const _cellDegrees = 0.0439;

  static String cellOf(double lat, double lng) => encodeGeohash(lat, lng, precision: 5);

  /// Hard ceiling on cost per map open: at most 9 × 30 = 270 donor reads,
  /// even in the densest neighbourhood. More pins than this aren't readable
  /// on a phone map, and the list is sorted by distance anyway.
  static const perCellLimit = 30;

  /// How many available donors of [groups] are within the same ~15 km
  /// square — using Firestore count() aggregation, billed at one read per
  /// 1,000 matching index entries. So this costs ~9 reads however many
  /// donors there are, versus downloading every donor document to count
  /// them. Needs the (is_available, blood_group, geohash) index.
  static Future<int> countCompatible(double lat, double lng, List<String> groups) async {
    if (groups.isEmpty) return 0;
    final cells = <String>{
      for (final dy in const [-1, 0, 1])
        for (final dx in const [-1, 0, 1]) cellOf(lat + dy * _cellDegrees, lng + dx * _cellDegrees),
    };
    final db = FirebaseFirestore.instance;
    final counts = await Future.wait(cells.map((cell) => db
        .collection('donors_public')
        .where('is_available', isEqualTo: true)
        .where('blood_group', whereIn: groups)
        .where('geohash', isGreaterThanOrEqualTo: cell)
        .where('geohash', isLessThan: '$cell~')
        .count()
        .get()
        .then((agg) => agg.count ?? 0)));
    return counts.fold<int>(0, (a, b) => a + b);
  }

  final _updates = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.broadcast();
  final _byCell = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final _subs = <StreamSubscription<dynamic>>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _latest;
  Object? _error;

  NearbyDonors(double lat, double lng) {
    final cells = <String>{
      for (final dy in const [-1, 0, 1])
        for (final dx in const [-1, 0, 1]) cellOf(lat + dy * _cellDegrees, lng + dx * _cellDegrees),
    };
    final db = FirebaseFirestore.instance;
    for (final cell in cells) {
      _subs.add(db
          .collection('donors_public')
          .where('is_available', isEqualTo: true)
          .where('geohash', isGreaterThanOrEqualTo: cell)
          .where('geohash', isLessThan: '$cell~')
          .limit(perCellLimit)
          .snapshots()
          .listen((snap) {
        _byCell[cell] = snap.docs;
        // Wait until every cell has answered once, so the list doesn't
        // flicker in cell by cell on first load.
        if (_byCell.length == cells.length) {
          _latest = [for (final docs in _byCell.values) ...docs];
          _updates.add(_latest!);
        }
      }, onError: (Object e) {
        _error = e;
        _updates.addError(e);
      }));
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get stream async* {
    if (_error != null) throw _error!;
    final latest = _latest;
    if (latest != null) yield latest;
    yield* _updates.stream;
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _updates.close();
  }
}
