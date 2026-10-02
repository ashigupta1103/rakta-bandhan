// Community, testimonials and support on an Android emulator (see
// support.dart for how to run it): sign up → share a story → offer a
// testimonial → report an issue. Each lands in Firestore through the real
// security rules, and the team's reply (written as an admin would) shows up
// under "My reports".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rakta_bandhan/main.dart' as app;
import 'package:rakta_bandhan/widgets/app_header.dart' show showMoreSheet;

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('engagement journey: story → testimonial → report → reply', (t) async {
    await app.main();
    final email = 'e2e-engage-${DateTime.now().millisecondsSinceEpoch}@example.com';
    final me = await signUpAndRegister(t, email: email, name: 'Test Member', bloodGroup: 'AB+');

    // 1. A community story (text only).
    await tapWhenReady(t, find.text('Community'));
    await tapWhenReady(t, find.textContaining('Share your donation story'));
    await waitFor(t, find.text('Share experience'), why: 'story composer');
    await t.enterText(find.byType(TextField).first, 'My first donation went smoothly.');
    await snap(t, '40_story_composer');
    await tapWhenReady(t, find.text('Share experience'));
    await waitFor(t, find.textContaining('My first donation went smoothly.'), why: 'the story in the feed', timeout: const Duration(seconds: 60));
    await snap(t, '41_story_posted');
    final stories = (await fsList('community_stories')).where((d) => fsString(d, 'author_uid') == me);
    expect(stories, hasLength(1));
    expect(fsString(stories.single, 'body'), 'My first donation went smoothly.');

    // 2. Offer a testimonial (needs consent; goes to a private queue).
    await tapWhenReady(t, find.text('Request'));
    showMoreSheet(t.element(find.text('Request').first));
    await tapWhenReady(t, find.text('Testimonials'));
    await tapWhenReady(t, find.text('Add a testimonial'));
    await t.enterText(find.byType(TextField).at(0), 'Rakta Bandhan helped us find a donor within the hour.');
    await t.enterText(find.byType(TextField).at(1), 'Donor, Adyar');
    await tapWhenReady(t, find.byType(Checkbox));
    await snap(t, '42_testimonial_sheet');
    await tapWhenReady(t, find.text('Send for review'));
    await waitFor(t, find.textContaining('Thank you! Our team will review it'), why: 'testimonial sent');
    final offers = (await fsList('testimonial_submissions')).where((d) => fsString(d, 'author_uid') == me);
    expect(offers, hasLength(1));
    expect(offers.single['fields']['consent_to_publish']['booleanValue'], isTrue);
    await popToRoot(t);

    // 3. Report an issue from Help & support.
    await tapWhenReady(t, find.text('Request'));
    showMoreSheet(t.element(find.text('Request').first));
    await tapWhenReady(t, find.text('Help & support'));
    await tapWhenReady(t, find.text('Report an issue'));
    await tapWhenReady(t, find.text('App problem or bug'));
    await t.enterText(find.byType(TextField).last, 'The map is slow to load on my phone.');
    await snap(t, '43_report');
    await tapWhenReady(t, find.text('Submit'));
    await waitFor(t, find.text('Thanks for the details'), why: 'report sent');
    final reports = (await fsList('issue_reports')).where((d) => fsString(d, 'reporter_uid') == me).toList();
    expect(reports, hasLength(1));
    final reportId = (reports.single['name'] as String).split('/').last;
    final copy = await fsGet('support_submissions/$reportId');
    expect(copy, isNotNull, reason: 'the author keeps a safe copy of what they sent');
    expect(fsString(copy, 'reporter_uid'), me);

    // 4. The team replies (as an admin would); the author reads it in the app.
    await fsSet('support_replies/e2e_reply_1', {
      'source_collection': 'issue_reports',
      'source_id': reportId,
      'to_uid': me,
      'body': 'Thanks — we are looking into the map.',
      'created_by': 'e2e_admin',
      'created_at': DateTime.now(),
    });
    await popToRoot(t);
    await tapWhenReady(t, find.text('Request'));
    showMoreSheet(t.element(find.text('Request').first));
    await tapWhenReady(t, find.text('Help & support'));
    await tapWhenReady(t, find.text('My reports & replies'));
    await waitFor(t, find.textContaining('we are looking into the map'), why: 'the team’s reply', timeout: const Duration(seconds: 60));
    await snap(t, '44_reply');
  });
}
