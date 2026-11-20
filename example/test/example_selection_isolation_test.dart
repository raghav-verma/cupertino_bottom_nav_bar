import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';

import 'package:glass_navigation_dock_example/main.dart' as example;

void main() {
  testWidgets('accepted example selections rebuild only selection consumers', (
    tester,
  ) async {
    await _pumpExample(tester);
    final focusedControl = Focus.of(tester.element(find.text('Reset')));
    focusedControl.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(focusedControl));
    final controls = _controls(tester);
    final list = tester.widget<ListView>(find.byType(ListView));
    final scrollPosition = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final scrollOffset = scrollPosition.pixels;
    final slider = tester.widget<Slider>(find.byType(Slider));
    final buttons = tester
        .widgetList(find.byType(SegmentedButton<bool>))
        .toList();
    final palettes = tester.widgetList(find.byType(ChoiceChip)).toList();
    final dock = _dock(tester);
    final dockState = tester.state(
      find.byType(CustomFlutterGlassNavigationDockWidget),
    );
    dock.onItemSelected(2);
    await tester.pump();

    expect(_dock(tester).selectedIndex, 2);
    expect(find.text('Host selection: Likes (index 2).'), findsOneWidget);
    expect(
      find.text('Request 1: Likes (index 2) accepted. Host index: 2.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppBar, 'Likes'), findsOneWidget);
    expect(find.text('Likes demo card 1'), findsOneWidget);
    expect(_controls(tester), same(controls));
    expect(tester.widget<ListView>(find.byType(ListView)), same(list));
    expect(tester.widget<Slider>(find.byType(Slider)), same(slider));
    final nextButtons = tester
        .widgetList(find.byType(SegmentedButton<bool>))
        .toList();
    final nextPalettes = tester.widgetList(find.byType(ChoiceChip)).toList();
    for (var i = 0; i < buttons.length; i++) {
      expect(nextButtons[i], same(buttons[i]));
    }
    for (var i = 0; i < palettes.length; i++) {
      expect(nextPalettes[i], same(palettes[i]));
    }
    expect(_dock(tester).items, same(dock.items));
    expect(_dock(tester).style, same(dock.style));
    expect(FocusManager.instance.primaryFocus, same(focusedControl));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable).first).position,
      same(scrollPosition),
    );
    expect(scrollPosition.pixels, scrollOffset);
    expect(
      tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
      same(dockState),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted held request retains dock and passive contact owner', (
    tester,
  ) async {
    await _pumpExample(tester);
    final dockState = tester.state(
      find.byType(CustomFlutterGlassNavigationDockWidget),
    );
    final probeChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Arm 2s lens switch'),
    );
    final probeStatus = tester.widget<Text>(
      find.textContaining('Live lens diagnostic'),
    );
    final profile = find.descendant(
      of: find.byType(CustomGlassNavigationDockWidget),
      matching: find.text('Profile'),
    );
    final owner = await tester.startGesture(tester.getCenter(profile));
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Arm 2s lens switch'),
      ),
      same(probeChip),
    );
    expect(
      tester.widget<Text>(find.textContaining('Live lens diagnostic')),
      same(probeStatus),
    );

    _dock(tester).onItemSelected(4);
    await tester.pump();
    expect(_dock(tester).selectedIndex, 4);
    expect(
      tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
      same(dockState),
    );
    expect(
      tester.widget<Text>(find.textContaining('Live lens diagnostic')),
      same(probeStatus),
    );

    await owner.cancel();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Arm 2s lens switch'),
      ),
      same(probeChip),
    );
    expect(
      tester.widget<Text>(find.textContaining('Live lens diagnostic')),
      same(probeStatus),
    );
    expect(_dock(tester).selectedIndex, 4);
    expect(
      find.text('Request 1: Profile (index 4) accepted. Host index: 4.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('example keeps rejection, configuration and reset host-owned', (
    tester,
  ) async {
    await _pumpExample(tester);
    _dock(tester).onItemSelected(1);
    await tester.pump();
    await tester.ensureVisible(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pump();
    _dock(tester).onItemSelected(4);
    await tester.pump();

    expect(_dock(tester).selectedIndex, 1);
    expect(find.text('Host selection: Featured (index 1).'), findsOneWidget);
    expect(
      find.text('Request 2: Profile (index 4) rejected. Host index: 1.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(_dock(tester).selectedIndex, 0);
    expect(find.text('No selection requests yet.'), findsOneWidget);
    expect(find.text('Host selection: Explore (index 0).'), findsOneWidget);
    _dock(tester).onItemSelected(4);
    await tester.pump();
    expect(_dock(tester).selectedIndex, 4);
    expect(
      find.text('Request 1: Profile (index 4) accepted. Host index: 4.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'example comparison preset resolves in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        await _pumpExample(tester, size: const Size(390, 2400));
        if (dark) {
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Dark theme'))
              .onSelected!(true);
          await tester.pumpAndSettle();
        }
        final dock = _dock(tester);
        final theme = Theme.of(
          tester.element(find.byType(CustomGlassNavigationDockWidget)),
        );
        final themed = AppGlassNavigationStyle.fromTheme(theme);
        final style = dock.style;
        expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
        expect(style.actionHeight, 54);
        expect(style.contentInset, themed.contentInset);
        expect(style.surfaceHeight, 62);
        expect(style.minTargetSize, 48);
        expect(style.labelStyle.fontSize, themed.labelStyle.fontSize);
        expect(style.labelStyle.height, themed.labelStyle.height);
        expect(style.labelStyle.fontFamily, themed.labelStyle.fontFamily);
        expect(style.labelStyle.fontWeight, FontWeight.w400);
        expect(style.labelStyle.letterSpacing, 0);
        expect(style.outlineWidth, 0.5);
        expect(style.heldInnerShadow!.spreadRadius, 1);
        expect(style.heldInnerShadow!.blurRadius, 10);
        expect(style.heldInnerShadow!.offset, const Offset(0, 1));
        expect(
          style.heldInnerShadow!.color,
          theme.colorScheme.shadow.withValues(alpha: dark ? 0.28 : 0.16),
        );
        expect(style.heldInnerHighlight!.spreadRadius, 2);
        expect(style.heldInnerHighlight!.blurRadius, 1);
        expect(
          style.heldInnerHighlight!.color,
          Colors.white.withValues(alpha: dark ? 0.16 : 0.98),
        );
        expect(style.itemSizing, AppGlassNavigationItemSizing.contentBalanced);
        expect(style.horizontalContentInset, 19);
        expect(style.selectionHorizontalInset, 0);
        expect(style.selectionHorizontalOutset, 10);
        expect(style.pressedScale, 1.24 / 1.04);
        expect(style.heldBarScale, 1.04);
        _expectDockTargets(tester);
        expect(dock.selectedIndex, 0);
        expect(find.text('No selection requests yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'balanced comparison track overlaps paint without overlapping hits',
    (tester) async {
      // Ahem's synthetic caption widths differ from device fonts. Use a fitting
      // wide viewport to test the geometry contract, not UIKit allocation values.
      await _pumpExample(tester);
      final initialDock = _dock(tester);
      final targets = [
        for (final item in initialDock.items)
          tester.getRect(_target(item.label)),
      ];
      final capsule = find.byKey(const Key('glass_navigation_selection'));
      expect(targets.first.left, initialDock.style.horizontalInset + 19);
      expect(targets.last.right, 1200 - initialDock.style.horizontalInset - 19);
      for (var index = 1; index < targets.length; index++) {
        expect(targets[index - 1].right, closeTo(targets[index].left, 0.001));
      }
      expect(
        tester.getRect(capsule).width,
        closeTo(targets.first.width + 20, 0.001),
      );
      expect(tester.getRect(capsule).center.dx, targets.first.center.dx);
      // This point is inside the first capsule's visual overlap but belongs to
      // Featured's separate action target.
      await tester.tapAt(
        Offset(targets.first.right + 5, targets.first.center.dy),
      );
      await tester.pumpAndSettle();
      expect(_dock(tester).selectedIndex, 1);
      expect(
        find.text('Request 1: Featured (index 1) accepted. Host index: 1.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Equal'));
      await tester.pumpAndSettle();
      expect(
        _dock(tester).style.itemSizing,
        AppGlassNavigationItemSizing.equal,
      );
      expect(_dock(tester).selectedIndex, 1);
      final equalTargets = [
        for (final item in _dock(tester).items)
          tester.getRect(_target(item.label)),
      ];
      for (final target in equalTargets) {
        expect(target.width, closeTo(equalTargets.first.width, 0.001));
      }
      expect(
        find.text('Request 1: Featured (index 1) accepted. Host index: 1.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(
        _dock(tester).style.itemSizing,
        AppGlassNavigationItemSizing.contentBalanced,
      );
      expect(_dock(tester).selectedIndex, 0);
      expect(find.text('No selection requests yet.'), findsOneWidget);
      _expectDockTargets(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison preset retains complete long-label large-text scrolling targets',
    (tester) async {
      await _pumpExample(tester, size: const Size(390, 2400));
      for (final label in ['Long labels', 'Large text ×2', 'RTL layout']) {
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, label))
            .onSelected!(true);
        await tester.pumpAndSettle();
      }
      final dockFinder = find.byType(CustomGlassNavigationDockWidget);
      final dock = _dock(tester);
      expect(
        find.descendant(
          of: dockFinder,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      _expectDockTargets(tester);
      final context = tester.element(dockFinder);
      expect(Directionality.of(context), TextDirection.rtl);
      expect(MediaQuery.textScalerOf(context).scale(1), 2);
      for (final item in dock.items) {
        final caption = find.descendant(
          of: dockFinder,
          matching: find.text(item.label),
        );
        expect(caption, findsOneWidget);
        final text = tester.widget<Text>(caption);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.visible);
      }
      dock.onItemSelected(4);
      await tester.pumpAndSettle();
      expect(_dock(tester).selectedIndex, 4);
      expect(find.text('Host selection: Profile (index 4).'), findsOneWidget);
      expect(
        find.text('Request 1: Profile (index 4) accepted. Host index: 4.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpExample(
  WidgetTester tester, {
  Size size = const Size(1200, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  example.main();
  await tester.pumpAndSettle();
}

Widget _controls(WidgetTester tester) => tester.widget(
  find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ExampleControls',
  ),
);

CustomGlassNavigationDockWidget _dock(WidgetTester tester) =>
    tester.widget(find.byType(CustomGlassNavigationDockWidget));

Finder _target(String label) => find.descendant(
  of: find.byType(CustomGlassNavigationDockWidget),
  matching: find.widgetWithText(InkWell, label),
);

void _expectDockTargets(WidgetTester tester) {
  final targets = find.descendant(
    of: find.byType(CustomGlassNavigationDockWidget),
    matching: find.byType(InkWell),
  );
  expect(targets, findsNWidgets(5));
  for (final element in targets.evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  }
}
