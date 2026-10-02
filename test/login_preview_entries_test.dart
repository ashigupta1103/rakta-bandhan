import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/preview_mode.dart';
import 'package:rakta_bandhan/screens/login_screen.dart';

// Run with --dart-define=ENABLE_PREVIEW_UI=true (also the default in tests).
void main() {
  testWidgets('login shows both Preview entries when kEnablePreviewUi', (t) async {
    expect(kEnablePreviewUi, isTrue);
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Preview UI — all screens (no backend)'), findsOneWidget);
    expect(find.text('Preview UI — 4 main tabs only (no backend)'), findsOneWidget);
  });
}
