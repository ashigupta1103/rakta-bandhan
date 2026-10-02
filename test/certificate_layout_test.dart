import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/certificate_screen.dart';
import 'package:rakta_bandhan/services/donation_history_service.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';

/// The certificate is a fixed A4-like card scaled to the screen: it must
/// lay out without overflow on small and large phones, with a long hospital
/// name. The donor name is injected so no Firebase call is made.
void main() {
  for (final size in const [Size(320, 640), Size(412, 915)]) {
    testWidgets('certificate fits a ${size.width.toInt()}×${size.height.toInt()} phone', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CertificateScreen(
          record: DonationRecord(hospital: 'Government General Hospital, Park Town, Chennai', date: '2 October 2026', bloodGroup: 'O+'),
          donationNumber: 12,
          donorName: 'Test Donor',
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      // Save and Share share one height.
      expect(tester.getSize(find.ancestor(of: find.text('Save'), matching: find.byType(OutlinedButton))).height,
          tester.getSize(find.ancestor(of: find.text('Share'), matching: find.byType(OutlinedButton))).height);
    });
  }
}
