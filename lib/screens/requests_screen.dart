import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/dashed_border.dart';
import '../widgets/state_card.dart';
import '../widgets/status_badge.dart';
import 'cancel_confirm_screen.dart';
import 'create_request_screen.dart';
import 'match_contact_screen.dart';
import 'notifications_screen.dart';
import 'request_detail_screen.dart';
import 'tracking_screen.dart';

/// Request tab root — "both sides of the emergency" per the final artifact:
/// requests you can answer ("You can help") and requests you raised
/// ("Yours"). Ranking on the You-can-help side is urgency then distance, so
/// the most urgent/nearest compatible request is the one raised card; every
/// other request is a quieter ground-level row. All request data below is
/// real Firestore state — nothing here is mocked.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _activeTab = 'You can help';
  String? _myBloodGroup;
  bool _isAvailable = false;
  bool _isVerified = false;
  Position? _position;

  @override
  void initState() {
    super.initState();
    Backend.instance.myDonorDoc().then((snap) {
      if (!mounted) return;
      final data = snap.data();
      setState(() {
        _myBloodGroup = data?['blood_group'] as String?;
        _isAvailable = data?['is_available'] as bool? ?? false;
        _isVerified = data?['is_verified'] as bool? ?? false;
      });
    });
    // Real device position for ranking "You can help" by distance — the
    // list still works (urgency-only ranking) while this resolves.
    Backend.instance.currentPosition().then((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  static int _urgencyRank(String urgency) => switch (urgency) {
        'critical' => 0,
        'urgent' => 1,
        _ => 2,
      };

  double? _distanceKmTo(Map<String, dynamic> request) {
    final pos = _position;
    final lat = (request['lat'] as num?)?.toDouble();
    final lng = (request['lng'] as num?)?.toDouble();
    if (pos == null || lat == null || lng == null) return null;
    return distanceKm(pos.latitude, pos.longitude, lat, lng);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case 'open':
        return AppColors.statusUrgentBg;
      case 'matched':
        return AppColors.statusPendingBg;
      case 'fulfilled':
        return AppColors.statusAvailableBg;
      default:
        return AppColors.cardBorderWarm;
    }
  }

  Color _getStatusText(String status) {
    switch (status) {
      case 'open':
        return AppColors.statusUrgentText;
      case 'matched':
        return AppColors.statusPendingText;
      case 'fulfilled':
        return AppColors.statusAvailableText;
      default:
        return AppColors.textPrimaryWarm;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'matched':
        return 'Matched';
      case 'fulfilled':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  Future<void> _cancel(String requestId) async {
    await Backend.instance.cancelRequest(requestId);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => CancelConfirmScreen(requestId: requestId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        title: 'Requests',
        onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
        stateStrip: _myBloodGroup == null
            ? null
            : AppStateStrip(
                isAvailable: _isAvailable,
                subtitle: (_isVerified ? 'verified · ' : '') + (_myBloodGroup ?? ''),
              ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _tabButton('You can help'),
                  const SizedBox(width: 22),
                  _tabButton('Yours', countStream: Backend.instance.myRequestsStream()),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _activeTab == 'You can help' ? _receivedList() : _myRequestsList()),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, {Stream<QuerySnapshot<Map<String, dynamic>>>? countStream}) {
    final isActive = _activeTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? AppColors.brandRed : Colors.transparent, width: 2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14.5, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.ink : AppColors.ink2),
            ),
            if (countStream != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: countStream,
                builder: (context, snap) {
                  final count = snap.data?.docs.length;
                  if (count == null || count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(999)),
                      child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _receivedList() {
    if (_myBloodGroup == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final compatible = Backend.instance.compatibleRecipientGroups(_myBloodGroup!);
    final myUid = Backend.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Backend.instance.openRequestsStream(),
      builder: (context, openSnapshot) {
        if (!openSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final openDocs = openSnapshot.data!.docs
            .where((d) => d.data()['requester_uid'] != myUid && compatible.contains(d.data()['blood_group']))
            .toList()
          ..sort((a, b) {
            final ua = _urgencyRank(a.data()['urgency'] as String? ?? 'normal');
            final ub = _urgencyRank(b.data()['urgency'] as String? ?? 'normal');
            if (ua != ub) return ua.compareTo(ub);
            final da = _distanceKmTo(a.data());
            final db = _distanceKmTo(b.data());
            if (da == null || db == null) return 0;
            return da.compareTo(db);
          });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('matched_donor_id', isEqualTo: myUid)
              .where('status', isEqualTo: 'matched')
              .snapshots(),
          builder: (context, matchedSnapshot) {
            final matchedDocs = matchedSnapshot.data?.docs ?? [];

            if (openDocs.isEmpty && matchedDocs.isEmpty) {
              return _receivedEmptyState();
            }

            final topDoc = openDocs.isNotEmpty ? openDocs.first : null;
            final restDocs = openDocs.skip(1).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                if (matchedDocs.isNotEmpty) ...[
                  _sectionLabel("You've accepted"),
                  const SizedBox(height: 10),
                  for (final doc in matchedDocs) ...[
                    _myRequestCard(doc.id, doc.data(), primaryAction: _CardAction.viewContact),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                ],
                if (topDoc != null) ...[
                  _raisedRequestCard(topDoc.id, topDoc.data()),
                  const SizedBox(height: 12),
                ],
                for (final doc in restDocs) ...[
                  _quietRequestRow(doc.id, doc.data()),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                _needBloodCta(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 4, height: 14, decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
      ],
    );
  }

  /// The one raised object: the most urgent, nearest compatible request.
  Widget _raisedRequestCard(String requestId, Map<String, dynamic> request) {
    final urgency = request['urgency'] as String? ?? 'normal';
    final isCritical = urgency == 'critical';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final units = request['units_needed'] ?? 1;
    final locationLabel = (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'Blood request';
    final createdAt = (request['created_at'] as Timestamp?)?.toDate();
    final distanceKmValue = _distanceKmTo(request);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: isCritical ? AppColors.brandRed : AppColors.orange),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BloodGroupDroplet(
                      label: bloodGroup,
                      size: 50,
                      filled: true,
                      color: isCritical ? AppColors.brandRed : AppColors.orange,
                      textColor: AppColors.whiteTextOnPrimary,
                      fontSize: 17,
                      serif: true,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCritical ? 'CRITICAL' : urgency.toUpperCase(),
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: isCritical ? AppColors.red700 : AppColors.orangeDeep),
                          ),
                          const SizedBox(height: 3),
                          Text(locationLabel, style: AppTextStyles.display(fontSize: 19, color: AppColors.ink, height: 1.25)),
                          const SizedBox(height: 3),
                          Text('$units unit(s) · ${createdAt == null ? 'just now' : _timeAgo(createdAt)}', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.only(top: 13),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.warmDivider))),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: AppColors.red200, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('You', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.red700)),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(height: 1, color: AppColors.warmDivider),
                            if (distanceKmValue != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                color: Colors.white,
                                child: Text('${distanceKmValue.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 10.5, color: AppColors.ink2)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: isCritical ? AppColors.red100 : AppColors.orangeTint, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Icon(LucideIcons.droplet, size: 13, color: isCritical ? AppColors.brandRed : AppColors.orangeDeep),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailScreen(requestId: requestId))),
                  child: const Text('Accept & help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A quieter ground-level row for everything below the raised card.
  Widget _quietRequestRow(String requestId, Map<String, dynamic> request) {
    final urgency = request['urgency'] as String? ?? 'normal';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final locationLabel = (request['location_label'] as String?)?.isNotEmpty == true ? request['location_label'] as String : 'Blood request';
    final createdAt = (request['created_at'] as Timestamp?)?.toDate();
    final distanceKmValue = _distanceKmTo(request);
    final metaParts = [
      if (distanceKmValue != null) '${distanceKmValue.toStringAsFixed(1)} km',
      if (createdAt != null) _timeAgo(createdAt),
    ];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailScreen(requestId: requestId))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            BloodGroupDroplet(label: bloodGroup, size: 38, filled: true, color: AppColors.sand, textColor: AppColors.ink2, fontSize: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge.pill(urgency),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Text(metaParts.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(locationLabel, style: AppTextStyles.display(fontSize: 16.5, color: AppColors.ink, height: 1.1)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.disabledTint),
          ],
        ),
      ),
    );
  }

  Widget _needBloodCta() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRequestScreen())),
      child: CustomPaint(
        painter: DashedRRectPainter(color: AppColors.warmBorder, radius: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.plus, size: 17, color: AppColors.brandRed),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need blood yourself?', style: AppTextStyles.display(fontSize: 16.5, color: AppColors.ink)),
                    const Text('Alert nearby compatible donors', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receivedEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/illustrations/received-empty-state.png', width: 220),
            const SizedBox(height: 20),
            const Text(
              'No blood requests yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
            ),
            const SizedBox(height: 8),
            const Text(
              'When someone needs blood near you, their request will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRequestScreen())),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Request Blood'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myRequestsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Backend.instance.myRequestsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: StateCard.empty(title: "You haven't sent any requests yet.", icon: LucideIcons.clipboardList));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _myRequestCard(docs[index].id, docs[index].data(), primaryAction: _CardAction.track),
        );
      },
    );
  }

  Widget _myRequestCard(String requestId, Map<String, dynamic> request, {required _CardAction primaryAction}) {
    final status = request['status'] as String? ?? 'open';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final locationLabel = (request['location_label'] as String?)?.isNotEmpty == true
        ? request['location_label'] as String
        : '${request['units_needed'] ?? 1} unit(s) needed';

    final isMatched = status == 'matched' && request['matched_donor_phone'] != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorderWarm),
        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMatched) Container(height: 3, color: AppColors.warmGreenText),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BloodGroupDroplet(
                      label: bloodGroup,
                      size: 38,
                      filled: status != 'fulfilled' && status != 'expired',
                      color: status == 'fulfilled'
                          ? AppColors.statusAvailableBg
                          : (status == 'expired' ? AppColors.dividerWarm : AppColors.primaryLightTint),
                      textColor: status == 'fulfilled'
                          ? AppColors.statusAvailableText
                          : (status == 'expired' ? AppColors.textSecondary : AppColors.primary),
                      fontSize: 12,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(label: _statusLabel(status), background: _getStatusBg(status), textColor: _getStatusText(status)),
                          const SizedBox(height: 4),
                          Text(
                            locationLabel,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isMatched) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.only(top: 13),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.dividerWarm))),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: AppColors.primaryLightTint, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(request['matched_donor_name'] as String? ?? '?'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        Container(width: 22, height: 1, color: AppColors.warmGreenText),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: AppColors.warmGreenBg, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.check, size: 14, color: AppColors.warmGreenText),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            request['matched_donor_name'] as String? ?? '',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(LucideIcons.phone, size: 15, color: AppColors.warmGreenText),
                      ],
                    ),
                  ),
                ],
                if (status == 'expired') ...[
                  const SizedBox(height: 10),
                  _terminalNote('No donor found in time — matching stopped. You can create a new request.'),
                ],
                if (status == 'cancelled') ...[
                  const SizedBox(height: 10),
                  _terminalNote('You cancelled this request.'),
                ],
                const SizedBox(height: 14),
                _cardActions(requestId, status, primaryAction),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
  }

  Widget _terminalNote(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.warmPageBackground, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  Widget _cardActions(String requestId, String status, _CardAction primaryAction) {
    switch (primaryAction) {
      case _CardAction.viewDetail:
        return ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailScreen(requestId: requestId))),
          child: const Text('View request'),
        );
      case _CardAction.viewContact:
        return ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MatchContactScreen(requestId: requestId))),
          child: const Text('View contact'),
        );
      case _CardAction.track:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrackingScreen(requestId: requestId))),
                child: const Text('Track status'),
              ),
            ),
            if (status == 'open') ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: () => _cancel(requestId), child: const Text('Cancel request')),
              ),
            ],
          ],
        );
    }
  }
}

enum _CardAction { viewDetail, viewContact, track }
