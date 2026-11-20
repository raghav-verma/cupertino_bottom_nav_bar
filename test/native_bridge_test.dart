import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

// These fakes exercise the Dart bridge and widget lifecycle only. No Swift,
// UIKit material, platform gesture recognition or native caption measurement
// executes in this suite.
const _discovery = MethodChannel('cupertino_bottom_nav_bar/native_navigation');
const _viewType = 'cupertino_bottom_nav_bar/native_navigation_dock';
const _portableKey = Key('flutter_glass_navigation_dock');
const _nativeKey = Key('glass_navigation_native_dock');
const _items = [
  AppGlassNavigationItem(
    icon: Icons.circle_outlined,
    label: 'One',
    nativeImage: AppGlassNavigationImage(initials: 'AB'),
  ),
  AppGlassNavigationItem(
    icon: Icons.circle_outlined,
    label: 'Two',
    nativeImage: AppGlassNavigationImage(initials: 'AB'),
  ),
  AppGlassNavigationItem(
    icon: Icons.circle_outlined,
    label: 'Three',
    nativeImage: AppGlassNavigationImage(initials: 'AB'),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final discoveryResult in ['unsupported', 'missing', 'error']) {
    _testBridge(
      '$discoveryResult discovery leaves usable portable navigation',
      (tester) async {
        final fake = _FakeNativeBridge(discoveryResult: discoveryResult);
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpHost(tester, selected: selected, requests: requests);
        await tester.pumpAndSettle();

        expect(fake.discoveryCalls, 1);
        expect(fake.createdIds, isEmpty);
        expect(find.byKey(_portableKey), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        await tester.tap(find.text('Two'));
        await tester.pumpAndSettle();
        expect(requests, [1]);
        expect(selected.value, 1);
      },
    );
  }

  for (final layout in [
    'overwide caption',
    'reduced motion',
    'RTL',
    'large text',
  ]) {
    _testBridge('$layout chooses portable navigation before native discovery', (
      tester,
    ) async {
      final fake = _FakeNativeBridge();
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final items = layout == 'overwide caption'
          ? [
              const AppGlassNavigationItem(
                icon: Icons.circle_outlined,
                label: 'A complete caption much wider than its target',
              ),
              _items[1],
              _items[2],
            ]
          : _items;
      await _pumpHost(
        tester,
        selected: selected,
        requests: <int>[],
        items: items,
        reducedMotion: layout == 'reduced motion',
        direction: layout == 'RTL' ? TextDirection.rtl : TextDirection.ltr,
        textScaler: layout == 'large text'
            ? TextScaler.linear(2)
            : TextScaler.noScaling,
      );
      await tester.pumpAndSettle();

      expect(fake.discoveryCalls, 0);
      expect(fake.createdIds, isEmpty);
      expect(find.byKey(_portableKey), findsOneWidget);
      if (layout == 'overwide caption') {
        expect(find.text(items.first.label), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      }
    });
  }

  for (final preference in [
    'high contrast',
    'bold text',
    'letter spacing',
    'zero letter spacing',
    'word spacing',
    'zero word spacing',
    'line height',
  ]) {
    _testBridge(
      '$preference uses portable navigation and normal preference restores native eligibility',
      (tester) async {
        final fake = _FakeNativeBridge();
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        const style = AppGlassNavigationStyle(surfaceColor: Color(0xAA102030));

        Future<void> pumpPreference(bool enabled) => _pumpHost(
          tester,
          selected: selected,
          requests: requests,
          style: style,
          highContrast: enabled && preference == 'high contrast',
          boldText: enabled && preference == 'bold text',
          letterSpacing: enabled
              ? switch (preference) {
                  'letter spacing' => 4,
                  'zero letter spacing' => 0,
                  _ => null,
                }
              : null,
          wordSpacing: enabled
              ? switch (preference) {
                  'word spacing' => 20,
                  'zero word spacing' => 0,
                  _ => null,
                }
              : null,
          lineHeight: enabled && preference == 'line height' ? 3 : null,
        );

        await pumpPreference(true);
        await tester.pumpAndSettle();
        expect(fake.discoveryCalls, 0);
        expect(fake.createdIds, isEmpty);
        expect(find.byKey(_portableKey), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        final media = MediaQuery.of(tester.element(find.byKey(_portableKey)));
        if (preference == 'zero letter spacing') {
          // Zero is a requested override, not the absence of a preference.
          expect(media.letterSpacingOverride, 0);
        } else if (preference == 'zero word spacing') {
          expect(media.wordSpacingOverride, 0);
        }
        if (preference == 'high contrast') {
          expect(find.byType(BackdropFilter), findsNothing);
          expect(
            tester
                .widgetList<ColoredBox>(
                  find.descendant(
                    of: find.byKey(_portableKey),
                    matching: find.byType(ColoredBox),
                  ),
                )
                .map((box) => box.color),
            contains(style.surfaceColor.withValues(alpha: 1)),
          );
        }
        await tester.tap(find.text('Two'));
        await tester.pumpAndSettle();
        expect(requests, [1]);
        expect(selected.value, 1);

        await pumpPreference(false);
        await _pumpUntil(
          tester,
          () => find.byKey(_portableKey).evaluate().isEmpty,
        );
        expect(fake.discoveryCalls, 1);
        expect(fake.createdIds, hasLength(1));
        expect(find.byType(UiKitView), findsOneWidget);
        expect(_nativeBlocked(tester), isFalse);
        expect(fake.updates.last['selectedIndex'], 1);

        await pumpPreference(true);
        await tester.pumpAndSettle();
        expect(find.byKey(_portableKey), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        expect(fake.discoveryCalls, 1);
        expect(selected.value, 1);

        await pumpPreference(false);
        await _pumpUntil(
          tester,
          () => find.byKey(_portableKey).evaluate().isEmpty,
        );
        expect(fake.discoveryCalls, 2);
        expect(fake.createdIds, hasLength(2));
        expect(_nativeBlocked(tester), isFalse);
        final acknowledgement = fake.select(2);
        await tester.pump();
        expect(await acknowledgement, 2);
        expect(requests, [1, 2]);
        expect(selected.value, 2);
        await tester.pumpAndSettle();
        expect(fake.mockErrors, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _testBridge('bridge stays portable until the current update succeeds', (
    tester,
  ) async {
    final initialUpdate = Completer<void>();
    final fake = _FakeNativeBridge(onUpdate: (_) => initialUpdate.future);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.updates.isNotEmpty);

    expect(find.byKey(_portableKey), findsOneWidget);
    expect(_nativeBlocked(tester), isTrue);
    final payload = fake.updates.single;
    expect(payload['selectedIndex'], 0);
    expect(payload['visible'], isTrue);
    expect(payload['captionMaxWidth'], greaterThan(0));
    final encodedItems = payload['items'] as List<dynamic>;
    expect(encodedItems, hasLength(3));
    expect(
      (encodedItems.first as Map<dynamic, dynamic>)['icon'],
      isA<Uint8List>(),
    );

    initialUpdate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_portableKey), findsNothing);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(_nativeBlocked(tester), isFalse);
  });

  for (final updateFailure in ['error', 'missing']) {
    _testBridge('$updateFailure update retains usable portable fallback', (
      tester,
    ) async {
      final fake = _FakeNativeBridge(
        onUpdate: (_) async {
          if (updateFailure == 'missing') throw MissingPluginException();
          throw PlatformException(code: 'mock_caption_validation_failed');
        },
      );
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpHost(tester, selected: selected, requests: requests);
      await _pumpUntil(tester, () => fake.updates.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byKey(_portableKey), findsOneWidget);
      expect(find.byKey(_nativeKey), findsNothing);
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(requests, [1]);
      expect(selected.value, 1);
    });
  }

  _testBridge(
    'view-registration error is reported while portable fallback works',
    (tester) async {
      final fake = _FakeNativeBridge(failCreation: true);
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpHost(tester, selected: selected, requests: requests);
      await _pumpUntil(tester, () => fake.createdIds.isNotEmpty);
      expect(tester.takeException(), isA<PlatformException>());
      expect(find.byKey(_portableKey), findsOneWidget);
      expect(_nativeBlocked(tester), isTrue);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(requests, [1]);
      expect(selected.value, 1);
    },
  );

  for (final acceptRequests in [true, false]) {
    _testBridge(
      'mock native requests acknowledge ${acceptRequests ? 'accepted' : 'rejected'} host selection',
      (tester) async {
        final fake = _FakeNativeBridge();
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        final requests = <int>[];
        await _pumpHost(
          tester,
          selected: selected,
          requests: requests,
          acceptRequests: acceptRequests,
        );
        await _pumpUntil(
          tester,
          () => find.byKey(_portableKey).evaluate().isEmpty,
        );
        final acknowledgement = fake.select(1);
        await tester.pump();
        expect(await acknowledgement, acceptRequests ? 1 : 0);
        expect(requests, [1]);
        expect(selected.value, acceptRequests ? 1 : 0);
        await tester.pumpAndSettle();
      },
    );
  }

  _testBridge(
    'invalid and disabled mock native requests do not reach the host',
    (tester) async {
      final fake = _FakeNativeBridge();
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      await _pumpHost(
        tester,
        selected: selected,
        requests: requests,
        items: [
          _items.first,
          const AppGlassNavigationItem(
            icon: Icons.circle_outlined,
            label: 'Two',
            nativeImage: AppGlassNavigationImage(initials: 'AB'),
            enabled: false,
          ),
          _items.last,
        ],
      );
      await _pumpUntil(
        tester,
        () => find.byKey(_portableKey).evaluate().isEmpty,
      );
      for (final index in [-1, 1, 3, 'invalid']) {
        final acknowledgement = fake.select(index);
        await tester.pump();
        expect(await acknowledgement, isNull);
      }
      expect(requests, isEmpty);
      expect(selected.value, 0);
    },
  );

  _testBridge(
    'callback error is reported and acknowledges accepted host index',
    (tester) async {
      final fake = _FakeNativeBridge();
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpHost(
        tester,
        selected: selected,
        requests: <int>[],
        callbackError: StateError('Synthetic rejected host callback'),
      );
      await _pumpUntil(
        tester,
        () => find.byKey(_portableKey).evaluate().isEmpty,
      );

      final acknowledgement = fake.select(1);
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(await acknowledgement, 0);
      expect(selected.value, 0);
    },
  );

  _testBridge(
    'older successful payload cannot expose a newer pending payload',
    (tester) async {
      final delayedUpdates = <Completer<void>>[];
      final fake = _FakeNativeBridge(
        onUpdate: (_) {
          final completer = Completer<void>();
          delayedUpdates.add(completer);
          return completer.future;
        },
      );
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpHost(tester, selected: selected, requests: <int>[]);
      await _pumpUntil(tester, () => delayedUpdates.length == 1);

      selected.value = 1;
      await _pumpUntil(tester, () => delayedUpdates.length == 2);
      expect(fake.updates.last['selectedIndex'], 1);
      await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
      delayedUpdates.first.complete();
      await tester.pumpAndSettle();
      expect(_nativeBlocked(tester), isTrue);
      expect(find.byKey(_portableKey), findsOneWidget);

      delayedUpdates.last.complete();
      await tester.pumpAndSettle();
      expect(_nativeBlocked(tester), isFalse);
      expect(find.byKey(_portableKey), findsNothing);
    },
  );

  _testBridge(
    'delayed successful update cannot reveal or select a hidden route',
    (tester) async {
      final delayedUpdate = Completer<void>();
      final fake = _FakeNativeBridge(onUpdate: (_) => delayedUpdate.future);
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final requests = <int>[];
      final navigator = GlobalKey<NavigatorState>();
      await _pumpHost(
        tester,
        selected: selected,
        requests: requests,
        navigator: navigator,
      );
      await _pumpUntil(tester, () => fake.updates.isNotEmpty);
      navigator.currentState!.push<void>(_TransparentPopupRoute());
      await _pumpUntil(tester, () => fake.visibilityUpdates.contains(false));
      delayedUpdate.complete();
      await tester.pumpAndSettle();

      expect(_nativeBlocked(tester), isTrue);
      expect(find.byKey(_portableKey), findsOneWidget);
      final hiddenAcknowledgement = fake.select(1);
      await tester.pump();
      expect(await hiddenAcknowledgement, isNull);
      expect(requests, isEmpty);
      expect(selected.value, 0);

      navigator.currentState!.pop();
      final hiddenRevision = fake.updates.last['layoutRevision'];
      await _pumpUntil(
        tester,
        () => fake.updates.last['layoutRevision'] != hiddenRevision,
      );
      await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
      await _pumpUntil(tester, () => !_nativeBlocked(tester));
      expect(_nativeBlocked(tester), isFalse);
      expect(find.byKey(_portableKey), findsNothing);
    },
  );

  _testBridge('late update after disposal cannot restore the old dock', (
    tester,
  ) async {
    final delayedUpdate = Completer<void>();
    final fake = _FakeNativeBridge(onUpdate: (_) => delayedUpdate.future);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.updates.isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    delayedUpdate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_nativeKey), findsNothing);
    expect(find.byKey(_portableKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _testBridge('caption badge and availability update on the existing view', (
    tester,
  ) async {
    final fake = _FakeNativeBridge();
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => find.byKey(_portableKey).evaluate().isEmpty);
    final viewId = fake.createdIds.single;
    final previousUpdates = fake.updates.length;

    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      items: [
        _items.first,
        const AppGlassNavigationItem(
          icon: Icons.circle_outlined,
          label: 'Second',
          semanticLabel: 'Second destination',
          badgeLabel: 'NEW',
          enabled: false,
          nativeImage: AppGlassNavigationImage(initials: 'AB'),
        ),
        _items.last,
      ],
    );
    await _pumpUntil(tester, () => fake.updates.length > previousUpdates);
    final updatedItem = _payloadItems(fake.updates.last)[1];
    expect(updatedItem['label'], 'Second');
    expect(updatedItem['semanticLabel'], 'Second destination');
    expect(updatedItem['badge'], 'NEW');
    expect(updatedItem['enabled'], isFalse);
    expect(fake.updates.last['selectedIndex'], 0);
    expect(fake.createdIds, [viewId]);
    final disabledAcknowledgement = fake.select(1);
    await tester.pump();
    expect(await disabledAcknowledgement, isNull);
    expect(requests, isEmpty);

    final disabledUpdateCount = fake.updates.length;
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => fake.updates.length > disabledUpdateCount);
    final restoredItem = _payloadItems(fake.updates.last)[1];
    expect(restoredItem['label'], 'Two');
    expect(restoredItem['badge'], isNull);
    expect(restoredItem['enabled'], isTrue);
    expect(fake.createdIds, [viewId]);
  });

  _testBridge('initials and style changes refresh encoded portrait inputs', (
    tester,
  ) async {
    final fake = _FakeNativeBridge();
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => find.byKey(_portableKey).evaluate().isEmpty);
    final viewId = fake.createdIds.single;
    final originalPortrait = _payloadItems(fake.updates.last).first['icon'];
    final originalUpdateCount = fake.updates.length;
    final updatedPortrait = [
      const AppGlassNavigationItem(
        icon: Icons.circle_outlined,
        label: 'One',
        nativeImage: AppGlassNavigationImage(initials: 'Z'),
      ),
      _items[1],
      _items[2],
    ];
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      items: updatedPortrait,
    );
    await _pumpUntil(tester, () => fake.updates.length > originalUpdateCount);
    final initialsPortrait = _payloadItems(fake.updates.last).first['icon'];
    expect(
      initialsPortrait,
      isNot(orderedEquals(originalPortrait as Uint8List)),
    );

    final initialsUpdateCount = fake.updates.length;
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      items: updatedPortrait,
      style: const AppGlassNavigationStyle(
        avatarBackgroundColor: Colors.blue,
        selectedForegroundColor: Colors.orange,
      ),
    );
    await _pumpUntil(tester, () => fake.updates.length > initialsUpdateCount);
    final coloredPortrait = _payloadItems(fake.updates.last).first['icon'];
    expect(
      coloredPortrait,
      isNot(orderedEquals(initialsPortrait as Uint8List)),
    );
    expect(fake.updates.last['selectedColor'], Colors.orange.toARGB32());

    final colorUpdateCount = fake.updates.length;
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => fake.updates.length > colorUpdateCount);
    expect(
      _payloadItems(fake.updates.last).first['icon'],
      orderedEquals(originalPortrait),
    );
    expect(fake.createdIds, [viewId]);
  });

  for (final variation in ['shadows', 'rounded font size']) {
    _testBridge(
      'portrait cache distinguishes $variation despite identical debug descriptions',
      (tester) async {
        final previousPrecision = debugDoublePrecision;
        try {
          final fake = _FakeNativeBridge();
          final selected = ValueNotifier(0);
          addTearDown(selected.dispose);
          final requests = <int>[];
          const originalTypography = TextStyle(fontSize: 12, height: 1);
          final changedTypography = variation == 'shadows'
              ? originalTypography.copyWith(
                  shadows: const [
                    Shadow(color: Colors.red, offset: Offset(3, 2)),
                  ],
                )
              : originalTypography.copyWith(fontSize: 14);
          if (variation == 'rounded font size') {
            // A legitimate diagnostic setting also exposes this collision in
            // debug; profile/release TextStyle descriptions omit all properties.
            debugDoublePrecision = 1;
          }
          const baseStyle = AppGlassNavigationStyle(
            initialsStyle: originalTypography,
          );
          final changedStyle = baseStyle.copyWith(
            initialsStyle: changedTypography,
          );
          expect(originalTypography, isNot(changedTypography));
          expect(originalTypography.toString(), changedTypography.toString());

          await _pumpHost(
            tester,
            selected: selected,
            requests: requests,
            style: baseStyle,
          );
          await _pumpUntil(tester, () => fake.updates.isNotEmpty);
          final viewId = fake.createdIds.single;
          final originalPortrait =
              _payloadItems(fake.updates.last).first['icon'] as Uint8List;
          final originalUpdateCount = fake.updates.length;

          await _pumpHost(
            tester,
            selected: selected,
            requests: requests,
            style: changedStyle,
          );
          await _pumpUntil(
            tester,
            () => fake.updates.length > originalUpdateCount,
          );
          expect(
            _payloadItems(fake.updates.last).first['icon'],
            isNot(orderedEquals(originalPortrait)),
          );

          final changedUpdateCount = fake.updates.length;
          // Reconstruct an equal value rather than reusing the same TextStyle.
          await _pumpHost(
            tester,
            selected: selected,
            requests: requests,
            style: baseStyle.copyWith(
              initialsStyle: originalTypography.copyWith(),
            ),
          );
          await _pumpUntil(
            tester,
            () => fake.updates.length > changedUpdateCount,
          );
          expect(
            _payloadItems(fake.updates.last).first['icon'],
            orderedEquals(originalPortrait),
          );
          expect(fake.createdIds, [viewId]);
          expect(selected.value, 0);
          expect(requests, isEmpty);
        } finally {
          // Restore before the binding checks its debug-variable invariants.
          debugDoublePrecision = previousPrecision;
        }
      },
    );
  }

  _testBridge('three four and five items retain the view and host selection', (
    tester,
  ) async {
    final fake = _FakeNativeBridge();
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      acceptRequests: false,
    );
    await _pumpUntil(tester, () => find.byKey(_portableKey).evaluate().isEmpty);
    final viewId = fake.createdIds.single;
    final items = [..._items];
    for (final label in ['Four', 'Five']) {
      final previousUpdates = fake.updates.length;
      items.add(
        AppGlassNavigationItem(
          icon: Icons.circle_outlined,
          label: label,
          nativeImage: const AppGlassNavigationImage(initials: 'AB'),
        ),
      );
      selected.value = items.length - 1;
      await _pumpHost(
        tester,
        selected: selected,
        requests: requests,
        items: List.unmodifiable(items),
        acceptRequests: false,
      );
      await _pumpUntil(tester, () => fake.updates.length > previousUpdates);
      expect(_payloadItems(fake.updates.last), hasLength(items.length));
      expect(fake.updates.last['selectedIndex'], items.length - 1);
      expect(fake.createdIds, [viewId]);
      expect(find.byKey(_portableKey), findsNothing);
    }

    final rejectedAcknowledgement = fake.select(0);
    await tester.pump();
    expect(await rejectedAcknowledgement, 4);
    expect(selected.value, 4);
    expect(requests, [0]);
    await tester.pumpAndSettle();
  });

  _testBridge('equivalent recreated items avoid an unnecessary native update', (
    tester,
  ) async {
    final fake = _FakeNativeBridge();
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => find.byKey(_portableKey).evaluate().isEmpty);
    final viewId = fake.createdIds.single;
    final previousUpdates = fake.updates.length;
    final equivalentItems = [
      for (final item in _items)
        AppGlassNavigationItem(
          icon: item.icon,
          label: item.label,
          nativeImage: AppGlassNavigationImage(
            initials: item.nativeImage!.initials,
          ),
        ),
    ];
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      items: equivalentItems,
    );
    await tester.pumpAndSettle();

    expect(fake.updates, hasLength(previousUpdates));
    expect(fake.createdIds, [viewId]);
    expect(fake.discoveryCalls, 1);
    expect(find.byKey(_portableKey), findsNothing);
  });

  _testBridge('measured minimum grows the lane before fitted native reveal', (
    tester,
  ) async {
    var queryCount = 0;
    final nominal = const AppGlassNavigationStyle().dockHeight;
    const minimum = 96.0; // Synthetic protocol fixture, not a UIKit constant.
    final fake = _FakeNativeBridge(
      metricsForPayload: (payload) => ++queryCount == 1
          ? _fixtureMetrics(
              payload,
              minimumHeight: minimum,
              topOverflow: minimum - nominal,
            )
          : null,
    );
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries >= 2);

    expect(tester.getSize(find.byKey(_nativeKey)).height, minimum);
    expect(_nativeBlocked(tester), isTrue);
    expect(find.byKey(_portableKey), findsOneWidget);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(
        fake.updates.last,
        height: minimum,
        minimumHeight: minimum,
      ),
    );
    expect(_nativeBlocked(tester), isFalse);
    expect(find.byKey(_portableKey), findsNothing);
  });

  _testBridge('pending view stays retained but cannot request host selection', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(tester, selected: selected, requests: requests);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    expect(fake.presentationUpdates, isNotEmpty);
    expect(fake.presentationUpdates.last, isFalse);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_nativeKey),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    for (final ancestor in tester.widgetList<Opacity>(
      find.ancestor(of: find.byType(UiKitView), matching: find.byType(Opacity)),
    )) {
      expect(ancestor.opacity, greaterThan(0));
    }
    expect(_nativeBlocked(tester), isTrue);
    expect(_nativeSemanticsExcluded(tester), isTrue);
    final preReadyAcknowledgement = fake.select(1);
    await tester.pump();
    expect(await preReadyAcknowledgement, isNull);
    expect(requests, isEmpty);
    expect(selected.value, 0);

    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(fake.presentationUpdates.last, isTrue);
    expect(_nativeBlocked(tester), isFalse);
    expect(_nativeSemanticsExcluded(tester), isFalse);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(find.byKey(_portableKey), findsNothing);
    final readyAcknowledgement = fake.select(1);
    await tester.pump();
    expect(await readyAcknowledgement, 1);
    expect(requests, [1]);
  });

  _testBridge('invalid stale and wrong-width metrics cannot grow or reveal', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final current = _fixtureMetrics(fake.updates.last);
    final nominal = const AppGlassNavigationStyle().dockHeight;
    final invalid = <Map<Object?, Object?>>[
      for (final field in ['width', 'height', 'minimumHeight'])
        for (final value in [0, -1, double.nan, double.infinity])
          {...current, field: value},
      for (final value in [-1, double.nan, double.infinity])
        {...current, 'topOverflow': value},
      {...current}..remove('height'),
      {...current, 'revision': 0},
      {...current, 'revision': (current['revision'] as int) + 1},
      {...current, 'revision': (current['revision'] as int).toDouble()},
      {...current, 'width': 300, 'minimumHeight': 96},
    ];
    for (final metrics in invalid) {
      await _reportAndPump(tester, fake, metrics);
      expect(tester.getSize(find.byKey(_nativeKey)).height, nominal);
      expect(_nativeBlocked(tester), isTrue);
      expect(find.byKey(_portableKey), findsOneWidget);
    }
    await _reportAndPump(tester, fake, current);
    expect(_nativeBlocked(tester), isFalse);
    final previousUpdates = fake.updates.length;
    selected.value = 1;
    // A no-duration pump rebuilds the host before the zero-timer payload work.
    await tester.pump();
    expect(fake.updates, hasLength(previousUpdates));
    await _reportAndPump(tester, fake, {...current, 'minimumHeight': 120});
    expect(tester.getSize(find.byKey(_nativeKey)).height, nominal);
    await _pumpUntil(tester, () => fake.updates.length > previousUpdates);
    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(tester.takeException(), isNull);
  });

  _testBridge(
    'denied presentation keeps fallback until current fit is accepted',
    (tester) async {
      var readyRequests = 0;
      final deniedPresentation = Completer<bool>();
      final fake = _FakeNativeBridge(
        metricsForPayload: (_) => null,
        onPresentation: (payload) =>
            payload['ready'] == true && ++readyRequests == 1
            ? deniedPresentation.future
            : Future.value(payload['ready'] as bool),
      );
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _pumpHost(tester, selected: selected, requests: <int>[]);
      await _pumpUntil(tester, () => fake.metricsQueries > 0);
      await tester.pumpAndSettle();
      final initialQueries = fake.metricsQueries;
      await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
      deniedPresentation.complete(false);
      await tester.pumpAndSettle();
      expect(fake.metricsQueries, greaterThan(initialQueries));
      expect(readyRequests, 1);
      expect(fake.mockErrors, isEmpty);
      expect(_nativeBlocked(tester), isTrue);
      expect(find.byKey(_portableKey), findsOneWidget);
      expect(fake.presentationUpdates, [false, true, false]);
      await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
      expect(fake.presentationUpdates.last, isTrue);
      expect(_nativeBlocked(tester), isFalse);
      expect(find.byKey(_portableKey), findsNothing);
    },
  );

  _testBridge('stale presentation denial cannot hide newer fitted geometry', (
    tester,
  ) async {
    final initialPresentation = Completer<bool>();
    var readyRequests = 0;
    final fake = _FakeNativeBridge(
      metricsForPayload: (_) => null,
      onPresentation: (payload) =>
          payload['ready'] == true && ++readyRequests == 1
          ? initialPresentation.future
          : Future.value(payload['ready'] as bool),
    );
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(fake.presentationUpdates.last, isTrue);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(fake.updates.last, minimumHeight: 96),
    );
    expect(_nativeBlocked(tester), isTrue);
    expect(fake.presentationUpdates.last, isFalse);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(fake.updates.last, height: 96, minimumHeight: 96),
    );
    expect(_nativeBlocked(tester), isFalse);
    initialPresentation.complete(false);
    await tester.pumpAndSettle();
    expect(_nativeBlocked(tester), isFalse);
    expect(find.byKey(_portableKey), findsNothing);
    expect(fake.presentationUpdates.last, isTrue);
  });

  _testBridge('older query reply cannot replace a newer fitted callback', (
    tester,
  ) async {
    final delayedQuery = Completer<Map<Object?, Object?>?>();
    final fake = _FakeNativeBridge(onMetricsQuery: (_) => delayedQuery.future);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final payload = fake.updates.last;
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(payload, minimumHeight: 96, topOverflow: 28),
      'measurementSequence': 2,
    });
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(payload, height: 96, minimumHeight: 96),
      'measurementSequence': 3,
    });
    expect(_nativeBlocked(tester), isFalse);
    delayedQuery.complete({
      ..._fixtureMetrics(payload, minimumHeight: 96, topOverflow: 28),
      'measurementSequence': 1,
    });
    await tester.pumpAndSettle();
    expect(_nativeBlocked(tester), isFalse);
    expect(find.byKey(_portableKey), findsNothing);
    expect(fake.presentationUpdates.last, isTrue);
    expect(fake.mockErrors, isEmpty);
  });

  _testBridge('newer measurements retain strict overflow and fit guards', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final payload = fake.updates.last;
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(payload),
      'measurementSequence': 1,
    });
    expect(_nativeBlocked(tester), isFalse);
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(payload, minimumHeight: 96, topOverflow: 28),
      'measurementSequence': 2,
    });
    expect(_nativeBlocked(tester), isTrue);
    expect(find.byKey(_portableKey), findsOneWidget);
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(payload, height: 96, minimumHeight: 96),
      'measurementSequence': 3,
    });
    expect(_nativeBlocked(tester), isFalse);
  });

  _testBridge('invalid sequence or geometry cannot advance measurement order', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final current = _fixtureMetrics(fake.updates.last);
    for (final sequence in [0, -1, 1.0, '1', null]) {
      await _reportAndPump(tester, fake, {
        ...current,
        'measurementSequence': sequence,
      });
      expect(_nativeBlocked(tester), isTrue);
    }
    for (final invalid in [
      {...current, 'width': 300},
      {...current, 'revision': (current['revision'] as int) + 1},
      {...current, 'topOverflow': -1},
    ]) {
      await _reportAndPump(tester, fake, {
        ...invalid,
        'measurementSequence': 99,
      });
      expect(_nativeBlocked(tester), isTrue);
    }
    await _reportAndPump(tester, fake, {...current, 'measurementSequence': 1});
    expect(_nativeBlocked(tester), isFalse);
    await _reportAndPump(tester, fake, {
      ...current,
      'minimumHeight': 96,
      'measurementSequence': 1,
    });
    expect(_nativeBlocked(tester), isFalse);
    expect(
      tester.getSize(find.byKey(_nativeKey)).height,
      const AppGlassNavigationStyle().dockHeight,
    );
  });

  _testBridge('legacy metrics work until a sequenced measurement is accepted', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final current = _fixtureMetrics(fake.updates.last);
    await _reportAndPump(tester, fake, current);
    expect(_nativeBlocked(tester), isFalse);
    await _reportAndPump(tester, fake, {...current, 'measurementSequence': 1});
    await _reportAndPump(tester, fake, {
      ...current,
      'minimumHeight': 96,
      'topOverflow': 28,
    });
    expect(_nativeBlocked(tester), isFalse);
    expect(find.byKey(_portableKey), findsNothing);
  });

  _testBridge('replacement native channel starts its own measurement order', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(
      tester,
      selected: selected,
      requests: <int>[],
      dockKey: const ValueKey('first'),
    );
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final oldChannel = fake.channels.last;
    final oldMetrics = {
      ..._fixtureMetrics(fake.updates.last),
      'measurementSequence': 99,
    };
    await _reportAndPump(tester, fake, oldMetrics);
    expect(_nativeBlocked(tester), isFalse);
    await _pumpHost(
      tester,
      selected: selected,
      requests: <int>[],
      dockKey: const ValueKey('second'),
    );
    await _pumpUntil(tester, () => fake.createdIds.length == 2);
    await _reportAndPump(tester, fake, oldMetrics, channel: oldChannel);
    expect(_nativeBlocked(tester), isTrue);
    await _reportAndPump(tester, fake, {
      ..._fixtureMetrics(fake.updates.last),
      'measurementSequence': 1,
    });
    expect(_nativeBlocked(tester), isFalse);
    expect(fake.mockErrors, isEmpty);
  });

  _testBridge('caller lane height is not cached as the native minimum', (
    tester,
  ) async {
    const tallStyle = AppGlassNavigationStyle(actionHeight: 100);
    const minimum = 96.0;
    final fake = _FakeNativeBridge(
      metricsForPayload: (payload) => _fixtureMetrics(
        payload,
        height: tallStyle.dockHeight,
        minimumHeight: minimum,
      ),
    );
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(
      tester,
      selected: selected,
      requests: <int>[],
      style: tallStyle,
    );
    await _pumpUntil(tester, () => !_nativeBlocked(tester));
    final viewId = fake.createdIds.single;
    final oldMetrics = _fixtureMetrics(
      fake.updates.last,
      height: tallStyle.dockHeight,
      minimumHeight: minimum,
    );
    final previousUpdates = fake.updates.length;
    expect(tester.getSize(find.byKey(_nativeKey)).height, tallStyle.dockHeight);

    await _pumpHost(tester, selected: selected, requests: <int>[]);
    await _pumpUntil(tester, () => fake.updates.length > previousUpdates);
    expect(tester.getSize(find.byKey(_nativeKey)).height, minimum);
    expect(_nativeBlocked(tester), isTrue);
    expect(fake.presentationUpdates.last, isFalse);
    await _reportAndPump(tester, fake, oldMetrics);
    expect(_nativeBlocked(tester), isTrue);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(
        fake.updates.last,
        height: tallStyle.dockHeight,
        minimumHeight: minimum,
      ),
    );
    expect(_nativeBlocked(tester), isTrue);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(
        fake.updates.last,
        height: minimum,
        minimumHeight: minimum,
      ),
    );
    expect(_nativeBlocked(tester), isFalse);
    expect(fake.createdIds, [viewId]);
  });

  _testBridge('hidden current geometry cannot reveal or request selection', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    final navigator = GlobalKey<NavigatorState>();
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      navigator: navigator,
    );
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    navigator.currentState!.push<void>(_TransparentPopupRoute());
    await _pumpUntil(tester, () => fake.updates.last['visible'] == false);
    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(_nativeBlocked(tester), isTrue);
    final acknowledgement = fake.select(1);
    await tester.pump();
    expect(await acknowledgement, isNull);
    expect(requests, isEmpty);
    navigator.currentState!.pop();
    await _pumpUntil(tester, () => fake.updates.last['visible'] == true);
    expect(_nativeBlocked(tester), isTrue);
    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(_nativeBlocked(tester), isFalse);
  });

  _testBridge('old-view and disposed geometry events cannot revive a dock', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _pumpHost(
      tester,
      selected: selected,
      requests: <int>[],
      dockKey: const ValueKey('first'),
    );
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    final oldChannel = fake.channels.single;
    final oldMetrics = _fixtureMetrics(fake.updates.last, minimumHeight: 96);
    await _pumpHost(
      tester,
      selected: selected,
      requests: <int>[],
      dockKey: const ValueKey('replacement'),
    );
    await _pumpUntil(tester, () => fake.createdIds.length == 2);
    await _reportAndPump(tester, fake, oldMetrics, channel: oldChannel);
    expect(
      tester.getSize(find.byKey(_nativeKey)).height,
      const AppGlassNavigationStyle().dockHeight,
    );
    expect(_nativeBlocked(tester), isTrue);
    await _reportAndPump(tester, fake, _fixtureMetrics(fake.updates.last));
    expect(_nativeBlocked(tester), isFalse);
    final currentChannel = fake.channels.last;
    final currentMetrics = _fixtureMetrics(fake.updates.last);
    await tester.pumpWidget(const SizedBox.shrink());
    await _reportAndPump(tester, fake, currentMetrics, channel: currentChannel);
    expect(find.byKey(_nativeKey), findsNothing);
    expect(find.byKey(_portableKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _testBridge('too-short caller constraints select sticky usable fallback', (
    tester,
  ) async {
    final fake = _FakeNativeBridge(metricsForPayload: (_) => null);
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final requests = <int>[];
    await _pumpHost(
      tester,
      selected: selected,
      requests: requests,
      maxDockHeight: 80,
    );
    await _pumpUntil(tester, () => fake.metricsQueries > 0);
    await _reportAndPump(
      tester,
      fake,
      _fixtureMetrics(fake.updates.last, minimumHeight: 96, topOverflow: 28),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_nativeKey), findsNothing);
    expect(find.byKey(_portableKey), findsOneWidget);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(requests, [1]);
    expect(selected.value, 1);
    await _pumpHost(tester, selected: selected, requests: requests);
    await tester.pumpAndSettle();
    expect(find.byKey(_nativeKey), findsNothing);
    expect(fake.createdIds, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

List<Map<Object?, Object?>> _payloadItems(Map<Object?, Object?> payload) => [
  for (final item in payload['items'] as List<dynamic>)
    Map<Object?, Object?>.from(item as Map<dynamic, dynamic>),
];

Future<void> _pumpHost(
  WidgetTester tester, {
  required ValueNotifier<int> selected,
  required List<int> requests,
  List<AppGlassNavigationItem> items = _items,
  AppGlassNavigationStyle style = const AppGlassNavigationStyle(),
  bool acceptRequests = true,
  bool reducedMotion = false,
  bool highContrast = false,
  bool boldText = false,
  double? letterSpacing,
  double? wordSpacing,
  double? lineHeight,
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  Object? callbackError,
  GlobalKey<NavigatorState>? navigator,
  Key? dockKey,
  double? maxDockHeight,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(
                disableAnimations: reducedMotion,
                highContrast: highContrast,
                boldText: boldText,
                textScaler: textScaler,
              )
              .applyTextStyleOverrides(
                letterSpacingOverride: letterSpacing,
                wordSpacingOverride: wordSpacing,
                lineHeightScaleFactorOverride: lineHeight,
                paragraphSpacingOverride: null,
              ),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (context, index, child) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxDockHeight ?? double.infinity,
              ),
              child: CustomGlassNavigationDockWidget(
                key: dockKey,
                items: items,
                selectedIndex: index,
                style: style,
                onItemSelected: (index) {
                  requests.add(index);
                  if (callbackError != null) throw callbackError;
                  if (acceptRequests) selected.value = index;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}

Future<void> _reportAndPump(
  WidgetTester tester,
  _FakeNativeBridge fake,
  Map<Object?, Object?> metrics, {
  MethodChannel? channel,
}) async {
  final response = fake.reportMetrics(metrics, channel: channel);
  await tester.pump(Duration.zero);
  await response;
}

void _testBridge(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      // Dispose platform-view controllers before clearing the channel fakes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  // Native payload preparation rasterizes synthetic initials into memory.
  // Yield to the real engine only for those Dart image futures, with a finite
  // bound; the mocked platform channels never execute a device implementation.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(Duration.zero);
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Dart bridge did not reach the expected mocked lifecycle state');
}

bool _nativeBlocked(WidgetTester tester) => tester
    .widget<IgnorePointer>(
      find.descendant(
        of: find.byKey(_nativeKey),
        matching: find.byType(IgnorePointer),
      ),
    )
    .ignoring;

bool _nativeSemanticsExcluded(WidgetTester tester) => tester
    .widget<ExcludeSemantics>(
      find.descendant(
        of: find.byKey(_nativeKey),
        matching: find.byType(ExcludeSemantics),
      ),
    )
    .excluding;

class _FakeNativeBridge {
  _FakeNativeBridge({
    String discoveryResult = 'supported',
    bool failCreation = false,
    Future<void> Function(Map<Object?, Object?> payload)? onUpdate,
    Future<bool> Function(Map<Object?, Object?> payload)? onPresentation,
    Future<Map<Object?, Object?>?> Function(Map<Object?, Object?> payload)?
    onMetricsQuery,
    Map<Object?, Object?>? Function(Map<Object?, Object?> payload)?
    metricsForPayload,
  }) {
    messenger.setMockMethodCallHandler(_discovery, (call) async {
      expectSync(call.method, 'supportsGlass');
      discoveryCalls++;
      if (discoveryResult == 'missing') throw MissingPluginException();
      if (discoveryResult == 'error') {
        throw PlatformException(code: 'mock_discovery_failed');
      }
      return discoveryResult == 'supported';
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map<dynamic, dynamic>;
        expectSync(arguments['viewType'], _viewType);
        final id = arguments['id'] as int;
        createdIds.add(id);
        if (failCreation) {
          throw PlatformException(code: 'mock_unregistered_platform_view');
        }
        final channel = MethodChannel('$_viewType/$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          try {
            if (call.method == 'update') {
              final payload = Map<Object?, Object?>.from(call.arguments as Map);
              updates.add(payload);
              await onUpdate?.call(payload);
            } else if (call.method == 'visibility') {
              final payload = call.arguments as Map<dynamic, dynamic>;
              visibilityUpdates.add(payload['visible'] as bool);
            } else if (call.method == 'presentation') {
              final payload = call.arguments as Map<dynamic, dynamic>;
              expectSync(payload['layoutRevision'], isA<int>());
              presentationUpdates.add(payload['ready'] as bool);
              return onPresentation == null
                  ? payload['ready']
                  : await onPresentation(Map<Object?, Object?>.from(payload));
            } else if (call.method == 'layoutMetrics') {
              metricsQueries++;
              final payload = updates.last;
              if (onMetricsQuery != null) return await onMetricsQuery(payload);
              return metricsForPayload == null
                  ? _fixtureMetrics(payload)
                  : metricsForPayload(payload);
            }
            return null;
          } catch (error) {
            mockErrors.add(error);
            rethrow;
          }
        });
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_discovery, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final createdIds = <int>[];
  final channels = <MethodChannel>[];
  final updates = <Map<Object?, Object?>>[];
  final visibilityUpdates = <bool>[];
  final presentationUpdates = <bool>[];
  final mockErrors = <Object>[];
  int discoveryCalls = 0;
  int metricsQueries = 0;

  Future<Object?> select(Object index) =>
      _invoke(channels.last, 'select', index);

  Future<Object?> reportMetrics(
    Map<Object?, Object?> metrics, {
    MethodChannel? channel,
  }) => _invoke(channel ?? channels.last, 'layoutMetrics', metrics);

  Future<Object?> _invoke(
    MethodChannel channel,
    String method,
    Object arguments,
  ) async {
    final response = await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      null,
    );
    return response == null ? null : channel.codec.decodeEnvelope(response);
  }
}

Map<Object?, Object?> _fixtureMetrics(
  Map<Object?, Object?> payload, {
  double? height,
  double? minimumHeight,
  double topOverflow = 0,
}) {
  final resolvedHeight = height ?? const AppGlassNavigationStyle().dockHeight;
  return {
    'revision': payload['layoutRevision'],
    'width': 390.0,
    'height': resolvedHeight,
    'minimumHeight': minimumHeight ?? resolvedHeight,
    'topOverflow': topOverflow,
  };
}

class _TransparentPopupRoute extends PopupRoute<void> {
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
