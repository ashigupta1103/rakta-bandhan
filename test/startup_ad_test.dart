import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/widgets/startup_ad_screen.dart';

void main() {
  Future<void> pumpAd(WidgetTester t, StartupAdLoader loader) => t.pumpWidget(
        MaterialApp(home: StartupAdScreen(next: const Text('NEXT'), loader: loader)),
      );

  testWidgets('shows label, then continues after 3s with no ad', (t) async {
    await pumpAd(t, () async => null);
    await t.pump();
    expect(find.text('Advertisement'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    await t.pump(const Duration(milliseconds: 2900));
    expect(find.text('NEXT'), findsNothing);
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('continues even if loader throws or hangs', (t) async {
    await pumpAd(t, () => throw Exception('no fill'));
    await t.pump(StartupAdScreen.maxDuration);
    await t.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('no overflow on small phone', (t) async {
    t.view.physicalSize = const Size(320, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpAd(t, () async => null);
    await t.pump();
    expect(t.takeException(), isNull);
    await t.pump(StartupAdScreen.maxDuration);
    await t.pumpAndSettle();
  });
}
