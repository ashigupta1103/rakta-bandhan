import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/backend.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/identity_disc.dart';
import '../widgets/pressable.dart';
import 'call_screen.dart';

/// In-app chat between the requester and the donor on one matched request.
///
/// Layout, top to bottom: a slim header (who, which request, call, menu) →
/// the thread, anchored to the bottom like every messenger → quick replies
/// written for the one thing these two people need to do (meet at a blood
/// bank) → the composer. When the conversation is over (donated,
/// cancelled, or blocked) the composer is replaced by a read-only footer
/// saying why — the thread stays as a record.
class ChatScreen extends StatefulWidget {
  final String requestId;

  const ChatScreen({super.key, required this.requestId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  /// Ids present on first load — only messages arriving after that get the
  /// entry animation (a thread shouldn't cascade in every time it opens).
  Set<String>? _initialIds;

  /// Which side of the request this user is on — set on every build from
  /// the live request doc; decides which read marker is "mine".
  bool _amRequester = false;

  /// Id of the newest peer message already marked read, so the read
  /// marker is written once per new message, not on every rebuild.
  String? _markedReadUpTo;

  String get _myUid => Backend.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    ChatService.instance.activeRequestId = widget.requestId;
  }

  @override
  void dispose() {
    if (ChatService.instance.activeRequestId == widget.requestId) ChatService.instance.activeRequestId = null;
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (preset == null) _controller.clear();
      HapticFeedback.selectionClick();
      await ChatService.instance.sendText(widget.requestId, text, amRequester: _amRequester);
    } catch (_) {
      if (!mounted) return;
      // Put the text back so nothing typed is lost.
      if (preset == null && _controller.text.isEmpty) _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message not sent — this chat may have closed. Try again.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _callInApp(_Peer peer) async {
    final me = (await Backend.instance.myDonorDoc()).data();
    if (!mounted) return;
    await startCallFlow(
      context,
      requestId: widget.requestId,
      peerUid: peer.uid,
      peerName: peer.name,
      myName: me?['name'] as String? ?? 'Rakta Bandhan user',
      peerPhone: peer.phone,
    );
  }

  Future<void> _shareLocation(Map<String, dynamic> request) async {
    final hospitalLat = (request['lat'] as num?)?.toDouble();
    final hospitalLng = (request['lng'] as num?)?.toDouble();
    final hospitalLabel = (request['location_label'] as String? ?? '').trim();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hospitalLat != null && hospitalLng != null)
                _sheetRow(sheet, 'hospital', LucideIcons.building2, 'Send the hospital location',
                    hospitalLabel.isEmpty ? 'Where the blood is needed' : hospitalLabel),
              _sheetRow(sheet, 'me', LucideIcons.locateFixed, 'Send my current location', 'Only to this person, just this once'),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'hospital') {
        await ChatService.instance.sendLocation(widget.requestId, lat: hospitalLat!, lng: hospitalLng!, label: hospitalLabel, amRequester: _amRequester);
      } else {
        final pos = await Backend.instance.preciseLocation();
        if (pos == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Couldn’t get your GPS location. Turn on location and try again.')));
          return;
        }
        final label = await Backend.instance.reverseGeocode(pos.latitude, pos.longitude) ?? 'My current location';
        await ChatService.instance.sendLocation(widget.requestId, lat: pos.latitude, lng: pos.longitude, label: label, amRequester: _amRequester);
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not share the location. Please try again.')));
    }
  }

  Widget _sheetRow(BuildContext sheet, String value, IconData icon, String title, String subtitle) => ListTile(
        onTap: () => Navigator.pop(sheet, value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 20, color: AppColors.brandRed),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
      );

  /// Tapping the header: everything about this person and this request in
  /// one place — the "ease of access" hub for the conversation.
  void _contactSheet(Map<String, dynamic> request, _Peer peer, bool open) {
    final bloodGroup = request['blood_group'] as String? ?? '';
    final units = request['units_needed'] ?? 1;
    final location = (request['location_label'] as String? ?? '').trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IdentityDisc(initials: peer.initials, size: 72, bloodGroup: _amRequester ? bloodGroup : null),
              const SizedBox(height: 12),
              Text(peer.name, textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                _amRequester ? 'Donor for your $bloodGroup request' : 'Needs $bloodGroup · $units unit${units == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 13, color: AppColors.ink2),
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(location, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.mutedInk)),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (open && peer.uid.isNotEmpty)
                    _SheetAction(icon: LucideIcons.phone, label: 'Voice call', onTap: () {
                      Navigator.pop(sheet);
                      _callInApp(peer);
                    }),
                  if (peer.phone.isNotEmpty)
                    _SheetAction(icon: LucideIcons.smartphone, label: 'Their phone', onTap: () {
                      Navigator.pop(sheet);
                      _callPhone(peer.phone);
                    }),
                  if (location.isNotEmpty && request['lat'] != null)
                    _SheetAction(icon: LucideIcons.mapPin, label: 'Directions', onTap: () {
                      Navigator.pop(sheet);
                      openInMaps((request['lat'] as num).toDouble(), (request['lng'] as num).toDouble(), location);
                    }),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.warmDivider, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.flag, size: 18, color: AppColors.ink2),
                title: const Text('Report', style: TextStyle(fontSize: 14.5, color: AppColors.ink)),
                onTap: () {
                  Navigator.pop(sheet);
                  _report(peer);
                },
              ),
              if (open)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.xCircle, size: 18, color: AppColors.red700),
                  title: const Text('Block and close chat', style: TextStyle(fontSize: 14.5, color: AppColors.red700)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _block(peer);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the dialer. Their number is $phone.')));
    }
  }

  Future<void> _report(_Peer peer) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Report ${peer.firstName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('Our admin team reviews every report. They won’t be told who reported them.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.4)),
              const SizedBox(height: 10),
              for (final r in chatReportReasons)
                InkWell(
                  onTap: () => Navigator.pop(sheet, r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.warmDivider))),
                    child: Row(children: [
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 14.5, color: AppColors.ink))),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await ChatService.instance.report(requestId: widget.requestId, reportedUid: peer.uid, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent. You can also block to end this chat.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send the report. Please try again.')));
    }
  }

  Future<void> _block(_Peer peer) async {
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Block ${peer.firstName} and close this chat?',
      message: 'Neither of you will be able to message or call inside the app about this request again. This can’t be undone.',
      confirmLabel: 'Block and close',
      cancelLabel: 'Not now',
    );
    if (!confirmed || !mounted) return;
    try {
      await ChatService.instance.closeChat(widget.requestId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not close this chat. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('requests').doc(widget.requestId).snapshots(),
          builder: (context, reqSnap) {
            final request = reqSnap.data?.data();
            if (request == null) {
              return Column(children: [
                _BackOnlyHeader(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: Center(
                    child: reqSnap.hasData
                        ? const Text('This conversation is no longer available.', style: TextStyle(color: AppColors.ink2))
                        : const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ]);
            }
            final amRequester = request['requester_uid'] == _myUid;
            _amRequester = amRequester;
            final peer = _Peer(
              uid: (amRequester ? request['matched_donor_id'] : request['requester_uid']) as String? ?? '',
              name: (amRequester ? request['matched_donor_name'] : request['requester_name']) as String? ?? 'Donor',
              phone: (amRequester ? request['matched_donor_phone'] : request['requester_phone']) as String? ?? '',
            );
            final closure = _closure(request);

            return Column(
              children: [
                _header(request, peer, closure == null),
                Container(height: 1, color: AppColors.warmDivider),
                _OnCallBar(requestId: widget.requestId),
                Expanded(child: _thread(request, peer, amRequester)),
                if (closure == null) ...[
                  if (_controller.text.trim().isEmpty) _quickReplies(amRequester),
                  _composer(request),
                ] else
                  _closedFooter(closure),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Why the conversation is read-only, or null if it's open.
  String? _closure(Map<String, dynamic> request) {
    final closedBy = request['chat_closed_by'] as String?;
    if (closedBy != null) return closedBy == _myUid ? 'You closed this chat.' : 'This chat was closed by the other person.';
    return switch (request['status']) {
      'matched' => null,
      'fulfilled' => 'Donation completed — this chat is now a record.',
      'cancelled' => 'The request was cancelled, so this chat is closed.',
      'expired' => 'The request expired, so this chat is closed.',
      _ => 'This chat is closed.',
    };
  }

  Widget _header(Map<String, dynamic> request, _Peer peer, bool open) {
    final bloodGroup = request['blood_group'] as String? ?? '';
    final units = request['units_needed'] ?? 1;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.ink),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _contactSheet(request, peer, open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    IdentityDisc(initials: peer.initials, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.15)),
                          const SizedBox(height: 1),
                          Text(
                            '$bloodGroup · $units unit${units == 1 ? '' : 's'}${open ? ' · tap for details' : ' · closed'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open && peer.uid.isNotEmpty)
            IconButton(
              tooltip: 'Voice call',
              icon: const Icon(LucideIcons.phone, size: 20, color: AppColors.brandRed),
              onPressed: () => _callInApp(peer),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(LucideIcons.ellipsis, size: 20, color: AppColors.ink),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.warmBorder)),
            onSelected: (v) => switch (v) {
              'phone' => _callPhone(peer.phone),
              'report' => _report(peer),
              'block' => _block(peer),
              _ => null,
            },
            itemBuilder: (_) => [
              if (peer.phone.isNotEmpty) _menuItem('phone', LucideIcons.phone, 'Call their phone number'),
              _menuItem('report', LucideIcons.flag, 'Report'),
              if (open) _menuItem('block', LucideIcons.xCircle, 'Block and close chat', danger: true),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {bool danger = false}) {
    final color = danger ? AppColors.red700 : AppColors.ink;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ]),
    );
  }

  Widget _thread(Map<String, dynamic> request, _Peer peer, bool amRequester) {
    return StreamBuilder<List<ChatMessage>>(
      stream: ChatService.instance.watchMessages(widget.requestId),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final messages = snap.data!;
        _initialIds ??= messages.map((m) => m.id).toSet();

        // Mark read once per newest peer message (never on every rebuild).
        ChatMessage? newestFromPeer;
        for (final m in messages.reversed) {
          if (m.senderUid != _myUid && m.sentAt != null) {
            newestFromPeer = m;
            break;
          }
        }
        final myReadAt = (request[amRequester ? 'requester_read_at' : 'donor_read_at'] as Timestamp?)?.toDate();
        if (newestFromPeer != null &&
            newestFromPeer.id != _markedReadUpTo &&
            (myReadAt == null || newestFromPeer.sentAt!.isAfter(myReadAt))) {
          _markedReadUpTo = newestFromPeer.id;
          ChatService.instance.markRead(widget.requestId, amRequester: amRequester).catchError((_) {});
        }

        // "Seen" sits under my newest message once the other person's read
        // marker has passed it — like any messenger, only on the latest.
        final peerReadAt = (request[amRequester ? 'donor_read_at' : 'requester_read_at'] as Timestamp?)?.toDate();
        ChatMessage? myNewest;
        for (final m in messages.reversed) {
          if (m.senderUid == _myUid && m.kind != ChatMessageKind.call) {
            myNewest = m;
            break;
          }
        }
        final seenId = (myNewest != null && myNewest.sentAt != null && peerReadAt != null && !peerReadAt.isBefore(myNewest.sentAt!) && identical(myNewest, messages.last))
            ? myNewest.id
            : null;

        // Reversed list: index 0 sits at the bottom, so the thread stays
        // pinned to the newest message as the keyboard opens and new
        // messages arrive — no manual scroll-to-bottom bookkeeping.
        final items = <Widget>[];
        for (var i = messages.length - 1; i >= 0; i--) {
          final m = messages[i];
          final prev = i > 0 ? messages[i - 1] : null;
          final next = i < messages.length - 1 ? messages[i + 1] : null;
          final isNew = !_initialIds!.contains(m.id);
          items.add(_Arrive(animate: isNew, child: _messageRow(m, prev: prev, next: next, seen: m.id == seenId)));
          if (prev == null || !_sameDay(prev.sentAt, m.sentAt)) {
            items.add(_DaySeparator(date: m.sentAt ?? DateTime.now()));
          }
        }
        items.add(_ContextCard(request: request, peerFirstName: peer.firstName, amRequester: amRequester));

        return ListView(
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          children: items,
        );
      },
    );
  }

  Widget _messageRow(ChatMessage m, {ChatMessage? prev, ChatMessage? next, required bool seen}) {
    if (m.kind == ChatMessageKind.call) return _CallLogRow(message: m, mine: m.senderUid == _myUid);
    if (m.kind == ChatMessageKind.location) return _LocationBubble(message: m, mine: m.senderUid == _myUid, seen: seen);
    if (m.kind == ChatMessageKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(m.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
      );
    }
    final mine = m.senderUid == _myUid;
    // Consecutive messages from one sender within 3 minutes read as one
    // group: tight spacing, one timestamp, the "tail" corner only on the last.
    final joinsPrev = prev != null && prev.kind == ChatMessageKind.text && prev.senderUid == m.senderUid && _within(prev.sentAt, m.sentAt);
    final joinsNext = next != null && next.kind == ChatMessageKind.text && next.senderUid == m.senderUid && _within(m.sentAt, next.sentAt);
    return _Bubble(message: m, mine: mine, tight: joinsPrev, isLastInGroup: !joinsNext, seen: seen);
  }

  Widget _quickReplies(bool amRequester) {
    final replies = amRequester
        ? const ['Please come to the blood bank counter', 'How long will you take?', 'I’ll meet you at the entrance', 'Thank you so much']
        : const ['I’m on my way', 'Which blood bank should I go to?', 'Reached the hospital', 'Running 10 min late'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        itemCount: replies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Pressable(
          onTap: _sending ? null : () => _send(replies[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(999)),
            child: Text(replies[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink)),
          ),
        ),
      ),
    );
  }

  Widget _composer(Map<String, dynamic> request) {
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
      decoration: const BoxDecoration(color: AppColors.warmPageBackground),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Share a location',
            onPressed: () => _shareLocation(request),
            icon: const Icon(LucideIcons.mapPin, size: 21, color: AppColors.ink2),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(22)),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.35),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: canSend ? _send : null,
            semanticLabel: 'Send',
            pressedScale: 0.92,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: canSend ? AppColors.brandRed : AppColors.sand, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(LucideIcons.send, size: 18, color: canSend ? AppColors.whiteTextOnPrimary : AppColors.mutedInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedFooter(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(color: AppColors.sand, border: Border(top: BorderSide(color: AppColors.warmBorder))),
      child: Row(children: [
        const Icon(LucideIcons.lock, size: 15, color: AppColors.ink2),
        const SizedBox(width: 10),
        Expanded(child: Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.4))),
      ]),
    );
  }

  static bool _within(DateTime? a, DateTime? b) => a == null || b == null || b.difference(a).inMinutes.abs() < 3;
  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _Peer {
  final String uid;
  final String name;
  final String phone;
  const _Peer({required this.uid, required this.name, required this.phone});

  String get firstName => name.trim().isEmpty ? 'them' : name.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return initialsOf(t);
  }
}

class _BackOnlyHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _BackOnlyHeader({required this.onBack});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(icon: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.ink), onPressed: onBack),
        ),
      );
}

/// The first thing in every thread: what these two people are meeting
/// about, and the one safety rule that matters here.
class _ContextCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String peerFirstName;
  final bool amRequester;

  const _ContextCard({required this.request, required this.peerFirstName, required this.amRequester});

  @override
  Widget build(BuildContext context) {
    final location = (request['location_label'] as String?)?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Column(
        children: [
          Text(
            amRequester ? '$peerFirstName accepted your request' : 'You accepted $peerFirstName’s request',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 16, color: AppColors.ink),
          ),
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(location, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: AppColors.goldTint, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: EdgeInsets.only(top: 1), child: Icon(LucideIcons.shieldCheck, size: 15, color: AppColors.goldDeep)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Blood is never bought or sold. If anyone asks for or offers money, report them from the menu above.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  const _DaySeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const Expanded(child: Divider(color: AppColors.warmDivider, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.mutedInk)),
          ),
          const Expanded(child: Divider(color: AppColors.warmDivider, height: 1)),
        ]),
      );
}

String _clock(DateTime? t) {
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool tight;
  final bool isLastInGroup;
  final bool seen;

  const _Bubble({required this.message, required this.mine, required this.tight, required this.isLastInGroup, this.seen = false});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(milliseconds: 1200)));
  }

  @override
  Widget build(BuildContext context) {
    const big = Radius.circular(18);
    const tail = Radius.circular(6);
    // The sender-side corners pinch where bubbles in one group touch, and
    // the bottom one always pinches — that small corner is the "tail".
    final radius = mine
        ? BorderRadius.only(topLeft: big, topRight: tight ? tail : big, bottomLeft: big, bottomRight: tail)
        : BorderRadius.only(topLeft: tight ? tail : big, topRight: big, bottomLeft: tail, bottomRight: big);
    final pending = message.sentAt == null;

    return Padding(
      padding: EdgeInsets.only(top: tight ? 2 : 10),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(MediaQuery.sizeOf(context).width, 430.0) * 0.76),
            child: GestureDetector(
              onLongPress: () => _copy(context),
              child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
              decoration: BoxDecoration(
                color: mine ? AppColors.brandRed : Colors.white,
                border: mine ? null : Border.all(color: AppColors.warmBorder),
                borderRadius: radius,
              ),
              child: Text(
                message.text,
                style: TextStyle(fontSize: 15, height: 1.38, color: mine ? AppColors.whiteTextOnPrimary : AppColors.ink),
              ),
            ),
            ),
          ),
          if (isLastInGroup || seen)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending) ...[
                    const Icon(LucideIcons.clock, size: 11, color: AppColors.mutedInk),
                    const SizedBox(width: 4),
                    const Text('Sending', style: TextStyle(fontSize: 11, color: AppColors.mutedInk)),
                  ] else ...[
                    Text(_clock(message.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.mutedInk, fontFeatures: [FontFeature.tabularFigures()])),
                    if (seen) const Text(' · Seen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.ink2)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CallLogRow extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _CallLogRow({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final seconds = message.callSeconds;
    final answered = seconds != null;
    final duration = answered ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}' : null;
    final label = answered ? 'Voice call · $duration' : (mine ? message.text : 'Missed voice call');
    final color = answered ? AppColors.ink2 : AppColors.red700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(answered ? LucideIcons.phone : LucideIcons.phoneMissed, size: 13, color: color),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 6),
            Text(_clock(message.sentAt), style: const TextStyle(fontSize: 11.5, color: AppColors.mutedInk)),
          ]),
        ),
      ),
    );
  }
}

/// New-message entry: 8px rise + fade, 220ms ease-out. Only for messages
/// that arrive while the screen is open — never on the initial load.
class _Arrive extends StatelessWidget {
  final bool animate;
  final Widget child;
  const _Arrive({required this.animate, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!animate || reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c)),
      child: child,
    );
  }
}

/// Opens a pin in the phone's maps app (Google Maps on Android and web,
/// Apple or Google Maps on iOS — the universal URL hands off either way).
Future<void> openInMaps(double lat, double lng, String label) async {
  final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'});
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// A shared place: the label, and one tap to open directions. Deliberately
/// not an embedded map tile — it would be another third-party request per
/// message and adds nothing the maps app doesn't do better.
class _LocationBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool seen;

  const _LocationBubble({required this.message, required this.mine, required this.seen});

  @override
  Widget build(BuildContext context) {
    final fg = mine ? AppColors.whiteTextOnPrimary : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(MediaQuery.sizeOf(context).width, 430.0) * 0.76),
            child: Pressable(
              onTap: message.lat == null ? null : () => openInMaps(message.lat!, message.lng!, message.text),
              semanticLabel: 'Open location in maps',
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                decoration: BoxDecoration(
                  color: mine ? AppColors.brandRed : Colors.white,
                  border: mine ? null : Border.all(color: AppColors.warmBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: mine ? Colors.white.withValues(alpha: 0.16) : AppColors.red100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.mapPin, size: 18, color: mine ? AppColors.whiteTextOnPrimary : AppColors.brandRed),
                    ),
                    const SizedBox(width: 11),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, color: fg)),
                          const SizedBox(height: 2),
                          Text('Open in maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mine ? AppColors.onEmberMuted : AppColors.brandRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              message.sentAt == null ? 'Sending' : '${_clock(message.sentAt)}${seen ? ' · Seen' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.red100, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.brandRed),
              ),
              const SizedBox(height: 7),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
            ],
          ),
        ),
      );
}

/// "On a call with Rohan · 02:14 — Return" strip, shown when the user
/// jumps from a live call into the chat (the Message button on the call
/// screen). Tapping it goes back to the call.
class _OnCallBar extends StatefulWidget {
  final String requestId;
  const _OnCallBar({required this.requestId});

  @override
  State<_OnCallBar> createState() => _OnCallBarState();
}

class _OnCallBarState extends State<_OnCallBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && CallService.instance.active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = CallService.instance.active;
    final show = call != null && call.requestId == widget.requestId && call.phase != CallPhase.ended;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Material(
              color: AppColors.successText,
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.phone, size: 14, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          call.phase == CallPhase.active
                              ? 'On a call with ${call.peerName} · ${_mmss(call.talkSeconds ?? 0)}'
                              : 'Calling ${call.peerName}…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                      const Text('Return', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
