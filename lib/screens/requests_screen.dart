import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/maps_link.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/messages_button.dart';
import '../widgets/rb_ui.dart';
import 'cancel_confirm_screen.dart';
import 'chat_screen.dart';
import 'create_request_screen.dart';
import 'match_contact_screen.dart';
import 'notifications_screen.dart';
import 'request_detail_screen.dart';
import 'tracking_screen.dart';
import '../widgets/rb_icon.dart';

/// Request tab. "Near you": compatible open requests around the donor's
/// registered area, most urgent first, plus any request this donor has
/// accepted. "Yours": requests this user raised. Every card reads the same
/// way — urgency and group, the place (tap to open it in Google Maps),
/// distance · age · units — with one dominant action.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

enum _Tab { nearby, yours }

/// A request id and its fields from Firestore.
typedef _Doc = ({String id, Map<String, dynamic> data});

class _RequestsScreenState extends State<RequestsScreen> {
  _Tab _tab = _Tab.nearby;
  String? _myBloodGroup;
  double? _myLat;
  double? _myLng;
  bool _profileLoaded = false;
  // Created once, so a rebuild doesn't tear down and re-bill the listeners;
  // recreated by [_resubscribe] because a Firestore stream is finished
  // after an error (a bare setState would retry against a dead stream).
  Stream<List<_Doc>>? _nearbyOpen;
  late Stream<List<_Doc>> _mine = _mineStream();
  late Stream<List<_Doc>> _accepted = _acceptedStream();

  static List<_Doc> _docs(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) => [for (final d in docs) (id: d.id, data: d.data())];

  static Stream<List<_Doc>> _mineStream() => Backend.instance.myRequestsStream().map((q) => _docs(q.docs));

  static Stream<List<_Doc>> _acceptedStream() => FirebaseFirestore.instance
      .collection('requests')
      .where('matched_donor_id', isEqualTo: Backend.instance.currentUser?.uid)
      .where('status', isEqualTo: 'matched')
      .snapshots()
      .map((q) => _docs(q.docs));

  static Stream<List<_Doc>> _nearStream(double lat, double lng) => Backend.instance.openRequestsNearStream(lat, lng).map(_docs);

  void _resubscribe() => setState(() {
        _mine = _mineStream();
        _accepted = _acceptedStream();
        if (_myLat != null && _myLng != null) _nearbyOpen = _nearStream(_myLat!, _myLng!);
      });

  @override
  void initState() {
    super.initState();
    Backend.instance.myDonorDoc().then((snap) {
      if (!mounted) return;
      final data = snap.data();
      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();
      setState(() {
        _profileLoaded = true;
        _myBloodGroup = data?['blood_group'] as String?;
        _myLat = lat;
        _myLng = lng;
        if (lat != null && lng != null) _nearbyOpen = _nearStream(lat, lng);
      });
    }).catchError((_) {
      if (mounted) setState(() => _profileLoaded = true);
    });
  }

  // ------------------------------------------------------------- helpers

  static const _urgencyRank = {'critical': 0, 'urgent': 1};

  static String _ago(Object? ts) {
    if (ts is! Timestamp) return '';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} d ago';
  }

  static String _units(Object? n) {
    final v = (n as num?)?.toInt() ?? 1;
    return v == 1 ? '1 unit' : '$v units';
  }

  double? _distanceTo(Map<String, dynamic> r) {
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (_myLat == null || _myLng == null || lat == null || lng == null) return null;
    return distanceKm(_myLat!, _myLng!, lat, lng);
  }

  static String _km(double d) => d < 1 ? 'under 1 km' : '${d.toStringAsFixed(1)} km';

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _openPlace(Map<String, dynamic> r) async {
    final lat = (r['lat'] as num?)?.toDouble();
    final lng = (r['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final ok = await openInMaps(lat, lng);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t open Google Maps on this device.')));
    }
  }

  Future<void> _cancel(String requestId) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Cancel this request?',
      message: 'Donors will stop seeing it. If you still need blood later, you can raise a new request.',
      confirmLabel: 'Cancel request',
    );
    if (!confirmed || !mounted) return;
    try {
      await Backend.instance.cancelRequest(requestId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel this request. Please try again.')));
      return;
    }
    if (!mounted) return;
    _open(CancelConfirmScreen(requestId: requestId));
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        showDivider: false,
        title: 'Requests',
        primaryAction: const MessagesButton(),
        onNotificationTap: () => _open(const NotificationsScreen()),
      ),
      body: StreamBuilder<List<_Doc>>(
        stream: _mine,
        builder: (context, mineSnap) {
          // Cancelled requests are finished business for the requester.
          final mine = mineSnap.data?.where((d) => d.data['status'] != 'cancelled').toList();
          final activeMine = mine?.where((d) => d.data['status'] == 'open' || d.data['status'] == 'matched').length ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tabRow(activeMine),
              Expanded(
                child: _tab == _Tab.nearby
                    ? _nearbyList()
                    : mineSnap.hasError
                        ? _error(_resubscribe)
                        : _yoursList(mine),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabRow(int yoursCount) => RbTabBar(
        showDivider: false,
        tabs: [('Near you', 0), ('Yours', yoursCount)],
        selected: _tab.index,
        onChanged: (i) => setState(() => _tab = _Tab.values[i]),
      );

  // ------------------------------------------------------------- Near you

  Widget _nearbyList() {
    if (!_profileLoaded) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    final compatible = _myBloodGroup == null ? const <String>[] : Backend.instance.compatibleRecipientGroups(_myBloodGroup!);
    final myUid = Backend.instance.currentUser?.uid;

    return StreamBuilder<List<_Doc>>(
      stream: _nearbyOpen ?? Stream.value(const []),
      builder: (context, openSnap) {
        return StreamBuilder<List<_Doc>>(
          stream: _accepted,
          builder: (context, acceptedSnap) {
            if (openSnap.hasError || acceptedSnap.hasError) return _error(_resubscribe);
            if (!openSnap.hasData || !acceptedSnap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            final open = openSnap.data!.where((d) => d.data['requester_uid'] != myUid && compatible.contains(d.data['blood_group'])).toList();
            for (final d in open) {
              // Lazy stand-in for expiry — a no-op unless genuinely past due.
              Backend.instance.expireIfStale(d.id, d.data);
            }
            open.sort((a, b) {
              final ua = _urgencyRank[a.data['urgency']] ?? 2;
              final ub = _urgencyRank[b.data['urgency']] ?? 2;
              if (ua != ub) return ua.compareTo(ub);
              return (_distanceTo(a.data) ?? double.infinity).compareTo(_distanceTo(b.data) ?? double.infinity);
            });
            final accepted = acceptedSnap.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                if (accepted.isNotEmpty) ...[
                  _sectionLabel('You’ve accepted'),
                  for (final doc in accepted) ...[_acceptedCard(doc.id, doc.data), const SizedBox(height: 12)],
                  const SizedBox(height: 8),
                ],
                if (open.isEmpty && accepted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: RbStatePanel(
                      icon: RbGlyph.inbox,
                      tone: GlyphTone.success,
                      title: 'No requests near you right now',
                      message: 'When someone nearby needs your blood group, their request appears here and you’ll get a notification.',
                    ),
                  ),
                if (open.isNotEmpty) _sectionLabel('${open.length} ${open.length == 1 ? 'request' : 'requests'} you can help with'),
                for (final doc in open) ...[_nearbyCard(doc.id, doc.data), const SizedBox(height: 12)],
                const SizedBox(height: 8),
                _createRequestCta(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _nearbyCard(String id, Map<String, dynamic> r) {
    final distance = _distanceTo(r);
    return _card(
      urgency: r['urgency'] as String?,
      bloodGroup: r['blood_group'] as String? ?? '',
      request: r,
      meta: [if (distance != null) _km(distance), _ago(r['created_at']), _units(r['units_needed'])],
      action: _actions(
        primary: ElevatedButton(style: _primaryStyle, onPressed: () => _open(RequestDetailScreen(requestId: id)), child: _label('See request & help')),
      ),
    );
  }

  /// A request this donor accepted — the counterpart shown is the
  /// requester, never the donor's own name.
  Widget _acceptedCard(String id, Map<String, dynamic> r) {
    final requester = (r['requester_name'] as String?)?.trim();
    final waitingOnThem = r['donor_confirmed_at'] != null;
    return _card(
      urgency: r['urgency'] as String?,
      bloodGroup: r['blood_group'] as String? ?? '',
      request: r,
      statusLabel: waitingOnThem ? 'Waiting for the requester to confirm' : 'You accepted',
      subtitle: requester == null || requester.isEmpty ? null : 'For $requester',
      meta: [_ago(r['matched_at'] ?? r['created_at']), _units(r['units_needed'])],
      action: _actions(
        primary: ElevatedButton.icon(
          style: _primaryStyle,
          onPressed: () => _open(MatchContactScreen(requestId: id)),
          icon: const RbIcon(RbGlyph.phone, size: 16),
          label: _label('Contact & confirm'),
        ),
        secondary: OutlinedButton.icon(
          style: _secondaryStyle,
          onPressed: () => _open(ChatScreen(requestId: id)),
          icon: const RbIcon(RbGlyph.message, size: 16),
          label: _label('Message'),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Yours

  Widget _yoursList(List<_Doc>? docs) {
    if (docs == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    for (final d in docs) {
      Backend.instance.expireIfStale(d.id, d.data);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _createRequestCta(),
        const SizedBox(height: 18),
        if (docs.isEmpty)
          const RbStatePanel(
            icon: RbGlyph.clipboard,
            title: 'No requests yet',
            message: 'Requests you raise appear here, with their status and who accepted them.',
          )
        else
          for (final doc in docs) ...[_yoursCard(doc.id, doc.data), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _yoursCard(String id, Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'open';
    final donor = (r['matched_donor_name'] as String?)?.trim();
    final (label, live) = switch (status) {
      'open' => ('Searching for a donor', true),
      'matched' => (r['requester_confirmed_at'] != null
          ? 'Waiting for the donor to confirm'
          : r['donor_confirmed_at'] != null
              ? 'Donor says they’ve donated — please confirm'
              : (donor == null || donor.isEmpty ? 'Donor found' : '$donor accepted'), true),
      'fulfilled' => ('Completed', false),
      'expired' => ('Expired — no donor in time', false),
      _ => (status, false),
    };
    return _card(
      urgency: r['urgency'] as String?,
      bloodGroup: r['blood_group'] as String? ?? '',
      request: r,
      statusLabel: label,
      muted: !live,
      meta: [_ago(r['created_at']), _units(r['units_needed'])],
      action: live
          ? _actions(
              primary: ElevatedButton.icon(
                style: _primaryStyle,
                onPressed: () => _open(TrackingScreen(requestId: id)),
                icon: const RbIcon(RbGlyph.route, size: 16),
                label: _label('Track request'),
              ),
              secondary: status == 'open'
                  ? OutlinedButton(
                      style: _secondaryStyle.merge(OutlinedButton.styleFrom(foregroundColor: AppColors.red700, side: const BorderSide(color: AppColors.red200))),
                      onPressed: () => _cancel(id),
                      child: _label('Cancel'),
                    )
                  : OutlinedButton.icon(
                      style: _secondaryStyle,
                      onPressed: () => _open(ChatScreen(requestId: id)),
                      icon: const RbIcon(RbGlyph.message, size: 16),
                      label: _label('Message'),
                    ),
            )
          : _actions(primary: OutlinedButton(style: _secondaryStyle, onPressed: () => _open(TrackingScreen(requestId: id)), child: _label('View details'))),
    );
  }

  // ------------------------------------------------------------- shared card

  Widget _card({
    required String? urgency,
    required String bloodGroup,
    required Map<String, dynamic> request,
    required List<String> meta,
    required Widget action,
    String? statusLabel,
    String? subtitle,
    bool muted = false,
  }) {
    final critical = urgency == 'critical';
    final urgent = urgency == 'urgent';
    final edge = muted ? AppColors.warmBorder : (critical ? AppColors.brandRed : (urgent ? AppColors.vermilion : AppColors.warmBorder));
    final place = Backend.shortPlace(request['location_label'] as String?, fallback: 'Location not given');
    final hasPoint = request['lat'] is num && request['lng'] is num;
    final metaText = meta.where((m) => m.isNotEmpty).join(' · ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warmBorder),
        boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: edge),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Blood group and urgency first — what a donor scans for.
                Row(
                  children: [
                    BloodGroupDroplet(
                      label: bloodGroup,
                      size: 40,
                      filled: true,
                      color: muted ? AppColors.warmDivider : AppColors.brandRed,
                      textColor: muted ? AppColors.ink2 : AppColors.onEmber,
                      fontSize: 12.5,
                      serif: true,
                    ),
                    const SizedBox(width: 12),
                    _urgencyTag(urgency, muted),
                    if (statusLabel != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(statusLabel, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink2, height: 1.3)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // The place — tap to open it in Google Maps.
                Semantics(
                  button: hasPoint,
                  label: hasPoint ? 'Open $place in Google Maps' : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: hasPoint ? () => _openPlace(request) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(place, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.display(fontSize: 19, color: AppColors.ink, height: 1.25)),
                        ),
                        if (hasPoint)
                          const Padding(
                            padding: EdgeInsets.only(left: 10, top: 2),
                            child: RbIcon(RbGlyph.pin, size: 18, color: AppColors.brandRed),
                          ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                ],
                if (metaText.isNotEmpty) ...[
                  SizedBox(height: subtitle != null ? 2 : 6),
                  Text(metaText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
                ],
                const SizedBox(height: 14),
                action,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card actions: one height, one padding, one type size, so a pair of
  // buttons always shares a baseline and never wraps.
  static final _primaryStyle = ElevatedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
  );
  static final _secondaryStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
  );

  static Widget _label(String text) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

  /// A primary action and an optional secondary one, side by side.
  Widget _actions({required Widget primary, Widget? secondary}) => Row(
        children: [
          Expanded(flex: secondary == null ? 1 : 3, child: primary),
          if (secondary != null) ...[const SizedBox(width: 10), Expanded(flex: 2, child: secondary)],
        ],
      );

  Widget _urgencyTag(String? urgency, bool muted) {
    final (label, bg, fg) = switch (urgency) {
      'critical' => ('Critical', AppColors.red100, AppColors.red700),
      'urgent' => ('Urgent', AppColors.statusUrgentBg, AppColors.statusUrgentText),
      _ => ('Normal', AppColors.warmDivider, AppColors.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: muted ? AppColors.warmDivider : bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted ? AppColors.ink2 : fg)),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
      );

  Widget _error(VoidCallback retry) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [RbStatePanel.error(title: 'Couldn’t load requests', message: 'Check your connection and try again.', onRetry: retry)],
      );

  Widget _createRequestCta() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        onTap: () => _open(const CreateRequestScreen()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            border: Border.all(color: AppColors.warmBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const RbIcon(RbGlyph.plus, size: 18, color: AppColors.brandRed),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need blood yourself?', style: AppTextStyles.display(fontSize: 17, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    const Text('Alert compatible donors near the hospital', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                  ],
                ),
              ),
              const RbIcon(RbGlyph.chevron, size: 18, color: AppColors.chevronMuted),
            ],
          ),
        ),
      ),
    );
  }
}
