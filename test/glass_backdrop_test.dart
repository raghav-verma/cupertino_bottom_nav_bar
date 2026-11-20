import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:cupertino_bottom_nav_bar/src/custom_glass_backdrop_widget.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('zero optical strength preserves ordinary clipped blur', (
    tester,
  ) async {
    await tester.pumpWidget(_host(strength: 0));

    final backdrop = tester.widget<BackdropFilter>(
      find.byKey(const ValueKey('glass_backdrop_blur_fallback')),
    );
    expect(backdrop.filter, ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7));
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(24));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('Sharp foreground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('high contrast bypasses all filters in ${brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(strength: 8, highContrast: true, brightness: brightness),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('Sharp foreground'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('zero blur and optics creates no filtering layer', (
    tester,
  ) async {
    await tester.pumpWidget(_host(strength: 0, blurSigma: 0));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('Sharp foreground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final prepareWhenInactive in [false, true]) {
    testWidgets(
      'inactive preparation $prepareWhenInactive preserves unfiltered foreground',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            strength: 8,
            blurSigma: 0,
            opticsProgress: 0,
            prepareWhenInactive: prepareWhenInactive,
            onTap: () => taps++,
          ),
        );

        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(ImageFiltered), findsNothing);
        expect(
          find.byKey(const ValueKey('glass_backdrop_refracting')),
          findsNothing,
        );
        await tester.tap(find.text('Sharp foreground'));
        expect(taps, 1);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('inactive preparation preserves configured fallback blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(strength: 8, opticsProgress: 0, prepareWhenInactive: true),
    );
    final backdrop = tester.widget<BackdropFilter>(
      find.byKey(const ValueKey('glass_backdrop_blur_fallback')),
    );
    expect(backdrop.filter, ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive preparation cannot override high contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        strength: 8,
        opticsProgress: 0,
        prepareWhenInactive: true,
        highContrast: true,
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive preparation cannot activate zero optical strength', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(strength: 0, blurSigma: 0, prepareWhenInactive: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only interaction foreground opts into inactive preparation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dockHost(
        style: _dockStyle.copyWith(refractForegroundDuringInteraction: true),
      ),
    );
    final helpers = tester.widgetList<CustomGlassBackdropWidget>(
      find.byType(CustomGlassBackdropWidget),
    );
    final foreground = tester.widget<CustomGlassBackdropWidget>(
      find.byKey(const ValueKey('glass_foreground_lens')),
    );
    expect(foreground.prepareWhenInactive, isTrue);
    expect(foreground.opticsProgress, 0);
    for (final helper in helpers.where((helper) => helper != foreground)) {
      expect(helper.prepareWhenInactive, isFalse);
    }
    expect(
      find.descendant(
        of: find.byWidget(foreground),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported renderer retains blur and foreground interaction', (
    tester,
  ) async {
    // Flutter's normal widget-test backend is Skia. Real Impeller sampling is
    // a separate runtime gate; these tests do not claim GPU optical execution.
    expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
    var taps = 0;
    await tester.pumpWidget(_host(strength: 8, onTap: () => taps++));

    expect(
      find.byKey(const ValueKey('glass_backdrop_blur_fallback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('glass_backdrop_refracting')),
      findsNothing,
    );
    await tester.tap(find.text('Sharp foreground'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion retains usable static backdrop and no tickers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(strength: 0, reducedMotion: true));
    expect(
      find.byKey(const ValueKey('glass_backdrop_blur_fallback')),
      findsOneWidget,
    );
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(
      _host(strength: 0, highContrast: true, reducedMotion: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Sharp foreground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retained backdrop refreshes geometry after ancestor translation',
    (tester) async {
      final translation = ValueNotifier<double>(10);
      final record = _CompositionRecord();
      final retainedChild = RepaintBoundary(
        child: SizedBox(
          width: 180,
          height: 56,
          child: _LayerProbe(record: record),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: translation,
              child: retainedChild,
              builder: (context, value, child) =>
                  Transform.translate(offset: Offset(value, 20), child: child),
            ),
          ),
        ),
      );
      final initialPaints = record.paints;
      final initialCompositions = record.origins.length;
      final initialOrigin = record.origins.last;
      expect(initialOrigin, tester.getTopLeft(find.byType(_LayerProbe)));

      translation.value = 35;
      await tester.pump();

      expect(record.paints, initialPaints);
      expect(record.origins.length, greaterThan(initialCompositions));
      expect(record.origins.last, initialOrigin + const Offset(25, 0));
      expect(record.origins.last, tester.getTopLeft(find.byType(_LayerProbe)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      translation.dispose();
    },
  );

  testWidgets(
    'always-composited layer can bypass filtering without assertions',
    (tester) async {
      var calls = 0;
      final layer = CustomGlassBackdropLayer(
        resolveFilter: () {
          calls++;
          return null;
        },
      );
      // Both bypass and ordinary filtering must avoid the inherited filter
      // setter's forbidden markNeedsAddToScene on an always-composited layer.
      layer.filter = ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
      layer.buildScene(ui.SceneBuilder()).dispose();
      layer.buildScene(ui.SceneBuilder()).dispose();
      expect(calls, 2);
      expect(layer.filter, isNull);
      layer.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dock paints bar and selected lens in separate backdrop passes', (
    tester,
  ) async {
    await tester.pumpWidget(_dockHost());

    final helpers = tester.widgetList<CustomGlassBackdropWidget>(
      find.byType(CustomGlassBackdropWidget),
    );
    expect(helpers, hasLength(2));
    final outer = helpers.singleWhere((widget) => widget.blurSigma > 0);
    final lens = helpers.singleWhere((widget) => widget.blurSigma == 0);
    expect(
      find.ancestor(
        of: find.byWidget(lens),
        matching: find.byType(CustomGlassBackdropWidget),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byWidget(outer), matching: find.text('Browse')),
      findsNothing,
    );
    for (final label in ['Browse', 'Saved', 'Profile']) {
      expect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CustomGlassBackdropWidget),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    }
    expect(outer.radius, _dockStyle.radius);
    expect(outer.refractionStrength, _dockStyle.refractionStrength);
    expect(outer.refractionEdge, _dockStyle.refractionEdge);
    expect(outer.magnification, _dockStyle.magnification);
    expect(lens.magnification, _dockStyle.magnification);
    expect(
      tester.getSize(find.byWidget(outer)),
      Size(360 - _dockStyle.horizontalInset * 2, _dockStyle.surfaceHeight),
    );
    expect(
      tester.getSize(find.byType(CustomFlutterGlassNavigationDockWidget)),
      Size(360, _dockStyle.dockHeight),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected lens pressure preserves configured backdrop zoom', (
    tester,
  ) async {
    await tester.pumpWidget(_dockHost());
    final initialTextRect = tester.getRect(find.text('Browse'));
    final gesture = await tester.startGesture(initialTextRect.center);
    await tester.pump();
    await tester.pump(_dockStyle.duration);

    final lens = tester
        .widgetList<CustomGlassBackdropWidget>(
          find.byType(CustomGlassBackdropWidget),
        )
        .singleWhere((widget) => widget.blurSigma == 0);
    expect(lens.magnification, _dockStyle.magnification);
    expect(tester.getRect(find.text('Browse')), initialTextRect);
    await gesture.cancel();
    await tester.pumpAndSettle();
    final releasedLens = tester
        .widgetList<CustomGlassBackdropWidget>(
          find.byType(CustomGlassBackdropWidget),
        )
        .singleWhere((widget) => widget.blurSigma == 0);
    expect(releasedLens.magnification, _dockStyle.magnification);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'foreground edge override leaves both backdrop widths unchanged',
    (tester) async {
      final shared = _dockStyle.copyWith(
        refractForegroundDuringInteraction: true,
        pressedScale: 1.18,
      );
      final overridden = shared.copyWith(foregroundRefractionEdge: 6);
      await tester.pumpWidget(_dockHost(style: shared));
      final originalTextRect = tester.getRect(find.text('Browse'));
      final gesture = await tester.startGesture(originalTextRect.center);
      await tester.pumpAndSettle();

      void expectEdges(double foregroundEdge) {
        final foreground = tester.widget<CustomGlassBackdropWidget>(
          find.byKey(const ValueKey('glass_foreground_lens')),
        );
        expect(foreground.refractionEdge, foregroundEdge);
        expect(foreground.opticsProgress, 1);
        expect(foreground.blurSigma, 0);
        final backdrops = tester
            .widgetList<CustomGlassBackdropWidget>(
              find.byType(CustomGlassBackdropWidget),
            )
            .where((widget) => !identical(widget, foreground));
        expect(backdrops, hasLength(2));
        for (final backdrop in backdrops) {
          expect(backdrop.refractionEdge, shared.refractionEdge);
        }
        expect(tester.getRect(find.text('Browse')), originalTextRect);
      }

      // Omitting the optional field preserves the original shared optical edge.
      expectEdges(shared.refractionEdge);
      for (final style in [overridden, overridden.copyWith()]) {
        await tester.pumpWidget(_dockHost(style: style));
        await tester.pumpAndSettle();
        expectEdges(6);
      }
      await tester.pumpWidget(
        _dockHost(style: overridden.copyWith(foregroundRefractionEdge: null)),
      );
      await tester.pumpAndSettle();
      expectEdges(shared.refractionEdge);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('high-contrast dock suppresses both optical passes', (
    tester,
  ) async {
    await tester.pumpWidget(_dockHost(highContrast: true));

    final helper = tester.widget<CustomGlassBackdropWidget>(
      find.byType(CustomGlassBackdropWidget),
    );
    expect(helper.highContrast, isTrue);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    final selected = tester.widget<DecoratedBox>(
      find.byKey(const Key('glass_navigation_selection')),
    );
    expect(
      (selected.decoration as BoxDecoration).color,
      _dockStyle.selectedSurfaceColor.withValues(alpha: 1),
    );
    expect(find.text('Browse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _dockStyle = AppGlassNavigationStyle(
  actionHeight: 52,
  horizontalInset: 18,
  contentInset: 6,
  topInset: 5,
  bottomInset: 7,
  radius: 27,
  blurSigma: 7,
  refractionStrength: 8,
  refractionEdge: 14,
  magnification: 1.08,
);

Widget _dockHost({
  bool highContrast = false,
  AppGlassNavigationStyle style = _dockStyle,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: CustomFlutterGlassNavigationDockWidget(
            items: const [
              AppGlassNavigationItem(
                icon: Icons.explore_outlined,
                label: 'Browse',
              ),
              AppGlassNavigationItem(
                icon: Icons.bookmark_border,
                label: 'Saved',
              ),
              AppGlassNavigationItem(
                icon: Icons.person_outline,
                label: 'Profile',
              ),
            ],
            selectedIndex: 0,
            onItemSelected: (_) {},
            style: style,
          ),
        ),
      ),
    ),
  ),
);

class _CompositionRecord {
  int paints = 0;
  final origins = <Offset>[];
}

class _LayerProbe extends SingleChildRenderObjectWidget {
  const _LayerProbe({required this.record})
    : super(child: const ColoredBox(color: Color(0x20000000)));

  final _CompositionRecord record;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayerProbe(record);
}

class _RenderLayerProbe extends RenderProxyBox {
  _RenderLayerProbe(this.record);

  final _CompositionRecord record;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  CustomGlassBackdropLayer? get layer =>
      super.layer as CustomGlassBackdropLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    record.paints++;
    layer ??= CustomGlassBackdropLayer(
      resolveFilter: () {
        record.origins.add(localToGlobal(Offset.zero));
        return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
      },
    );
    context.pushLayer(layer!, super.paint, offset);
  }
}

Widget _host({
  required double strength,
  double blurSigma = 7,
  double opticsProgress = 1,
  bool prepareWhenInactive = false,
  bool highContrast = false,
  bool reducedMotion = false,
  Brightness brightness = Brightness.light,
  VoidCallback? onTap,
}) => MaterialApp(
  theme: brightness == Brightness.light ? ThemeData.light() : ThemeData.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 56,
          child: CustomGlassBackdropWidget(
            radius: 24,
            blurSigma: blurSigma,
            refractionStrength: strength,
            refractionEdge: 12,
            magnification: 1.03,
            opticsProgress: opticsProgress,
            prepareWhenInactive: prepareWhenInactive,
            highContrast: highContrast,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const Center(child: Text('Sharp foreground')),
            ),
          ),
        ),
      ),
    ),
  ),
);
