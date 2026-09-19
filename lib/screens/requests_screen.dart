import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/state_card.dart';
import '../widgets/status_badge.dart';
import 'cancel_confirm_screen.dart';
import 'match_contact_screen.dart';
import 'request_detail_screen.dart';
import 'tracking_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _activeTab = 'Received';
  String? _myBloodGroup;

  @override
  void initState() {
    super.initState();
    Backend.instance.myDonorDoc().then((snap) {
      if (mounted) setState(() => _myBloodGroup = snap.data()?['blood_group'] as String?);
    });
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Blood requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(color: AppColors.tabTrackBackground, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(child: _tabButton('Received')),
                  Expanded(child: _tabButton('My requests')),
                ],
              ),
            ),
            Expanded(child: _activeTab == 'Received' ? _receivedList() : _myRequestsList()),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label) {
    final isActive = _activeTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: isActive ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: isActive ? AppColors.whiteTextOnPrimary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Backend.instance.openRequestsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final docs = snapshot.data!.docs
                .where((d) => d.data()['requester_uid'] != myUid && compatible.contains(d.data()['blood_group']))
                .toList();
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Open requests you can fulfil'),
                const SizedBox(height: 10),
                for (final doc in docs) ...[
                  _requestCard(doc.id, doc.data(), primaryAction: _CardAction.viewDetail),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('matched_donor_id', isEqualTo: myUid)
              .where('status', isEqualTo: 'matched')
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _sectionLabel("You've accepted"),
                const SizedBox(height: 10),
                for (final doc in docs) ...[
                  _requestCard(doc.id, doc.data(), primaryAction: _CardAction.viewContact),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _requestCard(docs[index].id, docs[index].data(), primaryAction: _CardAction.track),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 4, height: 14, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
      ],
    );
  }

  Widget _requestCard(String requestId, Map<String, dynamic> request, {required _CardAction primaryAction}) {
    // Lazy stand-in for the Blaze-only expireOldRequests scheduled
    // function — no-op unless this doc is genuinely open and past due.
    Backend.instance.expireIfStale(requestId, request);
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
        borderRadius: BorderRadius.circular(14),
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
