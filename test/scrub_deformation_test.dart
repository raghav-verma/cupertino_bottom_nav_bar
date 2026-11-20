import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// Synthetic portable mechanics only; these values are not UIKit calibration.
const _labels = ['Browse', 'Saved', 'Inbox', 'Updates', 'Profile'];
const _duration = Duration(milliseconds: 200);
const _style = AppGlassNavigationStyle(
  pressedScale: 1.18,
  pressureStretch: 0.2,
  // Widget-test glyphs use uniform widths. Match the existing fitting fixtures.
  labelStyle: TextStyle(fontSize: 8, height: 1.35),
  trackVerticalDrag: true,
  scrubSelectionPolicy:
      AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
  curve: Curves.linear,
);
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  test('scrub compression is neutral by default and fully overridable', () {
    expect(const AppGlassNavigationStyle().scrubVerticalScale, 1);
    final compressed = _style.copyWith(scrubVerticalScale: 0.82);
    expect(compressed.copyWith().scrubVerticalScale, 0.82);
    expect(
      compressed.copyWith(scrubVerticalScale: null).scrubVerticalScale,
      0.82,
    );
    expect(compressed.copyWith(scrubVerticalScale: 1).scrubVerticalScale, 1);
    for (final brightness in Brightness.values) {
      expect(
        AppGlassNavigationStyle.fromTheme(
          ThemeData(brightness: brightness),
          scrubVerticalScale: 0.82,
        ).scrubVerticalScale,
        0.82,
      );
    }
    for (final invalid in [0.0, -1.0, 1.01, double.nan, double.infinity]) {
      expect(
        () => _style.copyWith(scrubVerticalScale: invalid),
        throwsAssertionError,
      );
    }
  });

  testWidgets('neutral default preserves pressure on both axes during scrub', (
    tester,
  ) async {
    final style = ValueNotifier(_style);
    addTearDown(style.dispose);
    await _pump(tester, style);
    final gesture = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.2, 1.18));
    await gesture.moveTo(tester.getCenter(_target('Profile')));
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.2, 1.18));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.0, 1.0));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'only recognized fitting scrub compresses in ${brightness.name}',
      (tester) async {
        final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
        addTearDown(style.dispose);
        final requests = <int>[];
        await _pump(tester, style, brightness: brightness, requests: requests);
        final targets = [
          for (final label in _labels) tester.getRect(_target(label)),
        ];
        final gesture = await tester.startGesture(
          tester.getCenter(_target('Browse')),
        );
        await tester.pumpAndSettle();
        expect(_scales(tester), (1.2, 1.18));
        final heldHeight = _paintedHeight(tester);
        await gesture.moveTo(tester.getCenter(_target('Profile')));
        await tester.pump();
        expect(_scales(tester).$2, closeTo(1.18, 0.0001));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_scales(tester).$2, closeTo(1.18 * 0.91, 0.0001));
        await tester.pumpAndSettle();
        expect(_scales(tester).$1, 1.2);
        expect(_scales(tester).$2, closeTo(1.18 * 0.82, 0.0001));
        expect(_paintedHeight(tester), closeTo(heldHeight * 0.82, 0.001));
        expect(requests, isEmpty);
        expect(find.text('Host: 0'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Browse'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        for (var index = 0; index < targets.length; index++) {
          expect(tester.getRect(_target(_labels[index])), targets[index]);
        }
        await gesture.cancel();
        await tester.pump();
        expect(_scales(tester).$2, closeTo(1.18 * 0.82, 0.0001));
        await tester.pumpAndSettle();
        expect(_scales(tester), (1.0, 1.0));
        expect(requests, isEmpty);
        await tester.tap(_target('Inbox'));
        await tester.pumpAndSettle();
        expect(requests, [2]);
        expect(find.text('Host: 0'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  testWidgets(
    'release commits once and recovers without changing host policy',
    (tester) async {
      final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
      final selected = ValueNotifier(0);
      addTearDown(style.dispose);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pump(tester, style, selected: selected, requests: requests);
      final gesture = await _scrub(tester);
      final compressed = _scales(tester);
      expect(selected.value, 0);
      expect(requests, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(_scales(tester), compressed);
      expect(requests, [4]);
      expect(selected.value, 4);
      await tester.pumpAndSettle();
      expect(_scales(tester), (1.0, 1.0));
      expect(
        tester.getCenter(_capsule).dx,
        tester.getCenter(_target('Profile')).dx,
      );
    },
  );

  testWidgets(
    'live compression changes and regrab retain current paint scale',
    (tester) async {
      final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
      addTearDown(style.dispose);
      await _pump(tester, style);
      var gesture = await _scrub(tester);
      final compressed = _scales(tester).$2;
      style.value = style.value.copyWith(scrubVerticalScale: 0.7);
      await tester.pump();
      expect(_scales(tester).$2, compressed);
      await tester.pumpAndSettle();
      expect(_scales(tester).$2, closeTo(1.18 * 0.7, 0.0001));
      style.value = style.value.copyWith(scrubVerticalScale: 1);
      await tester.pump();
      expect(_scales(tester).$2, closeTo(1.18 * 0.7, 0.0001));
      await tester.pumpAndSettle();
      expect(_scales(tester).$2, 1.18);
      style.value = style.value.copyWith(scrubVerticalScale: 0.82);
      await tester.pumpAndSettle();
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final recovering = _scales(tester);
      gesture = await tester.startGesture(tester.getCenter(_target('Browse')));
      await tester.pump();
      expect(_scales(tester), recovering);
      await gesture.moveTo(tester.getCenter(_target('Profile')));
      await tester.pump();
      expect(_scales(tester), recovering);
      await tester.pumpAndSettle();
      expect(_scales(tester).$2, closeTo(1.18 * 0.82, 0.0001));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(_scales(tester), (1.0, 1.0));
    },
  );

  for (final zeroDuration in [false, true]) {
    testWidgets(
      '${zeroDuration ? 'zero duration' : 'reduced motion'} suppresses initial and live compression',
      (tester) async {
        final style = ValueNotifier(
          _style.copyWith(
            scrubVerticalScale: 0.82,
            duration: zeroDuration ? Duration.zero : _duration,
          ),
        );
        final reduced = ValueNotifier(!zeroDuration);
        addTearDown(style.dispose);
        addTearDown(reduced.dispose);
        await _pump(tester, style, reduced: reduced);
        var gesture = await _scrub(tester);
        expect(_scales(tester), (1.0, 1.0));
        await gesture.cancel();
        await tester.pumpAndSettle();
        style.value = style.value.copyWith(duration: _duration);
        reduced.value = false;
        await tester.pumpAndSettle();
        gesture = await _scrub(tester);
        expect(_scales(tester).$2, closeTo(1.18 * 0.82, 0.0001));
        if (zeroDuration) {
          style.value = style.value.copyWith(duration: Duration.zero);
        } else {
          reduced.value = true;
        }
        await tester.pump();
        expect(_scales(tester), (1.0, 1.0));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('scrolling long-press scrub ignores compression', (tester) async {
    final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
    addTearDown(style.dispose);
    await _pump(tester, style, width: 240);
    final gesture = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(55, 0));
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.2, 1.18));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.0, 1.0));
  });

  testWidgets('route cover cancels compression and old pointer cannot commit', (
    tester,
  ) async {
    final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
    addTearDown(style.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final requests = <int>[];
    await _pump(tester, style, navigator: navigator, requests: requests);
    final gesture = await _scrub(tester);
    navigator.currentState!.push<void>(_CoverRoute());
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.0, 1.0));
    expect(requests, isEmpty);
    expect(find.text('Host: 0'), findsOneWidget);
    await tester.tap(_target('Inbox'));
    await tester.pumpAndSettle();
    expect(requests, [2]);
  });

  testWidgets('style ancestry switch and disposal clear active deformation', (
    tester,
  ) async {
    final style = ValueNotifier(_style.copyWith(scrubVerticalScale: 0.82));
    addTearDown(style.dispose);
    final requests = <int>[];
    await _pump(tester, style, requests: requests);
    var gesture = await _scrub(tester);
    style.value = style.value.copyWith(pressedScale: 0.97);
    await tester.pumpAndSettle();
    expect(_scales(tester), (1.0, 1.0));
    await gesture.moveTo(tester.getCenter(_target('Inbox')));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    style.value = _style.copyWith(scrubVerticalScale: 0.82);
    await tester.pumpAndSettle();
    gesture = await _scrub(tester);
    await tester.pumpWidget(const SizedBox());
    await gesture.cancel();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<AppGlassNavigationStyle> style, {
  ValueNotifier<int>? selected,
  ValueNotifier<bool>? reduced,
  Brightness brightness = Brightness.light,
  List<int>? requests,
  GlobalKey<NavigatorState>? navigator,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => AnimatedBuilder(
        animation: Listenable.merge([?reduced]),
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduced?.value ?? false),
          child: child!,
        ),
      ),
      home: AnimatedBuilder(
        animation: Listenable.merge([style, ?selected]),
        builder: (context, _) => Scaffold(
          body: Center(child: Text('Host: ${selected?.value ?? 0}')),
          bottomNavigationBar: CustomGlassNavigationDockWidget(
            preferNative: false,
            items: [
              for (final label in _labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: selected?.value ?? 0,
            onItemSelected: (index) {
              requests?.add(index);
              selected?.value = index;
            },
            style: style.value,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _scrub(WidgetTester tester) async {
  expect(find.byType(SingleChildScrollView), findsNothing);
  final gesture = await tester.startGesture(
    tester.getCenter(_target('Browse')),
  );
  await tester.pumpAndSettle();
  await gesture.moveTo(tester.getCenter(_target('Profile')));
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
      .transform
      .storage;
  return (matrix[0], matrix[5]);
}

double _paintedHeight(WidgetTester tester) =>
    tester.getBottomRight(_capsule).dy - tester.getTopLeft(_capsule).dy;

class _CoverRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const IgnorePointer(child: SizedBox.expand());
}
