import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
import '../services/backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/alert_sound.dart';
import '../services/call_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/identity_disc.dart';
import '../widgets/pressable.dart';
import '../widgets/ring_field.dart';
import 'chat_screen.dart';
import '../widgets/rb_icon.dart';

/// Opens the call screen immediately and lets it place the call. Every
/// entry point (chat header, contact sheet, donor-found, match-contact,
/// tracking, inbox) goes through here, so the experience — and every
/// failure state — is identical wherever a call starts.
Future<void> startCallFlow(BuildContext context, {required String requestId, required String peerUid, required String peerName, required String myName}) async {
  final existing = CallService.instance.active;
  if (existing != null) {
    // Already on a call — go back to it instead of starting a second one.
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CallScreen(call: existing)));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CallScreen.outgoing(requestId: requestId, peerUid: peerUid, peerName: peerName, myName: myName),
    ),
  );
}

String _initialsOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return initialsOf(t);
}

String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

/// The call itself — on the ember field, the same family as the matching
/// and matched moments, because this is the same emotional register: a
/// person on the other end who is about to help.
///
/// Centre: who. Under it: one line of state (Starting… / Ringing… / 03:12).
/// Bottom: mute, speaker, message — and a clearly separated end button.
///
/// An outgoing call that isn't answered doesn't just vanish: the screen
/// stays with the next steps (message, or call again). Phone numbers are
/// never shown or dialled from here — everything stays in the app.
class CallScreen extends StatefulWidget {
  final ActiveCall? call;
  final String? requestId;
  final String? peerUid;
  final String? peerName;
  final String myName;

  const CallScreen({super.key, required ActiveCall this.call}) : requestId = null, peerUid = null, peerName = null, myName = '';

  const CallScreen.outgoing({super.key, required String this.requestId, required String this.peerUid, required String this.peerName, required this.myName}) : call = null;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Stage { starting, live, noAnswer, failed }

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  static const _hintAfter = Duration(seconds: 15);

  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  Timer? _clock;
  Timer? _hintTimer;
  bool _showHint = false;
  bool _closing = false;

  ActiveCall? _call;
  _Stage _stage = _Stage.starting;
  String? _failure;
  String? _noAnswerReason;
  CallPhase? _lastPhase;

  String get _requestId => _call?.requestId ?? widget.requestId!;
  String get _peerName => _call?.peerName ?? widget.peerName ?? '';

  late final Future<Map<String, dynamic>?> _request = Demo.isDemoId(_requestId)
      ? Future.value(Demo.instance.request)
      : FirebaseFirestore.instance.collection('requests').doc(_requestId).get().then((s) => s.data());

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _call?.phase == CallPhase.active) setState(() {});
    });
    if (widget.call != null) {
      _attach(widget.call!);
    } else {
      _place();
    }
  }

  Future<void> _place() async {
    setState(() {
      _stage = _Stage.starting;
      _failure = null;
      _showHint = false;
    });
    if (Demo.isDemoId(widget.requestId)) {
      _attach(ActiveCall.simulated(requestId: widget.requestId!, peerName: widget.peerName!, isCaller: true));
      return;
    }
    try {
      final call = await CallService.instance.startCall(requestId: widget.requestId!, peerUid: widget.peerUid!, peerName: widget.peerName!, myName: widget.myName);
      if (!mounted) {
        call.hangUp();
        return;
      }
      _attach(call);
    } on CallMicrophoneException catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _failure = e.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _failure = 'Couldn’t start the call. Check your connection — or send a message, it arrives the moment they open the app.';
        });
      }
    }
  }

  void _attach(ActiveCall call) {
    _call?.removeListener(_onCall);
    _call = call;
    _stage = _Stage.live;
    _lastPhase = null;
    call.addListener(_onCall);
    _hintTimer?.cancel();
    if (call.isCaller) {
      _hintTimer = Timer(_hintAfter, () {
        if (mounted && _call?.phase == CallPhase.ringing) setState(() => _showHint = true);
      });
    }
    // _onCall reads MediaQuery (reduced motion), which isn't allowed
    // during initState — run the first pass after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCall());
  }

  void _onCall() {
    final call = _call;
    if (!mounted || call == null) return;
    final waiting = call.phase == CallPhase.ringing || call.phase == CallPhase.connecting;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (waiting && !reduce && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!waiting && _breath.isAnimating) {
      _breath.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
    if (call.phase == CallPhase.active && _lastPhase != CallPhase.active) {
      HapticFeedback.mediumImpact(); // the moment the other person picks up
      _showHint = false;
    }
    _lastPhase = call.phase;

    if (call.phase == CallPhase.ended && !_closing && _stage == _Stage.live) {
      final unanswered = call.isCaller && call.connectedAt == null && call.endReason != 'Call cancelled';
      if (unanswered) {
        // Stay — the useful moment is what to do next.
        _stage = _Stage.noAnswer;
        _noAnswerReason = call.endReason == 'Declined' ? '$_firstName can’t talk right now' : 'No answer';
        _hintTimer?.cancel();
      } else {
        _closing = true;
        // Hold the end state for a beat so "Call ended · 4:12" is readable.
        Future.delayed(const Duration(milliseconds: 1200), _close);
      }
    }
    setState(() {});
  }

  String get _firstName {
    final t = _peerName.trim();
    return t.isEmpty ? 'They' : t.split(RegExp(r'\s+')).first;
  }

  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    // The chat may have been opened on top mid-call — remove this route
    // wherever it sits rather than popping whatever is on top.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _openChat({bool replace = false}) {
    final route = MaterialPageRoute(builder: (_) => ChatScreen(requestId: _requestId));
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  @override
  void dispose() {
    _call?.removeListener(_onCall);
    _clock?.cancel();
    _hintTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  String get _status {
    final call = _call;
    switch (_stage) {
      case _Stage.starting:
        return 'Starting call…';
      case _Stage.failed:
        return 'Call not started';
      case _Stage.noAnswer:
        return _noAnswerReason ?? 'No answer';
      case _Stage.live:
        break;
    }
    switch (call!.phase) {
      case CallPhase.connecting:
        return call.isCaller ? 'Connecting…' : 'Joining…';
      case CallPhase.ringing:
        return 'Ringing…';
      case CallPhase.active:
        return _mmss(call.talkSeconds ?? 0);
      case CallPhase.ended:
        final s = call.talkSeconds;
        return s == null ? (call.endReason ?? 'Call ended') : '${call.endReason ?? 'Call ended'} · ${_mmss(s)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final live = _stage == _Stage.live && call != null && call.phase != CallPhase.ended;
    return PopScope(
      // Back doesn't silently leave a live call — end it, or use Message.
      canPop: !live,
      child: Scaffold(
        backgroundColor: AppColors.gradientEmberEnd,
        body: _EmberField(
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const _TrustLine(),
                      if (!live)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Close',
                            icon: const RbIcon(RbGlyph.close, color: AppColors.onEmberMuted, size: 20),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                    ],
                  ),
                ),
                // Invisible, but required: on web this element is what
                // actually plays the other person's voice. Unmounted as soon
                // as the call ends — the renderer is disposed right after.
                SizedBox(width: 1, height: 1, child: live && !call.simulated ? RTCVideoView(call.remoteRenderer) : null),
                Expanded(
                  // Scrolls instead of overflowing on short phones or with
                  // large system text.
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Portrait(initials: _initialsOf(_peerName), breath: _breath),
                            const SizedBox(height: 22),
                            Text(
                              _peerName,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.display(fontSize: 30, color: AppColors.onEmberStrong, height: 1.1),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Row(
                                key: ValueKey('$_stage${call?.phase}'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _statusMark(call),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _status,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 15, color: AppColors.onEmberMuted, fontFeatures: [FontFeature.tabularFigures()]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _request,
                              builder: (context, snap) {
                                final r = snap.data;
                                if (r == null) return const SizedBox(height: 28);
                                final place = (r['location_label'] as String? ?? '').split(',').first.trim();
                                return _ContextChip(text: '${r['blood_group'] ?? ''} request${place.isEmpty ? '' : ' · $place'}');
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: _showHint && live ? _ringingHint() : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_stage == _Stage.noAnswer || _stage == _Stage.failed) _afterActions() else _liveControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A small mark that says which state the call is in at a glance:
  /// spinner while connecting, outgoing phone while ringing, a green dot
  /// once live, a missed/alert icon when it didn't connect.
  Widget _statusMark(ActiveCall? call) {
    const size = 15.0;
    switch (_stage) {
      case _Stage.starting:
        return const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.onEmberAccent));
      case _Stage.failed:
        return const RbIcon(RbGlyph.alertCircle, size: size, color: AppColors.onEmberAccent);
      case _Stage.noAnswer:
        return const RbIcon(RbGlyph.phoneMissed, size: size, color: AppColors.onEmberAccent);
      case _Stage.live:
        break;
    }
    return switch (call!.phase) {
      CallPhase.connecting => const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.onEmberAccent)),
      CallPhase.ringing => const RbIcon(RbGlyph.phone, size: size, color: AppColors.onEmberAccent),
      CallPhase.active => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.onEmberSuccess, shape: BoxShape.circle),
      ),
      CallPhase.ended => const RbIcon(RbGlyph.hangUp, size: size, color: AppColors.onEmberFaint),
    };
  }

  Widget _ringingHint() => Padding(
    padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
    child: Column(
      children: [
        Text(
          '$_firstName hasn’t picked up yet. If they don’t answer, you can leave them a message.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.onEmberFaint, height: 1.45),
        ),
      ],
    ),
  );

  Widget _liveControls() {
    final call = _call;
    final enabled = call != null && call.phase != CallPhase.ended;
    final VoidCallback? endAction;
    if (_stage == _Stage.starting) {
      endAction = () => Navigator.of(context).maybePop();
    } else {
      endAction = enabled ? call.hangUp : null;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundControl(
                icon: (call?.muted ?? false) ? RbGlyph.micOff : RbGlyph.mic,
                label: (call?.muted ?? false) ? 'Unmute' : 'Mute',
                active: call?.muted ?? false,
                onTap: enabled ? call.toggleMute : null,
              ),
              _RoundControl(icon: RbGlyph.speaker, label: 'Speaker', active: call?.speakerOn ?? false, onTap: enabled ? call.toggleSpeaker : null),
              _RoundControl(icon: RbGlyph.message, label: 'Message', active: false, onTap: _openChat),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _EndButton(onTap: endAction),
        const SizedBox(height: 28),
      ],
    );
  }

  /// After an unanswered or failed call: the three sensible next steps, in
  /// the order most likely to reach them.
  Widget _afterActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failure != null) ...[
            Text(
              _failure!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.onEmberMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              'Leave a message — it’s waiting for $_firstName the moment they open the app.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.onEmberMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmPageBackground, foregroundColor: AppColors.gradientEmberMid),
            onPressed: () => _openChat(replace: true),
            icon: const RbIcon(RbGlyph.message, size: 16),
            label: Text('Message $_firstName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          if (widget.requestId != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onEmber,
                side: const BorderSide(color: AppColors.onEmberOutline),
              ),
              onPressed: _place,
              icon: const RbIcon(RbGlyph.phone, size: 15),
              label: const Text('Call again in the app'),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Close', style: TextStyle(fontSize: 14, color: AppColors.onEmberFaint)),
          ),
        ],
      ),
    );
  }
}

/// Full-screen incoming call. Rings with [AlertSound.incomingCall] until
/// answered, declined, or the caller gives up (the call doc leaves
/// `ringing`) — then it closes itself.
class IncomingCallScreen extends StatefulWidget {
  final IncomingCall incoming;

  const IncomingCallScreen({super.key, required this.incoming});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _busy = false;

  IncomingCall get incoming => widget.incoming;

  @override
  void initState() {
    super.initState();
    AlertSound.incomingCall.start();
    if (Demo.isDemoId(incoming.requestId)) return;
    _sub = FirebaseFirestore.instance.collection('requests').doc(incoming.requestId).collection('calls').doc(incoming.callId).snapshots().listen((snap) {
      final status = snap.data()?['status'];
      if (status != 'ringing' && !_busy && mounted) {
        AlertSound.incomingCall.stop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Missed call from ${incoming.callerName}')));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce && !_breath.isAnimating) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _breath.dispose();
    AlertSound.incomingCall.stop();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await AlertSound.incomingCall.stop();
    if (Demo.isDemoId(incoming.requestId)) {
      navigator.pushReplacement(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(call: ActiveCall.simulated(requestId: incoming.requestId, peerName: incoming.callerName, isCaller: false)),
      ));
      return;
    }
    try {
      final call = await CallService.instance.answer(incoming);
      navigator.pushReplacement(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CallScreen(call: call)));
    } on CallMicrophoneException catch (e) {
      await CallService.instance.decline(incoming);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('This call has already ended.')));
    }
  }

  Future<void> _decline({bool thenMessage = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await AlertSound.incomingCall.stop();
    if (!Demo.isDemoId(incoming.requestId)) await CallService.instance.decline(incoming);
    if (!mounted) return;
    if (thenMessage) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(requestId: incoming.requestId)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.gradientEmberEnd,
        body: _EmberField(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),
                const _TrustLine(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Portrait(initials: _initialsOf(incoming.callerName), breath: _breath),
                      const SizedBox(height: 22),
                      Text(
                        incoming.callerName,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(fontSize: 30, color: AppColors.onEmberStrong, height: 1.1),
                      ),
                      const SizedBox(height: 8),
                      const Text('Incoming voice call', style: TextStyle(fontSize: 15, color: AppColors.onEmberMuted)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AnswerButton(icon: RbGlyph.hangUp, label: 'Decline', color: AppColors.brandRed, onTap: _busy ? null : () => _decline()),
                      _AnswerButton(icon: RbGlyph.phone, label: 'Accept', color: AppColors.successText, onTap: _busy ? null : _accept),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _busy ? null : () => _decline(thenMessage: true),
                  icon: const RbIcon(RbGlyph.message, size: 15, color: AppColors.onEmberMuted),
                  label: const Text('Can’t talk — send a message', style: TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmberField extends StatelessWidget {
  final Widget child;
  const _EmberField({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(-0.25, -1),
        end: Alignment(0.25, 1),
        colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
        stops: [0, 0.6, 1],
      ),
    ),
    child: child,
  );
}

class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      RbIcon(RbGlyph.lock, size: 12, color: AppColors.onEmber.withValues(alpha: 0.55)),
      const SizedBox(width: 6),
      Text('Rakta Bandhan call · encrypted, never recorded', style: TextStyle(fontSize: 11.5, color: AppColors.onEmber.withValues(alpha: 0.55))),
    ],
  );
}

/// The other person's disc inside the product's ring geometry. While the
/// call is waiting, the rings breathe (a slow 1.00→1.06 scale) — the one
/// motion on screen, saying "still reaching them". Still once connected.
class _Portrait extends StatelessWidget {
  final String initials;
  final AnimationController breath;
  const _Portrait({required this.initials, required this.breath});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: breath,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.06 * Curves.easeInOut.transform(breath.value),
                child: Opacity(opacity: 0.9 - 0.3 * breath.value, child: child),
              ),
              child: const RingField(scale: 1.0, referenceWidth: 240, outerOpacity: 0.14, middleOpacity: 0.22, innerOpacity: 0.32, strokeWidth: 1),
            ),
          ),
          IdentityDisc(initials: initials, size: 104),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String text;
  const _ContextChip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5, color: AppColors.onEmberMuted),
    ),
  );
}

class _RoundControl extends StatelessWidget {
  final RbGlyph icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _RoundControl({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressedScale: 0.94,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: active ? AppColors.onEmber : Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: RbIcon(icon, size: 22, color: active ? AppColors.gradientEmberMid : AppColors.onEmber),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onEmberMuted)),
          ],
        ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _EndButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: 'End call',
    pressedScale: 0.94,
    child: Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: onTap == null ? AppColors.red800 : AppColors.brandRed,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: AppColors.shadowDark, blurRadius: 18, offset: Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: const RbIcon(RbGlyph.hangUp, size: 26, color: Colors.white),
    ),
  );
}

class _AnswerButton extends StatelessWidget {
  final RbGlyph icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AnswerButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    pressedScale: 0.94,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: RbIcon(icon, size: 26, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onEmberMuted)),
      ],
    ),
  );
}
