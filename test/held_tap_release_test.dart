import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// Synthetic stationary-owner release checks, not native motion calibration.
const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  for (final brightness in Brightness.values) {
    for (final spring in [false, true]) {
      testWidgets(
        'accepted settled held tap has no fresh pulse in ${brightness.name}, spring $spring',
        (tester) async {
          final baseline = await _sample(
            tester,
            pulse: false,
            brightness: brightness,
            spring: spring,
          );
          final enabled = await _sample(
            tester,
            pulse: true,
            brightness: brightness,
            spring: spring,
          );
          expect(baseline.requests, [2]);
          expect(enabled.requests, [2]);
          expect(enabled.selected, 2);
          expect(enabled.heights.first, closeTo(baseline.heights.first, 0.001));
          for (var frame = 1; frame < enabled.heights.length; frame++) {
            expect(
              enabled.heights[frame],
              closeTo(baseline.heights[frame], 0.001),
              reason:
                  'Settled owner already supplied pressure; no new pulse '
                  'at ${frame * 20}ms after accepted UP',
            );
          }
        },
      );
    }

    testWidgets('rejected held tap has no fresh pulse in ${brightness.name}', (
      tester,
    ) async {
      final baseline = await _sample(
        tester,
        pulse: false,
        brightness: brightness,
        accept: false,
      );
      final enabled = await _sample(
        tester,
        pulse: true,
        brightness: brightness,
        accept: false,
      );
      expect(enabled.requests, [2]);
      expect(enabled.selected, 0);
      for (var frame = 0; frame < enabled.heights.length; frame++) {
        expect(enabled.heights[frame], closeTo(baseline.heights[frame], 0.001));
      }
    });
  }

  for (final programmatic in [false, true]) {
    testWidgets(
      '${programmatic ? 'programmatic change' : 'quick tap'} preserves opt-in pulse',
      (tester) async {
        final baseline = await _sample(
          tester,
          pulse: false,
          quick: true,
          programmatic: programmatic,
        );
        final enabled = await _sample(
          tester,
          pulse: true,
          quick: true,
          programmatic: programmatic,
        );
        expect(enabled.requests, programmatic ? isEmpty : [2]);
        expect(enabled.selected, 2);
        expect(enabled.heights[4], greaterThan(baseline.heights[4] + 1));
        expect(enabled.heights.last, closeTo(baseline.heights.last, 0.001));
      },
    );
  }

  for (final lateIndex in [2, 4]) {
    testWidgets(
      'rejected hold cannot suppress later programmatic index $lateIndex pulse',
      (tester) async {
        final baseline = await _sample(
          tester,
          pulse: false,
          accept: false,
          lateIndex: lateIndex,
        );
        final enabled = await _sample(
          tester,
          pulse: true,
          accept: false,
          lateIndex: lateIndex,
        );
        expect(enabled.requests, [2]);
        expect(enabled.selected, lateIndex);
        expect(enabled.heights[4], greaterThan(baseline.heights[4] + 1));
        expect(enabled.heights.last, closeTo(baseline.heights.last, 0.001));
      },
    );
  }

  testWidgets(
    'actual held CANCEL leaves the following quick tap pulse intact',
    (tester) async {
      final baseline = await _sample(tester, pulse: false, cancelThenTap: true);
      final enabled = await _sample(tester, pulse: true, cancelThenTap: true);
      expect(enabled.requests, [4]);
      expect(enabled.selected, 4);
      expect(enabled.heights[4], greaterThan(baseline.heights[4] + 1));
      expect(enabled.heights.last, closeTo(baseline.heights.last, 0.001));
    },
  );
}

Future<({List<double> heights, List<int> requests, int selected})> _sample(
  WidgetTester tester, {
  required bool pulse,
  Brightness brightness = Brightness.light,
  bool spring = false,
  bool accept = true,
  bool quick = false,
  bool programmatic = false,
  int? lateIndex,
  bool cancelThenTap = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final selected = ValueNotifier(0);
  final requests = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (context, index, _) => Scaffold(
          body: Text('Host: $index'),
          bottomNavigationBar: CustomFlutterGlassNavigationDockWidget(
            items: [
              for (final label in _labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: index,
            onItemSelected: (index) {
              requests.add(index);
              if (accept) selected.value = index;
            },
            style: AppGlassNavigationStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              pressedScale: 1.24 / 1.04,
              heldBarScale: 1.04,
              pressureStretch: 1.25 / 1.04 - 1,
              releaseVerticalStretch: 0,
              animateSelectionDeformation: pulse,
              selectionSpring: spring
                  ? const SpringDescription(
                      mass: 1,
                      stiffness: 560,
                      damping: 36,
                    )
                  : null,
              labelStyle: const TextStyle(fontSize: 8, height: 1.35),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (programmatic) {
    selected.value = 2;
  } else {
    final target = find
        .ancestor(of: find.text('Inbox'), matching: find.byType(InkWell))
        .first;
    final gesture = await tester.createGesture();
    await gesture.down(tester.getCenter(target), timeStamp: Duration.zero);
    await tester.pump();
    await tester.pump(Duration(milliseconds: quick ? 10 : 240));
    expect(requests, isEmpty);
    expect(selected.value, 0);
    if (cancelThenTap) {
      await gesture.cancel(timeStamp: const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(selected.value, 0);
      final nextTarget = find
          .ancestor(of: find.text('Profile'), matching: find.byType(InkWell))
          .first;
      final next = await tester.createGesture();
      await next.down(
        tester.getCenter(nextTarget),
        timeStamp: const Duration(milliseconds: 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await next.up(timeStamp: const Duration(milliseconds: 510));
    } else {
      await gesture.up(timeStamp: Duration(milliseconds: quick ? 10 : 240));
    }
  }
  await tester.pump();
  if (lateIndex != null) {
    // The rejected release's first-frame acknowledgement window has expired.
    await tester.pump(const Duration(milliseconds: 20));
    expect(selected.value, 0);
    selected.value = lateIndex;
    await tester.pump();
  }
  final heights = <double>[];
  for (var frame = 0; frame <= 12; frame++) {
    if (frame > 0) await tester.pump(const Duration(milliseconds: 20));
    heights.add(
      tester.getBottomRight(_capsule).dy - tester.getTopLeft(_capsule).dy,
    );
  }
  final result = (
    heights: heights,
    requests: List<int>.of(requests),
    selected: selected.value,
  );
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox.shrink());
  selected.dispose();
  return result;
}
