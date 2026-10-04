import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/certificate_screen.dart';
import 'package:rakta_bandhan/screens/donation_history_screen.dart';
import 'package:rakta_bandhan/screens/settings_screen.dart';
import 'package:rakta_bandhan/screens/testimonials_screen.dart';
import 'package:rakta_bandhan/services/donation_history_service.dart';
import 'package:rakta_bandhan/widgets/certificate_card.dart';

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.add(route);
}

void main() {
  testWidgets('privacy: private items are only under "cannot see"', (t) async {
    t.view.physicalSize = const Size(1080, 3000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PrivacyVisibility()))));
    final can = t.getTopLeft(find.text('What others can see')).dy;
    final cannot = t.getTopLeft(find.text('What others cannot see')).dy;
    expect(can, lessThan(cannot));
    for (final title in ['Your phone number', 'Your exact location', 'Your profile photo', 'Your ID proof']) {
      expect(t.getTopLeft(find.text(title)).dy, greaterThan(cannot), reason: '$title must be under "cannot see"');
    }
    for (final title in ['Your name and username', 'Your blood group and availability', 'Your neighbourhood', 'Chats and calls']) {
      final y = t.getTopLeft(find.text(title)).dy;
      expect(y, inExclusiveRange(can, cannot), reason: '$title must be under "can see"');
    }
  });

  const record = DonationRecord(hospital: 'Apollo Hospital', date: '4 March 2026', bloodGroup: 'O+');

  testWidgets('history, no donations: summary, empty state, no rows', (t) async {
    await t.pumpWidget(MaterialApp(home: DonationHistoryScreen(loader: () async => (0, <DonationRecord>[], 'Asha K'))));
    await t.pumpAndSettle();
    expect(find.text('Your journey'), findsOneWidget);
    expect(find.text('donations'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('milestone'), findsNothing);
    expect(find.textContaining('reach'), findsNothing);
    expect(find.textContaining('units'), findsNothing);
    expect(find.textContaining('people helped'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('See who needs help'), findsOneWidget);
    expect(find.text('No donations recorded yet'), findsOneWidget);
    expect(find.byType(DonationCertificateCard), findsNothing);
  });

  testWidgets('history: row shows a real certificate preview and opens the certificate', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final obs = _Pushes();
    await t.pumpWidget(MaterialApp(navigatorObservers: [obs], home: DonationHistoryScreen(loader: () async => (1, [record], 'Asha K'))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Apollo Hospital'), findsWidgets);
    expect(find.text('4 March 2026 · O+'), findsOneWidget);
    // the thumbnail IS the shared certificate widget, with the real name
    final card = t.widget<DonationCertificateCard>(find.byType(DonationCertificateCard));
    expect(card.name, 'Asha K');
    expect(card.record, same(record));
    // the thumbnail keeps the certificate's own proportions (portrait, 360 x 510)
    final box = t.getSize(find.ancestor(of: find.byType(DonationCertificateCard), matching: find.byType(Container)).first);
    expect(box.width / box.height, closeTo(DonationCertificateCard.size.width / DonationCertificateCard.size.height, 0.01));

    // Tapping pushes the existing CertificateScreen for this record. Read the
    // widget the route would build instead of mounting it (it needs Firebase).
    await t.tap(find.text('View certificate'));
    final page = (obs.routes.last as MaterialPageRoute).builder(t.element(find.byType(DonationHistoryScreen)));
    expect(page, isA<CertificateScreen>());
    expect((page as CertificateScreen).record, same(record));
    expect(page.donationNumber, 1);
  });

  testWidgets('testimonials empty state: quotation treatment, no minimum-word text', (t) async {
    await t.pumpWidget(const MaterialApp(home: TestimonialsScreen()));
    await t.pump();
    expect(find.text('No testimonials yet'), findsOneWidget);
    expect(find.text('“'), findsOneWidget);
    expect(find.text('”'), findsOneWidget);
    expect(find.textContaining('minimum', findRichText: true), findsNothing);
    expect(find.textContaining('10 words'), findsNothing);
  });
}
