import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/demo/demo.dart';
import 'package:rakta_bandhan/screens/create_experience_screen.dart';

void main() {
  tearDown(() => Demo.instance.stop());
  testWidgets('new story privacy switches save, and editing keeps their choices', (tester) async {
    final demo = Demo.instance..start(DemoRole.requester);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: Column(children: [
      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateExperienceScreen())), child: const Text('Create')),
      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateExperienceScreen(
        editStoryId: demo.stories.first['id'] as String, initialBody: demo.stories.first['body'] as String, initialTopic: demo.stories.first['topic'] as String,
      ))), child: const Text('Edit')),
    ])))));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First draft');
    final switches = find.byType(Switch);
    await tester.ensureVisible(switches.at(0));
    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(switches.at(1));
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share experience'));
    await tester.pumpAndSettle();
    expect(demo.stories.first['blood_group'], isNull);
    expect(demo.stories.first['location_label'], Demo.area);
    expect(demo.stories.first['author_username'], isNotEmpty);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    await tester.enterText(find.byType(TextField), 'Edited text');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(demo.stories.first['body'], 'Edited text');
    expect(demo.stories.first['blood_group'], isNull);
    expect(demo.stories.first['location_label'], Demo.area);
  });
}
