import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _style = AppGlassNavigationStyle(
  duration: Duration(milliseconds: 200),
  curve: Curves.linear,
  horizontalInset: 18,
  topInset: 8,
  bottomInset: 8,
  pressedScale: 1.18,
  pressureStretch: 0.2,
  heldBarScale: 1.04,
  animateSelectionDeformation: false,
  trackVerticalDrag: true,
  scrubSelectionPolicy:
      AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
  labelStyle: TextStyle(fontSize: 8, height: 1.35),
);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  for (final targetX in [135.0, 255.0]) {
    testWidgets(
      'stationary owner stays projected after bar pressure grows at x=$targetX',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pump(tester, selected, requests);
        final start = tester.getCenter(_target('Browse'));
        final position = Offset(targetX, start.dy);
        final gesture = await tester.startGesture(start);

        // Recognize the scrub before the first pressure animation frame. The
        // ancestor then expands around a stationary global owner coordinate.
        await gesture.moveTo(position);
        await tester.pumpAndSettle();
        final settledCenter = tester.getCenter(_capsule);
        expect(requests, isEmpty);
        expect(selected.value, 0);

        // A zero-displacement sample must not repair a stale local projection
        // or move the already-settled capsule in world space.
        await gesture.moveTo(position);
        await tester.pump();
        final resampledCenter = tester.getCenter(_capsule);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(selected.value, 0);
        expect(
          resampledCenter.dx,
          closeTo(settledCenter.dx, 0.001),
          reason: 'Identical global owner coordinates cannot move the lens.',
        );
        expect(resampledCenter.dy, closeTo(settledCenter.dy, 0.001));
        expect(settledCenter.dx, closeTo(position.dx, 0.001));
      },
    );
  }

  testWidgets('owner UP starts from the pressure-projected scrub position', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pump(tester, selected, requests);
    final start = tester.getCenter(_target('Browse'));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(Offset(255, start.dy));
    await tester.pumpAndSettle();
    final heldCenter = tester.getCenter(_capsule);
    expect(heldCenter.dx, closeTo(255, 0.001));

    // Release without a corrective zero-displacement move. Raw UP and SDK end
    // must transfer the currently painted projection into settling exactly once.
    await gesture.up();
    await tester.pump();
    expect(tester.getCenter(_capsule), heldCenter);
    expect(requests, [3]);
    expect(selected.value, 3);
    await tester.pumpAndSettle();
    expect(tester.getCenter(_capsule), tester.getCenter(_target('Updates')));
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final offsetX in [-6.0, 6.0]) {
    testWidgets(
      'unrecognized caught lens keeps stationary projection at dx=$offsetX',
      (tester) async {
        final selected = ValueNotifier(2);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pump(tester, selected, requests);
        final start = tester.getCenter(_target('Inbox'));
        final position = start + Offset(offsetX, 0);
        final gesture = await tester.startGesture(start);

        // Stay below SDK pan slop and long-press time: only the existing raw
        // tracked-lens path is active while the ancestor finishes expanding.
        await gesture.moveTo(position);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final settledCenter = tester.getCenter(_capsule);
        await gesture.moveTo(position);
        await tester.pump();
        final resampledCenter = tester.getCenter(_capsule);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(selected.value, 2);
        expect(
          resampledCenter.dx,
          closeTo(settledCenter.dx, 0.001),
          reason: 'A caught lens must not drift before SDK pan recognition.',
        );
        expect(resampledCenter.dy, closeTo(settledCenter.dy, 0.001));
        expect(settledCenter.dx, closeTo(position.dx, 0.001));
      },
    );
  }

  testWidgets('host retarget starts from the projected caught lens', (
    tester,
  ) async {
    final selected = ValueNotifier(2);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pump(tester, selected, requests);
    final start = tester.getCenter(_target('Inbox'));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(start + const Offset(6, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final heldCenter = tester.getCenter(_capsule);
    selected.value = 3;
    await tester.pump();
    final retargetCenter = tester.getCenter(_capsule);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(selected.value, 3);
    expect(
      retargetCenter.dx,
      closeTo(heldCenter.dx, 0.001),
      reason:
          'Clearing a raw capture must preserve its projected retarget origin.',
    );
    expect(retargetCenter.dy, closeTo(heldCenter.dy, 0.001));
  });

  testWidgets(
    'settled pressure reversal and next owner keep their projection',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pump(tester, selected, requests);
      final start = tester.getCenter(_target('Browse'));
      final firstOwner = await tester.startGesture(start);
      await tester.pumpAndSettle();
      final right = Offset(255, start.dy);
      await firstOwner.moveTo(right);
      await tester.pumpAndSettle();
      final beforeReversal = tester.getCenter(_capsule);
      await firstOwner.moveTo(Offset(135, start.dy));
      await tester.pumpAndSettle();
      await firstOwner.moveTo(right);
      await tester.pumpAndSettle();
      expect(tester.getCenter(_capsule), beforeReversal);
      expect(beforeReversal.dx, closeTo(right.dx, 0.001));
      await firstOwner.cancel();
      await tester.pumpAndSettle();
      expect(selected.value, 0);
      expect(requests, isEmpty);

      // The cancelled owner's global anchor must not transfer to a later owner.
      final nextOwner = await tester.startGesture(
        tester.getCenter(_target('Browse')),
      );
      await tester.pumpAndSettle();
      final left = Offset(135, start.dy);
      await nextOwner.moveTo(left);
      await tester.pumpAndSettle();
      expect(tester.getCenter(_capsule).dx, closeTo(left.dx, 0.001));
      await nextOwner.moveTo(left);
      await tester.pump();
      expect(tester.getCenter(_capsule).dx, closeTo(left.dx, 0.001));
      await nextOwner.up();
      await tester.pumpAndSettle();
      expect(requests, [1]);
      expect(selected.value, 1);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<int> selected,
  List<int> requests,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AnimatedBuilder(
        animation: selected,
        builder: (context, _) => Scaffold(
          body: const Text('Synthetic projection fixture'),
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
              selected.value = index;
            },
            style: _style,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
