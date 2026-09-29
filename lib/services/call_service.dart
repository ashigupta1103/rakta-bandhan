import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'chat_service.dart';

/// ICE servers for in-app calls. Google's public STUN servers are enough
/// when both phones can reach each other directly; roughly 10–20% of
/// mobile-carrier NAT pairs (common with Indian CGNAT) also need a TURN
/// relay, which is a paid service (Twilio, Metered, Cloudflare Calls…).
/// Add it here before launch — nothing else changes.
const callIceServers = <Map<String, dynamic>>[
  {
    'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
  },
  // {'urls': 'turn:turn.example.com:3478', 'username': '…', 'credential': '…'},
];

/// How long an unanswered call rings before it's logged as missed.
const callRingTimeout = Duration(seconds: 45);

enum CallPhase { connecting, ringing, active, ended }

/// Thrown by [CallService.startCall]/[CallService.answer] when the
/// microphone can't be opened (permission denied or no device).
class CallMicrophoneException implements Exception {
  const CallMicrophoneException();
  @override
  String toString() => 'Microphone access is needed for voice calls. Allow it in your device settings.';
}

@immutable
class IncomingCall {
  final String requestId;
  final String callId;
  final String callerUid;
  final String callerName;

  const IncomingCall({required this.requestId, required this.callId, required this.callerUid, required this.callerName});
}

/// One live call. Screens listen to this; [CallService] drives it.
class ActiveCall extends ChangeNotifier {
  final String requestId;
  final String callId;
  final String peerUid;
  final String peerName;
  final bool isCaller;

  ActiveCall._({required this.requestId, required this.callId, required this.peerUid, required this.peerName, required this.isCaller});

  CallPhase _phase = CallPhase.connecting;
  CallPhase get phase => _phase;

  bool _muted = false;
  bool get muted => _muted;

  bool _speakerOn = false;
  bool get speakerOn => _speakerOn;

  DateTime? _connectedAt;
  DateTime? get connectedAt => _connectedAt;

  /// Human-readable reason once [phase] is [CallPhase.ended].
  String? _endReason;
  String? get endReason => _endReason;

  /// Plays the remote audio on web (mobile routes it to the earpiece on its
  /// own); the call screen mounts an invisible view for it.
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _ringTimer;

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('requests')
      .doc(requestId)
      .collection('calls')
      .doc(callId);

  void _setPhase(CallPhase phase) {
    if (_phase == CallPhase.ended) return;
    _phase = phase;
    if (phase == CallPhase.active) _connectedAt ??= DateTime.now();
    notifyListeners();
  }

  int? get talkSeconds => _connectedAt == null ? null : DateTime.now().difference(_connectedAt!).inSeconds;

  Future<void> toggleMute() async {
    _muted = !_muted;
    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(_speakerOn);
      } catch (_) {
        // Desktop has no earpiece/speaker distinction — the flag is cosmetic there.
      }
    }
    notifyListeners();
  }

  /// Local hang-up / cancel. Idempotent.
  Future<void> hangUp() async {
    if (_phase == CallPhase.ended) return;
    final wasAnswered = _connectedAt != null;
    try {
      await _ref.update({
        'status': (!wasAnswered && isCaller) ? 'missed' : 'ended',
        'ended_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Offline or already terminal — the local teardown still happens.
    }
    await _finish(wasAnswered ? 'Call ended' : (isCaller ? 'Call cancelled' : 'Call ended'));
  }

  Future<void> _finish(String reason) async {
    if (_phase == CallPhase.ended) return;
    final seconds = talkSeconds;
    _endReason = reason;
    _phase = CallPhase.ended;
    notifyListeners();

    // Exactly one call-log row per call: the caller writes it.
    if (isCaller) {
      final outcome = seconds != null ? 'Voice call' : (reason == 'Declined' ? 'Call declined' : 'Missed voice call');
      ChatService.instance.logCall(requestId, seconds: seconds, outcome: outcome).catchError((_) {});
    }
    await _dispose();
    CallService.instance._clearActive(this);
  }

  Future<void> _dispose() async {
    _ringTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    for (final track in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    _pc = null;
    try {
      remoteRenderer.srcObject = null;
      await remoteRenderer.dispose();
    } catch (_) {}
  }

  Future<void> _openPeer({required String localCandidates, required String remoteCandidates}) async {
    await remoteRenderer.initialize();
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    } catch (_) {
      throw const CallMicrophoneException();
    }

    final pc = await createPeerConnection({'iceServers': callIceServers, 'sdpSemantics': 'unified-plan'});
    _pc = pc;
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) remoteRenderer.srcObject = event.streams.first;
    };
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _ref.collection(localCandidates).add(candidate.toMap()).catchError((_) => _ref);
    };
    // Some platforms (notably web/Safari) only report ICE state reliably.
    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _ringTimer?.cancel();
        _setPhase(CallPhase.active);
      }
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _ringTimer?.cancel();
        _setPhase(CallPhase.active);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _ref.update({'status': 'ended', 'ended_at': FieldValue.serverTimestamp()}).catchError((_) {});
        _finish('Connection lost');
      }
    };
    _subs.add(_ref.collection(remoteCandidates).snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final c = change.doc.data();
        if (c == null) continue;
        _pc?.addCandidate(RTCIceCandidate(c['candidate'] as String?, c['sdpMid'] as String?, c['sdpMLineIndex'] as int?));
      }
    }));
  }

  /// Watches the call doc for the other side's moves.
  void _watchDoc() {
    _subs.add(_ref.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String?;
      if (isCaller && data['answer'] != null && _pc != null) {
        final remote = await _pc!.getRemoteDescription();
        if (remote == null) {
          final a = data['answer'] as Map<String, dynamic>;
          await _pc!.setRemoteDescription(RTCSessionDescription(a['sdp'] as String?, a['type'] as String?));
        }
      }
      switch (status) {
        case 'accepted':
          if (_phase == CallPhase.ringing) _setPhase(CallPhase.connecting);
        case 'declined':
          _finish('Declined');
        case 'missed':
          _finish(isCaller ? 'No answer' : 'Missed call');
        case 'ended':
          _finish('Call ended');
      }
    }));
  }
}

/// In-app voice calls (Instagram-style — no phone numbers involved). Audio
/// is peer-to-peer WebRTC; Firestore only carries the handshake under
/// `requests/{id}/calls/{callId}`, readable/writable by the two people on
/// that matched request (see firestore.rules). Nothing is recorded.
///
/// Spark plan: an incoming call only rings while the callee has the app
/// open ([incomingCalls] is a live listener). On Blaze, a function on call
/// creation sends an FCM/VoIP push that reports a CallKit /
/// ConnectionService call — this class stays the same.
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  ActiveCall? _active;
  ActiveCall? get active => _active;

  void _clearActive(ActiveCall call) {
    if (identical(_active, call)) _active = null;
  }

  /// Calls ringing for the signed-in user right now, across all their
  /// matched requests. Stale "ringing" docs (caller vanished) are ignored.
  Stream<List<IncomingCall>> incomingCalls() => _db
      .collectionGroup('calls')
      .where('callee_uid', isEqualTo: _uid)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .map((snap) => snap.docs
          .where((d) {
            final created = (d.data()['created_at'] as Timestamp?)?.toDate();
            return created == null || DateTime.now().difference(created) < callRingTimeout + const Duration(seconds: 10);
          })
          .map((d) => IncomingCall(
                requestId: d.reference.parent.parent!.id,
                callId: d.id,
                callerUid: d.data()['caller_uid'] as String? ?? '',
                callerName: d.data()['caller_name'] as String? ?? 'Someone',
              ))
          .toList());

  Future<ActiveCall> startCall({
    required String requestId,
    required String peerUid,
    required String peerName,
    required String myName,
  }) async {
    if (_active != null) return _active!;
    final ref = _db.collection('requests').doc(requestId).collection('calls').doc();
    final call = ActiveCall._(requestId: requestId, callId: ref.id, peerUid: peerUid, peerName: peerName, isCaller: true);
    _active = call;
    try {
      await call._openPeer(localCandidates: 'caller_candidates', remoteCandidates: 'callee_candidates');
      final offer = await call._pc!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await call._pc!.setLocalDescription(offer);
      await ref.set({
        'caller_uid': _uid,
        'callee_uid': peerUid,
        'caller_name': myName,
        'status': 'ringing',
        'offer': offer.toMap(),
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await call._dispose();
      _active = null;
      rethrow;
    }
    call._setPhase(CallPhase.ringing);
    call._watchDoc();
    call._ringTimer = Timer(callRingTimeout, () {
      if (call.phase == CallPhase.ringing) call.hangUp();
    });
    return call;
  }

  Future<ActiveCall> answer(IncomingCall incoming) async {
    if (_active != null) return _active!;
    final call = ActiveCall._(
      requestId: incoming.requestId,
      callId: incoming.callId,
      peerUid: incoming.callerUid,
      peerName: incoming.callerName,
      isCaller: false,
    );
    _active = call;
    try {
      final snap = await call._ref.get();
      final offer = snap.data()?['offer'] as Map<String, dynamic>?;
      if (offer == null || snap.data()?['status'] != 'ringing') {
        throw StateError('This call has already ended.');
      }
      await call._openPeer(localCandidates: 'callee_candidates', remoteCandidates: 'caller_candidates');
      await call._pc!.setRemoteDescription(RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?));
      final answer = await call._pc!.createAnswer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await call._pc!.setLocalDescription(answer);
      await call._ref.update({
        'answer': answer.toMap(),
        'status': 'accepted',
        'answered_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await call._dispose();
      _active = null;
      rethrow;
    }
    call._setPhase(CallPhase.connecting);
    call._watchDoc();
    return call;
  }

  Future<void> decline(IncomingCall incoming) => _db
      .collection('requests')
      .doc(incoming.requestId)
      .collection('calls')
      .doc(incoming.callId)
      .update({'status': 'declined', 'ended_at': FieldValue.serverTimestamp()})
      .catchError((_) {});
}
