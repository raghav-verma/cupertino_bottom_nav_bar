import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _items = [
  AppGlassNavigationItem(icon: Icons.explore_outlined, label: 'Explore'),
  AppGlassNavigationItem(
    icon: Icons.mail_outline,
    label: 'Inbox',
    semanticLabel: 'Messages',
    badgeLabel: '3 unread',
    enabled: false,
  ),
  AppGlassNavigationItem(icon: Icons.person_outline, label: 'Profile'),
];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} theme defaults meet target, label and text-contrast guidelines',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(
          tester,
          selected: selected,
          onRequested: (index) => selected.value = index,
          brightness: brightness,
          items: const [
            AppGlassNavigationItem(
              icon: Icons.explore_outlined,
              label: 'Explore',
            ),
            AppGlassNavigationItem(
              icon: Icons.mail_outline,
              label: 'Inbox',
              badgeLabel: '3 unread',
            ),
            AppGlassNavigationItem(
              icon: Icons.person_outline,
              label: 'Profile',
            ),
          ],
        );
        expect(find.bySemanticsLabel('Inbox, 3 unread'), findsOneWidget);
        expect(find.bySemanticsLabel('3 unread'), findsNothing);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      },
    );

    for (final direction in TextDirection.values) {
      testWidgets(
        '${brightness.name} ${direction.name} keyboard skips disabled items and activates with Space and Enter',
        (tester) async {
          final selected = ValueNotifier(0);
          addTearDown(selected.dispose);
          final requests = <int>[];
          await _pump(
            tester,
            selected: selected,
            onRequested: (index) {
              requests.add(index);
              selected.value = index;
            },
            brightness: brightness,
            direction: direction,
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(_focus(tester, 'Explore').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(_focus(tester, 'Profile').hasFocus, isTrue);
          expect(_focus(tester, 'Inbox').canRequestFocus, isFalse);
          expect(requests, isEmpty);

          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(requests, [2]);
          expect(_selected(tester, 'Profile'), Tristate.isTrue);
          expect(_focus(tester, 'Profile').hasFocus, isTrue);

          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(_focus(tester, 'Explore').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(requests, [2, 0]);
          expect(_selected(tester, 'Explore'), Tristate.isTrue);
          expect(_selected(tester, 'Profile'), Tristate.isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${brightness.name} semantics activation remains host controlled with reduced motion and icon-only labels',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        var accepts = false;
        await _pump(
          tester,
          selected: selected,
          onRequested: (index) {
            requests.add(index);
            if (accepts) selected.value = index;
          },
          brightness: brightness,
          reducedMotion: true,
          iconOnly: true,
        );
        final disabled = tester.getSemantics(
          find.bySemanticsLabel('Messages, 3 unread'),
        );
        expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
        expect(
          disabled.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(find.bySemanticsLabel('3 unread'), findsNothing);
        expect(find.bySemanticsLabel('Inbox'), findsNothing);

        void activateProfile() {
          final node = tester.getSemantics(find.bySemanticsLabel('Profile'));
          tester.binding.renderViews.single.owner!.semanticsOwner!
              .performAction(node.id, SemanticsAction.tap);
        }

        activateProfile();
        await tester.pumpAndSettle();
        expect(requests, [2]);
        expect(_selected(tester, 'Explore'), Tristate.isTrue);
        expect(_selected(tester, 'Profile'), Tristate.isFalse);
        accepts = true;
        activateProfile();
        await tester.pump();
        expect(requests, [2, 2]);
        expect(_selected(tester, 'Profile'), Tristate.isTrue);
        expect(_selected(tester, 'Explore'), Tristate.isFalse);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

FocusNode _focus(WidgetTester tester, String label) =>
    Focus.of(tester.element(find.text(label)));

Tristate _selected(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(label))
    .flagsCollection
    .isSelected;

Future<void> _pump(
  WidgetTester tester, {
  required ValueNotifier<int> selected,
  required ValueChanged<int> onRequested,
  required Brightness brightness,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
  bool iconOnly = false,
  List<AppGlassNavigationItem> items = _items,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              bottomNavigationBar: ValueListenableBuilder<int>(
                valueListenable: selected,
                builder: (context, index, _) => CustomGlassNavigationDockWidget(
                  items: items,
                  selectedIndex: index,
                  onItemSelected: onRequested,
                  preferNative: false,
                  iconOnly: iconOnly,
                  style: AppGlassNavigationStyle.fromTheme(Theme.of(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
