import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['Browse', 'Stars', 'Likes', 'Chats', 'Profile'];
final _capsule = find.byKey(const Key('glass_navigation_selection'));

void main() {
  test('horizontal geometry defaults and finite nonnegative constraints', () {
    const defaults = AppGlassNavigationStyle(contentInset: 7);
    expect(defaults.horizontalContentInset, isNull);
    expect(defaults.resolvedHorizontalContentInset, 7);
    expect(defaults.selectionHorizontalOutset, 0);
    for (final invalid in [-1.0, double.infinity, double.nan]) {
      expect(
        () => AppGlassNavigationStyle(horizontalContentInset: invalid),
        throwsAssertionError,
      );
      expect(
        () => AppGlassNavigationStyle(selectionHorizontalOutset: invalid),
        throwsAssertionError,
      );
    }
  });

  testWidgets('omitted horizontal gutter preserves the existing default', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected, style: const AppGlassNavigationStyle());
    final before = tester.getRect(_capsule);
    final target = tester.getRect(_target(_labels.first));
    final surface = _surface(tester);
    expect(before.width, closeTo(target.width - 4, 0.001));
    await _pump(
      tester,
      selected,
      style: const AppGlassNavigationStyle(horizontalContentInset: 4),
    );
    expect(tester.getRect(_capsule), before);
    expect(_surface(tester), surface);
    expect(tester.getRect(_target(_labels.first)), target);
  });

  testWidgets('prototype widens only the visual lens with unchanged targets', (
    tester,
  ) async {
    final selected = ValueNotifier(2);
    addTearDown(selected.dispose);
    await _pump(tester, selected, style: _style(outset: 0));
    final targets = [
      for (final label in _labels) tester.getRect(_target(label)),
    ];
    final before = tester.getRect(_capsule);
    final surface = _surface(tester);
    await _pump(tester, selected, style: _style());
    final after = tester.getRect(_capsule);
    expect(after.width, closeTo(before.width + 8, 0.001));
    expect(after.width / targets[2].width, closeTo(1.11834, 0.001));
    expect(after.center, before.center);
    expect(after.height, before.height);
    expect(_surface(tester), surface);
    for (var i = 0; i < _labels.length; i++) {
      expect(tester.getRect(_target(_labels[i])), targets[i]);
      expect(targets[i].width, greaterThanOrEqualTo(48));
      expect(targets[i].height, greaterThanOrEqualTo(48));
    }
    await tester.tapAt(Offset(targets[2].right + 1, targets[2].center.dy));
    await tester.pumpAndSettle();
    expect(
      selected.value,
      3,
      reason: 'visual overlap does not expand hit boxes',
    );
  });

  testWidgets('horizontal gutter does not alter vertical height', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected, style: _style(horizontal: null, outset: 0));
    final beforeHeight = _surface(tester).height;
    final beforeLensHeight = tester.getSize(_capsule).height;
    await _pump(tester, selected, style: _style(horizontal: 12, outset: 0));
    expect(_surface(tester).height, beforeHeight);
    expect(tester.getSize(_capsule).height, beforeLensHeight);
  });

  testWidgets('narrow layout clamps outset to the available reduced gutter', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(
      tester,
      selected,
      width: 90,
      labels: const ['A', 'B', 'C', 'D', 'E'],
      style: _style(horizontal: 100, outset: 100),
    );
    final target = tester.getRect(_target('A'));
    expect(target.width, 48);
    expect(_surface(tester).width, 54);
    // Gutter and content inset both reduce to 3, which leaves no outset: the
    // capsule keeps the same 3-pixel gap from the ends as from top and bottom.
    expect(tester.getSize(_capsule).width, 48);
    expect(tester.getRect(_capsule).left - _surface(tester).left, 3);
    _within(tester.getRect(_capsule), _surface(tester));
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    for (final outset in [4.0, 100.0]) {
      testWidgets(
        '${direction.name} outset $outset stays contained under pressure and spring',
        (tester) async {
          final selected = ValueNotifier(0);
          addTearDown(selected.dispose);
          await _pump(
            tester,
            selected,
            direction: direction,
            style: _style(outset: outset),
          );
          final surface = _surface(tester);
          final targetWidth = tester.getSize(_target(_labels.first)).width;
          // The 8-pixel gutter less the 4-pixel content inset allows 4.
          expect(
            tester.getSize(_capsule).width,
            closeTo(targetWidth + 2 * outset.clamp(0, 4), 0.001),
          );
          for (final index in [0, 4]) {
            selected.value = index;
            await tester.pumpAndSettle();
            _within(tester.getRect(_capsule), surface);
            final gesture = await tester.startGesture(
              tester.getCenter(_target(_labels[index])),
            );
            await tester.pump(const Duration(milliseconds: 250));
            _within(tester.getRect(_capsule), surface);
            final atLeft = tester.getCenter(_capsule).dx < surface.center.dx;
            await gesture.moveTo(
              Offset(
                atLeft ? surface.left - 50 : surface.right + 50,
                surface.center.dy,
              ),
            );
            await tester.pump();
            _within(tester.getRect(_capsule), surface);
            await gesture.cancel();
            selected.value = index == 0 ? 4 : 0;
            await tester.pump();
            for (var frame = 0; frame < 70; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              _within(tester.getRect(_capsule), surface);
            }
            await tester.pumpAndSettle();
            expect(
              tester.getCenter(_capsule).dx,
              closeTo(
                tester.getCenter(_target(_labels[selected.value])).dx,
                0.001,
              ),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      '${direction.name} unequal scrolling slots retain visual outset',
      (tester) async {
        const labels = [
          'Browse destinations',
          'Stars',
          'Saved favourites',
          'Chats',
          'Profile',
        ];
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(
          tester,
          selected,
          width: 290,
          labels: labels,
          direction: direction,
        );
        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scroll.clipBehavior, Clip.none);
        expect(
          tester.getSize(_target(labels.first)).width,
          greaterThan(tester.getSize(_target(labels[1])).width),
        );
        for (final index in [0, 4, 2]) {
          selected.value = index;
          await tester.pumpAndSettle();
          final target = tester.getRect(_target(labels[index]));
          final lens = tester.getRect(_capsule);
          expect(lens.width, closeTo(target.width + 8, 0.001));
          expect(lens.center.dx, closeTo(target.center.dx, 0.001));
          _within(lens, _surface(tester));
          expect(target.height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reduced motion retains widened resting geometry and centres', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pump(tester, selected);
    final normal = tester.getRect(_capsule);
    await _pump(tester, selected, reduceMotion: true);
    expect(tester.getRect(_capsule), normal);
    selected.value = 4;
    await tester.pump();
    final target = tester.getRect(_target(_labels.last));
    final lens = tester.getRect(_capsule);
    expect(lens.width, closeTo(normal.width, 0.001));
    expect(lens.center.dx, closeTo(target.center.dx, 0.001));
    expect(lens.height, closeTo(normal.height, 0.001));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getRect(_capsule), lens);
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      '${direction.name} partial scroll clips only foreground to viewport',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          const labels = [
            'Browse destinations',
            'Stars',
            'Saved favourites',
            'Chats',
            'Profile',
          ];
          final selected = ValueNotifier(0);
          addTearDown(selected.dispose);
          await _pump(
            tester,
            selected,
            width: 290,
            labels: labels,
            direction: direction,
          );
          final scroll = tester.widget<SingleChildScrollView>(
            find.byType(SingleChildScrollView),
          );
          final controller = scroll.controller!;
          final clipFinder = find
              .ancestor(
                of: _target(labels.first),
                matching: find.byType(ClipRect),
              )
              .first;
          final clipWidget = tester.widget<ClipRect>(clipFinder);
          final clipBox = tester.renderObject<RenderBox>(clipFinder);
          final initialClip = clipWidget.clipper!.getClip(clipBox.size);
          for (final offset in [23.0, 41.0]) {
            controller.jumpTo(offset);
            await tester.pump();
            final localClip = clipWidget.clipper!.getClip(clipBox.size);
            final globalClip = localClip.shift(
              clipBox.localToGlobal(Offset.zero),
            );
            final viewport = tester.getRect(find.byType(SingleChildScrollView));
            expect(globalClip.left, closeTo(viewport.left, 0.001));
            expect(globalClip.right, closeTo(viewport.right, 0.001));
            expect(localClip, isNot(initialClip));
            expect(
              clipWidget.clipper!.getApproximateClipRect(clipBox.size),
              localClip,
            );
            expect(
              scroll.clipBehavior,
              Clip.none,
              reason: 'lens still paints into gutter',
            );
            expect(
              tester.getSize(_capsule).width,
              closeTo(tester.getSize(_target(labels.first)).width + 8, 0.001),
            );
            final first = tester.getRect(_target(labels.first));
            expect(first.overlaps(viewport), isTrue);
            expect(
              viewport.contains(first.topLeft) &&
                  viewport.contains(first.bottomRight),
              isFalse,
            );
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel(labels.first))
                  .flagsCollection
                  .isButton,
              isTrue,
            );
            final beforeTap = selected.value;
            await tester.tapAt(Offset(viewport.left - 2, viewport.center.dy));
            await tester.pump();
            expect(
              selected.value,
              beforeTap,
              reason: 'gutter is not an expanded target',
            );
          }
          selected.value = 4;
          await tester.pumpAndSettle();
          _within(tester.getRect(_capsule), _surface(tester));
          expect(
            tester.getCenter(_capsule).dx,
            closeTo(tester.getCenter(_target(labels.last)).dx, 0.001),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final duringScrub in [false, true]) {
    testWidgets(
      'live gutter/outset reflow during ${duringScrub ? 'scrub' : 'spring'} settles safely',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _pump(tester, selected);
        TestGesture? gesture;
        if (duringScrub) {
          gesture = await tester.startGesture(
            tester.getCenter(_target(_labels.first)),
          );
          await gesture.moveTo(tester.getCenter(_target(_labels[1])));
          await tester.pump();
        } else {
          selected.value = 4;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
        }
        await _pump(
          tester,
          selected,
          style: _style(horizontal: 12, outset: 6),
          settle: false,
        );
        await gesture?.cancel();
        await tester.pumpAndSettle();
        final lens = tester.getRect(_capsule);
        final target = tester.getRect(_target(_labels[selected.value]));
        expect(lens.width, closeTo(target.width + 12, 0.001));
        expect(lens.center.dx, closeTo(target.center.dx, 0.001));
        _within(lens, _surface(tester));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('native caption eligibility uses resolved horizontal gutter', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const discovery = MethodChannel(
      'cupertino_bottom_nav_bar/native_navigation',
    );
    var discoveries = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(discovery, (_) async {
          discoveries++;
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(discovery, null),
    );
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    try {
      await _pump(
        tester,
        selected,
        style: _style(horizontal: 60),
        native: true,
      );
      expect(
        discoveries,
        0,
        reason: 'new gutter leaves less than a minimum native target',
      );
      expect(
        find.byType(CustomFlutterGlassNavigationDockWidget),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

AppGlassNavigationStyle _style({double? horizontal = 8, double outset = 4}) =>
    AppGlassNavigationStyle(
      horizontalInset: 18,
      horizontalContentInset: horizontal,
      contentInset: 4,
      selectionHorizontalInset: 0,
      selectionHorizontalOutset: outset,
      selectionVerticalInset: 2,
      labelStyle: const TextStyle(fontSize: 8, height: 1.35),
      selectionSpring: const SpringDescription(
        mass: 1,
        stiffness: 560,
        damping: 12,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  AppGlassNavigationStyle? style,
  double width = 390,
  List<String> labels = _labels,
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
  bool native = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, _) => CustomGlassNavigationDockWidget(
            items: [
              for (final label in labels)
                AppGlassNavigationItem(
                  icon: Icons.circle_outlined,
                  label: label,
                ),
            ],
            selectedIndex: index,
            onItemSelected: (value) => selected.value = value,
            style: style ?? _style(),
            preferNative: native,
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Rect _surface(WidgetTester tester) => tester.getRect(
  find.ancestor(of: _capsule, matching: find.byType(ClipRRect)).last,
);

void _within(Rect rect, Rect bounds) {
  expect(rect.isFinite, isTrue);
  expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.001));
  expect(rect.right, lessThanOrEqualTo(bounds.right + 0.001));
  expect(rect.top, greaterThanOrEqualTo(bounds.top - 0.001));
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.001));
}
