import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/urgent_alert_screen.dart';
import '../services/backend.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/urgent_alert_service.dart';
import 'message_banner.dart';

/// Mounted once inside the signed-in tab shell. Listens for what must reach
/// the user whatever screen is up:
/// - an incoming in-app call → full-screen ringing route;
/// - an opted-in urgent request → full-screen alert route;
/// - a new chat message → a top banner (unless that chat is already open).
/// Calls always win: an urgent alert never covers a call, and is skipped
/// while one is ringing or live; banners are suppressed during calls too.
/// Everything is pushed on the root navigator.
class LiveEventsHost extends StatefulWidget {
  final Widget child;
  const LiveEventsHost({super.key, required this.child});

  @override
  State<LiveEventsHost> createState() => _LiveEventsHostState();
}

class _LiveEventsHostState extends State<LiveEventsHost> {
  StreamSubscription<List<IncomingCall>>? _callSub;
  StreamSubscription<UrgentAlert>? _alertSub;
  StreamSubscription<List<Conversation>>? _chatSub;

  /// Last activity already accounted for, per conversation. The first
  /// snapshot only records the baseline — nothing old is announced.
  final _lastSeenActivity = <String, DateTime>{};
  bool _chatBaselineTaken = false;
  final _shownCallIds = <String>{};
  bool _showingCall = false;
  bool _showingAlert = false;

  @override
  void initState() {
    super.initState();
    _callSub = CallService.instance.incomingCalls().listen(_onCalls, onError: (_) {});
    _alertSub = UrgentAlertService.instance.watch().listen(_onAlert, onError: (_) {});
    _chatSub = ChatService.instance.watchConversations().listen(_onConversations, onError: (_) {});
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
    _callSub?.cancel();
    _alertSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _onCalls(List<IncomingCall> calls) async {
    if (_showingCall || CallService.instance.active != null) return;
    final fresh = calls.where((c) => !_shownCallIds.contains(c.callId)).toList();
    if (fresh.isEmpty || !mounted) return;
    final next = fresh.first;
    _shownCallIds.add(next.callId);
    _showingCall = true;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => IncomingCallScreen(incoming: next)));
    _showingCall = false;
  }

  Future<void> _onAlert(UrgentAlert alert) async {
    if (_showingAlert || _showingCall || CallService.instance.active != null || !mounted) return;
    _showingAlert = true;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => UrgentAlertScreen(alert: alert)));
    _showingAlert = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
