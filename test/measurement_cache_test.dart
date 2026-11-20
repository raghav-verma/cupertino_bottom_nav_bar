import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['One', 'Two', 'Three'];
const _style = AppGlassNavigationStyle(
  // Selection-only updates do not need a different caption paint style.
  foregroundColor: Colors.black,
  selectedForegroundColor: Colors.black,
  labelStyle: TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1.35),
);

void main() {
  testWidgets('unchanged captions reuse measurements across host updates', (
    tester,
  ) async {
    await _pumpDock(tester);
    final creations = _TextPainterCreations();
    addTearDown(creations.dispose);
    final state = tester.state(
      find.byType(CustomFlutterGlassNavigationDockWidget),
    );
    final height = tester
        .getSize(find.byKey(const Key('flutter_glass_navigation_dock')))
        .height;

    await _pumpDock(tester);
    await _pumpDock(tester, selectedIndex: 1);
    await _pumpDock(
      tester,
      selectedIndex: 1,
      style: _style.copyWith(blurSigma: 0),
    );
    expect(
      tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
      same(state),
    );
    expect(creations.count, 0);
    expect(
      tester
          .getSize(find.byKey(const Key('flutter_glass_navigation_dock')))
          .height,
      height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'label snapshots invalidate after mutation and keep only latest input',
    (tester) async {
      final labels = List<String>.of(_labels);
      await _pumpDock(tester, labels: labels, width: 240);
      final creations = _TextPainterCreations();
      addTearDown(creations.dispose);
      expect(find.byType(SingleChildScrollView), findsNothing);

      labels[0] = 'A complete considerably longer caption';
      await _pumpDock(tester, labels: labels, width: 240);
      expect(creations.count, greaterThanOrEqualTo(labels.length));
      expect(
        creations.live,
        isEmpty,
        reason: 'Measurement painters are disposed immediately.',
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      creations.reset();
      labels[0] = _labels[0];
      await _pumpDock(tester, labels: labels, width: 240);
      expect(creations.count, greaterThanOrEqualTo(labels.length));
      expect(creations.live, isEmpty);
      expect(find.byType(SingleChildScrollView), findsNothing);
      creations.reset();
      await _pumpDock(tester, labels: labels, width: 240);
      expect(creations.count, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resolved caption style and accessibility spacing invalidate measurements',
    (tester) async {
      await _pumpDock(tester, width: 240);
      final creations = _TextPainterCreations();
      addTearDown(creations.dispose);
      final baseline = tester.getSize(
        find.byKey(const Key('flutter_glass_navigation_dock')),
      );
      await _pumpDock(
        tester,
        width: 240,
        style: _style.copyWith(
          labelStyle: _style.labelStyle.copyWith(height: 3),
        ),
      );
      expect(creations.count, greaterThanOrEqualTo(_labels.length));
      expect(
        tester
            .getSize(find.byKey(const Key('flutter_glass_navigation_dock')))
            .height,
        greaterThan(baseline.height),
      );

      creations.reset();
      await _pumpDock(tester, width: 240, letterSpacing: 20);
      expect(creations.count, greaterThanOrEqualTo(_labels.length));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('text scaler changes remeasure the complete caption lane', (
    tester,
  ) async {
    await _pumpDock(tester, width: 240);
    final creations = _TextPainterCreations();
    addTearDown(creations.dispose);
    final baseline = tester
        .getSize(find.byKey(const Key('flutter_glass_navigation_dock')))
        .height;
    await _pumpDock(tester, width: 240, scaler: TextScaler.linear(3));
    expect(creations.count, greaterThanOrEqualTo(_labels.length));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('flutter_glass_navigation_dock')))
          .height,
      greaterThan(baseline),
    );
    creations.reset();
    await _pumpDock(tester, width: 240, scaler: TextScaler.linear(3));
    expect(creations.count, 0);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} ambient text height behavior matches caption geometry and cache',
      (tester) async {
        const expanded = TextHeightBehavior();
        const trimmed = TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        );
        final style = _style.copyWith(
          labelStyle: _style.labelStyle.copyWith(fontSize: 24, height: 4),
        );
        await _pumpDock(
          tester,
          style: style,
          width: 600,
          brightness: brightness,
          fallbackTextHeightBehavior: expanded,
        );
        final state = tester.state(
          find.byType(CustomFlutterGlassNavigationDockWidget),
        );
        final expandedHeight = tester.getSize(find.text(_labels.first)).height;
        final creations = _TextPainterCreations();
        addTearDown(creations.dispose);

        Future<void> check({
          required TextHeightBehavior fallback,
          TextHeightBehavior? override,
          required TextHeightBehavior effective,
          required bool remeasures,
        }) async {
          creations.reset();
          await _pumpDock(
            tester,
            style: style,
            width: 600,
            brightness: brightness,
            fallbackTextHeightBehavior: fallback,
            defaultTextStyleHeightBehavior: override,
          );
          expect(
            creations.captionHeightBehaviors,
            hasLength(remeasures ? _labels.length : 0),
          );
          if (remeasures) {
            expect(creations.captionHeightBehaviors, everyElement(effective));
          }
          expect(creations.live, isEmpty);
          expect(
            tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
            same(state),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(_labels.first),
          );
          expect(paragraph.textHeightBehavior, effective);
          final captionHeight = paragraph.size.height;
          expect(
            captionHeight,
            effective == trimmed ? lessThan(expandedHeight) : expandedHeight,
          );
          // These deliberately tall captions exceed the minimum action lane,
          // so equality checks the measurement-driven lane, not merely fit.
          final target = find
              .ancestor(
                of: find.text(_labels.first),
                matching: find.byType(InkWell),
              )
              .first;
          expect(
            tester.getSize(target).height,
            closeTo(style.iconArea + style.labelGap + captionHeight, 0.001),
          );
          expect(tester.takeException(), isNull);
        }

        await check(fallback: trimmed, effective: trimmed, remeasures: true);
        await check(fallback: trimmed, effective: trimmed, remeasures: false);
        // DefaultTextStyle takes precedence over its ambient fallback.
        await check(
          fallback: trimmed,
          override: expanded,
          effective: expanded,
          remeasures: true,
        );
        await check(
          fallback: expanded,
          override: expanded,
          effective: expanded,
          remeasures: false,
        );
        // Removing an override with the same resolved behavior reuses metrics.
        await check(fallback: expanded, effective: expanded, remeasures: false);
        await check(fallback: trimmed, effective: trimmed, remeasures: true);
      },
    );

    testWidgets(
      '${brightness.name} ambient locale shapes captions and invalidates their cache',
      (tester) async {
        const initialLocale = Locale('en');
        const changedLocale = Locale('en', 'GB');
        await _pumpDock(tester, brightness: brightness, locale: initialLocale);
        final state = tester.state(
          find.byType(CustomFlutterGlassNavigationDockWidget),
        );
        final baseline = tester.getSize(
          find.byKey(const Key('flutter_glass_navigation_dock')),
        );
        final creations = _TextPainterCreations();
        addTearDown(creations.dispose);

        for (final locale in [changedLocale, initialLocale]) {
          await _pumpDock(tester, brightness: brightness, locale: locale);
          expect(creations.captionLocales, hasLength(_labels.length));
          expect(creations.captionLocales, everyElement(locale));
          expect(creations.live, isEmpty);
          expect(
            tester.state(find.byType(CustomFlutterGlassNavigationDockWidget)),
            same(state),
          );
          // Ahem uses the same metrics for these locales. Only shaping inputs
          // change; this does not claim coverage of regional font differences.
          expect(
            tester.getSize(
              find.byKey(const Key('flutter_glass_navigation_dock')),
            ),
            baseline,
          );

          creations.reset();
          await _pumpDock(tester, brightness: brightness, locale: locale);
          expect(creations.count, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'direction change remeasures and reverses destination placement',
    (tester) async {
      await _pumpDock(tester);
      final creations = _TextPainterCreations();
      addTearDown(creations.dispose);
      expect(
        tester.getCenter(find.text('One')).dx,
        lessThan(tester.getCenter(find.text('Three')).dx),
      );
      await _pumpDock(tester, direction: TextDirection.rtl);
      expect(creations.count, greaterThanOrEqualTo(_labels.length));
      expect(
        tester.getCenter(find.text('One')).dx,
        greaterThan(tester.getCenter(find.text('Three')).dx),
      );
      creations.reset();
      await _pumpDock(tester, direction: TextDirection.rtl);
      expect(creations.count, 0);
    },
  );

  testWidgets('icon-only mode clears caption geometry before captions return', (
    tester,
  ) async {
    await _pumpDock(
      tester,
      width: 240,
      labels: const ['A long complete caption', 'Two', 'Three'],
    );
    final creations = _TextPainterCreations();
    addTearDown(creations.dispose);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await _pumpDock(
      tester,
      width: 240,
      labels: const ['A long complete caption', 'Two', 'Three'],
      iconOnly: true,
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    // Entering icon-only mode also reparents Icon's own glyph paragraphs.
    // Observe the stable icon-only rebuild separately from that lifecycle work.
    creations.reset();
    await _pumpDock(
      tester,
      width: 240,
      labels: const ['A long complete caption', 'Two', 'Three'],
      iconOnly: true,
    );
    expect(creations.count, 0);
    await _pumpDock(
      tester,
      width: 240,
      labels: const ['A long complete caption', 'Two', 'Three'],
    );
    expect(creations.count, greaterThanOrEqualTo(_labels.length));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'font availability invalidates once and listener ends at disposal',
    (tester) async {
      await _pumpDock(tester);
      final creations = _TextPainterCreations();
      addTearDown(creations.dispose);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pumpAndSettle();
      expect(creations.count, _labels.length);
      expect(creations.live, isEmpty);
      creations.reset();
      await _pumpDock(tester);
      expect(creations.count, 0);

      // A queued notification and later notifications cannot revive disposed state.
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pumpWidget(const SizedBox.shrink());
      creations.reset();
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pumpAndSettle();
      expect(creations.count, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpDock(
  WidgetTester tester, {
  List<String> labels = _labels,
  AppGlassNavigationStyle style = _style,
  TextScaler scaler = TextScaler.noScaling,
  TextDirection direction = TextDirection.ltr,
  bool iconOnly = false,
  int selectedIndex = 0,
  double width = 390,
  double? letterSpacing,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  TextHeightBehavior fallbackTextHeightBehavior = const TextHeightBehavior(),
  TextHeightBehavior? defaultTextStyleHeightBehavior,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('en', 'GB')],
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: MediaQuery.applyTextStyleOverrides(
          lineHeightScaleFactorOverride: null,
          letterSpacingOverride: letterSpacing,
          wordSpacingOverride: null,
          paragraphSpacingOverride: null,
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: width,
                  child: DefaultTextHeightBehavior(
                    textHeightBehavior: fallbackTextHeightBehavior,
                    child: DefaultTextStyle.merge(
                      textHeightBehavior: defaultTextStyleHeightBehavior,
                      child: CustomFlutterGlassNavigationDockWidget(
                        items: [
                          for (final label in labels)
                            AppGlassNavigationItem(
                              icon: Icons.circle_outlined,
                              label: label,
                            ),
                        ],
                        selectedIndex: selectedIndex,
                        onItemSelected: (_) {},
                        style: style,
                        iconOnly: iconOnly,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Framework debug allocation events let these tests observe shaping work
// without adding counters or hooks to the package's production/public API.
// Only identity integers are retained, never TextPainter instances.
class _TextPainterCreations {
  _TextPainterCreations() {
    FlutterMemoryAllocations.instance.addListener(_onEvent);
  }

  int count = 0;
  final Set<int> live = {};
  final List<Locale?> captionLocales = [];
  final List<TextHeightBehavior?> captionHeightBehaviors = [];

  void _onEvent(ObjectEvent event) {
    if (event.object is! TextPainter) return;
    if (event is ObjectCreated) {
      count++;
      live.add(identityHashCode(event.object));
      final painter = event.object as TextPainter;
      if (_labels.contains(painter.text?.toPlainText())) {
        captionLocales.add(painter.locale);
        captionHeightBehaviors.add(painter.textHeightBehavior);
      }
    } else if (event is ObjectDisposed) {
      live.remove(identityHashCode(event.object));
    }
  }

  void reset() {
    count = 0;
    live.clear();
    captionLocales.clear();
    captionHeightBehaviors.clear();
  }

  void dispose() => FlutterMemoryAllocations.instance.removeListener(_onEvent);
}
