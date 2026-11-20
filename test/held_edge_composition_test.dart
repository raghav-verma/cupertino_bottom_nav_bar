import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _captureKey = Key('synthetic-dock-capture');
const _testRim = LinearGradient(colors: [Colors.red, Colors.blue]);
const _style = AppGlassNavigationStyle(
  actionHeight: 52,
  labelStyle: TextStyle(fontSize: 10, height: 1.35),
  selectedForegroundColor: Colors.black,
  foregroundColor: Colors.black,
  surfaceColor: Colors.white,
  selectedSurfaceColor: Colors.white,
  heldSurfaceColor: Colors.white,
  blurSigma: 1,
  heldBlurSigma: 0,
  refractionStrength: 1,
  pressedScale: 1.18,
  scrubVerticalScale: 0.74,
  trackVerticalDrag: true,
  scrubSelectionPolicy:
      AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
  refractForegroundDuringInteraction: true,
  // Keep the final rim branch present without adding ink to the pixel check.
  heldRimGradient: LinearGradient(
    colors: [Colors.transparent, Colors.transparent],
  ),
);

void main() {
  testWidgets(
    'colored held band follows the lip instead of forming an inner hoop',
    (tester) async {
      final style = ValueNotifier(
        _style.copyWith(
          heldInnerHighlight: const BoxShadow(
            color: Colors.white,
            spreadRadius: 4,
          ),
          heldInnerHighlightGradient: const LinearGradient(
            colors: [Colors.red, Colors.red],
          ),
        ),
      );
      addTearDown(style.dispose);
      await _pump(tester, style);
      final gesture = await _scrub(tester);
      final stack = find
          .ancestor(
            of: find.byKey(const ValueKey('glass_foreground_lens')),
            matching: find.byType(Stack),
          )
          .first;
      final painters = find.descendant(
        of: stack,
        matching: find.byType(CustomPaint),
      );
      expect(painters, findsNWidgets(2));
      final inset = tester.widget<CustomPaint>(painters.first).painter!;
      const size = Size(80, 56);
      final pixels = await _paintPixels(tester, size, inset.paint);
      List<int> rgba(int x, int y) {
        final offset = (y * size.width.toInt() + x) * 4;
        return pixels.sublist(offset, offset + 4);
      }

      // A spread-4 highlight supplies a width-2 band centered 1px inside the
      // lip. Previously its center was 4px inward, creating a separate hoop.
      expect(rgba(40, 1), [244, 67, 54, 255]);
      expect(rgba(40, 3), [255, 255, 255, 255]);
      // The existing lens clip still contains all decoration at rounded corners.
      expect(rgba(0, 0).last, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('thick held rim stays inside small-radius lens corners', (
    tester,
  ) async {
    final style = ValueNotifier(
      _style.copyWith(radius: 4, outlineWidth: 12, heldRimGradient: _testRim),
    );
    addTearDown(style.dispose);
    await _pump(tester, style);
    final gesture = await _scrub(tester);
    final painter = _rimPainter(tester);
    const size = Size(64, 32);
    final pixels = await _paintPixels(tester, size, painter.paint);
    int alpha(int x, int y) => pixels[(y * size.width.toInt() + x) * 4 + 3];
    // These pixel squares are wholly outside the radius-4 rounded corners.
    // The previous zero-radius centerline painted all four as opaque squares.
    for (final corner in [(0, 0), (63, 0), (0, 31), (63, 31)]) {
      expect(alpha(corner.$1, corner.$2), 0);
    }
    expect(alpha(4, 0), greaterThan(0));
    expect(alpha(0, 4), greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'ordinary rounded and pill rim retain original thin-stroke pixels',
    (tester) async {
      final style = ValueNotifier(_style);
      addTearDown(style.dispose);
      await _pump(tester, style);
      final gesture = await _scrub(tester);
      const size = Size(80, 56);
      const width = 0.75;
      for (final radius in [18.0, 999.0]) {
        style.value = _style.copyWith(
          radius: radius,
          outlineWidth: width,
          heldRimGradient: _testRim,
        );
        await tester.pumpAndSettle();
        final actual = await _paintPixels(
          tester,
          size,
          _rimPainter(tester).paint,
        );
        final original = await _paintPixels(tester, size, (canvas, size) {
          final bounds = Offset.zero & size;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              bounds.deflate(width / 2),
              Radius.circular(radius - width / 2),
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..shader = _testRim.createShader(
                bounds,
                textDirection: TextDirection.ltr,
              ),
          );
        });
        expect(
          actual,
          original,
          reason: 'radius $radius retains original pixels',
        );
      }
      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('held inset precedes row and foreground while rim follows both', (
    tester,
  ) async {
    final style = ValueNotifier(
      _style.copyWith(
        heldInnerShadow: const BoxShadow(color: Colors.black, spreadRadius: 2),
        heldInnerHighlight: const BoxShadow(
          color: Colors.white,
          spreadRadius: 4,
        ),
        heldInnerHighlightGradient: const LinearGradient(
          colors: [Colors.red, Colors.blue],
        ),
      ),
    );
    addTearDown(style.dispose);
    await _pump(tester, style);
    final gesture = await _scrub(tester);
    final stackFinder = find
        .ancestor(
          of: find.byKey(const ValueKey('glass_foreground_lens')),
          matching: find.byType(Stack),
        )
        .first;
    final painters = find.descendant(
      of: stackFinder,
      matching: find.byType(CustomPaint),
    );
    expect(painters, findsNWidgets(2));
    final stack = tester.widget<Stack>(stackFinder);
    int branchOf(Finder descendant) => stack.children.indexWhere(
      (child) => find
          .ancestor(of: descendant, matching: find.byWidget(child))
          .evaluate()
          .isNotEmpty,
    );

    expect(branchOf(painters.first), 1);
    expect(branchOf(find.text('Profile')), 2);
    expect(branchOf(find.byKey(const ValueKey('glass_foreground_lens'))), 3);
    expect(branchOf(painters.last), 4);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(painters, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opaque inset cannot erase flattened scrub caption ink', (
    tester,
  ) async {
    // The widget-test backend uses the ordinary filter fallback, not Impeller.
    // This regression isolates decorative overdraw, not shader optical quality.
    expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
    final style = ValueNotifier(_style);
    addTearDown(style.dispose);
    final requests = <int>[];
    await _pump(tester, style, requests: requests);
    final captionRect = tester.getRect(find.text('Profile'));
    final targetRect = tester.getRect(_target('Profile'));
    final gesture = await _scrub(tester);
    final referenceInk = await _captionInk(tester);
    expect(referenceInk, greaterThan(20));

    style.value = style.value.copyWith(
      heldInnerHighlight: const BoxShadow(
        color: Colors.white,
        spreadRadius: 12,
      ),
    );
    await tester.pumpAndSettle();
    expect(await _captionInk(tester), referenceInk);
    expect(tester.getRect(find.text('Profile')), captionRect);
    expect(tester.getRect(_target('Profile')), targetRect);
    expect(requests, isEmpty);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Profile'))
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    await tester.tap(_target('Profile'));
    await tester.pumpAndSettle();
    expect(requests, [2]);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<AppGlassNavigationStyle> style, {
  List<int>? requests,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: RepaintBoundary(
          key: _captureKey,
          child: ValueListenableBuilder<AppGlassNavigationStyle>(
            valueListenable: style,
            builder: (context, value, _) =>
                CustomFlutterGlassNavigationDockWidget(
                  selectedIndex: 0,
                  onItemSelected: (index) => requests?.add(index),
                  style: value,
                  items: const [
                    AppGlassNavigationItem(icon: Icons.circle, label: 'Browse'),
                    AppGlassNavigationItem(icon: Icons.circle, label: 'Saved'),
                    AppGlassNavigationItem(
                      icon: Icons.circle,
                      label: 'Profile',
                    ),
                  ],
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _scrub(WidgetTester tester) async {
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

CustomPainter _rimPainter(WidgetTester tester) {
  final stack = find
      .ancestor(
        of: find.byKey(const ValueKey('glass_foreground_lens')),
        matching: find.byType(Stack),
      )
      .first;
  final paint = find.descendant(of: stack, matching: find.byType(CustomPaint));
  expect(paint, findsOneWidget);
  return tester.widget<CustomPaint>(paint).painter!;
}

Future<List<int>> _paintPixels(
  WidgetTester tester,
  Size size,
  void Function(Canvas, Size) paint,
) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return data.buffer.asUint8List().toList();
  } finally {
    image.dispose();
    picture.dispose();
  }
}))!;

Future<int> _captionInk(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final caption = tester
      .getRect(find.text('Profile'))
      .shift(-tester.getTopLeft(find.byKey(_captureKey)));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var ink = 0;
      for (var y = caption.top.ceil(); y < caption.bottom.floor(); y++) {
        for (var x = caption.left.ceil(); x < caption.right.floor(); x++) {
          final offset = (y * image.width + x) * 4;
          if (pixels.getUint8(offset) < 32 &&
              pixels.getUint8(offset + 1) < 32 &&
              pixels.getUint8(offset + 2) < 32) {
            ink++;
          }
        }
      }
      return ink;
    } finally {
      image.dispose();
    }
  }))!;
}
