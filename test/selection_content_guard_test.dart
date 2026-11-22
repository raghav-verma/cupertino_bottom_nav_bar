import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Buckets', 'Likes', 'Chats', 'Profile'];
final _capsule = find.byKey(const Key('glass_navigation_selection'));

/// Caption 10 × 1.35 = 13.5, so icon area + gap + caption = 32 + 2 + 13.5.
const _contentHeight = 47.5;

void main() {
  group('vertical inset keeps the icon and caption inside the capsule', () {
    for (final inset in [0.0, 2.0, 4.0, 12.0, 100.0]) {
      testWidgets('selectionVerticalInset $inset', (tester) async {
        final selected = ValueNotifier(1);
        addTearDown(selected.dispose);
        await _pump(tester, selected, _style(verticalInset: inset));

        final capsule = tester.getRect(_capsule);
        _contains(capsule, tester.getRect(find.text('Buckets')));
        _contains(capsule, _iconArea(tester, 'Buckets'));
        expect(capsule.height, greaterThanOrEqualTo(_contentHeight - 0.001));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('default inset still fills the row', (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pump(tester, selected, _style(verticalInset: 0));
      expect(
        tester.getSize(_capsule).height,
        tester.getSize(_target('Browse')).height,
      );
    });

    testWidgets('a row tall enough keeps the requested inset', (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      // (56 - 47.5) / 2 = 4.25 of room, so an inset of 4 is honoured.
      await _pump(tester, selected, _style(verticalInset: 4, actionHeight: 56));
      final row = tester.getRect(_target('Browse'));
      final capsule = tester.getRect(_capsule);
      expect(capsule.top - row.top, closeTo(4, 0.001));
      expect(capsule.height, closeTo(row.height - 8, 0.001));
    });

    testWidgets('held inset cannot cut the caption during a press', (
      tester,
    ) async {
      final selected = ValueNotifier(1);
      addTearDown(selected.dispose);
      await _pump(
        tester,
        selected,
        _style(verticalInset: 0, heldVerticalInset: 20, pressedScale: 1.1),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(_target('Buckets')),
      );
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _contains(
          tester.getRect(_capsule),
          tester.getRect(find.text('Buckets')),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('outset keeps the capsule off the surface ends', () {
    for (final direction in TextDirection.values) {
      for (final (gutter, outset, gap) in [
        // A gutter equal to the content inset leaves no room to extend.
        (4.0, 4.0, 4.0),
        // Any outset beyond gutter - content inset is clamped to it.
        (8.0, 100.0, 4.0),
        // A wider gutter still honours the requested outset.
        (10.0, 4.0, 6.0),
      ]) {
        testWidgets(
          '${direction.name} gutter $gutter outset $outset leaves $gap',
          (tester) async {
            final selected = ValueNotifier(0);
            addTearDown(selected.dispose);
            await _pump(
              tester,
              selected,
              _style(gutter: gutter, outset: outset),
              direction: direction,
            );
            for (final index in [0, _labels.length - 1]) {
              selected.value = index;
              await tester.pumpAndSettle();
              final surface = _surface(tester);
              final capsule = tester.getRect(_capsule);
              final atStart = index == 0;
              final nearLeft = (direction == TextDirection.ltr) == atStart;
              final endGap = nearLeft
                  ? capsule.left - surface.left
                  : surface.right - capsule.right;
              expect(endGap, closeTo(gap, 0.001));
              expect(endGap, greaterThanOrEqualTo(4 - 0.001));
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}

AppGlassNavigationStyle _style({
  double verticalInset = 0,
  double? heldVerticalInset,
  double actionHeight = 48,
  double pressedScale = 0.97,
  double gutter = 4,
  double outset = 0,
}) => AppGlassNavigationStyle(
  actionHeight: actionHeight,
  contentInset: 4,
  horizontalContentInset: gutter,
  selectionHorizontalInset: 0,
  selectionHorizontalOutset: outset,
  selectionVerticalInset: verticalInset,
  heldSelectionVerticalInset: heldVerticalInset,
  pressedScale: pressedScale,
  labelStyle: const TextStyle(fontSize: 10, height: 1.35),
);

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<int> selected,
  AppGlassNavigationStyle style, {
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, _) => CustomGlassNavigationDockWidget(
            items: [
              for (final label in _labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: index,
            onItemSelected: (value) => selected.value = value,
            style: style,
            preferNative: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Rect _surface(WidgetTester tester) => tester.getRect(
  find.ancestor(of: _capsule, matching: find.byType(ClipRRect)).last,
);

/// The icon's reserved square, which sits directly above the caption.
Rect _iconArea(WidgetTester tester, String label) {
  final icon = tester.getRect(
    find.descendant(
      of: _target(label),
      matching: find.byIcon(Icons.circle_outlined),
    ),
  );
  return Rect.fromCenter(center: icon.center, width: 32, height: 32);
}

void _contains(Rect outer, Rect inner) {
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.001));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.001));
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.001));
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.001));
}
