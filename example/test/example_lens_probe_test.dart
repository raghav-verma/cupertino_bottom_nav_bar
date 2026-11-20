import 'package:flutter_test/flutter_test.dart';
import 'package:glass_navigation_dock_example/main.dart' as example;
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final cancel in [false, true]) {
    testWidgets(
      'unarmed ${cancel ? 'CANCEL' : 'UP'} keeps probe UI unchanged',
      (tester) async {
        await _pumpExample(tester);
        final listener = _probeListener(tester);
        final chip = _probeChip(tester);
        final status = _probeStatus(tester);
        final style = _dock(tester).style;

        listener.onPointerDown!(const PointerDownEvent(pointer: 10));
        await tester.pump(const Duration(seconds: 3));
        expect(_probeChip(tester), same(chip));
        expect(_probeStatus(tester), same(status));
        expect(_dock(tester).style, same(style));
        _end(listener, 10, cancel: cancel);
        await tester.pump();
        expect(_probeChip(tester), same(chip));
        expect(_probeStatus(tester), same(status));
        expect(_dock(tester).style, same(style));
        expect(_dock(tester).selectedIndex, 0);
        expect(find.text('No selection requests yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late arming refuses the silent owner until its own end', (
    tester,
  ) async {
    await _pumpExample(tester);
    final listener = _probeListener(tester);
    final style = _dock(tester).style;
    listener.onPointerDown!(const PointerDownEvent(pointer: 10));
    listener.onPointerDown!(const PointerDownEvent(pointer: 11));
    await tester.pump();
    expect(_probeChip(tester).onSelected, isNotNull);
    _probeChip(tester).onSelected!(true);
    await tester.pump();
    expect(_probeChip(tester).selected, isFalse);
    expect(_probeChip(tester).onSelected, isNull);
    expect(
      find.textContaining('Release this dock contact before arming'),
      findsOneWidget,
    );
    final refusedStatus = _probeStatus(tester);
    _end(listener, 11, cancel: true);
    await tester.pump(const Duration(seconds: 3));
    expect(_probeStatus(tester), same(refusedStatus));
    expect(_dock(tester).style, same(style));
    expect(_probeChip(tester).onSelected, isNull);
    _end(listener, 10);
    await tester.pump();
    expect(_probeChip(tester).onSelected, isNotNull);
    expect(
      find.textContaining('Ready to arm the next contact'),
      findsOneWidget,
    );
    _probeChip(tester).onSelected!(true);
    await tester.pump();
    expect(_probeChip(tester).selected, isTrue);
    // End the diagnostic explicitly so no timer/armed state survives the test.
    _probeChip(tester).onSelected!(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('armed owner fires both directions without selection requests', (
    tester,
  ) async {
    await _pumpExample(tester);
    final listener = _probeListener(tester);
    final originalScale = _dock(tester).style.pressedScale;
    expect(originalScale, greaterThan(1));
    for (var direction = 0; direction < 2; direction++) {
      final owner = 10 + direction;
      _probeChip(tester).onSelected!(true);
      listener.onPointerDown!(PointerDownEvent(pointer: owner));
      listener.onPointerDown!(const PointerDownEvent(pointer: 20));
      _end(listener, 20, cancel: true);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(_probeChip(tester).selected, isTrue);
      expect(
        _dock(tester).style.pressedScale,
        direction == 0 ? originalScale : 1.0,
      );
      expect(
        find.textContaining('Owner DOWN: lens switch pending'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        _dock(tester).style.pressedScale,
        direction == 0 ? 1.0 : originalScale,
      );
      expect(_probeChip(tester).selected, isFalse);
      expect(_probeChip(tester).onSelected, isNull);
      expect(
        find.textContaining('host index 0; request count 0'),
        findsOneWidget,
      );
      _end(listener, owner);
      await tester.pump();
      expect(_probeChip(tester).onSelected, isNotNull);
    }
    expect(_dock(tester).selectedIndex, 0);
    expect(find.text('No selection requests yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'armed early ${cancel ? 'CANCEL' : 'UP'} cancels the deadline',
      (tester) async {
        await _pumpExample(tester);
        final listener = _probeListener(tester);
        final style = _dock(tester).style;
        _probeChip(tester).onSelected!(true);
        listener.onPointerDown!(const PointerDownEvent(pointer: 10));
        await tester.pump(const Duration(seconds: 1));
        _end(listener, 10, cancel: cancel);
        await tester.pump(const Duration(seconds: 2));
        expect(_dock(tester).style, same(style));
        expect(_probeChip(tester).selected, isFalse);
        expect(_probeChip(tester).onSelected, isNotNull);
        expect(
          find.textContaining(
            'Pending switch cancelled by owner ${cancel ? 'CANCEL' : 'UP'}.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('explicit disarm cancels pending work and retains owner', (
    tester,
  ) async {
    await _pumpExample(tester);
    final listener = _probeListener(tester);
    final style = _dock(tester).style;
    _probeChip(tester).onSelected!(true);
    listener.onPointerDown!(const PointerDownEvent(pointer: 10));
    await tester.pump(const Duration(seconds: 1));
    _probeChip(tester).onSelected!(false);
    await tester.pump(const Duration(seconds: 2));
    expect(_dock(tester).style, same(style));
    expect(_probeChip(tester).onSelected, isNull);
    expect(find.textContaining('Probe disarmed'), findsOneWidget);
    _end(listener, 10, cancel: true);
    await tester.pump();
    expect(_probeChip(tester).onSelected, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final armed in [false, true]) {
    testWidgets('Reset retains ${armed ? 'armed' : 'silent'} raw ownership', (
      tester,
    ) async {
      await _pumpExample(tester);
      final listener = _probeListener(tester);
      if (armed) _probeChip(tester).onSelected!(true);
      listener.onPointerDown!(const PointerDownEvent(pointer: 10));
      listener.onPointerDown!(const PointerDownEvent(pointer: 11));
      await tester.pump(const Duration(seconds: 1));
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
          .onPressed!();
      await tester.pump(const Duration(seconds: 2));
      final resetStatus = _probeStatus(tester);
      expect(find.textContaining('Probe reset: disarmed'), findsOneWidget);
      expect(_dock(tester).style.pressedScale, greaterThan(1));
      expect(_probeChip(tester).onSelected, isNull);
      _end(listener, 11);
      await tester.pump();
      expect(_probeStatus(tester), same(resetStatus));
      expect(_probeChip(tester).onSelected, isNull);
      _end(listener, 10, cancel: true);
      await tester.pump();
      expect(_probeChip(tester).onSelected, isNotNull);
      _probeChip(tester).onSelected!(true);
      listener.onPointerDown!(const PointerDownEvent(pointer: 12));
      await tester.pump(const Duration(seconds: 2));
      expect(_dock(tester).style.pressedScale, 1.0);
      _end(listener, 12);
      await tester.pump();
      expect(_dock(tester).selectedIndex, 0);
      expect(find.text('No selection requests yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpExample(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  example.main();
  await tester.pumpAndSettle();
}

// Exercise the example's raw observer, not a synthetic dock gesture. Actual
// owned contact/dock retention is covered by example_selection_isolation_test.
Listener _probeListener(WidgetTester tester) {
  Listener? listener;
  tester
      .element(find.byType(CustomGlassNavigationDockWidget))
      .visitAncestorElements((element) {
        if (element.widget case final Listener widget) {
          listener = widget;
          return false;
        }
        return true;
      });
  return listener!;
}

void _end(Listener listener, int owner, {bool cancel = false}) {
  if (cancel) {
    listener.onPointerCancel!(PointerCancelEvent(pointer: owner));
  } else {
    listener.onPointerUp!(PointerUpEvent(pointer: owner));
  }
}

FilterChip _probeChip(WidgetTester tester) =>
    tester.widget(find.widgetWithText(FilterChip, 'Arm 2s lens switch'));

Text _probeStatus(WidgetTester tester) =>
    tester.widget(find.textContaining('Live lens diagnostic'));

CustomGlassNavigationDockWidget _dock(WidgetTester tester) =>
    tester.widget(find.byType(CustomGlassNavigationDockWidget));
