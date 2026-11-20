import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(_GlassNavigationExample(host: _ExampleHost()));
}

/// Process-lifetime, SDK-only demo state, deliberately outside all widgets.
///
/// This standalone example is an exception to the consumer app's GetX feature
/// convention. It demonstrates caller ownership without importing that app or
/// adding a state-management dependency to the reusable package.
class _ExampleHost {
  final selection = ValueNotifier<int>(0);
  final configuration = ValueNotifier<_ExampleConfiguration>(
    const _ExampleConfiguration(),
  );
  final feedback = ValueNotifier<String>('No selection requests yet.');
  final lensProbe = ValueNotifier<_LensProbeState>(const _LensProbeState());
  int _requestCount = 0;
  Timer? _lensProbeTimer;
  int? _lensProbeOwner;
  int _lensProbeEpoch = 0;

  void _cancelLensProbeTimer() {
    _lensProbeEpoch++;
    _lensProbeTimer?.cancel();
    _lensProbeTimer = null;
  }

  void armLensProbe(bool armed) {
    if (armed && _lensProbeOwner != null) {
      if (!lensProbe.value.contactOwned) {
        lensProbe.value = const _LensProbeState(
          contactOwned: true,
          message: 'Release this dock contact before arming the next one.',
        );
      }
      return;
    }
    _cancelLensProbeTimer();
    lensProbe.value = _LensProbeState(
      armed: armed,
      contactOwned: _lensProbeOwner != null,
      message: armed
          ? 'Armed: the next dock DOWN starts a 2-second lens switch.'
          : 'Probe disarmed; any pending switch is cancelled.',
    );
  }

  void beginLensProbeContact(PointerDownEvent event) {
    if (_lensProbeOwner != null) return;
    _lensProbeOwner = event.pointer;
    // Retain raw ownership silently until the user opts into the diagnostic.
    // Ordinary dock contacts must not animate/reflow the probe controls.
    if (!lensProbe.value.armed) return;
    final epoch = _lensProbeEpoch;
    final owner = event.pointer;
    _lensProbeTimer = Timer(const Duration(seconds: 2), () {
      if (_lensProbeEpoch != epoch ||
          _lensProbeOwner != owner ||
          !lensProbe.value.armed) {
        return;
      }
      _lensProbeTimer = null;
      final growing = !configuration.value.growingLens;
      final hostIndex = selection.value;
      final requestCount = _requestCount;
      lensProbe.value = _LensProbeState(
        contactOwned: true,
        message:
            'Switched pressedScale ${growing ? '1.0 → >1' : '>1 → 1.0'}. '
            'At firing: host index $hostIndex; request count $requestCount. '
            'Auto-disarmed; release the owner before rearming.',
      );
      // A synchronous status listener may reset/disarm or end this contact.
      if (_lensProbeEpoch != epoch || _lensProbeOwner != owner) return;
      configuration.value = configuration.value.copyWith(growingLens: growing);
    });
    lensProbe.value = const _LensProbeState(
      armed: true,
      contactOwned: true,
      message: 'Owner DOWN: lens switch pending in 2 seconds; keep holding.',
    );
  }

  void endLensProbeContact(PointerEvent event) {
    if (_lensProbeOwner != event.pointer) return;
    final pending = lensProbe.value.armed;
    final observedContact = lensProbe.value.contactOwned;
    _lensProbeOwner = null;
    _cancelLensProbeTimer();
    if (!pending && !observedContact) return;
    lensProbe.value = _LensProbeState(
      message: pending
          ? 'Pending switch cancelled by owner '
                '${event is PointerCancelEvent ? 'CANCEL' : 'UP'}.'
          : 'Probe off; contact ended. Ready to arm the next contact.',
    );
  }

  void requestSelection(int next) {
    final accepts = configuration.value.acceptRequests;
    if (accepts) selection.value = next;
    feedback.value =
        'Request ${++_requestCount}: ${_destinationNames[next]} '
        '(index $next) ${accepts ? 'accepted' : 'rejected'}. '
        'Host index: ${selection.value}.';
  }

  void reset() {
    _cancelLensProbeTimer();
    // Reset must not hand an already-down secondary pointer ownership.
    lensProbe.value = _LensProbeState(
      contactOwned: _lensProbeOwner != null,
      message: 'Probe reset: disarmed, original growing lens restored.',
    );
    configuration.value = const _ExampleConfiguration();
    selection.value = 0;
    _requestCount = 0;
    feedback.value = 'No selection requests yet.';
  }
}

@immutable
class _LensProbeState {
  const _LensProbeState({
    this.armed = false,
    this.contactOwned = false,
    this.message =
        'Probe off. Arm to switch the next held contact after 2 seconds.',
  });

  final bool armed;
  final bool contactOwned;
  final String message;
}

const _destinationNames = [
  'Explore',
  'Featured',
  'Likes',
  'Messages',
  'Profile',
];

enum _ExampleBadge {
  none(null),
  count('3'),
  wideCount('99+'),
  word('NEW');

  const _ExampleBadge(this.label);

  final String? label;
}

enum _ExamplePalette {
  indigo('Indigo', Color(0xFF4658A7)),
  teal('Teal', Color(0xFF006B62)),
  plum('Plum', Color(0xFF7C3F68));

  const _ExamplePalette(this.label, this.seed);

  final String label;
  final Color seed;
}

@immutable
class _ExampleConfiguration {
  const _ExampleConfiguration({
    this.acceptRequests = true,
    this.messagesEnabled = true,
    this.badge = _ExampleBadge.count,
    this.preferNative = true,
    this.itemSizing = AppGlassNavigationItemSizing.contentBalanced,
    this.scrubSelectionPolicy =
        AppGlassNavigationScrubSelectionPolicy.continuous,
    this.foregroundLens = true,
    this.flattenScrub = false,
    this.motionDeformation = true,
    this.innerBevel = false,
    this.heldBarTint = false,
    this.darkTheme = false,
    this.reduceMotion = false,
    this.zeroDuration = false,
    this.highContrast = false,
    this.largeText = false,
    this.longLabels = false,
    this.rtl = false,
    this.palette = _ExamplePalette.indigo,
    this.roundedCorners = false,
    this.blurSigma = 20,
    this.growingLens = true,
    this.comparisonCanvas = false,
  });

  final bool acceptRequests;
  final bool messagesEnabled;
  final _ExampleBadge badge;
  final bool preferNative;
  final AppGlassNavigationItemSizing itemSizing;
  final AppGlassNavigationScrubSelectionPolicy scrubSelectionPolicy;
  final bool foregroundLens;
  final bool flattenScrub;
  final bool motionDeformation;
  final bool innerBevel;
  final bool heldBarTint;
  final bool darkTheme;
  final bool reduceMotion;
  final bool zeroDuration;
  final bool highContrast;
  final bool largeText;
  final bool longLabels;
  final bool rtl;
  final _ExamplePalette palette;
  final bool roundedCorners;
  final double blurSigma;
  final bool growingLens;
  final bool comparisonCanvas;

  _ExampleConfiguration copyWith({
    bool? acceptRequests,
    bool? messagesEnabled,
    _ExampleBadge? badge,
    bool? preferNative,
    AppGlassNavigationItemSizing? itemSizing,
    AppGlassNavigationScrubSelectionPolicy? scrubSelectionPolicy,
    bool? foregroundLens,
    bool? flattenScrub,
    bool? motionDeformation,
    bool? innerBevel,
    bool? heldBarTint,
    bool? darkTheme,
    bool? reduceMotion,
    bool? zeroDuration,
    bool? highContrast,
    bool? largeText,
    bool? longLabels,
    bool? rtl,
    _ExamplePalette? palette,
    bool? roundedCorners,
    double? blurSigma,
    bool? growingLens,
    bool? comparisonCanvas,
  }) => _ExampleConfiguration(
    acceptRequests: acceptRequests ?? this.acceptRequests,
    messagesEnabled: messagesEnabled ?? this.messagesEnabled,
    badge: badge ?? this.badge,
    preferNative: preferNative ?? this.preferNative,
    itemSizing: itemSizing ?? this.itemSizing,
    scrubSelectionPolicy: scrubSelectionPolicy ?? this.scrubSelectionPolicy,
    foregroundLens: foregroundLens ?? this.foregroundLens,
    flattenScrub: flattenScrub ?? this.flattenScrub,
    motionDeformation: motionDeformation ?? this.motionDeformation,
    innerBevel: innerBevel ?? this.innerBevel,
    heldBarTint: heldBarTint ?? this.heldBarTint,
    darkTheme: darkTheme ?? this.darkTheme,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    zeroDuration: zeroDuration ?? this.zeroDuration,
    highContrast: highContrast ?? this.highContrast,
    largeText: largeText ?? this.largeText,
    longLabels: longLabels ?? this.longLabels,
    rtl: rtl ?? this.rtl,
    palette: palette ?? this.palette,
    roundedCorners: roundedCorners ?? this.roundedCorners,
    blurSigma: blurSigma ?? this.blurSigma,
    growingLens: growingLens ?? this.growingLens,
    comparisonCanvas: comparisonCanvas ?? this.comparisonCanvas,
  );
}

/// The dock receives resolved inputs; only its caller accepts destination state.
class _GlassNavigationExample extends StatelessWidget {
  const _GlassNavigationExample({required this.host});

  final _ExampleHost host;

  List<AppGlassNavigationItem> _items(_ExampleConfiguration configuration) => [
    AppGlassNavigationItem(
      icon: Icons.explore_outlined,
      label: configuration.longLabels
          ? 'Explore the demo collection'
          : _destinationNames[0],
    ),
    AppGlassNavigationItem(
      icon: Icons.star_outline,
      label: configuration.longLabels
          ? 'Featured demo selections'
          : _destinationNames[1],
    ),
    AppGlassNavigationItem(
      icon: Icons.favorite_outline,
      label: configuration.longLabels
          ? 'Likes on demo content'
          : _destinationNames[2],
      badgeLabel: configuration.badge.label,
    ),
    AppGlassNavigationItem(
      icon: Icons.chat_bubble_outline,
      label: configuration.longLabels
          ? 'Recent demo conversations'
          : _destinationNames[3],
      enabled: configuration.messagesEnabled,
    ),
    AppGlassNavigationItem(
      icon: Icons.person_outline,
      label: configuration.longLabels
          ? 'Your synthetic demo profile'
          : _destinationNames[4],
      nativeImage: const AppGlassNavigationImage(initials: 'AB'),
    ),
  ];

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<_ExampleConfiguration>(
    valueListenable: host.configuration,
    builder: (context, configuration, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glass navigation example',
      theme: ThemeData(
        colorSchemeSeed: configuration.palette.seed,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: configuration.palette.seed,
        brightness: Brightness.dark,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      themeMode: configuration.darkTheme ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Local overrides preserve platform motion and contrast preferences.
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                media.disableAnimations || configuration.reduceMotion,
            highContrast: media.highContrast || configuration.highContrast,
            textScaler: configuration.largeText
                ? TextScaler.linear(math.max(2, media.textScaler.scale(1)))
                : media.textScaler,
          ),
          child: Directionality(
            textDirection: configuration.rtl
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          ),
        );
      },
      home: Builder(
        builder: (context) {
          final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
          final theme = Theme.of(context);
          final themedStyle = AppGlassNavigationStyle.fromTheme(theme);
          final style = themedStyle.copyWith(
            // Resolve the theme once, then override only this demo's choices.
            // This comparison preset is deliberate, not a UIKit size contract.
            actionHeight: 54,
            labelStyle: themedStyle.labelStyle.copyWith(
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
            outlineWidth: 0.5,
            // Caller-only geometry trial: narrow the target-center track while
            // allowing visual capsule overlap without expanding action hits.
            horizontalContentInset: 19,
            selectionHorizontalInset: 0,
            selectionHorizontalOutset: 10,
            radius: configuration.roundedCorners ? 18 : 999,
            blurSigma: configuration.blurSigma,
            heldBarSurfaceColor: configuration.heldBarTint
                ? theme.brightness == Brightness.dark
                      ? theme.colorScheme.surface.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.82)
                : null,
            duration: configuration.zeroDuration
                ? Duration.zero
                : const Duration(milliseconds: 200),
            itemSizing: configuration.itemSizing,
            scrubSelectionPolicy: configuration.scrubSelectionPolicy,
            refractionStrength: 6,
            foregroundRefractionEdge: 6,
            foregroundMagnification: 1.12,
            foregroundDispersion: 0.25,
            selectedBackdropDispersion: 1,
            heldBlurSigma: 4,
            trackVerticalDrag: true,
            heldInnerShadow: BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.28
                    : 0.16,
              ),
              blurRadius: 10,
              offset: const Offset(0, 1),
              spreadRadius: 1,
            ),
            heldInnerHighlight: BoxShadow(
              color: Colors.white.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.16
                    : 0.98,
              ),
              blurRadius: 1,
              spreadRadius: 2,
            ),
            heldInnerHighlightGradient: configuration.innerBevel
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.tertiary.withValues(alpha: 0.5),
                      theme.colorScheme.primary.withValues(alpha: 0.45),
                      theme.colorScheme.tertiary.withValues(alpha: 0.25),
                    ],
                  )
                : null,
            heldRimGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5),
                Theme.of(context).colorScheme.onInverseSurface,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ],
            ),
            selectionSpring: const SpringDescription(
              mass: 1,
              stiffness: 560,
              damping: 36,
            ),
            animateSelectionDeformation: true,
            refractForegroundDuringInteraction: configuration.foregroundLens,
            heldBarScale: 1.04,
            // Preserve the capsule's total held size after ancestor expansion.
            pressedScale: configuration.growingLens ? 1.24 / 1.04 : 1.0,
            pressureStretch: 1.25 / 1.04 - 1,
            // Experimental consumer choice; not a calibrated UIKit curve.
            scrubVerticalScale: configuration.flattenScrub ? 0.74 : 1,
            scrubMotionStretch: configuration.motionDeformation ? 0.20 : 0,
            scrubMotionFlattening: configuration.motionDeformation ? 0.30 : 0,
            releaseVerticalStretch: 0,
          );
          final items = _items(configuration);
          // Selection changes rebuild only their consumers. In particular,
          // continuous scrubbing must not recreate the configuration controls,
          // list delegate, card decoration or resolved dock inputs each time
          // the host accepts another destination.
          return Scaffold(
            extendBody: true,
            appBar: AppBar(
              title: ValueListenableBuilder<int>(
                valueListenable: host.selection,
                builder: (context, index, _) => Text(_destinationNames[index]),
              ),
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Builder(
                  builder: (context) => ListView.builder(
                    // Scaffold includes the actual dock height in this padding,
                    // including enlarged labels, when extendBody is enabled.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      MediaQuery.paddingOf(context).bottom + 16,
                    ),
                    itemCount: 21,
                    itemBuilder: (context, row) {
                      if (row == 0) {
                        return _ExampleControls(
                          configuration: configuration,
                          selection: host.selection,
                          feedback: host.feedback,
                          lensProbe: host.lensProbe,
                          onProbeArmedChanged: host.armLensProbe,
                          onChanged: (next) => host.configuration.value = next,
                          onReset: host.reset,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          height: 160,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Color.lerp(
                                  Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  Theme.of(context)
                                      .colorScheme
                                      .tertiaryContainer,
                                  ((row - 1) % 5) / 4,
                                )!,
                                Theme.of(context).colorScheme.surfaceContainer,
                              ],
                            ),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: host.selection,
                            builder: (context, index, _) => Text(
                              '${_destinationNames[index]} demo card $row',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (configuration.comparisonCanvas)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 240 + math.max(safeBottom, style.bottomInset),
                    child: const _ComparisonCanvas(),
                  ),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: math.max(0, safeBottom - style.bottomInset),
              ),
              // Always present: observing raw events adds no recognizer or
              // conditional ancestry/key change to the dock under test.
              child: Listener(
                behavior: HitTestBehavior.deferToChild,
                onPointerDown: host.beginLensProbeContact,
                onPointerUp: host.endLensProbeContact,
                onPointerCancel: host.endLensProbeContact,
                child: ValueListenableBuilder<int>(
                  valueListenable: host.selection,
                  builder: (context, index, _) =>
                      CustomGlassNavigationDockWidget(
                        items: items,
                        selectedIndex: index,
                        style: style,
                        preferNative: configuration.preferNative,
                        semanticLabel: 'Synthetic demo destinations',
                        onItemSelected: host.requestSelection,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ExampleControls extends StatelessWidget {
  const _ExampleControls({
    required this.configuration,
    required this.selection,
    required this.feedback,
    required this.lensProbe,
    required this.onProbeArmedChanged,
    required this.onChanged,
    required this.onReset,
  });

  final _ExampleConfiguration configuration;
  final ValueListenable<int> selection;
  final ValueListenable<String> feedback;
  final ValueListenable<_LensProbeState> lensProbe;
  final ValueChanged<bool> onProbeArmedChanged;
  final ValueChanged<_ExampleConfiguration> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Demo controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: onReset,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        ValueListenableBuilder<int>(
          valueListenable: selection,
          builder: (context, index, _) => Text(
            'Host selection: ${_destinationNames[index]} (index $index).',
          ),
        ),
        ValueListenableBuilder<String>(
          valueListenable: feedback,
          builder: (context, message, _) => Semantics(
            container: true,
            liveRegion: true,
            child: Text(message),
          ),
        ),
        const SizedBox(height: 8),
        FilterChip(
          label: const Text('Comparison canvas'),
          selected: configuration.comparisonCanvas,
          tooltip:
              'Local diagnostic: a fixed pattern behind the dock, anchored '
              'above its bottom reserve. Scrolling and selection do not move it.',
          onSelected: (enabled) =>
              onChanged(configuration.copyWith(comparisonCanvas: enabled)),
        ),
        if (configuration.comparisonCanvas)
          const Text(
            'Comparison canvas on: the lower diagnostic pattern stays fixed '
            'behind the dock while these controls scroll. Match theme, text '
            'size and contact phase when comparing Auto with Flutter.',
          ),
        const SizedBox(height: 8),
        ValueListenableBuilder<_LensProbeState>(
          valueListenable: lensProbe,
          builder: (context, probe, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterChip(
                label: const Text('Arm 2s lens switch'),
                selected: probe.armed,
                tooltip:
                    'Local diagnostic: switch pressedScale on the next held '
                    'dock contact. Choose Flutter and ordinary motion.',
                onSelected: probe.armed || !probe.contactOwned
                    ? onProbeArmedChanged
                    : null,
              ),
              Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  'Live lens diagnostic · '
                  '${configuration.growingLens ? 'growing (>1)' : 'nongrowing (1.0)'} '
                  '· ${probe.message}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Feedback text above may reflow. Retain stable control paint at its
        // new offset rather than recording every Material control again.
        RepaintBoundary(
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selection requests',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    segments: const [
                      ButtonSegment(value: true, label: Text('Accept')),
                      ButtonSegment(value: false, label: Text('Reject')),
                    ],
                    selected: {configuration.acceptRequests},
                    onSelectionChanged: (selection) => onChanged(
                      configuration.copyWith(acceptRequests: selection.single),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Renderer preference',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    segments: const [
                      ButtonSegment(value: true, label: Text('Auto')),
                      ButtonSegment(value: false, label: Text('Flutter')),
                    ],
                    selected: {configuration.preferNative},
                    onSelectionChanged: (selection) => onChanged(
                      configuration.copyWith(preferNative: selection.single),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flutter target sizing',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AppGlassNavigationItemSizing>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: AppGlassNavigationItemSizing.equal,
                        label: Text('Equal'),
                        tooltip: 'Keep fitting destinations equally wide.',
                      ),
                      ButtonSegment(
                        value: AppGlassNavigationItemSizing.contentBalanced,
                        label: Text('Balanced'),
                        tooltip:
                            'Add equal spare space to complete caption minima.',
                      ),
                    ],
                    selected: {configuration.itemSizing},
                    onSelectionChanged: (selection) => onChanged(
                      configuration.copyWith(itemSizing: selection.single),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flutter scrub selection',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AppGlassNavigationScrubSelectionPolicy>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    segments: const [
                      ButtonSegment(
                        value:
                            AppGlassNavigationScrubSelectionPolicy.continuous,
                        label: Text('Continuous'),
                        tooltip:
                            'Request enabled destinations while scrubbing.',
                      ),
                      ButtonSegment(
                        value: AppGlassNavigationScrubSelectionPolicy
                            .onReleaseWithinLane,
                        label: Text('Release within lane'),
                        tooltip: 'Request only on owner release inside the visible bar.',
                      ),
                    ],
                    selected: {configuration.scrubSelectionPolicy},
                    onSelectionChanged: (selection) => onChanged(
                      configuration.copyWith(
                        scrubSelectionPolicy: selection.single,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Auto prefers eligible native iOS; otherwise it uses Flutter. '
          'The choice is a preference, not renderer detection. '
          'Target sizing and scrub policy affect fitting Flutter tracks only; '
          'UIKit keeps system selection and scrolling scrubs stay unchanged.',
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: _ExampleStyleControls(
            configuration: configuration,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Messages enabled'),
                selected: configuration.messagesEnabled,
                tooltip: 'Disabled Messages emit no selection requests.',
                onSelected: (enabled) =>
                    onChanged(configuration.copyWith(messagesEnabled: enabled)),
              ),
              FilterChip(
                label: const Text('Foreground lens'),
                selected: configuration.foregroundLens,
                tooltip:
                    'Flutter only: bend painted icons and labels during feedback. '
                    'Backdrop optics and selection geometry stay unchanged.',
                onSelected: (enabled) =>
                    onChanged(configuration.copyWith(foregroundLens: enabled)),
              ),
              FilterChip(
                label: const Text('Flatten scrub'),
                selected: configuration.flattenScrub,
                tooltip:
                    'Experimental Flutter only: blend scrub height to 0.74×. '
                    'Stationary holds keep their ordinary height.',
                onSelected: (enabled) =>
                    onChanged(configuration.copyWith(flattenScrub: enabled)),
              ),
              FilterChip(
                label: const Text('Moving deformation'),
                selected: configuration.motionDeformation,
                tooltip:
                    'Flutter only: stretch and flatten during movement, then '
                    'recover while held still. Selection stays host-controlled.',
                onSelected: (enabled) => onChanged(
                  configuration.copyWith(motionDeformation: enabled),
                ),
              ),
              FilterChip(
                label: const Text('Inner bevel'),
                selected: configuration.innerBevel,
                tooltip:
                    'Flutter only: add a theme-colored inner band during lens '
                    'feedback. The solid highlight stays enabled.',
                onSelected: (enabled) =>
                    onChanged(configuration.copyWith(innerBevel: enabled)),
              ),
              FilterChip(
                label: const Text('Held bar tint'),
                selected: configuration.heldBarTint,
                tooltip:
                    'Experimental Flutter only: tint the whole outer bar during '
                    'eligible contact. This is not calibrated native parity.',
                onSelected: (enabled) =>
                    onChanged(configuration.copyWith(heldBarTint: enabled)),
              ),
              FilterChip(
                label: const Text('Dark theme'),
                selected: configuration.darkTheme,
                onSelected: (dark) =>
                    onChanged(configuration.copyWith(darkTheme: dark)),
              ),
              FilterChip(
                label: const Text('Reduce motion'),
                selected: configuration.reduceMotion,
                onSelected: (reduce) =>
                    onChanged(configuration.copyWith(reduceMotion: reduce)),
              ),
              FilterChip(
                label: const Text('Zero duration'),
                selected: configuration.zeroDuration,
                tooltip:
                    'Flutter only: set the dock transition duration to zero. '
                    'Selection remains controlled by the host.',
                onSelected: (zero) =>
                    onChanged(configuration.copyWith(zeroDuration: zero)),
              ),
              FilterChip(
                label: const Text('High contrast'),
                selected: configuration.highContrast,
                tooltip:
                    'Enable local high contrast. An inherited system preference '
                    'remains active when this control is off.',
                onSelected: (high) =>
                    onChanged(configuration.copyWith(highContrast: high)),
              ),
              FilterChip(
                label: const Text('Large text ×2'),
                selected: configuration.largeText,
                onSelected: (large) =>
                    onChanged(configuration.copyWith(largeText: large)),
              ),
              FilterChip(
                label: const Text('Long labels'),
                selected: configuration.longLabels,
                onSelected: (long) =>
                    onChanged(configuration.copyWith(longLabels: long)),
              ),
              FilterChip(
                label: const Text('RTL layout'),
                selected: configuration.rtl,
                onSelected: (rtl) =>
                    onChanged(configuration.copyWith(rtl: rtl)),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const ExcludeSemantics(child: Text('Likes badge text')),
            Semantics(
              container: true,
              label: 'Likes badge text',
              child: DropdownButton<_ExampleBadge>(
                value: configuration.badge,
                itemHeight: 48,
                onChanged: (badge) {
                  if (badge != null) {
                    onChanged(configuration.copyWith(badge: badge));
                  }
                },
                items: [
                  for (final badge in _ExampleBadge.values)
                    DropdownMenuItem(
                      value: badge,
                      child: Text(badge.label ?? 'None'),
                    ),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Local demo only · Motion: '
          '${MediaQuery.disableAnimationsOf(context) ? 'reduced' : 'ordinary'} '
          '· Flutter duration: '
          '${configuration.zeroDuration ? 'zero' : 'ordinary'} '
          '· Contrast: '
          '${MediaQuery.highContrastOf(context) ? 'high' : 'ordinary'} '
          '· Text: ${MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(1)}× '
          '· ${configuration.rtl ? 'RTL' : 'LTR'} '
          '· Flutter widths: '
          '${configuration.itemSizing == AppGlassNavigationItemSizing.equal ? 'equal' : 'balanced'} '
          '· Flutter scrub: '
          '${configuration.scrubSelectionPolicy == AppGlassNavigationScrubSelectionPolicy.continuous ? 'continuous' : 'release within lane'} '
          '· Experimental scrub height: '
          '${configuration.flattenScrub ? '0.74×' : '1.00× (neutral)'} '
          '· Experimental whole-bar tint: '
          '${configuration.heldBarTint ? 'on' : 'off'}',
        ),
        const SizedBox(height: 8),
        const Text(
          'Flutter: tap or drag to request selection. Scrolling labels: '
          'swipe to reveal, long-press and drag to select.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose Flutter to check zero duration; UIKit keeps system motion.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Foreground lens compares only Flutter interaction optics. '
          'It does not change native UIKit material or resting geometry.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Flatten scrub compares experimental Flutter height during a '
          'recognized fitting drag. A paused scrub stays flattened until '
          'release or cancel; stationary pre-drag holds stay unchanged. '
          'Choose Flutter; UIKit keeps system motion.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Inner bevel compares the optional Flutter inner color band during '
          'lens feedback. Choose Flutter to compare it on iOS. '
          'The solid highlight remains enabled in both states.',
        ),
      ],
    ),
  );
}

/// Original static calibration artwork, separate from scrolling demo content.
/// It introduces no interaction, animation or additional backdrop filter.
class _ComparisonCanvas extends StatelessWidget {
  const _ComparisonCanvas();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        key: const ValueKey('comparison-canvas'),
        child: CustomPaint(
          painter: _ComparisonCanvasPainter(
            colors: Theme.of(context).colorScheme,
          ),
        ),
      ),
    ),
  );
}

class _ComparisonCanvasPainter extends CustomPainter {
  const _ComparisonCanvasPainter({required this.colors});

  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawRect(Offset.zero & size, paint..color = colors.surface);
    // Every row is identical: public UIKit lane height can differ from the
    // nominal Flutter height without changing this horizontal diagnostic input.
    // The original bars have fixed logical widths and a centered 96px cadence.
    const pitch = 96.0;
    for (
      var column = -((size.width / 2 / pitch).ceil());
      column <= (size.width / 2 / pitch).ceil();
      column++
    ) {
      final x = size.width / 2 + column * pitch;
      canvas.drawRect(
        Rect.fromLTRB(x, 0, x + 12, size.height),
        paint..color = colors.primaryContainer,
      );
      canvas.drawRect(
        Rect.fromLTRB(x + 24, 0, x + 48, size.height),
        paint..color = colors.tertiaryContainer,
      );
      canvas.drawRect(
        Rect.fromLTRB(x + 54, 0, x + 60, size.height),
        paint..color = colors.onSurface.withValues(alpha: 0.55),
      );
      canvas.drawRect(
        Rect.fromLTRB(x + 72, 0, x + 90, size.height),
        paint..color = colors.secondaryContainer,
      );
    }
  }

  @override
  bool shouldRepaint(_ComparisonCanvasPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

/// Consumer-owned styling examples composed through the public style API.
class _ExampleStyleControls extends StatelessWidget {
  const _ExampleStyleControls({
    required this.configuration,
    required this.onChanged,
  });

  final _ExampleConfiguration configuration;
  final ValueChanged<_ExampleConfiguration> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          'Customize appearance',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final palette in _ExamplePalette.values)
            ChoiceChip(
              label: Text(palette.label),
              selected: configuration.palette == palette,
              onSelected: (selected) {
                if (selected) {
                  onChanged(configuration.copyWith(palette: palette));
                }
              },
            ),
          FilterChip(
            label: const Text('Rounded Flutter corners'),
            selected: configuration.roundedCorners,
            onSelected: (rounded) =>
                onChanged(configuration.copyWith(roundedCorners: rounded)),
          ),
        ],
      ),
      Text('Flutter blur: ${configuration.blurSigma.round()}'),
      Slider(
        value: configuration.blurSigma,
        max: 30,
        divisions: 30,
        semanticFormatterCallback: (value) =>
            'Flutter blur, ${value.round()} logical pixels',
        onChanged: (value) =>
            onChanged(configuration.copyWith(blurSigma: value)),
      ),
      const Text(
        'Theme colors reach both renderers. Corner radius and blur customize '
        'Flutter; UIKit supplies its own glass shape and material.',
      ),
    ],
  );
}
