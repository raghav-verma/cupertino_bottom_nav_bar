import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// Synthetic portable ownership checks, not native motion calibration.
const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _duration = Duration(milliseconds: 200);
const _recovery = 0.3;
const _style = AppGlassNavigationStyle(
  duration: _duration,
  curve: Curves.linear,
  pressedScale: 1.18,
  pressureStretch: 0.2,
  releaseVerticalStretch: _recovery,
  animateSelectionDeformation: false,
  trackVerticalDrag: true,
  scrubSelectionPolicy:
      AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
  labelStyle: TextStyle(fontSize: 8, height: 1.35),
);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'owner UP produces one bounded recovery in ${brightness.name}',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(tester, selected, brightness: brightness);
        final restingHeight = _paintedHeight(tester);
        final targets = [
          for (final label in _labels) tester.getRect(_target(label)),
        ];
        final gesture = await _hold(tester);
        _expectScale(tester, 1.2, 1.18);
        await gesture.up();
        await tester.pump();
        _expectScale(tester, 1.2, 1.18);
        await tester.pump(const Duration(milliseconds: 100));
        _expectScale(tester, 1.1, 1.09 + _recovery);
        expect(
          _paintedHeight(tester),
          closeTo(restingHeight * (1.09 + _recovery), 0.001),
        );
        expect(selected.value, 0);
        for (var index = 0; index < targets.length; index++) {
          expect(tester.getRect(_target(_labels[index])), targets[index]);
        }
        await tester.pump(_duration ~/ 2);
        _expectScale(tester, 1, 1);
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets(
    'accepted scrub continues the same release hump without restart',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pump(tester, selected, requests: requests);
      final gesture = await _hold(tester);
      await gesture.moveTo(tester.getCenter(_target('Profile')));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(selected.value, 0);
      await gesture.up();
      await tester.pump();
      expect(requests, [4]);
      expect(selected.value, 4);
      await tester.pump(const Duration(milliseconds: 100));
      _expectScale(tester, 1.1, 1.09 + _recovery);
      await tester.pump(const Duration(milliseconds: 100));
      _expectScale(tester, 1, 1);
      await tester.pumpAndSettle();
      _expectAt(tester, 'Profile');
      expect(requests, [4]);
    },
  );

  testWidgets('actual CANCEL decays pressure without a release hump', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pump(tester, selected, requests: requests);
    final gesture = await _hold(tester);
    await gesture.moveTo(tester.getCenter(_target('Profile')));
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectScale(tester, 1.1, 1.09);
    await tester.pumpAndSettle();
    _expectScale(tester, 1, 1);
    _expectAt(tester, 'Browse');
    expect(requests, isEmpty);
    expect(selected.value, 0);
  });

  testWidgets('new owner press suppresses the old recovery immediately', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    final oldOwner = await _hold(tester);
    await oldOwner.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectScale(tester, 1.1, 1.09 + _recovery);
    final newOwner = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pump();
    _expectScale(tester, 1.1, 1.09);
    await tester.pump(const Duration(milliseconds: 100));
    _expectScale(tester, 1.15, 1.135);
    await newOwner.cancel();
    await tester.pumpAndSettle();
    _expectScale(tester, 1, 1);
  });

  testWidgets(
    'unrelated non-preview contact cannot inherit residual recovery',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      // A nongrowing lens gives an unselected tap no contact-preview ownership.
      await _pump(
        tester,
        selected,
        style: _style.copyWith(pressedScale: 0.88),
        acceptRequests: false,
        requests: requests,
      );
      final oldOwner = await _hold(tester);
      await oldOwner.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      _expectScale(tester, 1.1, 0.94 + _recovery);
      final unrelated = await tester.startGesture(
        tester.getCenter(_target('Inbox')),
      );
      await tester.pump();
      _expectScale(tester, 1.1, 0.94);
      await unrelated.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      _expectScale(tester, 1.05, 0.97);
      expect(selected.value, 0);
      expect(requests, [0, 2]);
      await tester.pumpAndSettle();
      _expectScale(tester, 1, 1);
      _expectAt(tester, 'Browse');
    },
  );

  testWidgets('host change before owner UP cannot start unrelated recovery', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected, acceptRequests: false);
    final gesture = await _hold(tester);
    selected.value = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    _expectScale(tester, 1.12, 1.108);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    _expectScale(tester, 1.08, 1.072);
    expect(selected.value, 2);
    await tester.pumpAndSettle();
    _expectScale(tester, 1, 1);
    _expectAt(tester, 'Inbox');
  });

  testWidgets(
    'mid-recovery host retarget preserves one continuous bounded hump',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pump(tester, selected, acceptRequests: false);
      final gesture = await _hold(tester);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final before = _scales(tester);
      final beforeRect = tester.getRect(_capsule);
      _expectScale(tester, 1.15, 1.135 + _recovery * math.sin(math.pi / 4));
      selected.value = 2;
      await tester.pump();
      expect(_scales(tester), before);
      expect(tester.getRect(_capsule), beforeRect);
      await tester.pump(const Duration(milliseconds: 50));
      _expectScale(tester, 1.1, 1.09 + _recovery);
      // A host retarget is not a new contact. It must neither restart nor add a
      // hump; the original release reaches zero at its original 200ms endpoint.
      await tester.pump(const Duration(milliseconds: 100));
      _expectScale(tester, 1, 1);
      await tester.pumpAndSettle();
      _expectAt(tester, 'Inbox');
      expect(selected.value, 2);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  AppGlassNavigationStyle style = _style,
  Brightness brightness = Brightness.light,
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
      home: AnimatedBuilder(
        animation: selected,
        builder: (context, _) => Scaffold(
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
              requests?.add(index);
              if (acceptRequests) selected.value = index;
            },
            style: style,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(_target('Browse')),
  );
  await tester.pumpAndSettle();
  return gesture;
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

(double, double) _scales(WidgetTester tester) {
  final matrix = tester
      .widget<Transform>(
        find.ancestor(of: _capsule, matching: find.byType(Transform)).first,
      )
      .transform;
  return (matrix.entry(0, 0), matrix.entry(1, 1));
}

void _expectScale(WidgetTester tester, double horizontal, double vertical) {
  final scales = _scales(tester);
  expect(scales.$1, closeTo(horizontal, 0.0001));
  expect(scales.$2, closeTo(vertical, 0.0001));
}

double _paintedHeight(WidgetTester tester) =>
    tester.getBottomRight(_capsule).dy - tester.getTopLeft(_capsule).dy;

void _expectAt(WidgetTester tester, String label) => expect(
  tester.getCenter(_capsule).dx,
  closeTo(tester.getCenter(_target(label)).dx, 0.001),
);
