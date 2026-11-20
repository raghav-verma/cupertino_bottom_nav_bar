import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// Synthetic portable motion checks, not UIKit trajectory or timing calibration.
const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _style = AppGlassNavigationStyle(
  pressedScale: 1.18,
  pressureStretch: 0.2,
  scrubMotionStretch: 0.2,
  scrubMotionFlattening: 0.2,
  duration: Duration(milliseconds: 200),
  curve: Curves.linear,
  trackVerticalDrag: true,
  scrubSelectionPolicy:
      AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
  labelStyle: TextStyle(fontSize: 8, height: 1.35),
);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  test(
    'motion customization is neutral, independently overridable and safe',
    () {
      const defaults = AppGlassNavigationStyle();
      expect(defaults.scrubMotionStretch, 0);
      expect(defaults.scrubMotionFlattening, 0);
      expect(_style.copyWith().scrubMotionStretch, 0.2);
      expect(_style.copyWith().scrubMotionFlattening, 0.2);
      final override = _style.copyWith(
        scrubMotionStretch: 0.3,
        scrubMotionFlattening: 0.4,
      );
      expect(override.resolvedScrubMotionStretch, 0.3);
      expect(override.resolvedScrubMotionFlattening, 0.4);
      expect(
        override.copyWith(scrubMotionStretch: null).scrubMotionStretch,
        0.3,
      );
      expect(
        override.copyWith(scrubMotionFlattening: null).scrubMotionFlattening,
        0.4,
      );
      for (final brightness in Brightness.values) {
        final theme = ThemeData(brightness: brightness);
        final themedDefaults = AppGlassNavigationStyle.fromTheme(theme);
        expect(themedDefaults.scrubMotionStretch, 0);
        expect(themedDefaults.scrubMotionFlattening, 0);
        final themed = AppGlassNavigationStyle.fromTheme(
          theme,
          scrubMotionStretch: 0.3,
          scrubMotionFlattening: 0.4,
        );
        expect(themed.resolvedScrubMotionStretch, 0.3);
        expect(themed.resolvedScrubMotionFlattening, 0.4);
        expect(themed.surfaceColor, themedDefaults.surfaceColor);
      }
      for (final invalid in [-0.1, 1.1, double.nan, double.infinity]) {
        expect(
          () => AppGlassNavigationStyle(scrubMotionStretch: invalid),
          throwsAssertionError,
        );
        expect(
          () => _style.copyWith(scrubMotionStretch: invalid),
          throwsAssertionError,
        );
        expect(
          () => AppGlassNavigationStyle.fromTheme(
            ThemeData.light(),
            scrubMotionStretch: invalid,
          ),
          throwsAssertionError,
        );
        expect(
          _UncheckedMotionStyle(stretch: invalid).resolvedScrubMotionStretch,
          0,
        );
      }
      for (final invalid in [-0.1, 1.0, double.nan, double.infinity]) {
        expect(
          () => AppGlassNavigationStyle(scrubMotionFlattening: invalid),
          throwsAssertionError,
        );
        expect(
          () => _style.copyWith(scrubMotionFlattening: invalid),
          throwsAssertionError,
        );
        expect(
          () => AppGlassNavigationStyle.fromTheme(
            ThemeData.dark(),
            scrubMotionFlattening: invalid,
          ),
          throwsAssertionError,
        );
        expect(
          _UncheckedMotionStyle(flattening: invalid)
              .resolvedScrubMotionFlattening,
          0,
        );
      }
      expect(
        const AppGlassNavigationStyle(scrubMotionStretch: 1)
            .resolvedScrubMotionStretch,
        1,
      );
    },
  );

  for (final brightness in Brightness.values) {
    for (final spring in [false, true]) {
      testWidgets('movement stretches and flattens; held pause recovers in '
          '${brightness.name} ${spring ? 'spring' : 'timed'} mode', (
        tester,
      ) async {
        final fixture = _Fixture(
          style: _style.copyWith(
            selectionSpring: spring
                ? const SpringDescription(mass: 1, stiffness: 500, damping: 34)
                : null,
          ),
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester, brightness: brightness);
        final targets = [
          for (final label in _labels) tester.getRect(_target(label)),
        ];
        final gesture = await _hold(tester);
        final held = _size(tester);
        await _move(tester, gesture, const Offset(8, 0), frames: 5);
        final moving = _size(tester);
        expect(moving.width, greaterThan(held.width + 0.1));
        expect(moving.height, lessThan(held.height - 0.1));
        expect(fixture.requests, isEmpty);
        expect(fixture.selected.value, 2);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Inbox'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        for (var index = 0; index < targets.length; index++) {
          expect(tester.getRect(_target(_labels[index])), targets[index]);
        }
        await tester.pumpAndSettle();
        _expectSize(_size(tester), held);
        expect(tester.binding.transientCallbackCount, 0);
        // A duplicate sample must not excite a fresh movement pulse.
        await gesture.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 16));
        _expectSize(_size(tester), held);
        await gesture.cancel();
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('reversals preserve shape and recover without a stuck pulse', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final gesture = await _hold(tester);
    final held = _size(tester);
    await _move(tester, gesture, const Offset(8, 0), frames: 5);
    final before = _size(tester);
    await gesture.moveBy(const Offset(-8, 0));
    await tester.pump();
    _expectSize(_size(tester), before);
    await _move(tester, gesture, const Offset(-8, 0), frames: 5);
    final reversed = _size(tester);
    expect(reversed.width, greaterThan(held.width));
    expect(reversed.height, lessThan(held.height));
    expect(reversed.width, lessThanOrEqualTo(held.width * 1.2 + 0.001));
    expect(reversed.height, greaterThanOrEqualTo(held.height * 0.8 - 0.001));
    await tester.pumpAndSettle();
    _expectSize(_size(tester), held);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(fixture.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final accept in [false, true]) {
    testWidgets(
      '${accept ? 'accepted' : 'rejected'} release continues live shape and settles to host',
      (tester) async {
        final fixture = _Fixture(accept: accept);
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        final gesture = await _hold(tester);
        await _move(tester, gesture, const Offset(8, 0), frames: 5);
        final moving = _size(tester);
        await gesture.up();
        await tester.pump();
        _expectSize(_size(tester), moving);
        expect(fixture.requests, [3]);
        expect(fixture.selected.value, accept ? 3 : 2);
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(_capsule).dx,
          closeTo(
            tester.getCenter(_target(accept ? 'Updates' : 'Inbox')).dx,
            0.001,
          ),
        );
        expect(_scales(tester), (1.0, 1.0));
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets('cancel and regrab preserve shape then clear stale motion', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    var gesture = await _hold(tester);
    await _move(tester, gesture, const Offset(8, 0), frames: 5);
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final recovering = _size(tester);
    gesture = await tester.startGesture(tester.getCenter(_capsule));
    await tester.pump();
    _expectSize(_size(tester), recovering);
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.2, 1.18));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(fixture.requests, isEmpty);
    expect(_scales(tester), (1.0, 1.0));
    await tester.tap(_target('Saved'));
    await tester.pumpAndSettle();
    expect(fixture.requests, [1]);
    expect(tester.takeException(), isNull);
  });

  for (final zeroDuration in [false, true]) {
    testWidgets(
      '${zeroDuration ? 'zero duration' : 'reduced motion'} suppresses initial and live deformation',
      (tester) async {
        final fixture = _Fixture(
          style: _style.copyWith(
            duration: zeroDuration ? Duration.zero : _style.duration,
          ),
          reduced: !zeroDuration,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        var gesture = await _hold(tester);
        await _move(tester, gesture, const Offset(8, 0), frames: 5);
        expect(_scales(tester), (1.0, 1.0));
        await gesture.cancel();
        await tester.pumpAndSettle();
        fixture.style.value = _style;
        fixture.reduced.value = false;
        await tester.pumpAndSettle();
        gesture = await _hold(tester);
        await _move(tester, gesture, const Offset(8, 0), frames: 5);
        expect(_scales(tester).$2, lessThan(1.18));
        if (zeroDuration) {
          fixture.style.value = _style.copyWith(duration: Duration.zero);
        } else {
          fixture.reduced.value = true;
        }
        await tester.pump();
        expect(_scales(tester), (1.0, 1.0));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets('default motion inputs preserve ordinary moving pressure shape', (
    tester,
  ) async {
    final fixture = _Fixture(
      style: _style.copyWith(scrubMotionStretch: 0, scrubMotionFlattening: 0),
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final gesture = await _hold(tester);
    final held = _size(tester);
    await _move(tester, gesture, const Offset(8, 0), frames: 5);
    _expectSize(_size(tester), held);
    expect(_scales(tester), (1.2, 1.18));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'live style removal clears motion and reflow cancels old ownership',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final gesture = await _hold(tester);
      final held = _size(tester);
      await _move(tester, gesture, const Offset(8, 0), frames: 5);
      expect(_size(tester).width, greaterThan(held.width));
      fixture.style.value = _style.copyWith(
        scrubMotionStretch: 0,
        scrubMotionFlattening: 0,
      );
      await tester.pump();
      _expectSize(_size(tester), held);
      await tester.pumpAndSettle();
      _expectSize(_size(tester), held);
      fixture.style.value = _style;
      await tester.pumpAndSettle();
      await _move(tester, gesture, const Offset(-8, 0), frames: 4);
      tester.view.physicalSize = const Size(350, 844);
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.requests, isEmpty);
      expect(_scales(tester), (1.0, 1.0));
      await tester.tap(_target('Saved'));
      await tester.pumpAndSettle();
      expect(fixture.requests, [1]);
    },
  );

  testWidgets('scrolling long-press drag ignores motion deformation', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, width: 240);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await _move(tester, gesture, const Offset(8, 0), frames: 5);
    expect(_scales(tester), (1.2, 1.18));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'coarse and fine samples deform the same path without input starvation',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final results = <(double, double)>[];
      for (final steps in [4, 16]) {
        final gesture = await _hold(tester);
        // Start the simulation at the same owner position and clock phase.
        await gesture.moveBy(const Offset(1, 0));
        await tester.pump();
        for (var step = 0; step < steps; step++) {
          final interval = Duration(milliseconds: 128 ~/ steps);
          await gesture.moveBy(
            Offset(32 / steps, 0),
            timeStamp: tester.binding.currentSystemFrameTimeStamp + interval,
          );
          await tester.pump(interval);
        }
        results.add(_scales(tester));
        expect(_scales(tester).$1, greaterThan(1.2));
        expect(_scales(tester).$2, lessThan(1.18));
        await tester.pumpAndSettle();
        expect(_scales(tester), (1.2, 1.18));
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
      expect(results.last.$1, closeTo(results.first.$1, 0.03));
      expect(results.last.$2, closeTo(results.first.$2, 0.03));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'large alternating moves remain bounded and cannot store a stuck pulse',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final gesture = await _hold(tester);
      for (final delta in [10000.0, -20000.0, 20000.0, -10000.0]) {
        await _move(tester, gesture, Offset(delta, 0));
        final scale = _scales(tester);
        expect(scale.$1, inInclusiveRange(1.2, 1.44));
        expect(scale.$2, inInclusiveRange(1.18 * 0.8, 1.18));
      }
      await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(_scales(tester), (1.2, 1.18));
      expect(fixture.requests, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  _Fixture({
    AppGlassNavigationStyle style = _style,
    this.accept = true,
    bool reduced = false,
  }) : style = ValueNotifier(style),
       reduced = ValueNotifier(reduced);

  final ValueNotifier<AppGlassNavigationStyle> style;
  final ValueNotifier<int> selected = ValueNotifier(2);
  final ValueNotifier<bool> reduced;
  final bool accept;
  final requests = <int>[];

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: AnimatedBuilder(
          animation: Listenable.merge([style, selected, reduced]),
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduced.value),
            child: Scaffold(
              body: Text('Host: ${selected.value}'),
              bottomNavigationBar: CustomFlutterGlassNavigationDockWidget(
                items: [
                  for (final label in _labels)
                    AppGlassNavigationItem(
                      icon: Icons.circle_outlined,
                      label: label,
                    ),
                ],
                selectedIndex: selected.value,
                onItemSelected: (index) {
                  requests.add(index);
                  if (accept) selected.value = index;
                },
                style: style.value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    style.dispose();
    selected.dispose();
    reduced.dispose();
  }
}

class _UncheckedMotionStyle extends AppGlassNavigationStyle {
  const _UncheckedMotionStyle({this.stretch = 0, this.flattening = 0});

  final double stretch;
  final double flattening;

  @override
  double get scrubMotionStretch => stretch;
  @override
  double get scrubMotionFlattening => flattening;
}

Future<TestGesture> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_target('Inbox')));
  await tester.pumpAndSettle();
  return gesture;
}

Future<void> _move(
  WidgetTester tester,
  TestGesture gesture,
  Offset delta, {
  int frames = 1,
}) async {
  for (var frame = 0; frame < frames; frame++) {
    await gesture.moveBy(
      delta,
      timeStamp:
          tester.binding.currentSystemFrameTimeStamp +
          const Duration(milliseconds: 16),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Size _size(WidgetTester tester) {
  final extent = tester.getBottomRight(_capsule) - tester.getTopLeft(_capsule);
  return Size(extent.dx, extent.dy);
}

(double, double) _scales(WidgetTester tester) {
  final matrix = tester
      .widget<Transform>(
        find.ancestor(of: _capsule, matching: find.byType(Transform)).first,
      )
      .transform
      .storage;
  return (matrix[0], matrix[5]);
}

void _expectSize(Size actual, Size expected) {
  expect(actual.width, closeTo(expected.width, 0.001));
  expect(actual.height, closeTo(expected.height, 0.001));
}
