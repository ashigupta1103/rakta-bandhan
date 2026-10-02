import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/about_screen.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';

/// About › Our team uses each member's own asset in their existing card:
/// the two portraits as cropped photos, the CSK logo whole (contain).
void main() {
  const radhika = 'assets/images/Radhika dhurv.jpeg';
  const adarsh = 'assets/images/Rtn Adarsh.jpg.jpeg';
  const csk = 'assets/images/Chennai_Super_Kings_Logo.svg';

  test('team assets exist on disk', () {
    for (final path in [radhika, adarsh, csk]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('each team card shows its own photo or logo', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const AboutScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    String? assetOf(Widget w) => w is Image && w.image is AssetImage ? (w.image as AssetImage).assetName : null;
    final photos = tester.widgetList<Image>(find.byType(Image)).map(assetOf).whereType<String>().toList();
    expect(photos, containsAll([radhika, adarsh]));

    final photo = tester.widget<Image>(find.byWidgetPredicate((w) => assetOf(w) == radhika));
    expect(photo.fit, BoxFit.cover, reason: 'portraits fill the frame without distortion');

    final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.fit, BoxFit.contain, reason: 'the logo is shown whole, never cropped');
    expect((logo.bytesLoader as SvgAssetLoader).assetName, csk);

    // Same frame for every member: 68 × 80.
    for (final f in [find.byWidgetPredicate((w) => assetOf(w) == radhika), find.byWidgetPredicate((w) => assetOf(w) == adarsh), find.byType(SvgPicture)]) {
      final frame = find.ancestor(of: f, matching: find.byType(ClipRRect)).first;
      expect(tester.getSize(frame), const Size(68, 80));
    }
  });
}
