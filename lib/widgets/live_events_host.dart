import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/match_contact_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/urgent_alert_screen.dart';
import '../services/backend.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/push_service.dart';
import '../services/urgent_alert_service.dart';
import 'message_banner.dart';

/// Mounted once inside the signed-in tab shell. Listens for what must reach
/// the user whatever screen is up:
/// - an incoming in-app call → full-screen ringing route;
/// - an opted-in urgent request → full-screen alert route;
/// - a new chat message → a top banner (unless that chat is already open);
/// - a push that arrives while the app is open → a top banner;
/// - a tapped notification, or a call answered from the native incoming-
///   call screen → the right screen.
/// Calls always win: an urgent alert never covers a call, and is skipped
/// while one is ringing or live; banners are suppressed during calls too.
/// While the app is in the background the in-app ring stays silent — the
/// native call screen (PushService) rings instead, so it never rings twice.
class LiveEventsHost extends StatefulWidget {
  final Widget child;
  const LiveEventsHost({super.key, required this.child});

  @override
  State<LiveEventsHost> createState() => _LiveEventsHostState();
}

class _LiveEventsHostState extends State<LiveEventsHost> with WidgetsBindingObserver {
  StreamSubscription<List<IncomingCall>>? _callSub;
  StreamSubscription<UrgentAlert>? _alertSub;
  StreamSubscription<List<Conversation>>? _chatSub;
  StreamSubscription<PushTarget>? _tapSub;
  StreamSubscription<ForegroundNotice>? _noticeSub;
  StreamSubscription<IncomingCall>? _acceptSub;

  /// Last activity already accounted for, per conversation. The first
  /// snapshot only records the baseline — nothing old is announced.
  final _lastSeenActivity = <String, DateTime>{};
  bool _chatBaselineTaken = false;
  final _shownCallIds = <String>{};
  List<IncomingCall> _latestCalls = const [];
  bool _showingCall = false;
  bool _showingAlert = false;
  bool _inForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSub = CallService.instance.incomingCalls().listen(_onCalls, onError: (_) {});
    _alertSub = UrgentAlertService.instance.watch().listen(_onAlert, onError: (_) {});
    _chatSub = ChatService.instance.watchConversations().listen(_onConversations, onError: (_) {});
    _tapSub = PushService.instance.taps.listen(_openTarget);
    _noticeSub = PushService.instance.foregroundNotices.listen(_onNotice);
    _acceptSub = PushService.instance.acceptedCalls.listen(_answerFromNative);
    // Whatever launched the app — a notification tap, or Accept on the
    // native call screen — is handled once the shell is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accepted = PushService.instance.takePendingAccept();
      if (accepted != null) {
        _answerFromNative(accepted);
        return;
      }
      final tap = PushService.instance.takePendingTap();
      if (tap != null) _openTarget(tap);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (_inForeground) _onCalls(_latestCalls);
  }

  void _onConversations(List<Conversation> list) {
    final myUid = Backend.instance.currentUser?.uid;
    for (final c in list) {
      final at = c.lastAt;
      if (at == null) continue;
      final before = _lastSeenActivity[c.requestId];
      _lastSeenActivity[c.requestId] = at;
      if (!_chatBaselineTaken || (before != null && !at.isAfter(before))) continue;
      final fromPeer = c.lastSenderUid != null && c.lastSenderUid != myUid;
      final alreadyLooking = ChatService.instance.activeRequestId == c.requestId;
      if (!fromPeer || alreadyLooking || _showingCall || CallService.instance.active != null || !mounted) continue;
      MessageBanner.show(
        context,
        name: c.peerName,
        text: c.lastText ?? 'New message',
        onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(requestId: c.requestId))),
      );
    }
    _chatBaselineTaken = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSub?.cancel();
    _alertSub?.cancel();
    _chatSub?.cancel();
    _tapSub?.cancel();
    _noticeSub?.cancel();
    _acceptSub?.cancel();
    super.dispose();
  }

  Future<void> _onCalls(List<IncomingCall> calls) async {
    _latestCalls = calls;
    if (!_inForeground || _showingCall || CallService.instance.active != null) return;
    final fresh = calls.where((c) => !_shownCallIds.contains(c.callId)).toList();
    if (fresh.isEmpty || !mounted) return;
    final next = fresh.first;
    _shownCallIds.add(next.callId);
    _showingCall = true;
    // The native screen may also be up if the push beat the listener.
    await PushService.endNativeCall(next.callId);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingCallScreen(incoming: next)));
    _showingCall = false;
  }

  /// Accept tapped on the native incoming-call screen.
  Future<void> _answerFromNative(IncomingCall incoming) async {
    _shownCallIds.add(incoming.callId);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final call = await CallService.instance.answer(incoming);
      _showingCall = true;
      await navigator.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CallScreen(call: call)));
    } on CallMicrophoneException catch (e) {
      await CallService.instance.decline(incoming);
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (_) {
      await PushService.endNativeCall(incoming.callId);
      messenger.showSnackBar(const SnackBar(content: Text('That call has already ended.')));
    } finally {
      _showingCall = false;
    }
  }

  Future<void> _onAlert(UrgentAlert alert) async {
    if (_showingAlert || _showingCall || CallService.instance.active != null || !mounted) return;
    _showingAlert = true;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => UrgentAlertScreen(alert: alert)));
    _showingAlert = false;
  }

  void _onNotice(ForegroundNotice notice) {
    if (!mounted || _showingCall || CallService.instance.active != null) return;
    // Urgent requests already ring in-app through UrgentAlertService.
    if (notice.target.type == PushType.urgentRequest) return;
    MessageBanner.show(
      context,
      name: notice.title,
      text: notice.body,
      onOpen: () => _openTarget(notice.target),
    );
  }

  /// Opens the screen a notification is about.
  Future<void> _openTarget(PushTarget target) async {
    final requestId = target.requestId;
    if (!mounted || requestId == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (target.type == PushType.chat || target.type == PushType.call) {
      navigator.push(MaterialPageRoute(builder: (_) => ChatScreen(requestId: requestId)));
      return;
    }
    try {
      final data = (await FirebaseFirestore.instance.collection('requests').doc(requestId).get()).data();
      final myUid = Backend.instance.currentUser?.uid;
      if (data == null) throw StateError('gone');
      final Widget screen;
      if (data['requester_uid'] == myUid) {
        screen = TrackingScreen(requestId: requestId);
      } else if (data['matched_donor_id'] == myUid) {
        screen = MatchContactScreen(requestId: requestId);
      } else if (data['status'] == 'open') {
        screen = RequestDetailScreen(requestId: requestId);
      } else {
        throw StateError('taken');
      }
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('This request is no longer open. Thank you for checking.')));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
