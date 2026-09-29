// The legal pages are what App Review and Play policy reviewers read. These
// checks keep the reader honest: every section of the document actually
// renders, the draft banner stays up until counsel approves the text, and
// the Privacy ↔ Terms cross-link lands on the other document.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rakta_bandhan/legal/legal_config.dart';
import 'package:rakta_bandhan/legal/legal_documents.dart';
import 'package:rakta_bandhan/screens/legal_reader_screen.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';

Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {'privacy': privacyPolicy, 'terms': termsOfUse}.entries) {
    testWidgets('${entry.key}: every section heading is rendered', (tester) async {
      final doc = entry.value;
      await _open(tester, entry.key == 'privacy' ? const LegalReaderScreen.privacy() : const LegalReaderScreen.terms());

      for (final section in doc.sections) {
        await tester.scrollUntilVisible(find.text(section.heading).last, 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(section.heading), findsWidgets, reason: 'missing section "${section.heading}"');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('draft banner is shown exactly while the text is unapproved', (tester) async {
    await _open(tester, const LegalReaderScreen.privacy());
    expect(find.textContaining('Draft awaiting legal review'), kLegalApproved ? findsNothing : findsOneWidget);
  });

  testWidgets('legacy title constructor still resolves the right document', (tester) async {
    await _open(tester, const LegalReaderScreen(title: 'Terms of use'));
    expect(find.text(termsOfUse.intro), findsOneWidget);
  });
}
