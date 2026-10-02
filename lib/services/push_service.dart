import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../firebase_options.dart';
import 'backend.dart';
import 'call_service.dart';

/// Push kinds sent by functions/src/index.ts (`data.type`).
abstract final class PushType {
  static const chat = 'chat';
  static const call = 'call';
  static const callEnded = 'call_ended';
  static const request = 'request';
  static const urgentRequest = 'urgent_request';
  static const broadcast = 'broadcast';
  static const supportReply = 'support_reply';
}

/// What a notification tap should open. Screens are resolved by the
/// signed-in shell (MainNavigationScreen), which knows the routes.
@immutable
class PushTarget {
  final String type;
  final String? requestId;
  const PushTarget(this.type, this.requestId);
}

/// A push that arrived while the app was on screen, shown as an in-app
/// banner (LiveEventsHost) instead of a system notification.
@immutable
class ForegroundNotice {
  final String title;
  final String body;
  final PushTarget target;
  const ForegroundNotice(this.title, this.body, this.target);
}

bool get _pushSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Runs in a background isolate when a data message arrives while the app
/// is in the background or closed. Only calls need work here — every other
/// push carries a `notification` block that the OS shows by itself.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  final type = message.data['type'];
  if (type == PushType.call) {
    await PushService.showIncomingCall(message.data);
  } else if (type == PushType.callEnded) {
    final callId = message.data['callId'] as String?;
    if (callId != null) await FlutterCallkitIncoming.endCall(callId);
  }
}

/// Decline tapped on the native incoming-call screen while the app was
/// closed: mark the call declined so the caller stops ringing at once
/// (otherwise they'd wait out the 45-second timeout).
@pragma('vm:entry-point')
Future<void> callkitBackgroundHandler(CallEvent event) async {
  if (event is! CallEventActionCallDecline) return;
  final incoming = PushService._incomingFrom(event.callKitParams);
  if (incoming == null) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await CallService.instance.decline(incoming);
  } catch (_) {
    // Signed out or offline — the caller's ring timeout covers it.
  }
}

/// Everything push: permission, the device token, topic subscriptions,
/// the native ringing call screen, and routing a tapped notification.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _taps = StreamController<PushTarget>.broadcast();
  final _notices = StreamController<ForegroundNotice>.broadcast();
  final _acceptedCalls = StreamController<IncomingCall>.broadcast();
  PushTarget? _pendingTap;
  IncomingCall? _pendingAccept;
  StreamSubscription<String>? _tokenSub;
  String? _subscribedGroupTopic;

  /// Notification taps. A tap that launched the app is held until the
  /// signed-in shell asks for it with [takePendingTap].
  Stream<PushTarget> get taps => _taps.stream;
  Stream<ForegroundNotice> get foregroundNotices => _notices.stream;

  /// Calls answered from the native incoming-call screen.
  Stream<IncomingCall> get acceptedCalls => _acceptedCalls.stream;

  PushTarget? takePendingTap() {
    final t = _pendingTap;
    _pendingTap = null;
    return t;
  }

  IncomingCall? takePendingAccept() {
    final c = _pendingAccept;
    _pendingAccept = null;
    return c;
  }

  /// Once, from main() after Firebase.initializeApp.
  Future<void> init() async {
    if (!_pushSupported) return;
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _emitTap(_targetOf(m.data)));
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingTap = _targetOf(initial.data);
    } catch (_) {}
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterCallkitIncoming.onBackgroundMessage(callkitBackgroundHandler);
      } catch (_) {}
    }
    FlutterCallkitIncoming.onEvent.listen(_onCallEvent, onError: (_) {});
    // The app may have been launched by tapping Accept on the native
    // incoming-call screen: that call is already marked accepted.
    try {
      for (final params in await FlutterCallkitIncoming.activeCalls()) {
        final incoming = _incomingFrom(params);
        if (params.isAccepted && incoming != null) _pendingAccept = incoming;
      }
    } catch (_) {}
  }

  /// After sign-in (MainNavigationScreen): permission prompt, token, and
  /// topics for admin broadcasts. Safe to call on every launch.
  Future<void> registerDevice({String? bloodGroup}) async {
    if (!_pushSupported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, sound: true, badge: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) await Backend.instance.savePushToken(token);
      _tokenSub ??= messaging.onTokenRefresh.listen((t) => Backend.instance.savePushToken(t).catchError((_) {}));
      await messaging.subscribeToTopic('all');
      final groupTopic = bloodGroup == null ? null : bloodGroupTopic(bloodGroup);
      if (groupTopic != _subscribedGroupTopic) {
        if (_subscribedGroupTopic != null) await messaging.unsubscribeFromTopic(_subscribedGroupTopic!);
        if (groupTopic != null) await messaging.subscribeToTopic(groupTopic);
        _subscribedGroupTopic = groupTopic;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+ asks separately for the call screen's notification.
        await FlutterCallkitIncoming.requestNotificationPermission({
          'title': 'Allow call notifications',
          'rationaleMessagePermission': 'Rakta Bandhan needs notifications to ring when a donor or requester calls you.',
          'postNotificationMessageRequired': 'Turn on notifications in Settings so calls can ring on this phone.',
        });
      }
    } catch (_) {
      // Push is best effort — the in-app listeners still work.
    }
  }

  /// On sign-out and account deletion: this phone stops receiving pushes
  /// meant for that account.
  Future<void> unregisterDevice() async {
    if (!_pushSupported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.unsubscribeFromTopic('all');
      if (_subscribedGroupTopic != null) await messaging.unsubscribeFromTopic(_subscribedGroupTopic!);
      _subscribedGroupTopic = null;
      await messaging.deleteToken();
    } catch (_) {}
  }

  /// "A+" → "bg_Apos" — must match bloodGroupTopic in functions/src/geo.ts.
  static String bloodGroupTopic(String group) => 'bg_${group.replaceAll('+', 'pos').replaceAll('-', 'neg')}';

  /// Shows the native full incoming-call UI (Android) with ringtone.
  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    if (callId == null) return;
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: callId,
      nameCaller: data['callerName'] as String? ?? 'Someone',
      appName: 'Rakta Bandhan',
      handle: 'Voice call · Rakta Bandhan',
      type: 0,
      duration: callRingTimeout.inMilliseconds,
      missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: false, subtitle: 'Missed voice call'),
      extra: {
        'requestId': data['requestId'],
        'callId': callId,
        'callerUid': data['callerUid'],
        'callerName': data['callerName'],
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#7F1D1D',
        actionColor: '#16A34A',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        isShowCallID: false,
        textAccept: 'Answer',
        textDecline: 'Decline',
      ),
      ios: const IOSParams(handleType: 'generic', supportsVideo: false, maximumCallGroups: 1, maximumCallsPerCallGroup: 1),
    ));
  }

  /// Clears the native call UI when the call ends inside the app.
  static Future<void> endNativeCall(String callId) async {
    if (!_pushSupported) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  static IncomingCall? _incomingFrom(CallKitParams params) {
    final extra = params.extra ?? const {};
    final requestId = extra['requestId'] as String?;
    final callId = extra['callId'] as String? ?? params.id;
    if (requestId == null) return null;
    return IncomingCall(
      requestId: requestId,
      callId: callId,
      callerUid: extra['callerUid'] as String? ?? '',
      callerName: extra['callerName'] as String? ?? params.nameCaller ?? 'Someone',
    );
  }

  void _onCallEvent(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final incoming = _incomingFrom(callKitParams);
        if (incoming == null) return;
        if (_acceptedCalls.hasListener) {
          _acceptedCalls.add(incoming);
        } else {
          _pendingAccept = incoming;
        }
      case CallEventActionCallDecline(:final callKitParams):
        final incoming = _incomingFrom(callKitParams);
        if (incoming != null) CallService.instance.decline(incoming);
      default:
        break;
    }
  }

  void _onForeground(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    // Calls and chats already surface in-app through their live Firestore
    // listeners (LiveEventsHost) — don't double up.
    if (type == PushType.call || type == PushType.callEnded || type == PushType.chat) return;
    final title = message.notification?.title ?? data['title'] as String? ?? 'Rakta Bandhan';
    final body = message.notification?.body ?? data['body'] as String? ?? '';
    _notices.add(ForegroundNotice(title, body, _targetOf(data)));
  }

  void _emitTap(PushTarget target) {
    if (_taps.hasListener) {
      _taps.add(target);
    } else {
      _pendingTap = target;
    }
  }

  static PushTarget _targetOf(Map<String, dynamic> data) =>
      PushTarget(data['type'] as String? ?? PushType.broadcast, data['requestId'] as String?);
}
