import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_navigation_dock_example/main.dart' as example;
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final darkRtl in [false, true]) {
    testWidgets(
      'stable control paint is isolated with identical ${darkRtl ? 'dark RTL' : 'light LTR'} output',
      (tester) async {
        tester.view.physicalSize = const Size(390, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => debugOnProfilePaint = null);

        final baseline = await _exercise(
          tester,
          isolated: false,
          darkRtl: darkRtl,
        );
        final candidate = await _exercise(
          tester,
          isolated: true,
          darkRtl: darkRtl,
        );
        expect(candidate.length, baseline.length);
        for (var i = 0; i < baseline.length; i++) {
          expect(
            candidate[i].pixels,
            orderedEquals(baseline[i].pixels),
            reason: 'state $i pixels',
          );
          expect(
            candidate[i].bounds,
            baseline[i].bounds,
            reason: 'state $i layout',
          );
          expect(
            candidate[i].semantics,
            baseline[i].semantics,
            reason: 'state $i semantics',
          );
          if (i > 0) {
            expect(baseline[i].stablePaints, everyElement(greaterThan(0)));
            expect(candidate[i].stablePaints, everyElement(0));
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<List<_Snapshot>> _exercise(
  WidgetTester tester, {
  required bool isolated,
  required bool darkRtl,
}) async {
  example.main();
  await tester.pumpAndSettle();
  if (darkRtl) {
    tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, 'Dark theme'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, 'RTL layout'))
        .onSelected!(true);
    await tester.pumpAndSettle();
  }
  final request = tester
      .widget<CustomGlassNavigationDockWidget>(
        find.byType(CustomGlassNavigationDockWidget),
      )
      .onItemSelected;
  final controls = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ExampleControls',
  );
  final theme = Theme.of(tester.element(controls));
  Padding? original;
  tester
      .element(controls)
      .visitChildren((child) => original = child.widget as Padding);
  final column = original!.child! as Column;
  final groups = column.children.whereType<RepaintBoundary>().toList();
  expect(groups, hasLength(3));
  final groupKeys = [for (var i = 0; i < groups.length; i++) GlobalKey()];
  final rootKey = GlobalKey();
  var groupIndex = 0;
  final children = <Widget>[
    for (final child in column.children)
      if (child is RepaintBoundary)
        if (isolated)
          RepaintBoundary(key: groupKeys[groupIndex++], child: child.child)
        else
          KeyedSubtree(key: groupKeys[groupIndex++], child: child.child!)
      else
        child,
  ];
  // Compare the same actual controls with only the three proxy boundaries
  // present/absent. No alternate copy of their content or interaction logic.
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Directionality(
          textDirection: darkRtl ? TextDirection.rtl : TextDirection.ltr,
          child: RepaintBoundary(
            key: rootKey,
            child: SingleChildScrollView(
              child: Padding(
                padding: original!.padding,
                child: Column(
                  crossAxisAlignment: column.crossAxisAlignment,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final stableObjects = <RenderObject>[
    for (final key in groupKeys)
      if (isolated)
        (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .child!
      else
        key.currentContext!.findRenderObject()!,
  ];
  final counts = List<int>.filled(3, 0);
  debugOnProfilePaint = (object) {
    final index = stableObjects.indexOf(object);
    if (index >= 0) counts[index]++;
  };
  final handle = tester.ensureSemantics();
  try {
    final snapshots = <_Snapshot>[];
    for (final index in [null, 3, 2, 4]) {
      counts.fillRange(0, counts.length, 0);
      if (index != null) request(index);
      await tester.pumpAndSettle();
      final bytes = (await tester.runAsync(() async {
        final image =
            await (rootKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        try {
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
      final bounds = <Rect>[
        for (final key in groupKeys) tester.getRect(find.byKey(key)),
        tester.getRect(find.byType(Slider)),
      ];
      final semantics = <String>[
        for (final finder in [
          find.text('Reset'),
          find.widgetWithText(FilterChip, 'Messages enabled'),
          find.widgetWithText(FilterChip, 'Dark theme'),
        ])
          // Overlay portal diagnostic identities differ between fresh hosts;
          // compare the serialized user-facing semantics, not object hashes.
          tester
              .getSemantics(finder)
              .getSemanticsData()
              .toString()
              .replaceAll(
                RegExp(
                  r', traversalParentIdentifier: _OverlayPortalState#[a-f0-9]+',
                ),
                '',
              ),
      ];
      snapshots.add(
        _Snapshot(
          pixels: bytes,
          bounds: bounds,
          semantics: semantics,
          stablePaints: List.of(counts),
        ),
      );
    }
    return snapshots;
  } finally {
    handle.dispose();
    debugOnProfilePaint = null;
  }
}

class _Snapshot {
  const _Snapshot({
    required this.pixels,
    required this.bounds,
    required this.semantics,
    required this.stablePaints,
  });
  final Uint8List pixels;
  final List<Rect> bounds;
  final List<String> semantics;
  final List<int> stablePaints;
}
