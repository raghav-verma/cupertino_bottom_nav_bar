import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _dockItems = [
  AppGlassNavigationItem(icon: Icons.explore_outlined, label: 'Browse'),
  AppGlassNavigationItem(
    icon: Icons.mail_outline,
    label: 'Inbox',
    semanticLabel: 'Messages',
    badgeLabel: '3',
  ),
  AppGlassNavigationItem(
    icon: Icons.person_outline,
    label: 'Profile',
    enabled: false,
  ),
];

void main() {
  testWidgets(
    'destination semantics preserve selection, badges and availability',
    (tester) async {
      final selected = ValueNotifier(1);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpDock(tester, selected: selected, requests: requests);

      final browse = tester.getSemantics(find.bySemanticsLabel('Browse'));
      expect(browse.flagsCollection.isButton, isTrue);
      expect(browse.flagsCollection.isEnabled, Tristate.isTrue);
      expect(browse.flagsCollection.isSelected, Tristate.isFalse);
      expect(browse.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      final messages = tester.getSemantics(
        find.bySemanticsLabel('Messages, 3'),
      );
      expect(messages.flagsCollection.isSelected, Tristate.isTrue);
      expect(messages.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('Inbox'), findsNothing);
      expect(find.bySemanticsLabel('3'), findsNothing);

      final profile = tester.getSemantics(find.bySemanticsLabel('Profile'));
      expect(profile.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        profile.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();
      expect(requests, [0]);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Browse'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Messages, 3'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
    },
  );

  testWidgets('noncurrent route keeps lane but hides and isolates the dock', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    final navigator = GlobalKey<NavigatorState>();
    await _pumpDock(
      tester,
      selected: selected,
      requests: requests,
      navigator: navigator,
    );
    final dock = find.byType(CustomGlassNavigationDockWidget);
    final dockRect = tester.getRect(dock);
    final inboxPosition = tester.getCenter(find.text('Inbox'));
    final inboxFocus = Focus.of(tester.element(find.text('Inbox')));
    inboxFocus.requestFocus();
    await tester.pump();
    expect(inboxFocus.hasFocus, isTrue);

    // A transparent, nonmodal popup lets the test probe the dock's own guard
    // without relying on an opaque page or modal barrier to block input.
    navigator.currentState!.push<void>(_TransparentPopupRoute());
    await tester.pumpAndSettle();

    expect(tester.getRect(dock), dockRect);
    expect(_accessibleLabels(tester), isNot(contains('Browse')));
    expect(_accessibleLabels(tester), isNot(contains('Messages, 3')));
    expect(inboxFocus.hasFocus, isFalse);
    expect(inboxFocus.canRequestFocus, isFalse);
    final surface = find.byKey(const Key('flutter_glass_navigation_dock'));
    expect(TickerMode.valuesOf(tester.element(surface)).enabled, isFalse);
    final opacity = tester.widget<Opacity>(
      find.descendant(of: dock, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0);
    await tester.tapAt(inboxPosition);
    await tester.pump();
    expect(requests, isEmpty);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getRect(dock), dockRect);
    expect(find.bySemanticsLabel('Browse'), findsOneWidget);
    expect(TickerMode.valuesOf(tester.element(surface)).enabled, isTrue);
    expect(inboxFocus.canRequestFocus, isTrue);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: dock, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );
    await tester.tapAt(inboxPosition);
    await tester.pumpAndSettle();
    expect(requests, [1]);
    expect(selected.value, 1);
  });

  for (final scrub in [false, true]) {
    testWidgets(
      'a ${scrub ? 'scrub' : 'tap'} begun before route cover cannot select while hidden',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        final navigator = GlobalKey<NavigatorState>();
        await _pumpDock(
          tester,
          selected: selected,
          requests: requests,
          navigator: navigator,
        );
        final browsePosition = tester.getCenter(find.text('Browse'));
        final inboxPosition = tester.getCenter(find.text('Inbox'));
        final gesture = await tester.startGesture(
          scrub ? browsePosition : inboxPosition,
        );
        await tester.pump();

        // Starting before cover exercises an in-flight stream, not just a new
        // hit test. Navigator cancellation and dock isolation must retain the
        // accepted host selection while the covering route is current.
        navigator.currentState!.push<void>(_TransparentPopupRoute());
        await tester.pumpAndSettle();
        if (scrub) {
          await gesture.moveTo(inboxPosition);
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        expect(requests, isEmpty);
        expect(selected.value, 0);

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.tapAt(inboxPosition);
        await tester.pumpAndSettle();
        expect(requests, [1]);
        expect(selected.value, 1);
      },
    );
  }

  for (final releaseWhileCovered in [false, true]) {
    testWidgets(
      'declarative cover cancels scrub with UP ${releaseWhileCovered ? 'while covered' : 'after immediate return'}',
      (tester) async {
        final selected = ValueNotifier(0);
        final cover = ValueNotifier(false);
        addTearDown(selected.dispose);
        addTearDown(cover.dispose);
        final requests = <int>[];
        await _pumpDock(
          tester,
          selected: selected,
          requests: requests,
          declarativeCover: cover,
          style: const AppGlassNavigationStyle(
            pressedScale: 1.2,
            trackVerticalDrag: true,
            scrubSelectionPolicy:
                AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane,
          ),
        );
        final surface = find.byType(CustomFlutterGlassNavigationDockWidget);
        final retainedState = tester.state(surface);
        final browse = tester.getCenter(find.text('Browse'));
        final inbox = tester.getCenter(find.text('Inbox'));
        final gesture = await tester.startGesture(browse);
        await gesture.moveTo(inbox);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(requests, isEmpty);
        expect(selected.value, 0);
        expect(
          tester
              .getCenter(find.byKey(const Key('glass_navigation_selection')))
              .dx,
          closeTo(inbox.dx, 0.01),
        );

        // Page-list changes avoid Navigator.push/pop's imperative pointer
        // cancellation. Return in the next frame without advancing animation
        // time, so cleanup must also work while the retained dock is muted.
        cover.value = true;
        await tester.pump();
        expect(tester.state(surface), same(retainedState));
        expect(TickerMode.valuesOf(tester.element(surface)).enabled, isFalse);
        expect(_accessibleLabels(tester), isNot(contains('Browse')));
        if (releaseWhileCovered) {
          await gesture.moveTo(browse);
          await gesture.moveTo(inbox);
          await gesture.up();
          await tester.pump();
          expect(requests, isEmpty);
          expect(selected.value, 0);
        }
        cover.value = false;
        await tester.pump();
        if (!releaseWhileCovered) {
          await gesture.moveTo(browse);
          await gesture.moveTo(inbox);
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(tester.state(surface), same(retainedState));
        expect(requests, isEmpty);
        expect(selected.value, 0);
        expect(find.text('Synthetic destination: 0'), findsOneWidget);
        expect(TickerMode.valuesOf(tester.element(surface)).enabled, isTrue);
        expect(find.bySemanticsLabel('Browse'), findsOneWidget);
        final selection = find.byKey(const Key('glass_navigation_selection'));
        expect(tester.getCenter(selection).dx, closeTo(browse.dx, 0.01));
        final transform = tester.widget<Transform>(
          find.ancestor(of: selection, matching: find.byType(Transform)).first,
        );
        expect(transform.transform.entry(0, 0), closeTo(1, 0.0001));
        expect(transform.transform.entry(1, 1), closeTo(1, 0.0001));

        await tester.tapAt(inbox);
        await tester.pumpAndSettle();
        expect(requests, [1]);
        expect(selected.value, 1);
        expect(find.text('Synthetic destination: 1'), findsOneWidget);
        expect(tester.getCenter(selection).dx, closeTo(inbox.dx, 0.01));
      },
    );
  }

  for (final scrub in [false, true]) {
    for (final releaseBeforeCancel in [false, true]) {
      testWidgets(
        'same-microtask declarative return ${releaseBeforeCancel ? 'blocks UP before queued CANCEL' : 'delivers queued CANCEL'} for ${scrub ? 'owned release-only scrub' : 'pending tap'}',
        (tester) async {
          final selected = ValueNotifier(0);
          final cover = ValueNotifier(false);
          addTearDown(selected.dispose);
          addTearDown(cover.dispose);
          final requests = <int>[];
          await _pumpDock(
            tester,
            selected: selected,
            requests: requests,
            declarativeCover: cover,
            style: scrub
                ? const AppGlassNavigationStyle(
                    pressedScale: 1.2,
                    trackVerticalDrag: true,
                    scrubSelectionPolicy: AppGlassNavigationScrubSelectionPolicy
                        .onReleaseWithinLane,
                  )
                : const AppGlassNavigationStyle(),
          );
          final surface = find.byType(CustomFlutterGlassNavigationDockWidget);
          final retainedState = tester.state(surface);
          final browse = tester.getCenter(find.text('Browse'));
          final inbox = tester.getCenter(find.text('Inbox'));
          final selection = find.byKey(const Key('glass_navigation_selection'));
          final pointer = TestPointer(71);
          final events = <Type>[];
          final ownerEvents = <Type>[
            PointerDownEvent,
            if (scrub) PointerMoveEvent,
          ];
          void recordEvent(PointerEvent event) {
            if (event.pointer == pointer.pointer) events.add(event.runtimeType);
          }

          tester.binding.pointerRouter.addGlobalRoute(recordEvent);
          addTearDown(
            () => tester.binding.pointerRouter.removeGlobalRoute(recordEvent),
          );
          tester.binding.handlePointerEvent(
            pointer.down(scrub ? browse : inbox, view: tester.view),
          );
          if (scrub) {
            tester.binding.handlePointerEvent(
              pointer.move(inbox, view: tester.view),
            );
          }
          await tester.pump();
          if (scrub) {
            await tester.pump(const Duration(milliseconds: 250));
            // Reaching the other capsule endpoint proves that the fitting pan
            // owns the stream, not merely that an unrecognized tap is pending.
            expect(tester.getCenter(selection).dx, closeTo(inbox.dx, 0.01));
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel('Browse'))
                  .flagsCollection
                  .isSelected,
              Tristate.isTrue,
            );
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel('Messages, 3'))
                  .flagsCollection
                  .isSelected,
              Tristate.isFalse,
            );
            expect(requests, isEmpty);
            expect(selected.value, 0);
            expect(find.text('Synthetic destination: 0'), findsOneWidget);
          }
          expect(events, ownerEvents);

          // pump() flushes microtasks before/after a frame. Reconcile both public
          // page lists synchronously instead, retaining the real binding's
          // cancelPointer queue until this stack yields. No private callback or
          // fabricated PointerCancelEvent is used.
          cover.value = true;
          tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
          expect(ModalRoute.of(tester.element(surface))!.isCurrent, isFalse);
          expect(TickerMode.valuesOf(tester.element(surface)).enabled, isFalse);
          expect(tester.state(surface), same(retainedState));
          expect(events, ownerEvents);

          cover.value = false;
          tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
          expect(ModalRoute.of(tester.element(surface))!.isCurrent, isTrue);
          expect(TickerMode.valuesOf(tester.element(surface)).enabled, isTrue);
          expect(tester.state(surface), same(retainedState));
          expect(events, ownerEvents);
          if (releaseBeforeCancel) {
            tester.binding.handlePointerEvent(pointer.up(view: tester.view));
            expect(events, [...ownerEvents, PointerUpEvent]);
            expect(requests, isEmpty);
            expect(selected.value, 0);
          }

          await tester.pumpAndSettle();
          expect(
            events,
            releaseBeforeCancel
                ? [...ownerEvents, PointerUpEvent]
                : [...ownerEvents, PointerCancelEvent],
          );
          // When UP wins, SDK dispatch removes its hit-test entry and the later
          // queued CANCEL has no path. The companion case above proves that the
          // same reconciliation really queues SDK cancellation before yielding.
          expect(requests, isEmpty);
          expect(selected.value, 0);
          expect(find.text('Synthetic destination: 0'), findsOneWidget);
          expect(tester.state(surface), same(retainedState));
          expect(tester.getCenter(selection).dx, closeTo(browse.dx, 0.01));
          final transform = tester.widget<Transform>(
            find
                .ancestor(of: selection, matching: find.byType(Transform))
                .first,
          );
          expect(transform.transform.entry(0, 0), closeTo(1, 0.0001));
          expect(transform.transform.entry(1, 1), closeTo(1, 0.0001));

          await tester.tapAt(inbox);
          await tester.pumpAndSettle();
          expect(requests, [1]);
          expect(selected.value, 1);
          expect(find.text('Synthetic destination: 1'), findsOneWidget);
        },
      );
    }
  }
}

Future<void> _pumpDock(
  WidgetTester tester, {
  required ValueNotifier<int> selected,
  required List<int> requests,
  GlobalKey<NavigatorState>? navigator,
  ValueNotifier<bool>? declarativeCover,
  AppGlassNavigationStyle style = const AppGlassNavigationStyle(),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final scaffold = Scaffold(
    body: ValueListenableBuilder<int>(
      valueListenable: selected,
      builder: (context, index, child) =>
          Center(child: Text('Synthetic destination: $index')),
    ),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: selected,
      builder: (context, index, child) => CustomGlassNavigationDockWidget(
        items: _dockItems,
        selectedIndex: index,
        onItemSelected: (requested) {
          requests.add(requested);
          selected.value = requested;
        },
        style: style,
        preferNative: false,
        semanticLabel: 'Example navigation',
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: declarativeCover == null
          ? scaffold
          : ValueListenableBuilder<bool>(
              valueListenable: declarativeCover,
              builder: (context, covered, child) => Navigator(
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('dock-host'),
                    child: scaffold,
                  ),
                  if (covered) const _TransparentPopupPage(),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TransparentPopupRoute extends PopupRoute<void> {
  _TransparentPopupRoute({super.settings});

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

class _TransparentPopupPage extends Page<void> {
  const _TransparentPopupPage() : super(key: const ValueKey('dock-cover'));

  @override
  Route<void> createRoute(BuildContext context) =>
      _TransparentPopupRoute(settings: this);
}

List<String> _accessibleLabels(WidgetTester tester) {
  final labels = <String>[];
  final root = tester
      .binding
      .renderViews
      .single
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  bool visit(SemanticsNode node) {
    labels.add(node.getSemanticsData().label);
    node.visitChildren(visit);
    return true;
  }

  visit(root);
  return labels;
}
