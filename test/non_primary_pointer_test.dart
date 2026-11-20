import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  for (final brightness in Brightness.values) {
    for (final selectedContact in [false, true]) {
      testWidgets(
        'secondary ${selectedContact ? 'caught-lens move' : 'held preview'} '
        'does not own feedback in ${brightness.name}',
        (tester) async {
          final selected = ValueNotifier(0);
          addTearDown(selected.dispose);
          final requests = <int>[];
          await _pump(tester, brightness, selected, requests);
          final rest = _paintedRect(tester);
          final start = tester.getCenter(
            _target(selectedContact ? 'Browse' : 'Inbox'),
          );
          final secondary = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await secondary.down(start);
          if (selectedContact) {
            // Exercise the raw caught-lens path, below SDK drag slop, before
            // recognition could admit any navigation gesture.
            await secondary.moveTo(start + const Offset(6, 0));
          }
          await tester.pumpAndSettle();
          expect(
            _paintedRect(tester),
            rectMoreOrLessEquals(rest, epsilon: 0.001),
            reason: 'Rejected buttons cannot preview, grow or move the lens.',
          );
          expect(requests, isEmpty);
          expect(selected.value, 0);

          await secondary.up();
          await tester.pumpAndSettle();
          expect(_paintedRect(tester), rectMoreOrLessEquals(rest));
          expect(requests, isEmpty);
          expect(selected.value, 0);

          // Rejected input must not strand ownership or suppress the next
          // valid primary contact's held feedback and accepted tap.
          final primary = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
            buttons: kPrimaryButton,
          );
          await primary.down(
            tester.getCenter(_target('Inbox')),
            timeStamp: const Duration(milliseconds: 500),
          );
          await tester.pumpAndSettle();
          expect(_paintedRect(tester).width, greaterThan(rest.width));
          expect(
            _paintedRect(tester).center.dx,
            greaterThan(rest.center.dx + 50),
          );
          expect(requests, isEmpty);
          expect(selected.value, 0);
          await primary.up(timeStamp: const Duration(milliseconds: 800));
          await tester.pumpAndSettle();
          expect(requests, [2]);
          expect(selected.value, 2);
          expect(
            _paintedRect(tester).center.dx,
            closeTo(tester.getCenter(_target('Inbox')).dx, 0.001),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
  ValueNotifier<int> selected,
  List<int> requests,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
              selected.value = index;
            },
            style: const AppGlassNavigationStyle(
              duration: Duration(milliseconds: 200),
              pressedScale: 1.18,
              pressureStretch: 0.2,
              heldBarScale: 1.04,
              trackVerticalDrag: true,
              scrubSelectionPolicy:
                  AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
              labelStyle: TextStyle(
                fontSize: 8,
                height: 1.35,
                letterSpacing: 0,
              ),
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

Rect _paintedRect(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(_capsule);
  // Include both the lens's nonuniform pressure scale and whole-bar scale.
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}
