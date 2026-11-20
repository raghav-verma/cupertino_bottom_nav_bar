import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_navigation_dock_example/main.dart' as example;
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('comparison canvas is opt-in, host-owned and resettable', (
    tester,
  ) async {
    await _pumpExample(tester);
    expect(_chip(tester, 'Comparison canvas').selected, isFalse);
    expect(_canvas, findsNothing);
    final dockState = tester.state(
      find.byType(CustomFlutterGlassNavigationDockWidget),
    );
    _dock(tester).onItemSelected(2);
    await tester.pumpAndSettle();
    final position = _position(tester);
    position.jumpTo(120);
    await tester.pump();
    _chip(tester, 'Comparison canvas').onSelected!(true);
    await tester.pumpAndSettle();

    expect(_canvas, findsOneWidget);
    expect(_chip(tester, 'Comparison canvas').selected, isTrue);
    expect(_dock(tester).selectedIndex, 2);
    expect(_dock(tester).preferNative, isTrue);
    expect(
      find.text('Request 1: Likes (index 2) accepted. Host index: 2.'),
      findsOneWidget,
    );
    expect(_position(tester), same(position));
    expect(position.pixels, 120);
    expect(
      tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
      same(dockState),
    );
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(_canvas, findsNothing);
    expect(_chip(tester, 'Comparison canvas').selected, isFalse);
    expect(_dock(tester).selectedIndex, 0);
    expect(find.text('No selection requests yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canvas pixels stay fixed across scroll, selection and height', (
    tester,
  ) async {
    await _pumpExample(tester);
    _chip(tester, 'Comparison canvas').onSelected!(true);
    await tester.pumpAndSettle();
    final pixels = await _pixels(tester);
    final canvas = tester.widget<RepaintBoundary>(_canvas);
    final controls = tester.widget(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ExampleControls',
      ),
    );
    final list = tester.widget<ListView>(find.byType(ListView));
    final dock = _dock(tester);
    _dock(tester).onItemSelected(4);
    await tester.pumpAndSettle();

    expect(tester.widget<RepaintBoundary>(_canvas), same(canvas));
    expect(tester.widget<ListView>(find.byType(ListView)), same(list));
    expect(
      tester.widget(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ExampleControls',
        ),
      ),
      same(controls),
    );
    expect(_dock(tester).items, same(dock.items));
    expect(_dock(tester).style, same(dock.style));
    expect(await _pixels(tester), orderedEquals(pixels));
    _position(tester).jumpTo(600);
    await tester.pumpAndSettle();
    expect(await _pixels(tester), orderedEquals(pixels));
    final bottomDistance =
        tester.view.physicalSize.height - tester.getRect(_canvas).bottom;
    tester.view.physicalSize = const Size(390, 1800);
    await tester.pumpAndSettle();
    expect(await _pixels(tester), orderedEquals(pixels));
    expect(
      tester.view.physicalSize.height - tester.getRect(_canvas).bottom,
      bottomDistance,
    );
    expect(_dock(tester).selectedIndex, 4);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'canvas stays passive and static in ${dark ? 'dark' : 'light'} reduced motion',
      (tester) async {
        await _pumpExample(tester);
        final semantics = tester.ensureSemantics();
        if (dark) {
          _chip(tester, 'Dark theme').onSelected!(true);
          await tester.pumpAndSettle();
        }
        _chip(tester, 'Comparison canvas').onSelected!(true);
        await tester.pumpAndSettle();
        final pixels = await _pixels(tester);
        final canvasElement = tester.element(_canvas);
        expect(
          find.ancestor(
            of: _canvas,
            matching: find.byWidgetPredicate(
              (widget) => widget is IgnorePointer && widget.ignoring,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: _canvas, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
        expect(
          Theme.of(canvasElement).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        expect(
          tester.getSemantics(
            find.widgetWithText(FilterChip, 'Comparison canvas'),
          ),
          matchesSemantics(
            label: 'Comparison canvas',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            isSelected: true,
            hasSelectedState: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        _chip(tester, 'Reduce motion').onSelected!(true);
        await tester.pumpAndSettle();
        expect(MediaQuery.disableAnimationsOf(tester.element(_canvas)), isTrue);
        expect(await _pixels(tester), orderedEquals(pixels));
        final featured = find.descendant(
          of: find.byType(CustomGlassNavigationDockWidget),
          matching: find.text('Featured'),
        );
        await tester.tap(featured);
        await tester.pumpAndSettle();
        expect(_dock(tester).selectedIndex, 1);
        expect(await _pixels(tester), orderedEquals(pixels));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'canvas anchor follows the dock bottom reserve, not safe-area height',
    (tester) async {
      await _pumpExample(tester);
      addTearDown(tester.view.resetViewPadding);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      await tester.pumpAndSettle();
      _chip(tester, 'Comparison canvas').onSelected!(true);
      await tester.pumpAndSettle();
      final before = await _pixels(tester);
      final canvasBefore = tester.getRect(_canvas);
      expect(canvasBefore.height, 264);

      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.physicalSize = const Size(390, 1800);
      await tester.pumpAndSettle();
      final after = await _pixels(tester);
      expect(tester.getRect(_canvas).height, 288);
      // A different reserve adds identical rows to the Y-invariant fixture.
      expect(after.sublist(0, before.length), orderedEquals(before));
      expect(tester.getRect(_canvas).top + 240, 1800 - 48);
      final stride = 390 * 4;
      for (var row = 1; row < 288; row++) {
        expect(
          after.sublist(row * stride, (row + 1) * stride),
          orderedEquals(after.sublist(0, stride)),
          reason: 'Every vertical position receives identical color bars.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}

final _canvas = find.byKey(const ValueKey('comparison-canvas'));

Future<void> _pumpExample(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 2400);
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

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<Uint8List> _pixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(_canvas);
      final image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;
