import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_navigation_dock_example/main.dart' as example;
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('experimental held bar tint defaults and resets to off', (
    tester,
  ) async {
    await _pumpExample(tester);
    expect(_chip(tester, 'Held bar tint').selected, isFalse);
    expect(_dock(tester).style.heldBarSurfaceColor, isNull);
    expect(_dock(tester).style.blurSigma, 20);
    _chip(tester, 'Held bar tint').onSelected!(true);
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Held bar tint').selected, isTrue);
    expect(_dock(tester).style.heldBarSurfaceColor, isNotNull);
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(_chip(tester, 'Held bar tint').selected, isFalse);
    expect(_dock(tester).style.heldBarSurfaceColor, isNull);
    expect(_dock(tester).style.blurSigma, 20);
    expect(_dock(tester).selectedIndex, 0);
    expect(find.text('No selection requests yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'experimental tint resolves only the held outer color in ${dark ? 'dark' : 'light'}',
      (tester) async {
        await _pumpExample(tester);
        if (dark) {
          _chip(tester, 'Dark theme').onSelected!(true);
          await tester.pumpAndSettle();
        }
        final source = _dock(tester).style;
        final theme = Theme.of(
          tester.element(find.byType(CustomGlassNavigationDockWidget)),
        );
        final targetBounds = _targetBounds(tester);
        _chip(tester, 'Held bar tint').onSelected!(true);
        await tester.pumpAndSettle();
        final tinted = _dock(tester).style;
        expect(
          tinted.heldBarSurfaceColor,
          dark
              ? theme.colorScheme.surface.withValues(alpha: 0.90)
              : Colors.white.withValues(alpha: 0.82),
        );
        expect(source.heldBarSurfaceColor, isNull);
        expect(
          AppGlassNavigationStyle.fromTheme(theme).heldBarSurfaceColor,
          isNull,
        );
        expect(tinted.surfaceColor, source.surfaceColor);
        expect(tinted.selectedSurfaceColor, source.selectedSurfaceColor);
        expect(tinted.heldSurfaceColor, source.heldSurfaceColor);
        expect(tinted.shadowColor, source.shadowColor);
        expect(tinted.heldShadowColor, source.heldShadowColor);
        expect(tinted.blurSigma, 20);
        expect(tinted.heldBlurSigma, source.heldBlurSigma);
        expect(tinted.refractionStrength, source.refractionStrength);
        expect(
          tinted.foregroundRefractionEdge,
          source.foregroundRefractionEdge,
        );
        expect(tinted.foregroundMagnification, source.foregroundMagnification);
        expect(tinted.foregroundDispersion, source.foregroundDispersion);
        expect(
          tinted.selectedBackdropDispersion,
          source.selectedBackdropDispersion,
        );
        expect(tinted.pressedScale, source.pressedScale);
        expect(tinted.pressureStretch, source.pressureStretch);
        expect(tinted.heldBarScale, source.heldBarScale);
        expect(tinted.duration, source.duration);
        expect(tinted.selectionSpring, source.selectionSpring);
        expect(_targetBounds(tester), targetBounds);
        _chip(tester, 'Held bar tint').onSelected!(false);
        await tester.pumpAndSettle();
        expect(_dock(tester).style.heldBarSurfaceColor, isNull);
        expect(_targetBounds(tester), targetBounds);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tint toggling retains selection, canvas and ordinary control identity',
    (tester) async {
      await _pumpExample(tester);
      _chip(tester, 'Comparison canvas').onSelected!(true);
      await tester.pumpAndSettle();
      _dock(tester).onItemSelected(2);
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('comparison-canvas'));
      final canvasRender = tester.renderObject<RenderRepaintBoundary>(canvas);
      final dockState = tester.state(
        find.byType(CustomFlutterGlassNavigationDockWidget),
      );
      for (final enabled in [true, false, true]) {
        _chip(tester, 'Held bar tint').onSelected!(enabled);
        await tester.pumpAndSettle();
        expect(_dock(tester).selectedIndex, 2);
        expect(_chip(tester, 'Comparison canvas').selected, isTrue);
        expect(
          tester.renderObject<RenderRepaintBoundary>(canvas),
          same(canvasRender),
        );
        expect(
          tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
          same(dockState),
        );
        expect(
          find.text('Request 1: Likes (index 2) accepted. Host index: 2.'),
          findsOneWidget,
        );
      }
      final controlFinder = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ExampleControls',
      );
      final controls = tester.widget(controlFinder);
      final chip = _chip(tester, 'Held bar tint');
      final list = tester.widget<ListView>(find.byType(ListView));
      final dock = _dock(tester);
      dock.onItemSelected(1);
      await tester.pumpAndSettle();
      expect(_dock(tester).selectedIndex, 1);
      expect(_chip(tester, 'Held bar tint'), same(chip));
      expect(tester.widget(controlFinder), same(controls));
      expect(tester.widget<ListView>(find.byType(ListView)), same(list));
      expect(_dock(tester).style, same(dock.style));
      expect(_dock(tester).items, same(dock.items));
      expect(
        tester.renderObject<RenderRepaintBoundary>(canvas),
        same(canvasRender),
      );
      expect(
        find.text('Request 2: Featured (index 1) accepted. Host index: 1.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpExample(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  example.main();
  await tester.pumpAndSettle();
}

FilterChip _chip(WidgetTester tester, String label) =>
    tester.widget(find.widgetWithText(FilterChip, label));

CustomGlassNavigationDockWidget _dock(WidgetTester tester) =>
    tester.widget(find.byType(CustomGlassNavigationDockWidget));

List<Rect> _targetBounds(WidgetTester tester) => [
  for (final item in _dock(tester).items)
    tester.getRect(
      find.descendant(
        of: find.byType(CustomGlassNavigationDockWidget),
        matching: find.widgetWithText(InkWell, item.label),
      ),
    ),
];
