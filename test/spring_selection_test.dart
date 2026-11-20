import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _spring = SpringDescription(mass: 1, stiffness: 180, damping: 14);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  for (final entry in {
    'zero mass': const SpringDescription(mass: 0, stiffness: 560, damping: 36),
    'NaN stiffness': const SpringDescription(
      mass: 1,
      stiffness: double.nan,
      damping: 36,
    ),
    'zero damping': const SpringDescription(
      mass: 1,
      stiffness: 560,
      damping: 0,
    ),
  }.entries) {
    testWidgets('invalid ${entry.key} settles with timed fallback', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpDock(tester, selected, selectionSpring: entry.value);
      final start = tester.getCenter(_capsule).dx;
      final target = tester.getCenter(find.text('Profile')).dx;
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final moving = tester.getRect(_capsule);
      expect(moving.isFinite, isTrue);
      expect(moving.center.dx, greaterThan(start));
      expect(moving.center.dx, lessThan(target));
      await tester.pump(const Duration(milliseconds: 100));
      _expectAt(tester, 'Profile');
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('null spring retains timed movement and stops at its duration', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpDock(tester, selected, selectionSpring: null);
    final start = tester.getCenter(_capsule).dx;
    final target = tester.getCenter(find.text('Profile')).dx;
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getCenter(_capsule).dx, greaterThan(start));
    expect(tester.getCenter(_capsule).dx, lessThan(target));
    await tester.pump(const Duration(milliseconds: 100));
    _expectAt(tester, 'Profile');
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('spring translates and settles in ${brightness.name}', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpDock(tester, selected, brightness: brightness);
      final start = tester.getCenter(_capsule).dx;
      final target = tester.getCenter(find.text('Profile')).dx;

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(tester.getCenter(_capsule).dx, closeTo(start, 0.001));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(_capsule).dx, greaterThan(start));
      expect(tester.getCenter(_capsule).dx, lessThan(target));
      await tester.pumpAndSettle();
      _expectAt(tester, 'Profile');
      expect(selected.value, 4);
    });
  }

  testWidgets('rapid retargeting preserves current position and velocity', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpDock(tester, selected);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final interrupted = tester.getCenter(_capsule).dx;

    await tester.tap(find.text('Browse'));
    await tester.pump();
    expect(tester.getCenter(_capsule).dx, closeTo(interrupted, 0.001));
    // Its existing rightward momentum survives the new leftward target.
    await tester.pump(const Duration(milliseconds: 5));
    expect(tester.getCenter(_capsule).dx, greaterThan(interrupted));
    await tester.pumpAndSettle();
    _expectAt(tester, 'Browse');
    expect(selected.value, 0);
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'rejected scrub follows pointer and springs home on ${cancel ? 'cancel' : 'release'}',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpDock(
          tester,
          selected,
          acceptRequests: false,
          requests: requests,
        );
        final home = tester.getCenter(_capsule).dx;
        final pointer = tester.getCenter(find.text('Updates'));
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Browse')),
        );
        await gesture.moveTo(pointer);
        await tester.pump();
        expect(tester.getCenter(_capsule).dx, closeTo(pointer.dx, 0.001));
        expect(selected.value, 0);
        expect(requests, [3]);

        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pump();
        expect(tester.getCenter(_capsule).dx, closeTo(pointer.dx, 0.001));
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getCenter(_capsule).dx, lessThan(pointer.dx));
        expect(tester.getCenter(_capsule).dx, greaterThan(home));
        await tester.pumpAndSettle();
        _expectAt(tester, 'Browse');
        expect(requests, [3]);
        // The pointer boundary remains usable after a cancelled simulation.
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        expect(requests, [3, 1]);
        _expectAt(tester, 'Browse');
      },
    );
  }

  testWidgets('cancelled accepted scrub settles to the latest host selection', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpDock(tester, selected);
    final target = tester.getCenter(find.text('Inbox'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await gesture.moveTo(target + const Offset(8, 0));
    await tester.pump();
    expect(selected.value, 2);
    expect(tester.getCenter(_capsule).dx, closeTo(target.dx + 8, 0.001));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(_capsule).dx, greaterThan(target.dx));
    expect(tester.getCenter(_capsule).dx, lessThan(target.dx + 8));
    await tester.pumpAndSettle();
    _expectAt(tester, 'Inbox');
  });

  testWidgets('spring overshoot stays inside the lane on both edges', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpDock(tester, selected);
    final first = tester.getRect(_capsule);
    final lastCenter = tester.getCenter(find.text('Profile')).dx;
    final laneLeft = first.left - 2;
    final laneRight = lastCenter + first.width / 2 + 2;
    for (final label in ['Profile', 'Browse']) {
      await tester.tap(find.text(label));
      await tester.pump();
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final rect = tester.getRect(_capsule);
        expect(rect.left, greaterThanOrEqualTo(laneLeft - 0.001));
        expect(rect.right, lessThanOrEqualTo(laneRight + 0.001));
        expect(rect.top, greaterThanOrEqualTo(first.top - 0.001));
        expect(rect.bottom, lessThanOrEqualTo(first.bottom + 0.001));
      }
      await tester.pumpAndSettle();
      _expectAt(tester, label);
    }
  });

  for (final reverseAtRight in [true, false]) {
    testWidgets(
      'reverse retarget from clamped ${reverseAtRight ? 'right' : 'left'} overshoot stays continuous and settles',
      (tester) async {
        final selected = ValueNotifier(reverseAtRight ? 0 : 4);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpDock(tester, selected, requests: requests);
        Rect targetRect(String label) => tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        final firstTarget = targetRect('Browse');
        final lastTarget = targetRect('Profile');
        final lane = Rect.fromLTRB(
          firstTarget.left,
          firstTarget.top,
          lastTarget.right,
          lastTarget.bottom,
        );
        final endpoint = reverseAtRight ? 4 : 0;
        final endpointCenter = tester
            .getCenter(find.text(_labels[endpoint]))
            .dx;
        selected.value = endpoint;
        await tester.pump();

        Rect? clamped;
        // Find the actual painted clamp instead of assuming a simulation time.
        // The destination center is inset from the lane edge, so reaching the
        // edge beyond that center establishes overshoot rather than settlement.
        for (var frame = 0; frame < 120; frame++) {
          await tester.pump(const Duration(milliseconds: 8));
          final painted = tester.getRect(_capsule);
          expect(painted.isFinite, isTrue);
          _expectWithin(painted, lane);
          final touchesEdge = reverseAtRight
              ? (painted.right - lane.right).abs() < 0.001
              : (painted.left - lane.left).abs() < 0.001;
          final beyondTarget = reverseAtRight
              ? painted.center.dx > endpointCenter + 1
              : painted.center.dx < endpointCenter - 1;
          if (touchesEdge && beyondTarget) {
            clamped = painted;
            break;
          }
        }
        expect(clamped, isNotNull, reason: 'exercise reversal while clamped');
        final beforeRetarget = clamped!;
        selected.value = reverseAtRight ? 0 : 4;
        await tester.pump();
        final afterRetarget = tester.getRect(_capsule);
        expect(afterRetarget.left, closeTo(beforeRetarget.left, 0.001));
        expect(afterRetarget.top, closeTo(beforeRetarget.top, 0.001));
        expect(afterRetarget.width, closeTo(beforeRetarget.width, 0.001));
        expect(afterRetarget.height, closeTo(beforeRetarget.height, 0.001));

        // Hard bounds may clip velocity. Assert position continuity and usable
        // bounded settling without claiming continuous velocity at the clamp.
        for (var frame = 0; frame < 90; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final painted = tester.getRect(_capsule);
          expect(painted.isFinite, isTrue);
          _expectWithin(painted, lane);
        }
        await tester.pumpAndSettle();
        _expectAt(tester, reverseAtRight ? 'Browse' : 'Profile');
        expect(selected.value, reverseAtRight ? 0 : 4);
        expect(requests, isEmpty);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'live reduced motion cancels scrub and spring without stranding next pointer',
    (tester) async {
      final selected = ValueNotifier(0);
      final reducedMotion = ValueNotifier(false);
      addTearDown(selected.dispose);
      addTearDown(reducedMotion.dispose);
      final requests = <int>[];
      await _pumpDock(
        tester,
        selected,
        acceptRequests: false,
        requests: requests,
        reduceMotionPreference: reducedMotion,
        pressureFeedback: true,
      );
      final home = tester.getRect(_capsule);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Browse')),
      );
      await gesture.moveTo(tester.getCenter(find.text('Updates')));
      await tester.pump();
      expect(requests, [3]);
      expect(tester.getCenter(_capsule).dx, greaterThan(home.center.dx));

      reducedMotion.value = true;
      await tester.pump();
      expect(tester.getRect(_capsule), home);
      await gesture.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(requests, [3]);
      expect(tester.getRect(_capsule), home);
      await gesture.up();
      await tester.pumpAndSettle();

      reducedMotion.value = false;
      await tester.pump();
      final nextGesture = await tester.startGesture(
        tester.getCenter(find.text('Browse')),
      );
      final pointer = tester.getCenter(find.text('Inbox'));
      await nextGesture.moveTo(pointer);
      await tester.pump();
      expect(requests, [3, 2]);
      expect(tester.getCenter(_capsule).dx, closeTo(pointer.dx, 0.001));
      await nextGesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(_capsule).dx, greaterThan(home.center.dx));
      expect(tester.getCenter(_capsule).dx, lessThan(pointer.dx));

      // Toggle again while the rejected scrub is springing home. The state
      // remains authoritative and restores a pressure-free, ticker-free lens.
      reducedMotion.value = true;
      await tester.pump();
      expect(tester.getRect(_capsule), home);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      reducedMotion.value = false;
      await tester.pump();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(requests, [3, 2, 4]);
      expect(selected.value, 0);
      expect(tester.getRect(_capsule), home);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RTL unequal-width spring follows host selection and reveals it',
    (tester) async {
      const labels = [
        'A',
        'Saved stories',
        'Inbox',
        'Upcoming activity and updates',
        'Profile',
      ];
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpDock(
        tester,
        selected,
        labels: labels,
        direction: TextDirection.rtl,
        requests: requests,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final initialWidth = tester.getSize(_capsule).width;
      final targetButton = find.ancestor(
        of: find.text(labels[3]),
        matching: find.byType(InkWell),
      );
      final targetWidth = tester.getSize(targetButton).width - 4;
      expect(targetWidth, greaterThan(initialWidth));

      selected.value = 3;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getSize(_capsule).width, greaterThan(initialWidth));
      expect(tester.getSize(_capsule).width, lessThan(targetWidth));
      await tester.pumpAndSettle();
      _expectAt(tester, labels[3]);
      expect(tester.getSize(_capsule).width, closeTo(targetWidth, 0.001));
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final buttonRect = tester.getRect(targetButton);
      expect(buttonRect.left, greaterThanOrEqualTo(viewport.left - 0.001));
      expect(buttonRect.right, lessThanOrEqualTo(viewport.right + 0.001));

      selected.value = 0;
      await tester.pumpAndSettle();
      _expectAt(tester, labels[0]);
      expect(tester.getSize(_capsule).width, closeTo(initialWidth, 0.001));
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pressed capsule stays inside actual outer surface at both edges',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpDock(tester, selected, pressureFeedback: true);
      final surface = tester.getRect(
        find.ancestor(of: _capsule, matching: find.byType(ClipRRect)).last,
      );
      final restingWidth = tester.getRect(_capsule).width;
      for (final index in [0, 4]) {
        selected.value = index;
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text(_labels[index])),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await gesture.moveTo(
          Offset(
            index == 0 ? surface.left - 100 : surface.right + 100,
            surface.center.dy,
          ),
        );
        await tester.pump();
        final painted = tester.getRect(_capsule);
        expect(painted.width, greaterThan(restingWidth));
        _expectWithin(painted, surface);
        await gesture.cancel();
        await tester.pump();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          _expectWithin(tester.getRect(_capsule), surface);
        }
        await tester.pumpAndSettle();
        _expectAt(tester, _labels[index]);
      }
    },
  );

  testWidgets('live zero duration snaps an interrupted spring and can resume', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    final duration = ValueNotifier(const Duration(milliseconds: 200));
    addTearDown(selected.dispose);
    addTearDown(duration.dispose);
    await _pumpDock(tester, selected, durationPreference: duration);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getCenter(_capsule).dx,
      lessThan(tester.getCenter(find.text('Profile')).dx),
    );

    duration.value = Duration.zero;
    await tester.pump();
    _expectAt(tester, 'Profile');
    await tester.pump(const Duration(seconds: 2));
    _expectAt(tester, 'Profile');
    expect(tester.takeException(), isNull);

    duration.value = const Duration(milliseconds: 200);
    await tester.pump();
    await tester.tap(find.text('Browse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getCenter(_capsule).dx,
      greaterThan(tester.getCenter(find.text('Browse')).dx),
    );
    await tester.pumpAndSettle();
    _expectAt(tester, 'Browse');
    expect(tester.takeException(), isNull);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      '${reducedMotion ? 'reduced motion' : 'zero duration'} snaps despite spring configuration',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pumpDock(
          tester,
          selected,
          reduceMotion: reducedMotion,
          duration: reducedMotion
              ? const Duration(milliseconds: 200)
              : Duration.zero,
        );
        await tester.tap(find.text('Profile'));
        await tester.pump();
        _expectAt(tester, 'Profile');
        expect(selected.value, 4);
        await tester.pump(const Duration(milliseconds: 60));
        _expectAt(tester, 'Profile');
      },
    );
  }
}

Future<void> _pumpDock(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  Brightness brightness = Brightness.light,
  bool acceptRequests = true,
  List<int>? requests,
  bool reduceMotion = false,
  ValueNotifier<bool>? reduceMotionPreference,
  Duration duration = const Duration(milliseconds: 200),
  ValueNotifier<Duration>? durationPreference,
  List<String> labels = _labels,
  TextDirection direction = TextDirection.ltr,
  bool pressureFeedback = false,
  SpringDescription? selectionSpring = _spring,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => AnimatedBuilder(
        animation: Listenable.merge([?reduceMotionPreference]),
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotionPreference?.value ?? reduceMotion,
          ),
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
      home: Scaffold(
        bottomNavigationBar: AnimatedBuilder(
          animation: Listenable.merge([selected, ?durationPreference]),
          builder: (context, child) => CustomFlutterGlassNavigationDockWidget(
            items: [
              for (final label in labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: selected.value,
            onItemSelected: (requested) {
              requests?.add(requested);
              if (acceptRequests) selected.value = requested;
            },
            style: AppGlassNavigationStyle(
              labelStyle: const TextStyle(fontSize: 8, height: 1.35),
              selectionSpring: selectionSpring,
              duration: durationPreference?.value ?? duration,
              pressureStretch: pressureFeedback ? 0.04 : 0,
              pressedScale: pressureFeedback ? 0.97 : 1,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectWithin(Rect painted, Rect surface) {
  expect(painted.left, greaterThanOrEqualTo(surface.left - 0.001));
  expect(painted.right, lessThanOrEqualTo(surface.right + 0.001));
  expect(painted.top, greaterThanOrEqualTo(surface.top - 0.001));
  expect(painted.bottom, lessThanOrEqualTo(surface.bottom + 0.001));
}

void _expectAt(WidgetTester tester, String label) {
  expect(
    tester.getCenter(_capsule).dx,
    closeTo(tester.getCenter(find.text(label)).dx, 0.001),
  );
}
