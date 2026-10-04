import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/conversations_screen.dart';
import 'package:rakta_bandhan/screens/create_request_screen.dart';
import 'package:rakta_bandhan/screens/main_navigation_screen.dart';
import 'package:rakta_bandhan/screens/tracking_screen.dart';
import 'package:rakta_bandhan/services/chat_service.dart';
import 'package:rakta_bandhan/widgets/identity_disc.dart';

// Injected streams only — never touches Backend.instance.
Future<void> pump(WidgetTester t, {Stream<List<Conversation>>? convs, required Stream<MyRequestState> state}) async {
  await t.pumpWidget(MaterialApp(
    home: ConversationsScreen(conversations: convs ?? Stream.value(const []), requestState: state, myUidOverride: 'me'),
  ));
  await t.pump();
  await t.pump();
}

/// Records pushed routes. The destination screens need Firebase, so the tests
/// read the widget the route *would* build (constructor only) and never pump
/// a frame after the tap — nothing is mounted.
class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);

  Widget get lastPage => (routes.last as MaterialPageRoute).builder(_ctx!);
  BuildContext? _ctx;
}

Future<Widget> tapAndGetDestination(WidgetTester t, MyRequestState state, String label) async {
  final obs = _Pushes();
  await t.pumpWidget(MaterialApp(
    navigatorObservers: [obs],
    home: ConversationsScreen(conversations: Stream.value(const []), requestState: Stream.value(state), myUidOverride: 'me'),
  ));
  await t.pump();
  await t.pump();
  obs._ctx = t.element(find.byType(ConversationsScreen));
  final before = obs.routes.length;
  await t.tap(find.text(label));
  expect(obs.routes.length, before + 1, reason: 'tap pushes exactly one route');
  return obs.lastPage;
}

void main() {
  testWidgets('tap View my request -> TrackingScreen for that request', (t) async {
    final page = await tapAndGetDestination(t, (openIds: const ['r1'], hasAny: true), 'View my request');
    expect(page, isA<TrackingScreen>());
    expect((page as TrackingScreen).requestId, 'r1');
  });

  testWidgets('tap View my requests -> Request tab of the main shell', (t) async {
    final page = await tapAndGetDestination(t, (openIds: const ['r1', 'r2'], hasAny: true), 'View my requests');
    expect(page, isA<MainNavigationScreen>());
    expect((page as MainNavigationScreen).initialTab, 0);
  });

  testWidgets('tap Request blood -> CreateRequestScreen', (t) async {
    final page = await tapAndGetDestination(t, (openIds: const [], hasAny: false), 'Request blood');
    expect(page, isA<CreateRequestScreen>());
  });

  testWidgets('tap Find donors -> main shell on the Find tab', (t) async {
    final page = await tapAndGetDestination(t, (openIds: const [], hasAny: false), 'Find donors');
    expect(page, isA<MainNavigationScreen>());
    expect((page as MainNavigationScreen).initialTab, 1);
  });

  testWidgets('brand-new user: generic state, Request blood + Find donors', (t) async {
    await pump(t, state: Stream.value((openIds: const [], hasAny: false)));
    expect(find.text('Request blood'), findsOneWidget);
    expect(find.text('Find donors'), findsOneWidget);
    expect(find.text('View my request'), findsNothing);
  });

  testWidgets('past requests only: no conversations yet, Request blood', (t) async {
    await pump(t, state: Stream.value((openIds: const [], hasAny: true)));
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Request blood'), findsOneWidget);
  });

  testWidgets('active request: View my request, no Request blood', (t) async {
    await pump(t, state: Stream.value((openIds: const ['r1'], hasAny: true)));
    expect(find.text('Your request is active'), findsOneWidget);
    expect(find.text('View my request'), findsOneWidget);
    expect(find.text('Request blood'), findsNothing);
    expect(find.text('Find donors'), findsOneWidget);
  });

  testWidgets('multiple open requests: View my requests, not a single pick', (t) async {
    await pump(t, state: Stream.value((openIds: const ['r1', 'r2'], hasAny: true)));
    expect(find.text('Your requests are active'), findsOneWidget);
    expect(find.text('View my requests'), findsOneWidget);
    expect(find.text('View my request'), findsNothing);
    expect(find.text('Request blood'), findsNothing);
  });

  testWidgets('query failure: safe generic state, no error text', (t) async {
    await pump(t, state: Stream.error(Exception('permission-denied')));
    expect(find.text('Request blood'), findsOneWidget);
    expect(find.textContaining('permission'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('conversations exist: list shown, no empty-state CTAs', (t) async {
    final c = Conversation(
      requestId: 'r1', amRequester: true, peerUid: 'u2', peerName: 'Asha K', bloodGroup: 'O+',
      status: 'matched', closedByBlock: false, lastText: 'On my way', lastSenderUid: 'u2',
      lastAt: DateTime.now(), myReadAt: null, peerReadAt: null, sortKey: DateTime.now(),
    );
    await pump(t, convs: Stream.value([c]), state: Stream.value((openIds: const [], hasAny: true)));
    expect(find.text('Asha K'), findsOneWidget);
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Request blood'), findsNothing);
  });

  testWidgets('empty state invents no conversation rows or people', (t) async {
    await pump(t, state: Stream.value((openIds: const [], hasAny: false)));
    expect(find.byType(IdentityDisc), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Earlier'), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('empty state fits a small phone without overflow', (t) async {
    t.view.physicalSize = const Size(320, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pump(t, state: Stream.value((openIds: const ['r1'], hasAny: true)));
    expect(t.takeException(), isNull);
    expect(find.text('View my request'), findsOneWidget);
  });

  // Privacy: a conversation only exists for the two people on a request that
  // has a donor. (Firestore rules cover the server side: backend/rules-test
  // rules.test.mjs "chat" — a stranger can't read/write messages.)
  group('Conversation.fromRequest privacy', () {
    final base = {'requester_uid': 'req', 'matched_donor_id': 'don', 'blood_group': 'O+', 'status': 'matched'};
    test('requester and matched donor each get it', () {
      expect(Conversation.fromRequest('r1', base, 'req')?.amRequester, isTrue);
      expect(Conversation.fromRequest('r1', base, 'don')?.amRequester, isFalse);
    });
    test('a stranger gets nothing', () {
      expect(Conversation.fromRequest('r1', base, 'other'), isNull);
    });
    test('a request with no donor has no conversation', () {
      expect(Conversation.fromRequest('r1', {...base, 'matched_donor_id': null, 'status': 'open'}, 'req'), isNull);
    });
  });

  testWidgets('loading: spinner, no fake content', (t) async {
    await t.pumpWidget(MaterialApp(
      home: ConversationsScreen(conversations: Stream.value(const []), requestState: const Stream.empty(), myUidOverride: 'me'),
    ));
    await t.pump();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Request blood'), findsNothing);
  });
}
