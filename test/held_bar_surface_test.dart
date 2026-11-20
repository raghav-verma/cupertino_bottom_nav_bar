import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:cupertino_bottom_nav_bar/src/custom_glass_backdrop_widget.dart';
import 'package:material_ui/material_ui.dart';

const _duration = Duration(milliseconds: 200);
const _heldColor = Color(0xE6F4F4FF);
const _style = AppGlassNavigationStyle(
  surfaceColor: Color(0xBD808090),
  heldBarSurfaceColor: _heldColor,
  heldSurfaceColor: Colors.red,
  pressedScale: 1.18,
  duration: _duration,
  curve: Curves.linear,
  blurSigma: 0,
);
const _items = [
  AppGlassNavigationItem(icon: Icons.circle, label: 'Browse'),
  AppGlassNavigationItem(icon: Icons.circle, label: 'Saved'),
  AppGlassNavigationItem(icon: Icons.circle, label: 'Profile'),
];

void main() {
  test(
    'held outer tint defaults, theme resolution and nullable copy contract',
    () {
      expect(const AppGlassNavigationStyle().heldBarSurfaceColor, isNull);
      expect(_style.copyWith().heldBarSurfaceColor, _heldColor);
      expect(
        _style.copyWith(surfaceColor: Colors.black).heldBarSurfaceColor,
        _heldColor,
      );
      expect(
        _style.copyWith(heldBarSurfaceColor: Colors.blue).heldBarSurfaceColor,
        Colors.blue,
      );
      final cleared = _style.copyWith(heldBarSurfaceColor: null);
      expect(cleared.heldBarSurfaceColor, isNull);
      expect(cleared.heldSurfaceColor, Colors.red);
      expect(cleared.surfaceColor, _style.surfaceColor);
      expect(
        () => _style.copyWith(heldBarSurfaceColor: 'white'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'heldBarSurfaceColor',
          ),
        ),
      );
      for (final brightness in Brightness.values) {
        final theme = ThemeData(brightness: brightness);
        final ordinary = AppGlassNavigationStyle.fromTheme(theme);
        final held = AppGlassNavigationStyle.fromTheme(
          theme,
          heldBarSurfaceColor: _heldColor,
          heldSurfaceColor: Colors.red,
        );
        expect(ordinary.heldBarSurfaceColor, isNull);
        expect(held.heldBarSurfaceColor, _heldColor);
        expect(held.surfaceColor, ordinary.surfaceColor);
        expect(held.selectedSurfaceColor, ordinary.selectedSurfaceColor);
        expect(held.heldSurfaceColor, Colors.red);
      }
    },
  );

  for (final brightness in Brightness.values) {
    for (final cancel in [false, true]) {
      testWidgets(
        'outer tint follows contact and ${cancel ? 'cancel' : 'release'} '
        'in ${brightness.name} without rebuilding stable children',
        (tester) async {
          final style =
              AppGlassNavigationStyle.fromTheme(
                ThemeData(brightness: brightness),
                heldBarSurfaceColor: _heldColor,
              ).copyWith(
                pressedScale: 1.18,
                duration: _duration,
                curve: Curves.linear,
                blurSigma: 0,
                heldSurfaceColor: Colors.red,
              );
          final requests = <int>[];
          await _pump(
            tester,
            style,
            brightness: brightness,
            requests: requests,
          );
          expect(_outerColor(tester), style.surfaceColor);
          final backdrop = tester.widget<CustomGlassBackdropWidget>(
            _outerBackdrop,
          );
          final decoration = tester.widget<DecoratedBox>(_outerDecoration);
          final viewport = _viewportWidget(tester);
          final target = tester.element(_target('Browse'));
          final targetRect = tester.getRect(_target('Browse'));
          final gesture = await tester.startGesture(
            tester.getCenter(_target('Browse')),
          );
          await tester.pump();
          await tester.pump(_duration ~/ 2);
          expect(
            _outerColor(tester),
            Color.lerp(style.surfaceColor, _heldColor, 0.5),
          );
          expect(requests, isEmpty);
          expect(identical(tester.widget(_outerBackdrop), backdrop), isTrue);
          expect(
            identical(tester.widget(_outerDecoration), decoration),
            isTrue,
          );
          expect(identical(_viewportWidget(tester), viewport), isTrue);
          expect(identical(tester.element(_target('Browse')), target), isTrue);
          expect(tester.getRect(_target('Browse')), targetRect);
          await tester.pump(_duration ~/ 2);
          expect(_outerColor(tester), _heldColor);
          // InkWell's existing splash may outlive the pressure animation.
          await tester.pumpAndSettle();
          expect(tester.binding.transientCallbackCount, 0);
          if (cancel) {
            await gesture.cancel();
          } else {
            await gesture.up();
          }
          await tester.pump();
          await tester.pump(_duration ~/ 2);
          expect(
            _outerColor(tester),
            Color.lerp(style.surfaceColor, _heldColor, 0.5),
          );
          await tester.pumpAndSettle();
          expect(_outerColor(tester), style.surfaceColor);
          expect(requests, cancel ? isEmpty : [0]);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('null retains ordinary outer tint and direct ColoredBox tree', (
    tester,
  ) async {
    final style = _style.copyWith(heldBarSurfaceColor: null);
    await _pump(tester, style);
    expect(
      tester.widget<CustomGlassBackdropWidget>(_outerBackdrop).child,
      isA<ColoredBox>(),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(_target('Browse')),
    );
    await tester.pumpAndSettle();
    expect(_outerColor(tester), style.surfaceColor);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_outerColor(tester), style.surfaceColor);
  });

  for (final boundary in [
    'reduced',
    'zero',
    'contrast',
    'scroll',
    'nongrowing',
  ]) {
    testWidgets('$boundary retains ordinary outer surface', (tester) async {
      final style = _style.copyWith(
        duration: boundary == 'zero' ? Duration.zero : _duration,
        pressedScale: boundary == 'nongrowing' ? 0.97 : 1.18,
      );
      await _pump(
        tester,
        style,
        reduced: boundary == 'reduced',
        highContrast: boundary == 'contrast',
        width: boundary == 'scroll' ? 120 : 390,
      );
      final ordinary = boundary == 'contrast'
          ? style.surfaceColor.withValues(alpha: 1)
          : style.surfaceColor;
      expect(
        tester.widget<CustomGlassBackdropWidget>(_outerBackdrop).child,
        isA<ColoredBox>(),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(_target('Browse')),
      );
      await tester.pumpAndSettle();
      expect(_outerColor(tester), ordinary);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(_outerColor(tester), ordinary);
    });
  }

  testWidgets('accepted selection feedback alone cannot tint outer bar', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(
      tester,
      _style.copyWith(animateSelectionDeformation: true),
      selected: selected,
    );
    selected.value = 2;
    await tester.pump();
    await tester.pump(_duration ~/ 2);
    expect(_outerColor(tester), _style.surfaceColor);
    await tester.pumpAndSettle();
    expect(_outerColor(tester), _style.surfaceColor);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppGlassNavigationStyle style, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
  bool highContrast = false,
  double width = 390,
  List<int>? requests,
  ValueNotifier<int>? selected,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget dock(int index) => CustomFlutterGlassNavigationDockWidget(
    items: _items,
    selectedIndex: index,
    onItemSelected: (index) => requests?.add(index),
    style: style,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduced, highContrast: highContrast),
          child: Scaffold(
            bottomNavigationBar: selected == null
                ? dock(0)
                : ValueListenableBuilder<int>(
                    valueListenable: selected,
                    builder: (context, index, _) => dock(index),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _outerBackdrop = find.byType(CustomGlassBackdropWidget).first;
final _outerTint = find
    .descendant(of: _outerBackdrop, matching: find.byType(ColoredBox))
    .first;
final _outerDecoration = find
    .descendant(of: _outerTint, matching: find.byType(DecoratedBox))
    .first;
Color _outerColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(_outerTint).color;
Widget _viewportWidget(WidgetTester tester) {
  final material = tester.widget<Material>(
    find.ancestor(of: _target('Browse'), matching: find.byType(Material)).first,
  );
  return (material.child! as Padding).child!;
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
