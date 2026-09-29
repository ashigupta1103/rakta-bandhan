import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Looping sound + haptic pulse for the two moments that must be noticed
/// even with the phone face-down on a desk: an incoming in-app call and an
/// urgent blood request (the "Rapido ride request" ring). Both sounds are
/// generated in-house (assets/sounds/) — no licensed audio.
class AlertSound {
  AlertSound._(this._asset);

  static final incomingCall = AlertSound._('sounds/incoming_call.wav');
  static final urgentRequest = AlertSound._('sounds/urgent_alert.wav');

  final String _asset;
  AudioPlayer? _player;
  Timer? _haptics;

  Future<void> start() async {
    if (_player != null) return;
    final player = AudioPlayer();
    _player = player;
    _haptics = Timer.periodic(const Duration(milliseconds: 1400), (_) => HapticFeedback.heavyImpact());
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(_asset));
    } catch (_) {
      // Browsers block autoplay until the page has had a user gesture —
      // the full-screen alert still shows; it just can't make noise.
    }
  }

  Future<void> stop() async {
    _haptics?.cancel();
    _haptics = null;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }
}
