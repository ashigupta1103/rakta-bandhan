import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/screens/testimonials_screen.dart';

// A short sentence is a valid testimonial; there is no word minimum.
void main() {
  testWidgets('short testimonial + consent enables Send; empty does not', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TestimonialSheet())));
    ElevatedButton send() => t.widget<ElevatedButton>(find.byType(ElevatedButton));

    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(send().onPressed, isNull, reason: 'empty text is not valid');

    await t.enterText(find.byType(TextField).first, 'Rakta Bandhan helped me find a donor.');
    await t.pump();
    expect(send().onPressed, isNotNull);
    expect(find.textContaining('Minimum'), findsNothing);
  });
}
