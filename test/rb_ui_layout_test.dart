import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rakta_bandhan/theme/app_theme.dart';
import 'package:rakta_bandhan/widgets/rb_ui.dart';

/// The shared building blocks must lay out at a small phone width (360px)
/// with long text and no overflow — every redesigned screen leans on them.
void main() {
  testWidgets('shared rows, chips, tabs and panels fit a 360px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var retried = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Column(
          children: [
            RbTabBar(tabs: const [('Stories', 0), ("What's new", 0), ('Impact', 3)], selected: 0, onChanged: (_) {}),
            Expanded(
              child: ListView(
                padding: kRbPagePadding,
                children: [
                  const RbSectionLabel('A fairly long section label that should simply wrap or clip'),
                  RbListGroup(
                    children: [
                      RbRow(
                        icon: LucideIcons.bellRing,
                        title: 'A very long settings row title that would overflow a naive Row layout',
                        subtitle: 'And an equally long subtitle explaining exactly what this setting does on the phone',
                        trailing: RbSwitch(value: true, onChanged: (_) {}),
                      ),
                      RbRow(icon: LucideIcons.trash2, destructive: true, title: 'Delete my account', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Wrap(spacing: 6, children: [RbChip('Verified donor', icon: LucideIcons.badgeCheck, tone: RbTone.success), RbChip('Available now')]),
                  const SizedBox(height: 12),
                  RbStatePanel.error(title: "Couldn't load stories", message: 'Check your connection and try again.', onRetry: () => retried = true),
                  const RbAvatar(name: 'Radhika Dhruv'),
                ],
              ),
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(RbAvatar.initialsOf('Radhika Dhruv'), 'RD');
    expect(RbAvatar.initialsOf('  '), '?');
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
