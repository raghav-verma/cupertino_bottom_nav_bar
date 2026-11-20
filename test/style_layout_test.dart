import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _items = [
  AppGlassNavigationItem(icon: Icons.explore_outlined, label: 'Browse'),
  AppGlassNavigationItem(icon: Icons.bookmark_border, label: 'Saved'),
  AppGlassNavigationItem(icon: Icons.person_outline, label: 'Profile'),
];

const _fiveItems = [
  ..._items,
  AppGlassNavigationItem(icon: Icons.star_outline, label: 'Featured'),
  AppGlassNavigationItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
];

const _selectionKey = Key('glass_navigation_selection');
const _dockKey = Key('flutter_glass_navigation_dock');

void main() {
  test(
    'foreground edge defaults to the shared width and overrides independently',
    () {
      const defaults = AppGlassNavigationStyle();
      expect(defaults.foregroundRefractionEdge, isNull);
      expect(
        defaults.resolvedForegroundRefractionEdge,
        defaults.refractionEdge,
      );
      const shared = AppGlassNavigationStyle(refractionEdge: 18);
      expect(shared.resolvedForegroundRefractionEdge, 18);
      const independent = AppGlassNavigationStyle(
        refractionEdge: 18,
        foregroundRefractionEdge: 6,
      );
      expect(independent.resolvedForegroundRefractionEdge, 6);
      expect(independent.refractionEdge, 18);
      expect(independent.magnification, defaults.magnification);
      expect(independent.refractionStrength, defaults.refractionStrength);
    },
  );

  test(
    'foreground edge copyWith retains omission and clears explicit null',
    () {
      const style = AppGlassNavigationStyle(
        refractionEdge: 18,
        foregroundRefractionEdge: 6,
      );
      expect(style.copyWith().foregroundRefractionEdge, 6);
      expect(
        style.copyWith(refractionEdge: 20).resolvedForegroundRefractionEdge,
        6,
      );
      final cleared = style.copyWith(foregroundRefractionEdge: null);
      expect(cleared.foregroundRefractionEdge, isNull);
      expect(cleared.resolvedForegroundRefractionEdge, 18);
      final integerOverride = cleared.copyWith(foregroundRefractionEdge: 8);
      expect(integerOverride.foregroundRefractionEdge, isA<double>());
      expect(integerOverride.resolvedForegroundRefractionEdge, 8);
      expect(
        () => style.copyWith(foregroundRefractionEdge: '6'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'foregroundRefractionEdge',
          ),
        ),
      );
    },
  );

  test(
    'foreground edge validates inputs and safely resolves unchecked values',
    () {
      for (final invalid in [
        0.0,
        -1.0,
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => AppGlassNavigationStyle(foregroundRefractionEdge: invalid),
          throwsAssertionError,
        );
        expect(
          () => const AppGlassNavigationStyle().copyWith(
            foregroundRefractionEdge: invalid,
          ),
          throwsAssertionError,
        );
        expect(
          () => AppGlassNavigationStyle.fromTheme(
            ThemeData.light(),
            foregroundRefractionEdge: invalid,
          ),
          throwsAssertionError,
        );
        expect(
          _UncheckedEdgeStyle(
            foregroundRefractionEdge: invalid,
            refractionEdge: 18,
          ).resolvedForegroundRefractionEdge,
          18,
        );
        expect(
          _UncheckedEdgeStyle(
            foregroundRefractionEdge: invalid,
            refractionEdge: invalid,
          ).resolvedForegroundRefractionEdge,
          12,
        );
        expect(
          _UncheckedEdgeStyle(
            foregroundRefractionEdge: 6,
            refractionEdge: invalid,
          ).resolvedForegroundRefractionEdge,
          6,
        );
        expect(
          _UncheckedEdgeStyle(refractionEdge: invalid)
              .resolvedForegroundRefractionEdge,
          12,
        );
      }
    },
  );

  test(
    'const styles resolve positive finite springs and retain null timing',
    () {
      const spring = SpringDescription(mass: 1, stiffness: 560, damping: 36);
      const style = AppGlassNavigationStyle(selectionSpring: spring);
      expect(style.resolvedSelectionSpring, same(spring));
      expect(const AppGlassNavigationStyle().resolvedSelectionSpring, isNull);
    },
  );

  for (final parameter in ['mass', 'stiffness', 'damping']) {
    test('invalid spring $parameter falls back and theme factory asserts', () {
      for (final value in [
        0.0,
        -1.0,
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        final spring = SpringDescription(
          mass: parameter == 'mass' ? value : 1,
          stiffness: parameter == 'stiffness' ? value : 560,
          damping: parameter == 'damping' ? value : 36,
        );
        // Const-compatible construction cannot inspect nested object fields.
        // Resolution validates them before the renderer creates a simulation.
        final style = AppGlassNavigationStyle(selectionSpring: spring);
        expect(style.resolvedSelectionSpring, isNull);
        expect(
          () => AppGlassNavigationStyle.fromTheme(
            ThemeData.light(),
            selectionSpring: spring,
          ),
          throwsAssertionError,
        );
      }
    });
  }

  testWidgets('applies caller-resolved colors, typography and geometry', (
    tester,
  ) async {
    const style = AppGlassNavigationStyle(
      surfaceColor: Color(0xAA102030),
      selectedSurfaceColor: Color(0xBB304050),
      foregroundColor: Color(0xFF405060),
      selectedForegroundColor: Color(0xFF607080),
      outlineColor: Color(0xFF8090A0),
      selectionOutlineColor: Color(0xFFA0B0C0),
      shadowColor: Color(0x33010203),
      labelStyle: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      actionHeight: 64,
      minTargetSize: 56,
      horizontalInset: 20,
      contentInset: 6,
      topInset: 7,
      bottomInset: 11,
      radius: 17,
      outlineWidth: 2,
      selectionHorizontalInset: 3,
      selectionVerticalInset: 2,
    );
    await _pumpDock(tester, style: style, width: 420, selectedIndex: 1);

    final selected = tester.widget<Text>(find.text('Saved'));
    final ordinary = tester.widget<Text>(find.text('Browse'));
    expect(selected.style?.color, style.selectedForegroundColor);
    expect(ordinary.style?.color, style.foregroundColor);
    expect(selected.style?.fontSize, 14);
    expect(selected.style?.height, 1.2);
    expect(selected.style?.fontWeight, FontWeight.w600);
    expect(tester.getSize(find.byKey(_dockKey)), Size(420, style.dockHeight));
    expect(_surfaceColors(tester), contains(style.surfaceColor));
    final decoration = _selectionDecoration(tester);
    expect(decoration.color, style.selectedSurfaceColor);
    expect(decoration.borderRadius, BorderRadius.circular(17));
    expect(
      decoration.border,
      Border.all(color: style.selectionOutlineColor, width: 2),
    );
    final target = tester.getRect(_target('Saved'));
    final capsule = tester.getRect(find.byKey(_selectionKey));
    expect(capsule.left, closeTo(target.left + 3, 0.01));
    expect(capsule.top, closeTo(target.top + 2, 0.01));
    expect(capsule.width, closeTo(target.width - 6, 0.01));
    expect(capsule.height, closeTo(target.height - 4, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    test(
      'theme factory forwards optical and spring inputs in ${brightness.name}',
      () {
        final theme = ThemeData(brightness: brightness);
        final defaults = AppGlassNavigationStyle.fromTheme(theme);
        const spring = SpringDescription(mass: 1, stiffness: 560, damping: 36);
        final optical = AppGlassNavigationStyle.fromTheme(
          theme,
          refractionStrength: 8,
          foregroundRefractionEdge: 6,
          selectionSpring: spring,
        );

        expect(defaults.refractionStrength, 0);
        expect(defaults.foregroundRefractionEdge, isNull);
        expect(
          defaults.resolvedForegroundRefractionEdge,
          defaults.refractionEdge,
        );
        expect(defaults.selectionSpring, isNull);
        expect(optical.refractionStrength, 8);
        expect(optical.foregroundRefractionEdge, 6);
        expect(optical.resolvedForegroundRefractionEdge, 6);
        expect(optical.selectionSpring, same(spring));
        expect(optical.refractionEdge, defaults.refractionEdge);
        expect(optical.magnification, defaults.magnification);
        expect(optical.surfaceColor, defaults.surfaceColor);
        expect(optical.selectedSurfaceColor, defaults.selectedSurfaceColor);
        expect(optical.labelStyle, defaults.labelStyle);
      },
    );

    testWidgets('theme-derived style applies ${brightness.name} colors', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF486A92),
          brightness: brightness,
        ),
      );
      final style = AppGlassNavigationStyle.fromTheme(theme);
      await _pumpDock(tester, theme: theme);

      expect(_surfaceColors(tester), contains(style.surfaceColor));
      expect(_selectionDecoration(tester).color, style.selectedSurfaceColor);
      expect(
        tester.widget<Text>(find.text('Browse')).style?.color,
        theme.colorScheme.primary,
      );
      expect(
        tester.widget<Text>(find.text('Saved')).style?.color,
        theme.colorScheme.onSurface,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('responds to a host theme change without losing selection', (
    tester,
  ) async {
    await _pumpDock(tester, selectedIndex: 2);
    final light = _selectionDecoration(tester).color;
    final darkTheme = ThemeData.dark();
    await _pumpDock(tester, selectedIndex: 2, theme: darkTheme);
    await tester.pumpAndSettle();

    expect(
      _selectionDecoration(tester).color,
      AppGlassNavigationStyle.fromTheme(darkTheme).selectedSurfaceColor,
    );
    expect(_selectionDecoration(tester).color, isNot(light));
    expect(
      tester.getRect(find.byKey(_selectionKey)).center.dx,
      closeTo(tester.getRect(_target('Profile')).center.dx, 0.01),
    );
  });

  testWidgets('high contrast removes blur and makes surface tints opaque', (
    tester,
  ) async {
    const style = AppGlassNavigationStyle();
    await _pumpDock(tester, style: style);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await _pumpDock(tester, style: style, highContrast: true);

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      _surfaceColors(tester),
      contains(style.surfaceColor.withValues(alpha: 1)),
    );
    final selection = _selectionDecoration(tester);
    expect(selection.color, style.selectedSurfaceColor.withValues(alpha: 1));
    expect(
      selection.border,
      Border.all(
        color: style.selectedForegroundColor,
        width: style.outlineWidth,
      ),
    );
    final decorations = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    expect(
      decorations
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .any((decoration) => decoration.gradient != null),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bold captions use the same resolved weight for layout and Text', (
    tester,
  ) async {
    const style = AppGlassNavigationStyle(
      labelStyle: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
    await _pumpDock(tester, style: style, width: 300, selectedIndex: 1);
    expect(
      tester.widget<Text>(find.text('Saved')).style?.fontWeight,
      FontWeight.w500,
    );

    await _pumpDock(
      tester,
      style: style,
      width: 300,
      selectedIndex: 1,
      boldText: true,
    );
    for (final item in _items) {
      final caption = tester.widget<Text>(find.text(item.label));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(item.label),
      );
      final renderedStyle = (paragraph.text as TextSpan).style!;
      // Ahem's weights have equal advances. Comparing effective styles catches
      // the measurement mismatch without shipping an application font fixture.
      expect(renderedStyle.fontWeight, FontWeight.bold);
      expect(caption.style?.fontWeight, renderedStyle.fontWeight);
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: caption.style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      expect(
        tester.getSize(_target(item.label)).width,
        greaterThanOrEqualTo(painter.width + style.labelPadding * 2),
      );
      painter.dispose();
    }
    expect(tester.takeException(), isNull);

    await _pumpDock(tester, style: style, width: 300, selectedIndex: 1);
    expect(
      tester.widget<Text>(find.text('Saved')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      tester.getRect(find.byKey(_selectionKey)).center.dx,
      closeTo(tester.getRect(_target('Saved')).center.dx, 0.01),
    );
  });

  testWidgets('zero blur omits sampling while retaining the resolved tint', (
    tester,
  ) async {
    const style = AppGlassNavigationStyle(blurSigma: 0);
    await _pumpDock(tester, style: style);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_surfaceColors(tester), contains(style.surfaceColor));
  });

  testWidgets(
    'reduced motion requests selection and settles without movement',
    (tester) async {
      const style = AppGlassNavigationStyle(
        duration: Duration(seconds: 5),
        selectionScale: 1.1,
        pressedScale: 0.8,
        pressureStretch: 0.2,
      );
      final requests = <int>[];
      await _pumpDock(
        tester,
        style: style,
        reduceMotion: true,
        onSelected: requests.add,
      );
      await tester.tap(_target('Profile'));
      await tester.pump();
      expect(requests, [2]);
      expect(
        tester.getRect(find.byKey(_selectionKey)).center.dx,
        closeTo(tester.getRect(_target('Browse')).center.dx, 0.01),
      );
      await _pumpDock(
        tester,
        style: style,
        reduceMotion: true,
        selectedIndex: 2,
      );
      final settled = tester.getRect(find.byKey(_selectionKey));
      expect(
        settled.center.dx,
        closeTo(tester.getRect(_target('Profile')).center.dx, 0.01),
      );
      final transform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(_selectionKey),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.getMaxScaleOnAxis(), 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.byKey(_selectionKey)), settled);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('badge text uses resolved styling and one destination label', (
    tester,
  ) async {
    const style = AppGlassNavigationStyle(
      badgeBackgroundColor: Color(0xFF123456),
      badgeForegroundColor: Color(0xFFFEDCBA),
      badgeStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      badgeMinWidth: 28,
      badgeMinHeight: 22,
    );
    await _pumpDock(
      tester,
      style: style,
      items: const [
        AppGlassNavigationItem(icon: Icons.explore_outlined, label: 'Browse'),
        AppGlassNavigationItem(
          icon: Icons.bookmark_border,
          label: 'Saved',
          badgeLabel: 'NEW',
        ),
        AppGlassNavigationItem(icon: Icons.person_outline, label: 'Profile'),
      ],
    );

    final badge = tester.widget<Text>(find.text('NEW'));
    expect(badge.style?.color, style.badgeForegroundColor);
    expect(badge.style?.fontSize, 12);
    expect(badge.style?.fontWeight, FontWeight.w800);
    final decoration = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('NEW'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (decoration.decoration as BoxDecoration).color,
      style.badgeBackgroundColor,
    );
    expect(
      tester.getSize(find.byWidget(decoration)).width,
      greaterThanOrEqualTo(28),
    );
    expect(
      tester.getSize(find.byWidget(decoration)).height,
      greaterThanOrEqualTo(22),
    );
    expect(find.bySemanticsLabel('Saved, NEW'), findsOneWidget);
    expect(find.bySemanticsLabel('NEW'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final asset in <String?>[
    null,
    'assets/intentionally_missing_portrait.png',
  ]) {
    testWidgets(
      'portrait ${asset == null ? 'initials' : 'missing asset'} fallback stays decorative',
      (tester) async {
        const style = AppGlassNavigationStyle(
          avatarBackgroundColor: Color(0xFF234567),
          avatarForegroundColor: Color(0xFFEEDDCC),
          initialsStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          avatarSize: 30,
        );
        await _pumpDock(
          tester,
          style: style,
          items: [
            ..._items.take(2),
            AppGlassNavigationItem(
              icon: Icons.person_outline,
              label: 'Profile',
              nativeImage: AppGlassNavigationImage(
                assetPath: asset,
                initials: 'AB',
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('AB'), findsOneWidget);
        final initials = tester.widget<Text>(find.text('AB'));
        expect(initials.style?.color, style.avatarForegroundColor);
        expect(initials.style?.fontSize, 13);
        expect(_surfaceColors(tester), contains(style.avatarBackgroundColor));
        expect(find.bySemanticsLabel('Profile'), findsOneWidget);
        expect(find.bySemanticsLabel('AB'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('long scaled labels retain complete text and minimum targets', (
    tester,
  ) async {
    const labels = [
      'Browse collections',
      'Saved selections',
      'Profile settings',
    ];
    final items = [
      for (final label in labels)
        AppGlassNavigationItem(icon: Icons.circle_outlined, label: label),
    ];
    await _pumpDock(tester, items: items, width: 240, textScale: 2);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_dockKey)).height,
      greaterThan(const AppGlassNavigationStyle().dockHeight),
    );
    for (final label in labels) {
      final text = tester.widget<Text>(find.text(label));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.overflow, TextOverflow.visible);
      expect(text.softWrap, isFalse);
      expect(paragraph.didExceedMaxLines, isFalse);
      final target = tester.getSize(_target(label));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(paragraph.size.width));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow viewport preserves minimum destination targets', (
    tester,
  ) async {
    await _pumpDock(tester, width: 150, items: _fiveItems);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_dockKey)).width, 150);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    for (final item in _fiveItems) {
      final target = tester.getSize(_target(item.label));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL reverses physical positions while preserving item indices', (
    tester,
  ) async {
    final requests = <int>[];
    await _pumpDock(
      tester,
      direction: TextDirection.rtl,
      onSelected: requests.add,
    );
    final first = tester.getRect(_target('Browse'));
    final last = tester.getRect(_target('Profile'));
    expect(first.center.dx, greaterThan(last.center.dx));
    expect(
      tester.getRect(find.byKey(_selectionKey)).center.dx,
      closeTo(first.center.dx, 0.01),
    );
    await tester.tap(_target('Profile'));
    await tester.pumpAndSettle();
    expect(requests, [2]);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      '${direction.name} reveals initial and changed selected destinations',
      (tester) async {
        await _pumpDock(
          tester,
          width: 200,
          items: _fiveItems,
          direction: direction,
          selectedIndex: 4,
        );
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        expect(scrollable.position.pixels, greaterThan(0));
        expect(_target('Messages').hitTestable(), findsOneWidget);
        _expectWithinViewport(tester, 'Messages');

        await _pumpDock(
          tester,
          width: 200,
          items: _fiveItems,
          direction: direction,
        );
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, closeTo(0, 0.01));
        expect(_target('Browse').hitTestable(), findsOneWidget);
        _expectWithinViewport(tester, 'Browse');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keyboard focus reveals an off-screen enabled destination', (
    tester,
  ) async {
    await _pumpDock(tester, width: 200, items: _fiveItems);
    await tester.pumpAndSettle();
    for (var index = 0; index < _fiveItems.length; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    expect(Focus.of(tester.element(find.text('Messages'))).hasFocus, isTrue);
    expect(_target('Messages').hitTestable(), findsOneWidget);
    _expectWithinViewport(tester, 'Messages');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDock(
  WidgetTester tester, {
  List<AppGlassNavigationItem> items = _items,
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  AppGlassNavigationStyle? style,
  ThemeData? theme,
  double width = 390,
  double textScale = 1,
  bool highContrast = false,
  bool boldText = false,
  bool reduceMotion = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            highContrast: highContrast,
            boldText: boldText,
            disableAnimations: reduceMotion,
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: CustomGlassNavigationDockWidget(
                    items: items,
                    selectedIndex: selectedIndex,
                    onItemSelected: onSelected ?? (_) {},
                    style:
                        style ??
                        AppGlassNavigationStyle.fromTheme(Theme.of(context)),
                    preferNative: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

BoxDecoration _selectionDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(_selectionKey)).decoration
        as BoxDecoration;

Iterable<Color> _surfaceColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(find.byType(ColoredBox))
    .map((widget) => widget.color);

void _expectWithinViewport(WidgetTester tester, String label) {
  final target = tester.getRect(_target(label));
  final viewport = tester.getRect(find.byType(SingleChildScrollView));
  expect(target.left, greaterThanOrEqualTo(viewport.left - 0.01));
  expect(target.right, lessThanOrEqualTo(viewport.right + 0.01));
}

// Exercise the release-mode resolver branches without disabling assertions for
// the suite. Only these optical getters model unchecked constructor inputs.
class _UncheckedEdgeStyle extends AppGlassNavigationStyle {
  const _UncheckedEdgeStyle({
    double? foregroundRefractionEdge,
    double refractionEdge = 12,
  }) : _foregroundEdge = foregroundRefractionEdge,
       _sharedEdge = refractionEdge;

  final double? _foregroundEdge;
  final double _sharedEdge;

  @override
  double? get foregroundRefractionEdge => _foregroundEdge;

  @override
  double get refractionEdge => _sharedEdge;
}
