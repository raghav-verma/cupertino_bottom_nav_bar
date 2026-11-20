import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'unselected press does not deform accepted capsule in ${brightness.name}',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpDock(
          tester,
          selected: selected,
          requests: requests,
          brightness: brightness,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Profile')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        _expectCapsuleScale(tester, 1, 1);
        _expectCapsuleAt(tester, 'Browse');
        expect(requests, isEmpty);
        expect(selected.value, 0);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(requests, [4]);
        _expectCapsuleAt(tester, 'Profile');
        _expectCapsuleScale(tester, 1, 1);
      },
    );
  }

  testWidgets('press feedback does not follow an external selection change', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(tester, selected: selected, requests: requests);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    _expectCapsuleScale(tester, 1.04, 0.97);

    selected.value = 4;
    await tester.pumpAndSettle();
    _expectCapsuleAt(tester, 'Profile');
    _expectCapsuleScale(tester, 1, 1);
    expect(requests, isEmpty);

    await gesture.cancel();
    await tester.pumpAndSettle();
    _expectCapsuleScale(tester, 1, 1);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(requests, [1]);
    _expectCapsuleAt(tester, 'Saved');
  });

  testWidgets('reduced motion suppresses selected and unselected pressure', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      reduceMotion: true,
    );
    for (final label in ['Browse', 'Profile']) {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(label)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      _expectCapsuleScale(tester, 1, 1);
      expect(requests, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      _expectCapsuleScale(tester, 1, 1);
    }
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(requests, [4]);
    _expectCapsuleAt(tester, 'Profile');
    _expectCapsuleScale(tester, 1, 1);
  });

  testWidgets('taps request selection and the host accepts it', (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(tester, selected: selected, requests: requests);
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.text('Profile'),
              matching: find.byType(Tooltip),
            ),
          )
          .triggerMode,
      TooltipTriggerMode.manual,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(requests, [4]);
    expect(selected.value, 4);
    _expectCapsuleAt(tester, 'Profile');
  });

  testWidgets('stationary touch retains scrub ownership without a tooltip', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(tester, selected: selected, requests: requests);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await tester.pump();
    // Hold past the ordinary tooltip long-press deadline. A touch tooltip
    // must not cancel the dock's owner before that pointer starts scrubbing.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Browse'), findsOneWidget);
    expect(requests, isEmpty);
    expect(selected.value, 0);
    _expectCapsuleScale(tester, 1.04, 0.97);

    await gesture.moveTo(tester.getCenter(find.text('Profile')));
    await tester.pump();
    expect(requests, [4]);
    expect(selected.value, 4);

    await gesture.cancel();
    await tester.pumpAndSettle();
    _expectCapsuleAt(tester, 'Profile');
    _expectCapsuleScale(tester, 1, 1);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(requests, [4, 1]);
    expect(selected.value, 1);
    _expectCapsuleAt(tester, 'Saved');
  });

  testWidgets('rejected taps retain selection until the host changes it', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      acceptRequests: false,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(requests, [4]);
    expect(selected.value, 0);
    _expectCapsuleAt(tester, 'Browse');

    selected.value = 2;
    await tester.pumpAndSettle();
    expect(requests, [4]);
    _expectCapsuleAt(tester, 'Inbox');
  });

  testWidgets('scrubbing forward and reverse requests crossed destinations', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(tester, selected: selected, requests: requests);

    await _scrub(tester, ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile']);
    expect(requests, [1, 2, 3, 4]);
    expect(selected.value, 4);
    _expectCapsuleAt(tester, 'Profile');

    await _scrub(tester, ['Profile', 'Updates', 'Inbox', 'Saved', 'Browse']);
    expect(requests, [1, 2, 3, 4, 3, 2, 1, 0]);
    expect(selected.value, 0);
    _expectCapsuleAt(tester, 'Browse');
  });

  testWidgets('release policy previews until one enabled inside-UP request', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      scrubSelectionPolicy:
          AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    for (final label in ['Saved', 'Updates', 'Profile']) {
      await gesture.moveTo(tester.getCenter(find.text(label)));
      await tester.pump();
    }
    expect(requests, isEmpty);
    expect(selected.value, 0);
    expect(find.text('Host destination: Browse'), findsOneWidget);
    _expectCapsuleAt(tester, 'Profile');
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Browse').first)
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Profile').first)
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(requests, [4]);
    expect(selected.value, 4);
    expect(find.text('Host destination: Profile'), findsOneWidget);
    _expectCapsuleAt(tester, 'Profile');
  });

  for (final outsideRight in [false, true]) {
    testWidgets(
      'release policy rejects outside-${outsideRight ? 'right' : 'left'} UP',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpDock(
          tester,
          selected: selected,
          requests: requests,
          scrubSelectionPolicy:
              AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Browse')),
        );
        await gesture.moveTo(tester.getCenter(find.text('Profile')));
        await tester.pump();
        final dock = tester.getRect(
          find.byKey(const Key('flutter_glass_navigation_dock')),
        );
        await gesture.moveTo(
          Offset(
            outsideRight ? dock.right + 20 : dock.left - 20,
            tester.getCenter(find.text('Profile')).dy,
          ),
        );
        await tester.pump();
        expect(requests, isEmpty);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(selected.value, 0);
        expect(find.text('Host destination: Browse'), findsOneWidget);
        _expectCapsuleAt(tester, 'Browse');
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        expect(requests, [1]);
        expect(selected.value, 1);
      },
    );
  }

  testWidgets('release policy actual cancel discards preview and permits tap', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      scrubSelectionPolicy:
          AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await gesture.moveTo(tester.getCenter(find.text('Profile')));
    await tester.pump();
    expect(requests, isEmpty);
    _expectCapsuleAt(tester, 'Profile');
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(selected.value, 0);
    _expectCapsuleAt(tester, 'Browse');
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(requests, [1]);
    expect(selected.value, 1);
  });

  testWidgets('release policy rejected request settles to accepted host', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      acceptRequests: false,
      scrubSelectionPolicy:
          AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await gesture.moveTo(tester.getCenter(find.text('Profile')));
    await tester.pump();
    expect(requests, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(requests, [4]);
    expect(selected.value, 0);
    expect(find.text('Host destination: Browse'), findsOneWidget);
    _expectCapsuleAt(tester, 'Browse');
  });

  testWidgets(
    'release policy disabled final item never commits prior preview',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpDock(
        tester,
        selected: selected,
        requests: requests,
        disabledInbox: true,
        scrubSelectionPolicy:
            AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Browse')),
      );
      for (final label in ['Profile', 'Inbox']) {
        await gesture.moveTo(tester.getCenter(find.text(label)));
        await tester.pump();
      }
      expect(requests, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(selected.value, 0);
      _expectCapsuleAt(tester, 'Browse');
    },
  );

  testWidgets('release policy exit and reentry commits final inside item', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      scrubSelectionPolicy:
          AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    final dock = tester.getRect(
      find.byKey(const Key('flutter_glass_navigation_dock')),
    );
    await gesture.moveTo(
      Offset(dock.right + 20, tester.getCenter(find.text('Profile')).dy),
    );
    await tester.pump();
    expect(requests, isEmpty);
    await gesture.moveTo(tester.getCenter(find.text('Saved')));
    await tester.pump();
    expect(requests, isEmpty);
    expect(selected.value, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(requests, [1]);
    expect(selected.value, 1);
    _expectCapsuleAt(tester, 'Saved');
  });

  for (final initialPolicy in AppGlassNavigationScrubSelectionPolicy.values) {
    testWidgets('live ${initialPolicy.name} policy switch invalidates owner', (
      tester,
    ) async {
      final selected = ValueNotifier(0);
      final policy = ValueNotifier(initialPolicy);
      addTearDown(selected.dispose);
      addTearDown(policy.dispose);
      final requests = <int>[];
      await _pumpDock(
        tester,
        selected: selected,
        requests: requests,
        policyOverride: policy,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Browse')),
      );
      await gesture.moveTo(tester.getCenter(find.text('Profile')));
      await tester.pump();
      final wasContinuous =
          initialPolicy == AppGlassNavigationScrubSelectionPolicy.continuous;
      expect(requests, wasContinuous ? [4] : isEmpty);
      final accepted = selected.value;
      final previousRequests = List<int>.of(requests);
      policy.value = wasContinuous
          ? AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane
          : AppGlassNavigationScrubSelectionPolicy.continuous;
      await tester.pumpAndSettle();
      _expectCapsuleAt(tester, _labels[accepted]);
      await gesture.moveTo(tester.getCenter(find.text('Saved')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(requests, previousRequests);
      expect(selected.value, accepted);
      _expectCapsuleAt(tester, _labels[accepted]);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(requests, [...previousRequests, 1]);
      expect(selected.value, 1);
    });
  }

  testWidgets('disabled destinations reject taps and scrub requests', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      disabledInbox: true,
    );

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    _expectCapsuleAt(tester, 'Browse');

    await _scrub(tester, ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile']);
    expect(requests, [1, 3, 4]);
    expect(selected.value, 4);
    _expectCapsuleAt(tester, 'Profile');

    requests.clear();
    await _scrub(tester, ['Inbox', 'Saved', 'Browse']);
    expect(requests, isEmpty);
    expect(selected.value, 4);
    _expectCapsuleAt(tester, 'Profile');
  });

  testWidgets(
    'sparse forward and reverse scrubs request sampled endpoints only',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpDock(tester, selected: selected, requests: requests);

      // This fixture forces the portable renderer. Sparse Flutter pointer samples
      // do not establish how UIKit handles real fast-drag event delivery.
      final browse = tester.getCenter(find.text('Browse'));
      final profile = tester.getCenter(find.text('Profile'));
      final forward = await tester.startGesture(browse);
      await forward.moveTo(profile);
      await tester.pump();
      expect(requests, [4]);
      expect(selected.value, 4);
      // A second sample inside the same target must not request it again.
      await forward.moveTo(profile - const Offset(1, 0));
      await tester.pump();
      expect(requests, [4]);
      await forward.up();
      await tester.pumpAndSettle();
      _expectCapsuleAt(tester, 'Profile');

      final reverse = await tester.startGesture(profile);
      await reverse.moveTo(browse);
      await tester.pump();
      expect(requests, [4, 0]);
      expect(selected.value, 0);
      await reverse.moveTo(browse + const Offset(1, 0));
      await tester.pump();
      expect(requests, [4, 0]);
      await reverse.up();
      await tester.pumpAndSettle();
      expect(selected.value, 0);
      _expectCapsuleAt(tester, 'Browse');
    },
  );

  testWidgets('cancellation retains selections already accepted by the host', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(tester, selected: selected, requests: requests);

    await _scrub(tester, ['Browse', 'Saved', 'Inbox'], cancel: true);

    expect(requests, [1, 2]);
    expect(selected.value, 2);
    _expectCapsuleAt(tester, 'Inbox');
    // Cancellation must also release the tracked pointer for a later gesture.
    await _scrub(tester, ['Inbox', 'Saved', 'Browse']);
    expect(requests, [1, 2, 1, 0]);
    _expectCapsuleAt(tester, 'Browse');
  });

  testWidgets('pointer cancellation settles an accepted long-press scrub', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      textScaler: TextScaler.linear(2),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Browse')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (final label in ['Saved', 'Inbox']) {
      await gesture.moveTo(tester.getCenter(find.text(label)));
      await tester.pump();
    }
    expect(requests, [1, 2]);

    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selected.value, 2);
    _expectCapsuleAt(tester, 'Inbox');
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 0]);
    _expectCapsuleAt(tester, 'Browse');
  });

  testWidgets(
    'scrolling scrub mode retains hover tooltips and focused semantics',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpDock(
        tester,
        selected: selected,
        requests: requests,
        textScaler: TextScaler.linear(2),
      );
      final position = tester.getCenter(find.text('Browse'));
      final focus = Focus.of(tester.element(find.text('Browse')));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(position);
      await tester.pumpAndSettle();
      expect(find.text('Browse'), findsNWidgets(2));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Browse').first)
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(focus.hasFocus, isTrue);
      expect(requests, isEmpty);
      expect(selected.value, 0);

      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'rejected scrub settles to host selection on ${cancel ? 'cancel' : 'release'}',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpDock(
          tester,
          selected: selected,
          requests: requests,
          acceptRequests: false,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Browse')),
        );
        for (final label in ['Saved', 'Inbox', 'Updates']) {
          await gesture.moveTo(tester.getCenter(find.text(label)));
          await tester.pump();
        }
        expect(requests, [1, 2, 3]);
        expect(selected.value, 0);
        _expectCapsuleAt(tester, 'Updates');

        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();

        expect(selected.value, 0);
        expect(requests, [1, 2, 3]);
        _expectCapsuleAt(tester, 'Browse');
      },
    );
  }
}

Future<void> _pumpDock(
  WidgetTester tester, {
  required ValueNotifier<int> selected,
  required List<int> requests,
  bool acceptRequests = true,
  bool disabledInbox = false,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  AppGlassNavigationScrubSelectionPolicy scrubSelectionPolicy =
      AppGlassNavigationScrubSelectionPolicy.continuous,
  ValueNotifier<AppGlassNavigationScrubSelectionPolicy>? policyOverride,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final items = [
    for (var index = 0; index < _labels.length; index++)
      AppGlassNavigationItem(
        icon: Icons.circle_outlined,
        label: _labels[index],
        enabled: !disabledInbox || index != 2,
      ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: textScaler, disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, child) =>
              Text('Host destination: ${_labels[index]}'),
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: Listenable.merge([selected, policyOverride]),
          builder: (context, child) => CustomGlassNavigationDockWidget(
            items: items,
            selectedIndex: selected.value,
            onItemSelected: (requested) {
              requests.add(requested);
              if (acceptRequests) selected.value = requested;
            },
            // Widget-test fonts have uniform glyph widths; this resolved
            // caption style keeps the fixture in the ordinary scrub layout.
            style: AppGlassNavigationStyle(
              scrubSelectionPolicy:
                  policyOverride?.value ?? scrubSelectionPolicy,
              surfaceColor: Theme.of(context).colorScheme.surface,
              selectedSurfaceColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              labelStyle: const TextStyle(fontSize: 8, height: 1.35),
            ),
            preferNative: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrub(
  WidgetTester tester,
  List<String> labels, {
  bool cancel = false,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text(labels.first)),
  );
  for (final label in labels.skip(1)) {
    await gesture.moveTo(tester.getCenter(find.text(label)));
    await tester.pump();
  }
  if (cancel) {
    await gesture.cancel();
  } else {
    await gesture.up();
  }
  await tester.pumpAndSettle();
}

void _expectCapsuleAt(WidgetTester tester, String label) {
  final capsule = tester.getCenter(
    find.byKey(const Key('glass_navigation_selection')),
  );
  expect(capsule.dx, closeTo(tester.getCenter(find.text(label)).dx, 0.01));
}

void _expectCapsuleScale(
  WidgetTester tester,
  double horizontal,
  double vertical,
) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byKey(const Key('glass_navigation_selection')),
          matching: find.byType(Transform),
        )
        .first,
  );
  expect(transform.transform.entry(0, 0), closeTo(horizontal, 0.0001));
  expect(transform.transform.entry(1, 1), closeTo(vertical, 0.0001));
}
