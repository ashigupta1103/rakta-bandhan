import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../services/nearby_donors.dart';
import '../theme/app_colors.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/ring_field.dart';
import 'cancel_confirm_screen.dart';
import 'donor_found_screen.dart';
import 'no_donor_found_screen.dart';

/// Matching / searching — the final artifact's ember-field emotional-peak
/// state. Everything shown here is real: the request document itself
/// (watched live, so a real donor accepting elsewhere navigates this screen
/// forward on its own), the count of currently-available compatible donors,
/// and elapsed real time since the request was raised. There is no backend
/// concept of search radius, "notified" counts, or ladder/escalation
/// stages — `matching_ladder_service.dart`'s MockMatchingLadderService
/// fabricated all of that, so this screen no longer uses it. A request with
/// no response by its real `expires_at` is treated as unmatched — the same
/// honest signal request_detail/tracking screens already read.
class MatchingScreen extends StatefulWidget {
  final String requestId;
  final String bloodGroup;
  final String urgency;

  const MatchingScreen({super.key, required this.requestId, required this.bloodGroup, required this.urgency});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _donorSub;
  NearbyDonors? _nearby;
  Timer? _tick;

  DateTime? _createdAt;
  DateTime? _expiresAt;
  int? _compatibleAvailableCount;
  bool _navigated = false;
  bool _cancelling = false;
  bool _searchPhaseOver = false;
  Timer? _searchPhaseTimer;

  @override
  void initState() {
    super.initState();
    _searchPhaseTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _searchPhaseOver = true);
    });
    _requestSub = FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots().listen(_onRequestUpdate);


    // Real elapsed-time display and a real expiry check — no fixed-delay
    // simulation of an outcome.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
      _checkExpiry();
    });
  }

  void _onRequestUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    final data = snap.data();
    if (data == null) return;
    setState(() {
      _createdAt = (data['created_at'] as Timestamp?)?.toDate();
      _expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
    });
    // Count compatible donors around the request's own location — bounded
    // query (NearbyDonors), started once the request doc gives us a point.
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (_nearby == null && lat != null && lng != null) {
      final compatibleGroups = bloodCompatibility[widget.bloodGroup] ?? const <String>[];
      _nearby = NearbyDonors(lat, lng);
      _donorSub = _nearby!.stream.listen((docs) {
        if (!mounted) return;
        setState(() {
          _compatibleAvailableCount = docs.where((d) => compatibleGroups.contains(d.data()['blood_group'])).length;
        });
      }, onError: (_) {});
    }
    final status = data['status'] as String? ?? 'open';
    if (status == 'matched') {
      _goTo(() => DonorFoundScreen(requestId: widget.requestId));
    } else if (status == 'cancelled') {
      // Cancellation from this screen already navigates on its own; a
      // cancellation from elsewhere (e.g. another device) just leaves this
      // screen — nothing more to show.
      if (!_navigated) Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _checkExpiry();
    }
  }

  void _checkExpiry() {
    final expiresAt = _expiresAt;
    if (expiresAt == null || _navigated) return;
    if (DateTime.now().isAfter(expiresAt)) {
      _goTo(() => NoDonorFoundScreen(requestId: widget.requestId));
    }
  }

  void _goTo(Widget Function() builder) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => builder()));
  }

  /// The request stays open and visible to donors — the requester just
  /// stops watching this screen. The live status is always one tap away
  /// under Request → My requests → Track status.
  void _keepWaitingInBackground() {
    _navigated = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Still searching. Track it anytime from My requests.')),
    );
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Cancel this request?',
      message: 'Donors will stop seeing it. Choose "Keep waiting" instead if you just want to leave this screen — the search carries on.',
      confirmLabel: 'Cancel request',
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelling = true);
    _navigated = true;
    await _requestSub?.cancel();
    try {
      await Backend.instance.cancelRequest(widget.requestId);
    } catch (_) {
      // Already terminal server-side (matched/expired) — fine to proceed to
      // the cancel-confirmation screen either way from the requester's view.
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CancelConfirmScreen(requestId: widget.requestId)));
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _donorSub?.cancel();
    _nearby?.dispose();
    _tick?.cancel();
    _searchPhaseTimer?.cancel();
    super.dispose();
  }

  String get _waitingLabel {
    final createdAt = _createdAt;
    if (createdAt == null) return 'Just now';
    final mins = DateTime.now().difference(createdAt).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return 'Waiting $mins min';
    return 'Waiting ${(mins / 60).floor()}h ${mins % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientMatchingStart,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.3, -1),
              end: Alignment(0.3, 1),
              colors: [AppColors.gradientMatchingStart, AppColors.gradientMatchingEnd],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Positioned.fill(
                              child: RingField(scale: 1.0, referenceWidth: 390, color: AppColors.onEmber, outerOpacity: 0.16, middleOpacity: 0.26, innerOpacity: 0, strokeWidth: 1),
                            ),
                            ..._compatibleDots(),
                            BloodGroupDroplet(label: widget.bloodGroup, size: 60, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 20, serif: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(_searchPhaseOver ? 'Still waiting' : 'Searching', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: AppColors.onEmberEyebrow)),
                      const SizedBox(height: 10),
                      Text(
                        _searchPhaseOver ? "No match confirmed yet — this screen updates the moment a donor accepts" : 'Visible now to compatible donors nearby',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onEmberStrong, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _compatibleAvailableCount == null
                            ? _waitingLabel
                            : '$_waitingLabel · $_compatibleAvailableCount compatible donor${_compatibleAvailableCount == 1 ? '' : 's'} available',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [
                            _stageRow('Request submitted', done: true, showDivider: true),
                            _stageRow('Waiting for a donor to accept', done: false, showSpinner: !_searchPhaseOver, showDivider: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
                      onPressed: _cancelling ? null : _keepWaitingInBackground,
                      icon: const Icon(LucideIcons.hourglass, size: 16),
                      label: const Text('Keep waiting in background'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your request stays live for donors. The Request tab updates the moment someone accepts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.5), height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _cancelling ? null : _cancel,
                      child: Text(_cancelling ? 'Cancelling…' : 'Cancel this request', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A static, non-animated echo of the real compatible-available-donor
  /// count fetched above — capped for legibility, never incremented on a
  /// timer.
  List<Widget> _compatibleDots() {
    final count = (_compatibleAvailableCount ?? 0).clamp(0, 4);
    const positions = [
      (dx: -72.0, dy: -84.0, size: 44.0, opacity: 0.95),
      (dx: 44.0, dy: -96.0, size: 38.0, opacity: 0.8),
      (dx: -96.0, dy: 44.0, size: 30.0, opacity: 0.65),
      (dx: 76.0, dy: 56.0, size: 26.0, opacity: 0.5),
    ];
    return [
      for (var i = 0; i < count; i++)
        Positioned(
          left: 110 + positions[i].dx,
          top: 110 + positions[i].dy,
          child: Opacity(
            opacity: positions[i].opacity,
            child: Container(
              width: positions[i].size,
              height: positions[i].size,
              decoration: const BoxDecoration(color: AppColors.onEmber, shape: BoxShape.circle),
            ),
          ),
        ),
    ];
  }

  Widget _stageRow(String label, {required bool done, required bool showDivider, bool showSpinner = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))) : null),
      child: Row(
        children: [
          if (done)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: Color.fromRGBO(90, 180, 110, 0.2), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.check, size: 12, color: AppColors.onEmberSuccess),
            )
          else if (showSpinner)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onEmberAccent))
          else
            const Icon(LucideIcons.clock, size: 18, color: AppColors.onEmberAccent),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}
