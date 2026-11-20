import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// These synthetic widget checks exercise portable mechanics, not UIKit timing.
const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _duration = Duration(milliseconds: 200);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  test('selection deformation remains opt-in', () {
    expect(
      const AppGlassNavigationStyle().animateSelectionDeformation,
      isFalse,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'accepted tap widens/flattens then rests in ${brightness.name}',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pump(
          tester,
          selected,
          brightness: brightness,
          requests: requests,
        );
        final resting = tester.getSize(_capsule);
        final targets = [
          for (final label in _labels) tester.getRect(_target(label)),
        ];
        await tester.tap(_target('Inbox'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        _expectDeformed(tester);
        expect(requests, [2]);
        expect(selected.value, 2);
        for (var i = 0; i < _labels.length; i++) {
          expect(tester.getRect(_target(_labels[i])), targets[i]);
        }
        await tester.pumpAndSettle();
        _expectResting(tester);
        _expectAt(tester, 'Inbox');
        expect(tester.getSize(_capsule).width, closeTo(resting.width, 0.001));
        expect(tester.getSize(_capsule).height, closeTo(resting.height, 0.001));
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('rejected tap has no selection pulse in ${brightness.name}', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pump(
        tester,
        selected,
        brightness: brightness,
        acceptRequests: false,
        requests: requests,
      );
      final before = tester.getRect(_capsule);
      await tester.tap(_target('Profile'));
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _expectResting(tester);
        expect(tester.getRect(_capsule), before);
      }
      expect(requests, [4]);
      expect(selected.value, 0);
    });
  }

  testWidgets(
    'default-disabled pulse preserves translation without deformation',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pump(tester, selected, enabled: false);
      selected.value = 4;
      await tester.pump();
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _expectResting(tester);
      }
      await tester.pumpAndSettle();
      _expectAt(tester, 'Profile');
    },
  );

  testWidgets('rapid authoritative retarget preserves current deformation', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    selected.value = 4;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    _expectDeformed(tester);
    final before = _scales(tester);
    selected.value = 1;
    await tester.pump();
    final after = _scales(tester);
    expect(after.$1, closeTo(before.$1, 0.001));
    expect(after.$2, closeTo(before.$2, 0.001));
    await tester.pumpAndSettle();
    _expectResting(tester);
    _expectAt(tester, 'Saved');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('pointer pressure and transition pulse combine by maximum', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    final gesture = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final fullPressure = _scales(tester);
    expect(fullPressure.$1, closeTo(1.2, 0.001));
    expect(fullPressure.$2, closeTo(0.88, 0.001));
    selected.value = 2;
    await tester.pump();
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = _scales(tester);
      expect(scale.$1, lessThanOrEqualTo(1.20001));
      expect(scale.$2, greaterThanOrEqualTo(0.87999));
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    _expectResting(tester);
  });

  testWidgets(
    'active scrub has the same pressure trajectory with pulse opted in',
    (tester) async {
      final trajectories = <List<(double, double)>>[];
      for (final enabled in [false, true]) {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(tester, selected, enabled: enabled);
        final gesture = await tester.startGesture(
          tester.getCenter(_target('Browse')),
        );
        await gesture.moveTo(tester.getCenter(_target('Saved')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        for (final label in ['Inbox', 'Updates', 'Profile']) {
          await gesture.moveTo(tester.getCenter(_target(label)));
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(selected.value, 4);
        await gesture.up();
        await tester.pump();
        final trajectory = <(double, double)>[];
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          trajectory.add(_scales(tester));
        }
        trajectories.add(trajectory);
        await tester.pumpAndSettle();
        _expectResting(tester);
        await tester.pumpWidget(const SizedBox());
      }
      for (var frame = 0; frame < trajectories.first.length; frame++) {
        expect(
          trajectories.last[frame].$1,
          closeTo(trajectories.first[frame].$1, 0.001),
        );
        expect(
          trajectories.last[frame].$2,
          closeTo(trajectories.first[frame].$2, 0.001),
        );
      }
    },
  );

  testWidgets('reduced motion initially and live suppresses the pulse', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    final reduceMotion = ValueNotifier(true);
    addTearDown(selected.dispose);
    addTearDown(reduceMotion.dispose);
    await _pump(tester, selected, reduceMotion: reduceMotion);
    selected.value = 4;
    await tester.pump();
    _expectResting(tester);
    _expectAt(tester, 'Profile');
    reduceMotion.value = false;
    await tester.pump();
    selected.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    _expectDeformed(tester);
    reduceMotion.value = true;
    await tester.pump();
    _expectResting(tester);
    _expectAt(tester, 'Saved');
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('zero duration initially and live cancels deformation', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    final duration = ValueNotifier(Duration.zero);
    addTearDown(selected.dispose);
    addTearDown(duration.dispose);
    await _pump(tester, selected, duration: duration);
    selected.value = 4;
    await tester.pump();
    _expectResting(tester);
    _expectAt(tester, 'Profile');
    duration.value = _duration;
    await tester.pump();
    selected.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    _expectDeformed(tester);
    duration.value = Duration.zero;
    await tester.pump();
    _expectResting(tester);
    _expectAt(tester, 'Saved');
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'style opt-out clears an active pulse without stale deformation',
    (tester) async {
      final selected = ValueNotifier(0);
      final enabled = ValueNotifier(true);
      addTearDown(selected.dispose);
      addTearDown(enabled.dispose);
      await _pump(tester, selected, enabledPreference: enabled);
      selected.value = 4;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      _expectDeformed(tester);
      enabled.value = false;
      await tester.pump();
      _expectResting(tester);
      await tester.pumpAndSettle();
      _expectAt(tester, 'Profile');
      selected.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      _expectResting(tester);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('destination topology changes clear an active pulse', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    final labels = ValueNotifier<List<String>>(_labels);
    addTearDown(selected.dispose);
    addTearDown(labels.dispose);
    await _pump(tester, selected, labels: labels);
    selected.value = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    _expectDeformed(tester);
    labels.value = _labels.take(3).toList();
    await tester.pump();
    _expectResting(tester);
    await tester.pumpAndSettle();
    _expectAt(tester, 'Inbox');
    await tester.tap(_target('Browse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    _expectDeformed(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      '${direction.name} pulse and positional overshoot stay inside pill',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(tester, selected, direction: direction);
        final surface = tester.getRect(
          find.ancestor(of: _capsule, matching: find.byType(ClipRRect)).last,
        );
        for (final index in [4, 0]) {
          selected.value = index;
          await tester.pump();
          for (var frame = 0; frame < 50; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final lens = tester.getRect(_capsule);
            expect(lens.isFinite, isTrue);
            expect(lens.left, greaterThanOrEqualTo(surface.left - 0.001));
            expect(lens.right, lessThanOrEqualTo(surface.right + 0.001));
            expect(lens.top, greaterThanOrEqualTo(surface.top - 0.001));
            expect(lens.bottom, lessThanOrEqualTo(surface.bottom + 0.001));
          }
          await tester.pumpAndSettle();
          _expectResting(tester);
          _expectAt(tester, _labels[index]);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  bool enabled = true,
  ValueNotifier<bool>? enabledPreference,
  ValueNotifier<bool>? reduceMotion,
  ValueNotifier<Duration>? duration,
  ValueNotifier<List<String>>? labels,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  bool acceptRequests = true,
  List<int>? requests,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => AnimatedBuilder(
        animation: Listenable.merge([?reduceMotion]),
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion?.value ?? false),
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
      home: Scaffold(
        bottomNavigationBar: AnimatedBuilder(
          animation: Listenable.merge([
            selected,
            ?enabledPreference,
            ?duration,
            ?labels,
          ]),
          builder: (context, _) => CustomFlutterGlassNavigationDockWidget(
            items: [
              for (final label in labels?.value ?? _labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: selected.value,
            onItemSelected: (index) {
              requests?.add(index);
              if (acceptRequests) selected.value = index;
            },
            style: AppGlassNavigationStyle(
              animateSelectionDeformation: enabledPreference?.value ?? enabled,
              duration: duration?.value ?? _duration,
              horizontalInset: 18,
              horizontalContentInset: 8,
              selectionHorizontalInset: 0,
              selectionHorizontalOutset: 4,
              selectionVerticalInset: 2,
              labelStyle: const TextStyle(fontSize: 8, height: 1.35),
              selectionSpring: const SpringDescription(
                mass: 1,
                stiffness: 560,
                damping: 12,
              ),
              pressureStretch: 0.2,
              pressedScale: 0.88,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

(double, double) _scales(WidgetTester tester) {
  final transform = tester
      .widget<Transform>(
        find.ancestor(of: _capsule, matching: find.byType(Transform)).first,
      )
      .transform
      .storage;
  return (transform[0], transform[5]);
}

void _expectResting(WidgetTester tester) {
  final scale = _scales(tester);
  expect(scale.$1, closeTo(1, 0.001));
  expect(scale.$2, closeTo(1, 0.001));
}

void _expectDeformed(WidgetTester tester) {
  final scale = _scales(tester);
  expect(scale.$1, greaterThan(1.001));
  expect(scale.$2, lessThan(0.999));
}

void _expectAt(WidgetTester tester, String label) => expect(
  tester.getCenter(_capsule).dx,
  closeTo(tester.getCenter(_target(label)).dx, 0.001),
);
