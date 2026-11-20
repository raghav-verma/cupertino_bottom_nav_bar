import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import 'custom_glass_backdrop_widget.dart';
import 'glass_navigation_models.dart';

/// An SDK-only floating glass dock with externally controlled selection.
///
/// Flutter samples the backdrop with blur and optional Impeller refraction.
/// Foreground stays sharp by default, with optional interaction-only refraction;
/// this is not UIKit's optical implementation.
/// One capsule translates between destinations and responds to pointer presses.
/// Fitting growing lenses may preview a touched enabled destination locally;
/// that pressure/artwork feedback does not change host-owned selection.
/// Other layouts retain selected-contact pressure and individual item highlights.
/// An optional accepted-selection pulse uses the same deformation axes without
/// transferring pointer ownership or accepting a declined request.
/// Dragging across enabled destinations requests selection while scrubbing.
/// The first contact owns scrub and capsule pressure until release/cancellation;
/// an already-down secondary contact cannot take over that gesture. Individual
/// destination taps and the scrolling viewport retain their own SDK gestures.
///
/// Complete labels and minimum targets use a horizontal viewport when needed.
/// In that layout ordinary swipes scroll, while a long press followed by a drag
/// scrubs destinations without competing with the scroll gesture. Keyboard
/// focus and external selection reveal their destination in the same viewport.
///
/// The stateful implementation owns only animation, gesture and scroll
/// lifecycle. [selectedIndex] remains the sole accepted selection; transient
/// drag feedback returns to that input after release or cancellation.
class CustomFlutterGlassNavigationDockWidget extends StatefulWidget {
  /// Creates a glass dock from resolved SDK-only inputs.
  const CustomFlutterGlassNavigationDockWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.style,
    this.iconOnly = false,
    this.semanticLabel = 'Primary navigation',
  }) : assert(items.length >= 2, 'A navigation dock needs at least two items'),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  /// Immutable destination inputs in the caller's canonical order.
  final List<AppGlassNavigationItem> items;

  /// The accepted selection supplied by the owning application.
  final int selectedIndex;

  /// Requests selection by index; the caller may accept or decline the request.
  final ValueChanged<int> onItemSelected;

  /// Resolved colors, typography, geometry and motion.
  final AppGlassNavigationStyle style;

  /// Hides visual captions while preserving labels and tooltips.
  final bool iconOnly;

  /// Resolved label for the navigation container.
  final String semanticLabel;

  @override
  State<CustomFlutterGlassNavigationDockWidget> createState() =>
      _FlutterGlassNavigationDockState();
}

/// Component-local animation, pointer and scroll mechanics only.
class _FlutterGlassNavigationDockState
    extends State<CustomFlutterGlassNavigationDockWidget>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double?> _dragCenter = ValueNotifier(null);
  // Notifies destinations only at contact boundaries, never every animation
  // tick, so touch-only ink suppression cannot remove keyboard feedback.
  final ValueNotifier<bool> _pointerFeedback = ValueNotifier(false);
  // Visual contact feedback only; destination semantics and callbacks remain
  // controlled by widget.selectedIndex and the host.
  final ValueNotifier<int?> _contactPreviewIndex = ValueNotifier(null);
  // Base material and the fitting selected lens read one scene input. The
  // post-foreground lens deliberately does not share this key: it reads icons.
  final BackdropKey _sceneBackdropKey = BackdropKey();
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  final GlobalKey _trackKey = GlobalKey();
  late final AnimationController _selectionMotion;
  late final AnimationController _pressureMotion;
  late final AnimationController _selectionDeformationMotion;
  late final AnimationController _releaseRecoveryMotion;
  // Component-local geometric handoff only, never a destination-state owner.
  late final AnimationController _scrubCorrectionMotion;
  late final AnimationController _scrubVerticalScaleMotion;
  late final AnimationController _scrubDeformationMotion;
  late final Listenable _motion;
  _DockLayout? _layout;
  _LabelMeasurements? _labelMeasurements;
  bool _fontUpdateScheduled = false;
  _DockLayout? _contactPreviewLayout;
  Rect? _selectionFrom;
  Rect? _selectionTo;
  _CapsuleSpringMotion? _selectionSpring;
  bool _reduceMotion = false;
  bool _scrubbing = false;
  bool _revealScheduled = false;
  int? _pendingRevealIndex;
  int? _lastRequestedIndex;
  int? _pointer;
  int? _pressedIndex;
  Offset? _pointerDown;
  Duration? _pointerDownTime;
  double _grabOffset = 0;
  double? _pointerGrabOffset;
  // A fitting pan contact that actually caught the painted lens may follow raw
  // moves before recognition, without requesting or accepting navigation.
  Rect? _pointerTrackedLens;
  ({double x, double scale})? _capturedPointerProjection;
  Rect? _heldSelection;
  Rect? _scrubCorrection;
  _CapsuleSpringMotion? _scrubCorrectionSpring;
  double _pressureTarget = 0;
  double _heldBarScaleLimit = 1;
  double _paintedHeldBarScale = 1;
  double _pointerDownBarScale = 1;
  double _scrubSampleBarScale = 1;
  bool _pointerUsesBarTransform = false;
  ({double scale, double rate, double relativeX})? _releasedBarProjection;
  // Only an actual owner UP can authorize a deferred fitting-scrub request.
  // Keep its incoming track coordinates across raw-up cleanup until SDK end.
  ({_DockLayout layout, double x, double adjustedX})? _releasedScrubContact;
  // A matching first-frame acknowledgement continues release feedback rather
  // than starting an additional accepted-selection pulse. Never accepted state.
  ({int index, Object token})? _releasedSelectionPulse;
  // Raw UP records a completed owned hold; only InkWell's pointer-tap
  // qualification may turn it into a matching first-frame acknowledgement.
  ({int index, _DockLayout layout, Object token})? _releasedHeldTap;
  double _selectionDeformationFrom = 0;
  double _releaseRecoveryPressure = 0;
  bool _releaseRecoveryTriggered = false;
  double _scrubVerticalScaleFrom = 1;
  double _scrubVerticalScaleTo = 1;
  double? _scrubDeformationPointerX;
  _ScrubDeformationRecovery? _scrubDeformationSpring;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
    _selectionMotion = AnimationController.unbounded(
      vsync: this,
      duration: widget.style.duration,
    );
    _pressureMotion = AnimationController(
      vsync: this,
      duration: widget.style.duration,
    );
    _selectionDeformationMotion = AnimationController(
      vsync: this,
      duration: widget.style.duration,
      value: 1,
    );
    _releaseRecoveryMotion = AnimationController(
      vsync: this,
      duration: widget.style.duration,
      value: 1,
    );
    _scrubCorrectionMotion = AnimationController.unbounded(
      vsync: this,
      duration: widget.style.duration,
      value: 0,
    );
    _scrubVerticalScaleMotion = AnimationController(
      vsync: this,
      duration: widget.style.duration,
      value: 1,
    );
    _scrubDeformationMotion = AnimationController.unbounded(vsync: this);
    _motion = Listenable.merge([
      _selectionMotion,
      _pressureMotion,
      _selectionDeformationMotion,
      _releaseRecoveryMotion,
      _scrubCorrectionMotion,
      _scrubVerticalScaleMotion,
      _scrubDeformationMotion,
      _dragCenter,
    ]);
    _syncItemKeys();
  }

  void _onSystemFontsChanged() {
    if (_fontUpdateScheduled) return;
    _fontUpdateScheduled = true;
    // Font notifications can arrive mid-frame. Match RenderParagraph's deferred
    // font invalidation so measuring and painting use the same font generation.
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _fontUpdateScheduled = false;
      if (!mounted) return;
      setState(() => _labelMeasurements = null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _snapToHostSelection();
    }
  }

  void _snapToHostSelection() {
    _selectionMotion.stop();
    _selectionSpring = null;
    _pressureMotion.stop();
    final layout = _layout;
    if (layout != null && widget.selectedIndex < layout.rects.length) {
      _selectionFrom = _selectionTo = layout.rects[widget.selectedIndex];
    }
    _scrubbing = false;
    _contactPreviewIndex.value = null;
    _resetScrubCorrection();
    _resetScrubVerticalScale();
    _resetScrubDeformation();
    _pressedIndex = null;
    _pointerFeedback.value = false;
    _lastRequestedIndex = null;
    _dragCenter.value = null;
    _pressureMotion.value = 0;
    _pressureTarget = 0;
    _clearPointerCapture();
    _resetSelectionDeformation();
    _resetReleaseRecovery(suppressUntilNextPress: true);
  }

  @override
  void didUpdateWidget(CustomFlutterGlassNavigationDockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemKeys();
    _selectionMotion.duration = widget.style.duration;
    _pressureMotion.duration = widget.style.duration;
    _selectionDeformationMotion.duration = widget.style.duration;
    _releaseRecoveryMotion.duration = widget.style.duration;
    _scrubCorrectionMotion.duration = widget.style.duration;
    _scrubVerticalScaleMotion.duration = widget.style.duration;
    if (oldWidget.style.selectionSpring != widget.style.selectionSpring ||
        oldWidget.style.duration != widget.style.duration) {
      _recoverScrubDeformation();
    }
    if (widget.style.resolvedScrubMotionStretch == 0 &&
        widget.style.resolvedScrubMotionFlattening == 0) {
      _resetScrubDeformation();
    }
    if (oldWidget.style.scrubVerticalScale != widget.style.scrubVerticalScale) {
      _animateScrubVerticalScale(_scrubbing);
    }
    if (oldWidget.style.releaseVerticalStretch !=
        widget.style.releaseVerticalStretch) {
      _resetReleaseRecovery(suppressUntilNextPress: true);
    }
    if (oldWidget.items.length != widget.items.length) {
      // A changed destination topology invalidates pointer coordinates.
      _scrubbing = false;
      _contactPreviewIndex.value = null;
      _resetScrubCorrection();
      _resetScrubVerticalScale();
      _resetScrubDeformation();
      _pointer = null;
      _pointerFeedback.value = false;
      _pressedIndex = null;
      _pointerDown = null;
      _lastRequestedIndex = null;
      _dragCenter.value = null;
      _layout = null;
      _selectionMotion.stop();
      _selectionSpring = null;
      _pressureMotion.stop();
      _pressureMotion.value = 0;
      _clearPointerCapture();
      _resetSelectionDeformation();
      _resetReleaseRecovery(suppressUntilNextPress: true);
    }
    final changesGrowingLensEligibility =
        (oldWidget.style.pressedScale > 1) != (widget.style.pressedScale > 1);
    if (_layout?.usesScroll == false &&
        (oldWidget.style.trackVerticalDrag != widget.style.trackVerticalDrag ||
            oldWidget.style.scrubSelectionPolicy !=
                widget.style.scrubSelectionPolicy ||
            (_pointer != null && changesGrowingLensEligibility))) {
      // Changing selection policy, recognizer types or growing-lens ancestry can
      // dispose an accepted drag without an end callback. Cancel independently
      // of preview presence: host acceptance may already have cleared it.
      // Settle before replacing that subtree, retaining raw ownership until
      // actual up/cancel and invalidating this down against late recognition.
      _pointerDown = null;
      _finishScrub(cancelled: true);
      _pressedIndex = null;
      _clearPointerCapture();
      _resetReleaseRecovery(suppressUntilNextPress: true);
      _press(false);
    }
    if (oldWidget.style.resolvedHeldBarScale !=
            widget.style.resolvedHeldBarScale &&
        _pointer != null) {
      // Adding/removing the optional transform can reparent the recognizer.
      // Resolve its owned contact before that change, as with a mode switch.
      _pointerDown = null;
      _finishScrub(cancelled: true);
      _pressedIndex = null;
      _clearPointerCapture();
      _resetReleaseRecovery(suppressUntilNextPress: true);
      _press(false);
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final continuesReleaseFeedback =
          _releasedSelectionPulse?.index == widget.selectedIndex;
      _releasedSelectionPulse = null;
      _contactPreviewIndex.value = null;
      final capturedOrigin = _clearPointerCapture();
      if (!_scrubbing) {
        // A host update cannot transfer a held press to an untouched tab.
        _press(_pointer != null && _pressedIndex == widget.selectedIndex);
        _animateToAcceptedSelection(from: capturedOrigin);
        if (!continuesReleaseFeedback) _pulseAcceptedSelection();
        _scheduleReveal(widget.selectedIndex);
      }
    } else if (!_scrubbing &&
        (oldWidget.style.selectionSpring != widget.style.selectionSpring ||
            (oldWidget.style.duration != widget.style.duration &&
                widget.style.duration == Duration.zero))) {
      final layout = _layout;
      final previewIndex = _contactPreviewIndex.value;
      final previewTarget =
          _pointer != null &&
              layout != null &&
              previewIndex != null &&
              widget.items[previewIndex].enabled &&
              _allowsContactPreview(layout) &&
              (_contactPreviewLayout?.sameGeometry(layout) ?? false)
          ? previewIndex
          : null;
      final capturedOrigin = _clearPointerCapture();
      _resetScrubCorrection();
      // A changed spring retargets the owned contact preview, not navigation.
      // Host changes above and invalid/zero-motion contacts retain host priority.
      _animateToAcceptedSelection(
        from: capturedOrigin,
        previewIndex: previewTarget,
      );
    }
    // Updating a controller's duration does not stop an active simulation.
    // This also applies during scrubbing, outside the settling branch above.
    if (widget.style.duration == Duration.zero) {
      _contactPreviewIndex.value = null;
      _resetScrubCorrection();
      _clearPointerCapture();
      _pressureMotion.stop();
      _pressureMotion.value = 0;
      _resetScrubVerticalScale();
      _resetScrubDeformation();
      _resetReleaseRecovery(suppressUntilNextPress: true);
    }
    // A host-accepted scrub may already have cleared its visual preview. The
    // geometric handoff still belongs only to the fitting, growing path.
    if (widget.style.pressedScale <= 1) _resetScrubCorrection();
    final previewIndex = _contactPreviewIndex.value;
    final pressedIndex = _pressedIndex;
    final invalidPreview =
        previewIndex != null &&
        (!widget.items[previewIndex].enabled || widget.style.pressedScale <= 1);
    final disabledPreviewOwner =
        pressedIndex != null &&
        _layout != null &&
        !_layout!.usesScroll &&
        oldWidget.style.pressedScale > 1 &&
        !widget.items[pressedIndex].enabled;
    if (invalidPreview || disabledPreviewOwner) {
      _contactPreviewIndex.value = null;
      _pressedIndex = null;
      final capturedOrigin = _clearPointerCapture();
      if (_scrubbing) {
        _finishScrub(cancelled: true);
      } else {
        _resetScrubCorrection();
        _animateToAcceptedSelection(
          from: capturedOrigin,
          initialVelocity: const <double>[0, 0, 0, 0],
        );
        _press(false);
      }
    }
    if (!widget.style.animateSelectionDeformation ||
        widget.style.duration == Duration.zero) {
      _resetSelectionDeformation();
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    _releasedScrubContact = null;
    _releasedSelectionPulse = null;
    _releasedHeldTap = null;
    _resetScrubCorrection();
    _selectionMotion.dispose();
    _pressureMotion.dispose();
    _selectionDeformationMotion.dispose();
    _releaseRecoveryMotion.dispose();
    _scrubCorrectionMotion.dispose();
    _scrubVerticalScaleMotion.dispose();
    _scrubDeformationMotion.dispose();
    _dragCenter.dispose();
    _pointerFeedback.dispose();
    _contactPreviewIndex.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncItemKeys() {
    while (_itemKeys.length < widget.items.length) {
      _itemKeys.add(GlobalKey());
    }
    if (_itemKeys.length > widget.items.length) {
      _itemKeys.removeRange(widget.items.length, _itemKeys.length);
    }
  }

  Rect _currentCapsule(_DockLayout layout) {
    if (_reduceMotion) return layout.rects[widget.selectedIndex];
    final center = _projectedDragCenter(layout);
    if (_scrubbing && center != null) {
      return layout.clampCapsule(_scrubCapsule(layout, center));
    }
    final captured = _capturedPointerProjection;
    final held = _heldSelection;
    final grabOffset = _pointerGrabOffset;
    if (captured != null && held != null && grabOffset != null) {
      return layout.clampCapsule(
        Rect.fromCenter(
          center: Offset(
            _projectPointerX(layout, captured.x, captured.scale) + grabOffset,
            held.center.dy,
          ),
          width: held.width,
          height: held.height,
        ),
      );
    }
    final spring = _selectionSpring;
    if (spring != null) {
      return layout.clampCapsule(spring.rectAt(_selectionMotion.value));
    }
    final from = _selectionFrom ?? layout.rects[widget.selectedIndex];
    final to = _selectionTo ?? layout.rects[widget.selectedIndex];
    if (from == to) return to;
    return Rect.lerp(
      from,
      to,
      widget.style.curve.transform(_selectionMotion.value),
    )!;
  }

  Rect _scrubCapsule(_DockLayout layout, double center) {
    final rect = layout.rectAtCenter(center);
    final correction = _scrubCorrection;
    if (correction == null || !_scrubCorrectionMotion.isAnimating) return rect;
    final spring = _scrubCorrectionSpring;
    final offset = spring?.rectAt(_scrubCorrectionMotion.value);
    final amount = _scrubCorrectionMotion.value;
    return Rect.fromLTRB(
      rect.left + (offset?.left ?? correction.left * amount),
      rect.top + (offset?.top ?? correction.top * amount),
      rect.right + (offset?.right ?? correction.right * amount),
      rect.bottom + (offset?.bottom ?? correction.bottom * amount),
    );
  }

  double? _projectedDragCenter(_DockLayout layout) {
    final center = _dragCenter.value;
    if (center == null) return null;
    return _projectPointerX(
          layout,
          center - _grabOffset,
          _scrubSampleBarScale,
        ) +
        _grabOffset;
  }

  double _projectPointerX(_DockLayout layout, double x, double sampledScale) {
    if (!_pointerUsesBarTransform || layout.usesScroll) return x;
    // The last move was projected through the then-painted bar transform.
    // Pressure may keep expanding that ancestor while the finger is still.
    // Reproject its sampled X for this frame rather than freezing local X and
    // letting a later zero-displacement move visibly repair the lens position.
    final midpoint = layout.totalWidth / 2;
    return midpoint + (x - midpoint) * sampledScale / _currentHeldBarScale;
  }

  bool _allowsContactPreview(_DockLayout layout) =>
      !layout.usesScroll &&
      widget.style.pressedScale > 1 &&
      !_reduceMotion &&
      widget.style.duration != Duration.zero;

  bool _commitsScrubOnRelease(_DockLayout layout) =>
      !layout.usesScroll &&
      widget.style.scrubSelectionPolicy ==
          AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane;

  void _resetScrubCorrection() {
    _scrubCorrectionMotion.stop();
    _scrubCorrection = null;
    _scrubCorrectionSpring = null;
  }

  double get _scrubVerticalScale =>
      _scrubVerticalScaleFrom +
      (_scrubVerticalScaleTo - _scrubVerticalScaleFrom) *
          _scrubVerticalScaleMotion.value;

  void _animateScrubVerticalScale(bool active) {
    if (_reduceMotion ||
        widget.style.duration == Duration.zero ||
        _layout?.usesScroll != false) {
      _resetScrubVerticalScale();
      return;
    }
    final target = active ? widget.style.resolvedScrubVerticalScale : 1.0;
    final current = _scrubVerticalScale;
    if (target == _scrubVerticalScaleTo &&
        (_scrubVerticalScaleMotion.isAnimating || current == target)) {
      return;
    }
    _scrubVerticalScaleFrom = current;
    _scrubVerticalScaleTo = target;
    _scrubVerticalScaleMotion.value = 0;
    _scrubVerticalScaleMotion.animateTo(
      1,
      duration: widget.style.duration,
      curve: widget.style.curve,
    );
  }

  void _resetScrubVerticalScale() {
    // Layout invalidation may call this during build. Reset scalar endpoints
    // without notifying the animation subtree while that build is in progress.
    _scrubVerticalScaleMotion.stop();
    _scrubVerticalScaleFrom = _scrubVerticalScaleTo = 1;
  }

  double get _scrubDeformation =>
      _scrubDeformationSpring != null &&
          !_reduceMotion &&
          widget.style.duration != Duration.zero &&
          _scrubDeformationMotion.isAnimating
      ? _scrubDeformationSpring!
            .amountAt(_scrubDeformationMotion.value)
            .clamp(0.0, 1.0)
      : 0;

  void _sampleScrubDeformation(PointerMoveEvent event, _DockLayout layout) {
    final previous = _scrubDeformationPointerX;
    _scrubDeformationPointerX = event.position.dx;
    if (previous == null ||
        _pointerDown == null ||
        (!_scrubbing && _pointerTrackedLens == null) ||
        layout.usesScroll ||
        _reduceMotion ||
        widget.style.duration == Duration.zero ||
        (widget.style.resolvedScrubMotionStretch == 0 &&
            widget.style.resolvedScrubMotionFlattening == 0)) {
      return;
    }
    // Sample world-space displacement so expansion of the ancestor bar cannot
    // excite deformation beneath a stationary finger. The lane bounds the
    // sample; dragging arbitrarily far outside cannot accumulate hidden energy.
    final position = _trackPosition(event.position, event.localPosition);
    final displacement = (event.position.dx - previous) / _currentHeldBarScale;
    final laneStart = -layout.horizontalContentInset;
    final laneEnd = layout.totalWidth + layout.horizontalContentInset;
    final distance =
        (position.dx.clamp(laneStart, laneEnd) -
                (position.dx - displacement).clamp(laneStart, laneEnd))
            .abs();
    final width = _currentCapsule(layout).width;
    if (!distance.isFinite || distance == 0 || !width.isFinite || width <= 0) {
      return;
    }
    _recoverScrubDeformation(distanceInWidths: distance / width);
  }

  void _recoverScrubDeformation({
    double distanceInWidths = 0,
    bool cancelled = false,
  }) {
    if (_reduceMotion ||
        widget.style.duration == Duration.zero ||
        _layout?.usesScroll != false) {
      _resetScrubDeformation();
      return;
    }
    final running =
        _scrubDeformationSpring != null && _scrubDeformationMotion.isAnimating;
    if (!running && distanceInWidths == 0) return;
    final time = running ? _scrubDeformationMotion.value : 0.0;
    final from = running ? _scrubDeformationSpring!.amountAt(time) : 0.0;
    final velocity = running && !cancelled
        ? _scrubDeformationSpring!.velocityAt(time)
        : 0.0;
    if (running) {
      // Keep the existing ticker's clock. Restarting animateWith on every move
      // would lose a frame of elapsed time at each input and can freeze a shape
      // when samples arrive every frame.
      _scrubDeformationSpring!.retarget(
        spring: widget.style.resolvedSelectionSpring,
        duration: widget.style.duration,
        from: from,
        velocity: velocity,
        distanceInWidths: distanceInWidths,
        time: time,
      );
      return;
    }
    final simulation = _ScrubDeformationRecovery(
      spring: widget.style.resolvedSelectionSpring,
      duration: widget.style.duration,
      from: from,
      velocity: velocity,
      distanceInWidths: distanceInWidths,
    );
    _scrubDeformationSpring = simulation;
    _scrubDeformationMotion.animateWith(simulation);
  }

  void _resetScrubDeformation() {
    // Geometry invalidation may run during build: clear the read guard without
    // notifying the animation subtree or leaving an old contact sample alive.
    _scrubDeformationMotion.stop();
    _scrubDeformationSpring = null;
    _scrubDeformationPointerX = null;
  }

  void _resolveContactPreview({bool cancelled = false}) {
    final hadPreview = _contactPreviewIndex.value != null;
    _contactPreviewIndex.value = null;
    _contactPreviewLayout = null;
    if (hadPreview && !_scrubbing && _heldSelection == null) {
      _animateToAcceptedSelection(
        initialVelocity: cancelled ? const <double>[0, 0, 0, 0] : null,
      );
    }
    _resumeHeldSelection();
  }

  _CapsulePaintGeometry _capsulePaintGeometry(_DockLayout layout, Rect rect) {
    final style = widget.style;
    final pressure = _reduceMotion || style.duration == Duration.zero
        ? 0.0
        : math.max(_pressureMotion.value, _selectionDeformation);
    final deformation = layout.usesScroll ? 0.0 : _scrubDeformation;
    final scaleX = _reduceMotion
        ? 1.0
        : style.selectionScale *
              (1 + style.pressureStretch * pressure) *
              (1 + style.resolvedScrubMotionStretch * deformation);
    final scaleY = _reduceMotion
        ? 1.0
        : style.selectionScale *
              (1 + (style.pressedScale - 1) * pressure + _releaseRecovery) *
              (layout.usesScroll || style.duration == Duration.zero
                  ? 1.0
                  : _scrubVerticalScale) *
              (1 - style.resolvedScrubMotionFlattening * deformation);
    final barScale = _currentHeldBarScale;
    final surfaceWidth = layout.totalWidth + layout.horizontalContentInset * 2;
    // The ancestor bar transform has already consumed part of the shell gutter.
    // Convert the remainder back into child-local units before allowing the
    // lens to use it; spending the original inset again can overflow wide ends.
    final remainingOuterInset = math.max(
      0.0,
      (layout.outerHorizontalInset - surfaceWidth * (barScale - 1) / 2) /
          barScale,
    );
    final sourceRect = layout.containHorizontalScale(
      rect,
      scaleX,
      extraMargin: !layout.usesScroll && style.pressedScale > 1
          ? remainingOuterInset * pressure
          : 0,
    );
    return _CapsulePaintGeometry(
      sourceRect: sourceRect,
      rect: _allowsContactPreview(layout)
          ? layout.feedbackRect(sourceRect, pressure)
          : sourceRect,
      scaleX: scaleX,
      scaleY: scaleY,
      pressure: pressure,
    );
  }

  double get _currentHeldBarScale =>
      1 + (_heldBarScaleLimit - 1) * _pressureMotion.value.clamp(0.0, 1.0);

  Rect? _clearPointerCapture() {
    // Callers that continue motion must use the projected held origin, not the
    // local rectangle sampled before the ancestor's pressure expansion.
    final layout = _layout;
    final held = _heldSelection != null && layout != null
        ? _currentCapsule(layout)
        : _heldSelection;
    _pointerGrabOffset = null;
    _pointerTrackedLens = null;
    _capturedPointerProjection = null;
    _heldSelection = null;
    _releasedBarProjection = null;
    _releasedScrubContact = null;
    _releasedSelectionPulse = null;
    _releasedHeldTap = null;
    return held;
  }

  void _resumeHeldSelection() {
    final held = _clearPointerCapture();
    if (held != null) {
      // Settling was paused for this contact. Resume toward the current host
      // selection without resurrecting momentum from before the contact.
      _animateToAcceptedSelection(
        from: held,
        initialVelocity: const <double>[0, 0, 0, 0],
      );
    }
  }

  void _animateToAcceptedSelection({
    Rect? from,
    List<double>? initialVelocity,
    int? previewIndex,
  }) {
    final layout = _layout;
    if (layout == null || widget.selectedIndex >= layout.rects.length) return;
    final target = layout.rects[previewIndex ?? widget.selectedIndex];
    final origin = from ?? _currentCapsule(layout);
    final currentSpring = _selectionSpring;
    final velocity =
        initialVelocity ??
        (from == null && _selectionMotion.isAnimating && currentSpring != null
            ? layout.clampCapsuleVelocity(
                currentSpring.rectAt(_selectionMotion.value),
                currentSpring.velocityAt(_selectionMotion.value),
              )
            : null);
    _selectionFrom = origin;
    _selectionTo = target;
    _selectionSpring = null;
    if (_reduceMotion || widget.style.duration == Duration.zero) {
      _selectionMotion.stop();
      _selectionFrom = target;
    } else if (widget.style.resolvedSelectionSpring case final spring?) {
      final simulation = _CapsuleSpringMotion(
        spring: spring,
        from: origin,
        to: target,
        velocity: velocity,
      );
      _selectionSpring = simulation;
      _selectionMotion.animateWith(simulation);
    } else {
      _selectionMotion.value = 0;
      _selectionMotion.animateTo(1, duration: widget.style.duration);
    }
  }

  void _press(bool pressed) {
    if (_reduceMotion || widget.style.duration == Duration.zero) {
      _pressureMotion.stop();
      _pressureMotion.value = 0;
      _pressureTarget = 0;
      return;
    }
    final target = pressed ? 1.0 : 0.0;
    // Raw contact and gesture recognition can request the same pressure phase.
    // Preserve its original timeline instead of extending expansion at drag
    // recognition or restarting release when both up/end are delivered.
    if (_pressureTarget == target &&
        (_pressureMotion.isAnimating || _pressureMotion.value == target)) {
      return;
    }
    _pressureTarget = target;
    _pressureMotion.animateTo(
      target,
      duration: widget.style.duration,
      curve: widget.style.curve,
    );
  }

  double get _selectionDeformation {
    if (_reduceMotion || !widget.style.animateSelectionDeformation) return 0;
    final progress = _selectionDeformationMotion.value;
    if (progress >= 1) return 0;
    // A smooth bounded hump. On interruption its starting amplitude is retained
    // rather than snapping an already deformed capsule back to resting shape.
    return _selectionDeformationFrom * (1 - progress) +
        (1 - _selectionDeformationFrom) * math.sin(math.pi * progress);
  }

  void _pulseAcceptedSelection() {
    if (_reduceMotion ||
        !widget.style.animateSelectionDeformation ||
        widget.style.duration == Duration.zero ||
        _layout == null) {
      return;
    }
    _selectionDeformationFrom = _selectionDeformation;
    _selectionDeformationMotion.forward(from: 0);
  }

  void _resetSelectionDeformation() {
    _selectionDeformationFrom = 0;
    _selectionDeformationMotion.stop();
    _selectionDeformationMotion.value = 1;
  }

  double get _releaseRecovery {
    if (_reduceMotion || widget.style.duration == Duration.zero) return 0;
    final progress = _releaseRecoveryMotion.value;
    if (progress >= 1 || _releaseRecoveryPressure == 0) return 0;
    return math.sin(math.pi * progress) *
        _releaseRecoveryPressure *
        widget.style.resolvedReleaseVerticalStretch;
  }

  void _startReleaseRecovery() {
    // Raw up and recognizer end can both finish one contact. Capture once,
    // before pressure starts decaying, without synthesizing another selection.
    if (_releaseRecoveryTriggered) return;
    _releaseRecoveryTriggered = true;
    final pressedIndex = _pressedIndex;
    final ownsSelectedPress =
        pressedIndex != null &&
        pressedIndex == widget.selectedIndex &&
        widget.items[pressedIndex].enabled;
    // Residual pressure must not transfer recovery from an unrelated contact.
    // A local held preview is an eligible owner without accepting navigation.
    if (!_scrubbing &&
        !ownsSelectedPress &&
        _contactPreviewIndex.value == null) {
      return;
    }
    if (_reduceMotion ||
        widget.style.duration == Duration.zero ||
        widget.style.resolvedReleaseVerticalStretch == 0) {
      return;
    }
    _releaseRecoveryPressure = math
        .max(_pressureMotion.value, _selectionDeformation)
        .clamp(0.0, 1.0);
    if (_releaseRecoveryPressure > 0) {
      _releaseRecoveryMotion.forward(from: 0);
    }
  }

  void _resetReleaseRecovery({bool suppressUntilNextPress = false}) {
    // Do not notify an animation subtree while accepting a layout during build.
    // Invalidated contacts stay suppressed even if their raw up arrives later.
    _releaseRecoveryMotion.stop();
    _releaseRecoveryPressure = 0;
    _releaseRecoveryTriggered = suppressUntilNextPress;
  }

  void _onPointerDown(PointerDownEvent event) {
    // Raw feedback must admit the same buttons as the SDK drag recognizers.
    if (!mounted || _pointer != null || event.buttons != kPrimaryButton) return;
    final layout = _layout;
    _pointerUsesBarTransform =
        widget.style.resolvedHeldBarScale > 1 && layout?.usesScroll == false;
    _pointerDownBarScale = _paintedHeldBarScale;
    final position = _trackPosition(event.position, event.localPosition);
    final index = layout?.indexAt(position.dx);
    final pressedIndex = index != null && widget.items[index].enabled
        ? index
        : null;
    var hitsLens = false;
    _clearPointerCapture();
    if (layout != null &&
        !layout.usesScroll &&
        pressedIndex != null &&
        !_reduceMotion &&
        widget.style.duration != Duration.zero) {
      // Sample the already painted lens before this contact changes pressure
      // or recovery. Recognition may occur after a settling spring has moved.
      // Its painted hit can cross another enabled logical slot while settling;
      // capture that lens without changing the slot's tap or press ownership.
      final capsule = _currentCapsule(layout);
      final paint = _capsulePaintGeometry(layout, capsule);
      hitsLens = paint.contains(position, widget.style.radius);
      _pointerGrabOffset = hitsLens ? paint.rect.center.dx - position.dx : 0;
      if (hitsLens && _selectionMotion.isAnimating) {
        _selectionMotion.stop();
        _selectionSpring = null;
        _selectionFrom = _selectionTo = capsule;
        _heldSelection = capsule;
      }
      if (hitsLens &&
          widget.style.trackVerticalDrag &&
          _allowsContactPreview(layout)) {
        // Preserve the actual contained size as well as the captured offset.
        // Subsequent raw moves use the scrub lane's center bounds, so winning
        // recognition does not add another catch-up for travelled touch slop.
        _pointerTrackedLens = paint.sourceRect;
        _heldSelection = paint.sourceRect;
        _selectionMotion.stop();
        _selectionSpring = null;
        _selectionFrom = _selectionTo = paint.sourceRect;
      }
    }
    _resetReleaseRecovery();
    _pointer = event.pointer;
    _pointerDownTime = event.timeStamp;
    _pointerFeedback.value = true;
    _pointerDown = position;
    _scrubDeformationPointerX = event.position.dx;
    _pressedIndex = pressedIndex;
    if (layout != null &&
        pressedIndex != null &&
        _allowsContactPreview(layout)) {
      // A held contact can preview another destination without navigating.
      // Catching the painted moving lens retains its captured geometry.
      _contactPreviewLayout = layout;
      _contactPreviewIndex.value = pressedIndex;
      if (!hitsLens) _animateToAcceptedSelection(previewIndex: pressedIndex);
    }
    _press(
      _contactPreviewIndex.value != null ||
          _pressedIndex == widget.selectedIndex,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final layout = _layout;
    if (mounted && _pointer == event.pointer && layout != null) {
      _sampleScrubDeformation(event, layout);
    }
    final lens = _pointerTrackedLens;
    final offset = _pointerGrabOffset;
    if (!mounted ||
        _pointer != event.pointer ||
        _scrubbing ||
        _pointerDown == null ||
        layout == null ||
        lens == null ||
        offset == null ||
        !widget.style.trackVerticalDrag ||
        !_allowsContactPreview(layout)) {
      return;
    }
    final position = _trackPosition(event.position, event.localPosition);
    _capturedPointerProjection = (x: position.dx, scale: _paintedHeldBarScale);
    // A caught settling lens can lie beyond a destination center while its
    // current size still fits the lane. Keep that captured position continuous;
    // rectAtCenter's narrower endpoint clamp would snap it on the first move.
    final center = position.dx + offset;
    _heldSelection = layout.clampCapsule(
      Rect.fromCenter(
        center: Offset(center, lens.center.dy),
        width: lens.width,
        height: lens.height,
      ),
    );
    _selectionFrom = _selectionTo = _heldSelection;
    // Notify only the existing animated paint subtree; this is a direct sample,
    // not an animation, and destination callbacks/semantics remain untouched.
    _selectionMotion.value = 0;
  }

  Offset _trackPosition(Offset globalPosition, Offset fallback) {
    if (!_pointerUsesBarTransform && _heldBarScaleLimit == 1) return fallback;
    // Pointer moves reuse their down-time hit-test transform. Resolve against
    // the current bar instead, including pressure changes since that down.
    final renderObject = _trackKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return fallback;
    final position = renderObject.globalToLocal(globalPosition);
    return position.dx.isFinite && position.dy.isFinite ? position : fallback;
  }

  ({double scale, double rate, double relativeX}) _barProjectionAt(
    Offset position,
  ) {
    final rate = (_heldBarScaleLimit - 1) * _pressureMotion.velocity;
    return (
      scale: _currentHeldBarScale,
      rate: rate.isFinite ? rate : 0,
      relativeX: position.dx - (_layout?.totalWidth ?? 0) / 2,
    );
  }

  double _trackHorizontalVelocity(
    double velocity,
    Offset position, {
    bool released = false,
  }) {
    if (!velocity.isFinite) return 0;
    if (!_pointerUsesBarTransform) return velocity;
    if (_reduceMotion || widget.style.duration == Duration.zero) return 0;
    final projection = released
        ? _releasedBarProjection ?? _barProjectionAt(position)
        : _barProjectionAt(position);
    if (!projection.scale.isFinite ||
        projection.scale <= 0 ||
        !projection.relativeX.isFinite ||
        !_pointerDownBarScale.isFinite ||
        _pointerDownBarScale <= 0) {
      return 0;
    }
    // SDK tracking remains in the down-time transform's coordinate basis.
    // Differentiating the current inverse scale also moves off-center local
    // coordinates by -relativeX * scaleRate / scale. Controller.velocity uses
    // the SDK timed simulation's finite-difference estimate, not an exact curve
    // derivative. This does not compensate the bar's release-direction change
    // or claim full world-space C1 continuity. Keep one SDK sample history.
    final speed =
        (velocity * _pointerDownBarScale -
            projection.relativeX * projection.rate) /
        projection.scale;
    return speed.isFinite ? speed : 0;
  }

  void _onPointerReleased(PointerEvent event, {bool cancelled = false}) {
    if (!mounted || _pointer != event.pointer) return;
    // Raw up precedes recognizer end. Sample the incoming pressure phase before
    // _press(false) replaces it; preserve this owner snapshot through cleanup.
    final incomingProjection =
        !cancelled && _scrubbing && _pointerUsesBarTransform
        ? _barProjectionAt(_trackPosition(event.position, event.localPosition))
        : null;
    final layout = _layout;
    final downTime = _pointerDownTime;
    final heldTapIndex =
        !cancelled &&
            !_scrubbing &&
            _pointerDown != null &&
            downTime != null &&
            event.timeStamp - downTime >= widget.style.duration &&
            layout != null &&
            _allowsContactPreview(layout) &&
            !_pressureMotion.isAnimating &&
            _pressureMotion.value == 1 &&
            _contactPreviewIndex.value == _pressedIndex
        ? _pressedIndex
        : null;
    final position =
        !cancelled &&
            _scrubbing &&
            layout != null &&
            _commitsScrubOnRelease(layout)
        ? _trackPosition(event.position, event.localPosition)
        : null;
    final releasedContact = position == null || layout == null
        ? null
        : (
            layout: layout,
            x: position.dx,
            adjustedX: position.dx + _grabOffset,
          );
    if (cancelled) {
      _recoverScrubDeformation(cancelled: true);
      _resetReleaseRecovery(suppressUntilNextPress: true);
    } else {
      _startReleaseRecovery();
    }
    _pointer = null;
    _pointerDownTime = null;
    _scrubDeformationPointerX = null;
    _pointerFeedback.value = false;
    _pressedIndex = null;
    _pointerDown = null;
    _press(false);
    _resolveContactPreview(cancelled: cancelled);
    _releasedBarProjection = incomingProjection;
    _releasedScrubContact = releasedContact;
    if (heldTapIndex != null && layout != null) {
      final token = Object();
      _releasedHeldTap = (index: heldTapIndex, layout: layout, token: token);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_releasedHeldTap?.token, token)) {
          _releasedHeldTap = null;
        }
      });
    }
  }

  void _qualifyHeldTapRelease(int index) {
    final release = _releasedHeldTap;
    _releasedHeldTap = null;
    final layout = _layout;
    if (release != null &&
        release.index == index &&
        layout != null &&
        release.layout.sameGeometry(layout)) {
      _continueReleasedSelectionFeedback(index);
    }
  }

  void _continueReleasedSelectionFeedback(int index) {
    if (_reduceMotion ||
        widget.style.duration == Duration.zero ||
        !widget.style.animateSelectionDeformation) {
      return;
    }
    final token = Object();
    _releasedSelectionPulse = (index: index, token: token);
    // Register expiry before external code. Rejection, delayed acceptance or a
    // different host destination must not suppress a later selection pulse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_releasedSelectionPulse?.token, token)) {
        _releasedSelectionPulse = null;
      }
    });
  }

  void _onPointerCancelled(PointerCancelEvent event) {
    if (!mounted || _pointer != event.pointer) return;
    _onPointerReleased(event, cancelled: true);
    if (!TickerMode.valuesOf(context).enabled) {
      // An animation first started while muted may not get its first timestamp
      // until return. Resolve actual cancellation now, so that return cannot
      // resurrect the covered contact's geometry or feedback. This is a muted
      // cancellation rule, not route visibility ownership in the direct widget.
      _snapToHostSelection();
      return;
    }
    // An accepted long press does not emit its recognizer's cancellation
    // callback. The raw pointer boundary also settles that active scrub.
    _finishScrub(cancelled: true);
  }

  void _beginScrub(Offset position, {double horizontalVelocity = 0}) {
    final layout = _layout;
    final start = _pointerDown;
    // A pending recognizer may win after reflow invalidated its coordinate
    // space. Only a live, still-valid raw down may start a new scrub.
    if (layout == null || _pointer == null || start == null) return;
    final initialIndex = layout.indexAt(start.dx);
    if (initialIndex == null || !widget.items[initialIndex].enabled) return;
    final alreadyTracksPointer = _pointerTrackedLens != null;
    final selected = _currentCapsule(layout);
    final settling = _selectionSpring;
    final sourceVelocity = _selectionMotion.isAnimating && settling != null
        ? layout.clampCapsuleVelocity(
            settling.rectAt(_selectionMotion.value),
            settling.velocityAt(_selectionMotion.value),
          )
        : const <double>[0, 0, 0, 0];
    _grabOffset =
        _pointerGrabOffset ??
        (selected.contains(start) ? selected.center.dx - start.dx : 0);
    _clearPointerCapture();
    _selectionMotion.stop();
    _resetScrubCorrection();
    _scrubbing = true;
    _animateScrubVerticalScale(true);
    if (_allowsContactPreview(layout)) {
      final preview = layout.rectAtCenter(position.dx + _grabOffset);
      // Carry the current center AND size into direct pointer following. Only
      // the geometric difference decays; pointer updates themselves stay direct.
      _scrubCorrection = Rect.fromLTRB(
        selected.left - preview.left,
        selected.top - preview.top,
        selected.right - preview.right,
        selected.bottom - preview.bottom,
      );
      final extent = <double>[
        _scrubCorrection!.left.abs(),
        _scrubCorrection!.top.abs(),
        _scrubCorrection!.right.abs(),
        _scrubCorrection!.bottom.abs(),
      ].reduce(math.max);
      final spring = widget.style.resolvedSelectionSpring;
      if (spring != null) {
        final pointerVelocity = layout.scrubReleaseVelocity(
          position.dx + _grabOffset,
          horizontalVelocity,
        );
        final correctionVelocity = <double>[
          for (var axis = 0; axis < sourceVelocity.length; axis++)
            // Raw captured-pan moves already carry horizontal finger motion.
            // Cancelling it here would reintroduce the recognition catch-up.
            alreadyTracksPointer && axis == 0
                ? 0
                : sourceVelocity[axis] - pointerVelocity[axis],
        ].map((speed) => speed.isFinite ? speed : 0.0).toList();
        if (extent > 0 || correctionVelocity.any((speed) => speed != 0)) {
          // Independent axes carry the moving preview's velocity into pointer
          // following, including a zero-displacement but moving handoff.
          // Default painted regrabs were frozen at down; opted-in pan captures
          // already follow X directly, while their size/Y handoff stays smooth.
          final simulation = _CapsuleSpringMotion(
            spring: spring,
            from: _scrubCorrection!,
            to: Rect.zero,
            velocity: correctionVelocity,
          );
          _scrubCorrectionSpring = simulation;
          _scrubCorrectionMotion.animateWith(simulation);
        }
      } else if (extent > 0) {
        // Arbitrary timed curves have no derivative API. Retain their existing
        // position-continuous handoff rather than inventing spring parameters.
        _scrubCorrectionMotion.value = 1;
        _scrubCorrectionMotion.animateTo(
          0,
          duration: widget.style.duration,
          curve: widget.style.curve,
        );
      }
    }
    _lastRequestedIndex = widget.selectedIndex;
    _press(true);
    _updateScrub(position);
  }

  void _updateScrub(Offset position) {
    final layout = _layout;
    if (!_scrubbing || layout == null) return;
    final center = position.dx + _grabOffset;
    _scrubSampleBarScale = _paintedHeldBarScale;
    _dragCenter.value = center;
    final index = layout.indexAt(center);
    if (index == null || !widget.items[index].enabled) return;
    if (_allowsContactPreview(layout)) {
      _contactPreviewLayout = layout;
      _contactPreviewIndex.value = index;
    }
    if (_commitsScrubOnRelease(layout)) return;
    if (_lastRequestedIndex == index) return;
    _lastRequestedIndex = index;
    widget.onItemSelected(index);
  }

  void _configureScrubRecognizer(
    DragGestureRecognizer recognizer,
    double Function() ownerHorizontalVelocity,
    DeviceGestureSettings? gestureSettings,
  ) {
    recognizer
      ..gestureSettings = gestureSettings
      // Carry measured geometric momentum, including slow releases. Keep
      // recognition slop and maximum velocity at the SDK's device defaults.
      ..minFlingVelocity = 0
      ..minFlingDistance = 0
      ..dragStartBehavior = DragStartBehavior.start
      ..onStart = (details) {
        final position = _trackPosition(
          details.globalPosition,
          details.localPosition,
        );
        _beginScrub(
          position,
          horizontalVelocity: _trackHorizontalVelocity(
            ownerHorizontalVelocity(),
            position,
          ),
        );
      }
      ..onUpdate = (details) {
        _updateScrub(
          _trackPosition(details.globalPosition, details.localPosition),
        );
      }
      ..onEnd = (details) {
        _finishScrub(
          horizontalVelocity: _trackHorizontalVelocity(
            details.velocity.pixelsPerSecond.dx,
            _trackPosition(details.globalPosition, details.localPosition),
            released: true,
          ),
        );
      }
      ..onCancel = () => _finishScrub(cancelled: true);
  }

  void _finishScrub({double horizontalVelocity = 0, bool cancelled = false}) {
    if (cancelled) _recoverScrubDeformation(cancelled: true);
    _animateScrubVerticalScale(false);
    final releasedContact = _releasedScrubContact;
    _releasedScrubContact = null;
    _releasedBarProjection = null;
    if (!_scrubbing) {
      if (cancelled && _pointer != null) {
        // A rejected recognizer can cancel before a scrub starts. Release its
        // press feedback, but retain raw ownership until that contact ends.
        // A late cancel after raw up must preserve legitimate release recovery.
        _pressedIndex = null;
        _resetReleaseRecovery(suppressUntilNextPress: true);
        _press(false);
        _resolveContactPreview(cancelled: true);
      }
      return;
    }
    final layout = _layout;
    int? commitIndex;
    if (!cancelled && layout != null && _commitsScrubOnRelease(layout)) {
      // Use raw owner-UP X within the visible bar (track plus content insets),
      // never a clamped lens, exterior growth/shadow or remembered enabled slot.
      // SDK end's last move can precede the actual release.
      final insideLane =
          releasedContact != null &&
          releasedContact.layout.sameGeometry(layout) &&
          releasedContact.x.isFinite &&
          releasedContact.adjustedX.isFinite &&
          releasedContact.x >= -layout.horizontalContentInset &&
          releasedContact.x <=
              layout.totalWidth + layout.horizontalContentInset;
      if (!insideLane) {
        cancelled = true;
      } else {
        final index = layout.indexAt(releasedContact.adjustedX);
        if (index != null &&
            widget.items[index].enabled &&
            index != widget.selectedIndex) {
          commitIndex = index;
        }
      }
    }
    if (cancelled) {
      _releasedSelectionPulse = null;
      _resetReleaseRecovery(suppressUntilNextPress: true);
    } else {
      _startReleaseRecovery();
    }
    final from = layout == null ? null : _currentCapsule(layout);
    // Preserve the preview's geometric velocity, not a fling destination.
    // Cancellation retains the default zero velocity and the host still owns
    // the destination to which the local spring settles.
    var velocity = layout == null || from == null
        ? null
        : layout.scrubReleaseVelocity(
            _projectedDragCenter(layout) ?? from.center.dx,
            cancelled ? 0 : horizontalVelocity,
          );
    final correction = _scrubCorrection;
    if (!cancelled &&
        velocity != null &&
        layout != null &&
        correction != null &&
        _scrubCorrectionMotion.isAnimating) {
      final speed = _scrubCorrectionMotion.velocity;
      final correctionVelocity =
          _scrubCorrectionSpring?.velocityAt(_scrubCorrectionMotion.value) ??
          <double>[
            correction.center.dx * speed,
            correction.center.dy * speed,
            correction.width * speed,
            correction.height * speed,
          ];
      velocity = <double>[
        for (var axis = 0; axis < velocity.length; axis++)
          velocity[axis] + correctionVelocity[axis],
      ];
      velocity = layout
          .clampCapsuleVelocity(
            _scrubCapsule(
              layout,
              _projectedDragCenter(layout) ?? from!.center.dx,
            ),
            velocity,
          )
          .map((speed) => speed.isFinite ? speed : 0.0)
          .toList();
    }
    _scrubbing = false;
    _contactPreviewIndex.value = null;
    _resetScrubCorrection();
    _lastRequestedIndex = null;
    _animateToAcceptedSelection(from: from, initialVelocity: velocity);
    _dragCenter.value = null;
    _press(false);
    _scheduleReveal(widget.selectedIndex);
    if (commitIndex != null) _continueReleasedSelectionFeedback(commitIndex);
    // No component work follows external code: it may reject, rebuild, change
    // policy/topology or dispose this dock. Repeated SDK end/cancel cannot commit.
    if (commitIndex != null) widget.onItemSelected(commitIndex);
  }

  void _scheduleReveal(int index) {
    _pendingRevealIndex = index;
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      final targetIndex = _pendingRevealIndex;
      _pendingRevealIndex = null;
      if (!mounted || targetIndex == null || targetIndex >= _itemKeys.length) {
        return;
      }
      _reveal(targetIndex);
    });
  }

  void _reveal(int index) {
    if (_scrubbing ||
        _layout?.usesScroll != true ||
        !_scrollController.hasClients) {
      return;
    }
    final target = _itemKeys[index].currentContext?.findRenderObject();
    final viewport = _scrollController.position.context.storageContext
        .findRenderObject();
    if (target is! RenderBox ||
        viewport is! RenderBox ||
        !target.attached ||
        !viewport.attached) {
      return;
    }
    final rect = MatrixUtils.transformRect(
      target.getTransformTo(viewport),
      target.paintBounds,
    );
    final leading = rect.left < 0;
    final trailing = rect.right > viewport.size.width;
    if (!leading && !trailing) return;
    final rtl = _scrollController.position.axisDirection == AxisDirection.left;
    final alignment = rtl ? (trailing ? 0.0 : 1.0) : (leading ? 0.0 : 1.0);
    _scrollController.position.ensureVisible(
      target,
      alignment: alignment,
      duration: _reduceMotion ? Duration.zero : widget.style.duration,
      curve: widget.style.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final defaultTextStyle = DefaultTextStyle.of(context);
    final textHeightBehavior =
        defaultTextStyle.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final inheritedLabelStyle = defaultTextStyle.style.merge(style.labelStyle);
    // Text resolves accessibility weight and spacing before shaping. Apply the
    // same absolute overrides to measurement, including explicit zero spacing.
    final weightedLabelStyle = (MediaQuery.maybeBoldTextOf(context) ?? false)
        ? inheritedLabelStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          )
        : inheritedLabelStyle;
    final labelStyle = weightedLabelStyle.merge(
      TextStyle(
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
        wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumTarget = math.max(
          AppGlassNavigationStyle.minimumTouchTarget,
          style.minTargetSize,
        );
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ??
                  minimumTarget * widget.items.length +
                      style.horizontalInset * 2;
        final horizontalInset = math.min(
          style.horizontalInset,
          math.max(0.0, (availableWidth - minimumTarget) / 2),
        );
        final surfaceWidth = math.max(
          0.0,
          availableWidth - horizontalInset * 2,
        );
        final contentInset = math.min(
          style.contentInset,
          math.max(0.0, (surfaceWidth - minimumTarget) / 2),
        );
        final horizontalContentInset = math.min(
          style.resolvedHorizontalContentInset,
          math.max(0.0, (surfaceWidth - minimumTarget) / 2),
        );
        final viewportWidth = math.max(
          0.0,
          surfaceWidth - horizontalContentInset * 2,
        );
        final measured = _measureLabels(
          labelStyle,
          textScaler,
          direction,
          locale,
          textHeightBehavior,
        );
        final minimumWidths = <double>[
          for (final size in measured)
            math.max(
              minimumTarget,
              math.max(style.iconArea, size.width + style.labelPadding * 2),
            ),
        ];
        final minimumWidth = minimumWidths.fold(
          0.0,
          (sum, value) => sum + value,
        );
        final largeText =
            !widget.iconOnly && textScaler.scale(1) >= style.largeTextScale;
        final equalWidth = viewportWidth / widget.items.length;
        final contentBalanced =
            style.itemSizing == AppGlassNavigationItemSizing.contentBalanced;
        final usesScroll =
            largeText ||
            minimumWidth > viewportWidth ||
            (!contentBalanced &&
                minimumWidths.any((width) => width > equalWidth));
        // Keep sharing stable across the entire contact, including rest, so
        // pointer-down never switches the material's sampling source abruptly.
        final sceneBackdropKey =
            !usesScroll &&
                style.pressedScale > 1 &&
                style.refractionStrength > 0 &&
                style.blurSigma > 0 &&
                !highContrast
            ? _sceneBackdropKey
            : null;
        // Only calculate spare space after proving that all measured minima
        // fit. Keep real slot widths shared by paint, input and lens geometry.
        final spareWidth = !usesScroll && contentBalanced
            ? (viewportWidth - minimumWidth) / widget.items.length
            : 0.0;
        final widths = <double>[
          for (final width in minimumWidths)
            usesScroll
                ? math.max(width, equalWidth)
                : contentBalanced
                ? width + spareWidth
                : equalWidth,
        ];
        final maxLabelHeight = measured.fold(
          0.0,
          (height, size) => math.max(height, size.height),
        );
        final actionHeight = math.max(
          math.max(style.actionHeight, minimumTarget),
          widget.iconOnly
              ? style.iconArea
              : style.iconArea + style.labelGap + maxLabelHeight,
        );
        final surfaceHeight = actionHeight + contentInset * 2;
        final requestedBarScale = style.resolvedHeldBarScale;
        _heldBarScaleLimit = 1;
        if (!usesScroll &&
            style.pressedScale > 1 &&
            !_reduceMotion &&
            style.duration != Duration.zero &&
            !highContrast &&
            surfaceWidth.isFinite &&
            surfaceWidth > 0 &&
            surfaceHeight.isFinite &&
            surfaceHeight > 0) {
          // Centered growth must fit both sides of every existing exterior
          // inset. This is paint-only: row/lane layout and shell reserve stay put.
          final limit = math.min(
            requestedBarScale,
            math.min(
              1 + horizontalInset * 2 / surfaceWidth,
              1 +
                  math.min(style.topInset, style.bottomInset) *
                      2 /
                      surfaceHeight,
            ),
          );
          if (limit.isFinite && limit >= 1) _heldBarScaleLimit = limit;
        }
        final layout = _DockLayout(
          widths: widths,
          viewportWidth: viewportWidth,
          actionHeight: actionHeight,
          direction: direction,
          usesScroll: usesScroll,
          horizontalContentInset: horizontalContentInset,
          outerHorizontalInset: horizontalInset,
          style: style,
        );
        _acceptLayout(layout);
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < widget.items.length; index++)
              SizedBox(
                key: _itemKeys[index],
                width: widths[index],
                child: ValueListenableBuilder<int?>(
                  valueListenable: _contactPreviewIndex,
                  builder: (context, previewIndex, child) =>
                      _GlassDockDestination(
                        item: widget.items[index],
                        selected: index == widget.selectedIndex,
                        visuallySelected:
                            index ==
                            (((_contactPreviewLayout?.sameGeometry(layout) ??
                                        false)
                                    ? previewIndex
                                    : null) ??
                                widget.selectedIndex),
                        pointerFeedback: _pointerFeedback,
                        style: style,
                        labelStyle: labelStyle,
                        textHeightBehavior: textHeightBehavior,
                        iconOnly: widget.iconOnly,
                        onTap: widget.items[index].enabled
                            ? () => widget.onItemSelected(index)
                            : null,
                        onPointerTapUp: widget.items[index].enabled
                            ? () => _qualifyHeldTapRelease(index)
                            : null,
                        onFocus: () => _scheduleReveal(index),
                      ),
                ),
              ),
          ],
        );
        final track = SizedBox(
          width: layout.totalWidth,
          height: actionHeight,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            // Destinations expose their own buttons. Synthetic whole-track
            // scroll/long-press semantics cannot identify a destination.
            excludeFromSemantics: true,
            gestures: {
              if (usesScroll)
                _DockLongPressRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _DockLongPressRecognizer
                    >(
                      () => _DockLongPressRecognizer(
                        isOwner: (pointer) => pointer == _pointer,
                        debugOwner: this,
                      ),
                      (recognizer) => recognizer
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                          context,
                        )
                        ..onLongPressStart = (details) {
                          _beginScrub(details.localPosition);
                        }
                        ..onLongPressMoveUpdate = (details) {
                          _updateScrub(details.localPosition);
                        }
                        ..onLongPressEnd = (details) {
                          _finishScrub(
                            horizontalVelocity:
                                details.velocity.pixelsPerSecond.dx,
                          );
                        }
                        ..onLongPressCancel = () {
                          _finishScrub(cancelled: true);
                        },
                    )
              else if (style.trackVerticalDrag)
                _DockPanDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _DockPanDragRecognizer
                    >(
                      () => _DockPanDragRecognizer(
                        isOwner: (pointer) => pointer == _pointer,
                        debugOwner: this,
                      ),
                      (recognizer) => _configureScrubRecognizer(
                        recognizer,
                        () => recognizer.ownerHorizontalVelocity,
                        MediaQuery.maybeGestureSettingsOf(context),
                      ),
                    )
              else
                _DockHorizontalDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _DockHorizontalDragRecognizer
                    >(
                      () => _DockHorizontalDragRecognizer(
                        isOwner: (pointer) => pointer == _pointer,
                        debugOwner: this,
                      ),
                      (recognizer) => _configureScrubRecognizer(
                        recognizer,
                        () => recognizer.ownerHorizontalVelocity,
                        MediaQuery.maybeGestureSettingsOf(context),
                      ),
                    ),
              if (!usesScroll && !style.trackVerticalDrag)
                _DockVerticalDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _DockVerticalDragRecognizer
                    >(
                      () => _DockVerticalDragRecognizer(
                        isOwner: (pointer) => pointer == _pointer,
                        debugOwner: this,
                      ),
                      (recognizer) => recognizer
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                          context,
                        )
                        // Give vertical escape its own arena participant so
                        // horizontal scrubbing cannot win by default when the
                        // destination tap rejects a vertically moving touch.
                        ..onStart = (_) => _finishScrub(cancelled: true),
                    ),
            },
            child: Listener(
              key: _trackKey,
              // Hit-test delivery is child-first: establish raw ownership before
              // the enclosing recognizer considers this pointer's admission.
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerReleased,
              onPointerCancel: _onPointerCancelled,
              child: AnimatedBuilder(
                animation: _motion,
                child: row,
                builder: (context, child) {
                  final paint = _capsulePaintGeometry(
                    layout,
                    _currentCapsule(layout),
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GlassLensPosition(
                        rect: paint.rect,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Transform.scale(
                              scaleX: paint.scaleX,
                              scaleY: paint.scaleY,
                              child: _GlassSelectionSurface(
                                style: style,
                                highContrast: highContrast,
                                pressure: paint.pressure,
                                backdropKey: sceneBackdropKey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (sceneBackdropKey != null &&
                          !highContrast &&
                          (style.resolvedHeldInnerShadow != null ||
                              style.resolvedHeldInnerHighlight != null) &&
                          paint.pressure > 0)
                        _GlassLensPosition(
                          rect: paint.rect,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Transform.scale(
                                scaleX: paint.scaleX,
                                scaleY: paint.scaleY,
                                // Inset material belongs below artwork and
                                // captions, even when a scrub flattens the lens.
                                child: CustomPaint(
                                  painter: _GlassHeldEdgePainter(
                                    gradient: null,
                                    innerShadow: style.resolvedHeldInnerShadow,
                                    innerHighlight:
                                        style.resolvedHeldInnerHighlight,
                                    innerHighlightGradient:
                                        style.heldInnerHighlightGradient,
                                    pressure: paint.pressure,
                                    radius: style.radius,
                                    strokeWidth: style.outlineWidth,
                                    textDirection: direction,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: usesScroll && style.selectionHorizontalOutset > 0
                            ? ClipRect(
                                clipper: _ForegroundViewportClipper(
                                  controller: _scrollController,
                                  viewportWidth: viewportWidth,
                                  direction: direction,
                                ),
                                child: child!,
                              )
                            : child!,
                      ),
                      if (style.refractForegroundDuringInteraction)
                        _GlassLensPosition(
                          rect: paint.rect,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Transform.scale(
                                scaleX: paint.scaleX,
                                scaleY: paint.scaleY,
                                // Sample the already painted row, not a second
                                // widget copy. At rest this transparent pass has
                                // no filter; input/focus/semantics stay unchanged.
                                child: CustomGlassBackdropWidget(
                                  key: const ValueKey('glass_foreground_lens'),
                                  radius: style.radius,
                                  blurSigma: 0,
                                  refractionStrength: style.refractionStrength,
                                  refractionEdge:
                                      style.resolvedForegroundRefractionEdge,
                                  magnification:
                                      style.resolvedForegroundMagnification,
                                  dispersion:
                                      style.resolvedForegroundDispersion,
                                  opticsProgress: paint.pressure,
                                  prepareWhenInactive: true,
                                  highContrast: highContrast,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (sceneBackdropKey != null &&
                          !highContrast &&
                          style.heldRimGradient != null &&
                          paint.pressure > 0)
                        _GlassLensPosition(
                          rect: paint.rect,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Transform.scale(
                                scaleX: paint.scaleX,
                                scaleY: paint.scaleY,
                                // The rim belongs on the final optical edge,
                                // not in the foreground filter's scene input.
                                child: CustomPaint(
                                  painter: _GlassHeldEdgePainter(
                                    gradient: style.heldRimGradient,
                                    innerShadow: null,
                                    innerHighlight: null,
                                    innerHighlightGradient: null,
                                    pressure: paint.pressure,
                                    radius: style.radius,
                                    strokeWidth: style.outlineWidth,
                                    textDirection: direction,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        final viewport = SizedBox(
          width: viewportWidth,
          height: actionHeight,
          child: usesScroll
              ? SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  // The outer pill still clips painting. Let an opted-in lens
                  // use its gutter instead of clipping it at the target viewport.
                  clipBehavior: style.selectionHorizontalOutset > 0
                      ? Clip.none
                      : Clip.hardEdge,
                  child: track,
                )
              : track,
        );
        final dockSurface = _GlassDockSurface(
          style: style,
          highContrast: highContrast,
          pressure: _pressureMotion,
          animateHeldTint:
              !usesScroll &&
              style.pressedScale > 1 &&
              !_reduceMotion &&
              style.duration != Duration.zero &&
              !highContrast,
          contentInset: contentInset,
          horizontalContentInset: horizontalContentInset,
          clipContent: usesScroll || style.pressedScale <= 1,
          backdropKey: sceneBackdropKey,
          child: viewport,
        );
        Widget heldSurface = dockSurface;
        if (requestedBarScale > 1 && !usesScroll) {
          heldSurface = AnimatedBuilder(
            animation: _pressureMotion,
            // Keep material, row, recognizer and backdrop identity stable while
            // only their common ancestor transform changes with actual contact.
            child: dockSurface,
            builder: (context, child) {
              _paintedHeldBarScale = _currentHeldBarScale;
              return Transform.scale(scale: _paintedHeldBarScale, child: child);
            },
          );
        } else {
          _paintedHeldBarScale = 1;
        }
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.semanticLabel,
          child: SizedBox(
            key: const Key('flutter_glass_navigation_dock'),
            width: availableWidth,
            height:
                actionHeight +
                contentInset * 2 +
                style.topInset +
                style.bottomInset,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                style.topInset,
                horizontalInset,
                style.bottomInset,
              ),
              child: heldSurface,
            ),
          ),
        );
      },
    );
  }

  List<Size> _measureLabels(
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
  ) {
    final labels = [for (final item in widget.items) item.label];
    final cached = _labelMeasurements;
    if (cached != null &&
        cached.matches(
          labels,
          style,
          scaler,
          direction,
          locale,
          textHeightBehavior,
          widget.iconOnly,
        )) {
      return cached.sizes;
    }
    final sizes = widget.iconOnly
        ? List<Size>.filled(labels.length, Size.zero)
        : [
            for (final label in labels)
              _measureLabel(
                label,
                style,
                scaler,
                direction,
                locale,
                textHeightBehavior,
              ),
          ];
    _labelMeasurements = _LabelMeasurements(
      labels: List<String>.unmodifiable(labels),
      style: style,
      scaler: scaler,
      direction: direction,
      locale: locale,
      textHeightBehavior: textHeightBehavior,
      iconOnly: widget.iconOnly,
      sizes: List<Size>.unmodifiable(sizes),
    );
    return sizes;
  }

  Size _measureLabel(
    String label,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: scaler,
      textDirection: direction,
      locale: locale,
      textHeightBehavior: textHeightBehavior,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  void _acceptLayout(_DockLayout layout) {
    final previous = _layout;
    _layout = layout;
    if (previous != null && previous.sameGeometry(layout)) return;
    final hadScrub = _scrubbing;
    final hadContactPreview = _contactPreviewIndex.value != null;
    _pointerDown = null;
    // The new row ignores previews captured against different geometry. Clear
    // the notifier in the cancellation below, never while accepting a build.
    _contactPreviewLayout = null;
    _resetScrubCorrection();
    _clearPointerCapture();
    _resetReleaseRecovery(suppressUntilNextPress: true);
    _resetScrubVerticalScale();
    _resetScrubDeformation();
    _selectionMotion.stop();
    _selectionSpring = null;
    _selectionFrom = _selectionTo = layout.rects[widget.selectedIndex];
    // Stop reading the old drag coordinate synchronously: its coordinate space
    // is no longer valid. Leave notifier cleanup until after this build so the
    // first reflowed frame already paints the host's new destination geometry.
    _scrubbing = false;
    _lastRequestedIndex = null;
    if (hadScrub || hadContactPreview) {
      final invalidatedPointer = _pointer;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pointer == invalidatedPointer) {
          _contactPreviewIndex.value = null;
          _dragCenter.value = null;
          _pressedIndex = null;
          _press(false);
        }
      });
    }
    if (layout.usesScroll) _scheduleReveal(widget.selectedIndex);
  }
}

/// Latest complete caption measurement only; no painter or prior input is held.
class _LabelMeasurements {
  const _LabelMeasurements({
    required this.labels,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.locale,
    required this.textHeightBehavior,
    required this.iconOnly,
    required this.sizes,
  });

  final List<String> labels;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final Locale? locale;
  final TextHeightBehavior? textHeightBehavior;
  final bool iconOnly;
  final List<Size> sizes;

  bool matches(
    List<String> labels,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
    bool iconOnly,
  ) =>
      listEquals(this.labels, labels) &&
      this.style == style &&
      this.scaler == scaler &&
      this.direction == direction &&
      this.locale == locale &&
      this.textHeightBehavior == textHeightBehavior &&
      this.iconOnly == iconOnly;
}

/// Shared transformed lens geometry for painting and contact capture.
class _CapsulePaintGeometry {
  const _CapsulePaintGeometry({
    required this.sourceRect,
    required this.rect,
    required this.scaleX,
    required this.scaleY,
    required this.pressure,
  });

  // Canonical resting-inset coordinates for capture/spring handoff. Feeding
  // the feedback-adjusted paint rectangle back into motion expands it twice.
  final Rect sourceRect;
  final Rect rect;
  final double scaleX;
  final double scaleY;
  final double pressure;

  bool contains(Offset position, double radius) {
    // Test in lens-local coordinates, matching the nonuniform transform of its
    // rounded clip rather than treating the painted bounds as a rectangle.
    final center = rect.center;
    final local = Offset(
      center.dx + (position.dx - center.dx) / scaleX,
      center.dy + (position.dy - center.dy) / scaleY,
    );
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius),
    ).contains(local);
  }
}

// Gate before super.addPointer, rather than isPointerAllowed: rejecting an
// extra pointer through OneSequenceGestureRecognizer.handleNonAllowedPointer
// would reject the pending owner gesture as well. Ignoring admission preserves
// the SDK recognizer's normal arena, slop, button and device behavior for its
// owner. Do not gate end callbacks: raw up clears ownership before they run.
class _DockDragVelocity {
  _DockDragVelocity(this.isOwner);

  final bool Function(int pointer) isOwner;
  VelocityTracker? _ownerVelocityTracker;
  int? _velocityPointer;

  VelocityTracker track(PointerEvent event) {
    // The SDK records events into this kind-aware tracker before onStart.
    // Keep only its reference, not another independent sample history.
    _velocityPointer = event.pointer;
    return _ownerVelocityTracker = VelocityTracker.withKind(event.kind);
  }

  double horizontalVelocity(double maximum) {
    final pointer = _velocityPointer;
    if (pointer == null || !isOwner(pointer)) return 0;
    final speed = _ownerVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    return boundedHorizontalVelocity(speed, maximum);
  }

  static double boundedHorizontalVelocity(double speed, double maximum) {
    if (!speed.isFinite) return 0;
    return speed.clamp(-maximum, maximum);
  }

  void clear() {
    _ownerVelocityTracker = null;
    _velocityPointer = null;
  }
}

class _DockHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _DockHorizontalDragRecognizer({required this.isOwner, super.debugOwner}) {
    _velocity = _DockDragVelocity(isOwner);
    velocityTrackerBuilder = _velocity.track;
  }

  final bool Function(int pointer) isOwner;
  late final _DockDragVelocity _velocity;

  double get ownerHorizontalVelocity =>
      _velocity.horizontalVelocity(maxFlingVelocity ?? kMaxFlingVelocity);

  @override
  void addPointer(PointerDownEvent event) {
    if (isOwner(event.pointer)) super.addPointer(event);
  }

  @override
  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    if (isOwner(event.pointer)) super.addPointerPanZoom(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _velocity.clear();
  }

  @override
  void dispose() {
    _velocity.clear();
    super.dispose();
  }
}

class _DockPanDragRecognizer extends PanGestureRecognizer {
  _DockPanDragRecognizer({required this.isOwner, super.debugOwner}) {
    _velocity = _DockDragVelocity(isOwner);
    velocityTrackerBuilder = _velocity.track;
  }

  final bool Function(int pointer) isOwner;
  late final _DockDragVelocity _velocity;

  double get ownerHorizontalVelocity =>
      _velocity.horizontalVelocity(maxFlingVelocity ?? kMaxFlingVelocity);

  @override
  DragEndDetails? considerFling(
    VelocityEstimate estimate,
    PointerDeviceKind kind,
  ) {
    final fling = super.considerFling(estimate, kind);
    if (fling == null) return null;
    // Pan qualifies the gesture in both axes, but this capsule follows only X.
    // The SDK's vector-magnitude cap would reduce horizontal release momentum
    // merely because vertical speed increased. Use the same finite X projection
    // as the scrub handoff, retaining SDK qualification and release positions.
    final speed = _DockDragVelocity.boundedHorizontalVelocity(
      estimate.pixelsPerSecond.dx,
      maxFlingVelocity ?? kMaxFlingVelocity,
    );
    return DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(speed, 0)),
      globalPosition: fling.globalPosition,
      localPosition: fling.localPosition,
    );
  }

  @override
  void addPointer(PointerDownEvent event) {
    if (isOwner(event.pointer)) super.addPointer(event);
  }

  @override
  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    if (isOwner(event.pointer)) super.addPointerPanZoom(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _velocity.clear();
  }

  @override
  void dispose() {
    _velocity.clear();
    super.dispose();
  }
}

class _DockVerticalDragRecognizer extends VerticalDragGestureRecognizer {
  _DockVerticalDragRecognizer({required this.isOwner, super.debugOwner});

  final bool Function(int pointer) isOwner;

  @override
  void addPointer(PointerDownEvent event) {
    if (isOwner(event.pointer)) super.addPointer(event);
  }

  @override
  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    if (isOwner(event.pointer)) super.addPointerPanZoom(event);
  }
}

class _DockLongPressRecognizer extends LongPressGestureRecognizer {
  _DockLongPressRecognizer({required this.isOwner, super.debugOwner});

  final bool Function(int pointer) isOwner;

  @override
  void addPointer(PointerDownEvent event) {
    if (isOwner(event.pointer)) super.addPointer(event);
  }
}

/// Clips foreground in track coordinates while the sibling lens uses the gutter.
class _ForegroundViewportClipper extends CustomClipper<Rect> {
  _ForegroundViewportClipper({
    required this.controller,
    required this.viewportWidth,
    required this.direction,
  }) : super(reclip: controller);

  final ScrollController controller;
  final double viewportWidth;
  final TextDirection direction;

  @override
  Rect getClip(Size size) {
    final offset = controller.hasClients ? controller.offset : 0.0;
    final left = direction == TextDirection.ltr
        ? offset
        : size.width - viewportWidth - offset;
    return Rect.fromLTWH(left, 0, viewportWidth, size.height);
  }

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(_ForegroundViewportClipper oldClipper) =>
      oldClipper.controller != controller ||
      oldClipper.viewportWidth != viewportWidth ||
      oldClipper.direction != direction;
}

/// A continuous, distance-driven shape envelope, separate from lens position.
///
/// Each displacement adds velocity, rather than a per-event shape increment.
/// Recovery runs even without further pointer events. The duration normalizes
/// the driven distance window; the configured spring controls its response.
/// This is a portable approximation, not a reconstruction of UIKit physics.
class _ScrubDeformationRecovery extends Simulation {
  _ScrubDeformationRecovery({
    required SpringDescription? spring,
    required Duration duration,
    required double from,
    required double velocity,
    required double distanceInWidths,
  }) {
    retarget(
      spring: spring,
      duration: duration,
      from: from,
      velocity: velocity,
      distanceInWidths: distanceInWidths,
      time: 0,
    );
  }

  late SpringSimulation _recovery;
  double _originTime = 0;

  void retarget({
    required SpringDescription? spring,
    required Duration duration,
    required double from,
    required double velocity,
    required double distanceInWidths,
    required double time,
  }) {
    _originTime = time;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    final frequency = 2 * math.pi / seconds;
    final fallback = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: frequency * frequency,
      ratio: 1,
    );
    var resolved = spring ?? fallback;
    var drive = resolved.stiffness / resolved.mass * seconds;
    var frequencySquared = resolved.stiffness / resolved.mass;
    // Individually finite spring inputs can still overflow their ratios. Use
    // the duration-derived response rather than passing nonfinite SDK physics.
    if (!drive.isFinite || !frequencySquared.isFinite) {
      resolved = fallback;
      drive = fallback.stiffness * seconds;
      frequencySquared = fallback.stiffness;
    }
    final origin = from.isFinite ? from.clamp(0.0, 1.0) : 0.0;
    // Bound stored spring energy, not only painted geometry: k*x² + m*v² <= k.
    // Positive damping then keeps the entire response within unit amplitude.
    // An exponential approach to the available velocity has the composition
    // property for simultaneous distance samples, avoiding per-event kicks or
    // a hard velocity cap whose effect depends on how a move was subdivided.
    final velocityLimit = math.sqrt(frequencySquared * (1 - origin * origin));
    final currentVelocity = velocity.isFinite
        ? velocity.clamp(-velocityLimit, velocityLimit)
        : 0.0;
    final incomingVelocity = velocityLimit == 0
        ? 0.0
        : velocityLimit -
              (velocityLimit - currentVelocity) *
                  math.exp(-distanceInWidths * drive / velocityLimit);
    _recovery = SpringSimulation(resolved, origin, 0, incomingVelocity);
  }

  double amountAt(double time) =>
      isDone(time) ? 0 : _recovery.x(time - _originTime);

  double velocityAt(double time) =>
      isDone(time) ? 0 : _recovery.dx(time - _originTime);

  @override
  double x(double time) => time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) =>
      _recovery.isDone(time - _originTime) ||
      (time > _originTime && _recovery.x(time - _originTime) <= 0);
}

/// Drives one ticker while each geometric axis retains physical velocity.
class _CapsuleSpringMotion extends Simulation {
  _CapsuleSpringMotion({
    required SpringDescription spring,
    required Rect from,
    required Rect to,
    List<double>? velocity,
  }) : _target = to {
    final origin = [from.center.dx, from.center.dy, from.width, from.height];
    final target = [to.center.dx, to.center.dy, to.width, to.height];
    _axes = [
      for (var index = 0; index < origin.length; index++)
        SpringSimulation(
          spring,
          origin[index],
          target[index],
          velocity?[index] ?? 0,
        ),
    ];
  }

  final Rect _target;
  late final List<SpringSimulation> _axes;

  Rect rectAt(double time) => isDone(time)
      ? _target
      : Rect.fromCenter(
          center: Offset(_axes[0].x(time), _axes[1].x(time)),
          width: _axes[2].x(time),
          height: _axes[3].x(time),
        );

  List<double> velocityAt(double time) => [
    for (final axis in _axes) axis.dx(time),
  ];

  // The animation value is elapsed simulation time rather than a curve phase.
  @override
  double x(double time) => time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => _axes.every((axis) => axis.isDone(time));
}

class _DockLayout {
  _DockLayout({
    required this.widths,
    required this.viewportWidth,
    required this.actionHeight,
    required this.direction,
    required this.usesScroll,
    required this.horizontalContentInset,
    required this.outerHorizontalInset,
    required AppGlassNavigationStyle style,
  }) {
    horizontalOutset = math.min(
      style.selectionHorizontalOutset,
      horizontalContentInset,
    );
    verticalInset = math.min(style.selectionVerticalInset, actionHeight / 2);
    heldVerticalInset = math.min(
      style.resolvedHeldSelectionVerticalInset,
      actionHeight / 2,
    );
    totalWidth = widths.fold(0.0, (sum, width) => sum + width);
    var logicalStart = 0.0;
    final destinations = <Rect>[];
    for (final width in widths) {
      destinations.add(_selectionRect(width, logicalStart, style));
      logicalStart += width;
    }
    rects = List.unmodifiable(destinations);
    physicalRects = direction == TextDirection.ltr
        ? rects
        : List.unmodifiable(rects.reversed);
  }

  final List<double> widths;
  final double viewportWidth;
  final double actionHeight;
  final TextDirection direction;
  final bool usesScroll;
  final double horizontalContentInset;
  final double outerHorizontalInset;
  late final double horizontalOutset;
  late final double verticalInset;
  late final double heldVerticalInset;
  late final double totalWidth;
  late final List<Rect> rects;
  late final List<Rect> physicalRects;

  Rect _selectionRect(
    double width,
    double logicalStart,
    AppGlassNavigationStyle style,
  ) {
    final left = direction == TextDirection.ltr
        ? logicalStart
        : totalWidth - logicalStart - width;
    final horizontalInset = math.min(style.selectionHorizontalInset, width / 2);
    return Rect.fromLTWH(
      left + horizontalInset - horizontalOutset,
      verticalInset,
      width - horizontalInset * 2 + horizontalOutset * 2,
      actionHeight - verticalInset * 2,
    );
  }

  /// Resolves only visual height; horizontal pressure containment stays intact.
  Rect feedbackRect(Rect sourceRect, double feedback) {
    final insetDelta = verticalInset - heldVerticalInset;
    if (insetDelta == 0 || feedback <= 0) return sourceRect;
    final height =
        (sourceRect.height + insetDelta * 2 * feedback.clamp(0.0, 1.0)).clamp(
          0.0,
          actionHeight,
        );
    return Rect.fromCenter(
      center: Offset(
        sourceRect.center.dx,
        sourceRect.center.dy.clamp(height / 2, actionHeight - height / 2),
      ),
      width: sourceRect.width,
      height: height,
    );
  }

  int? indexAt(double x) {
    if (!x.isFinite) return null;
    final logicalX = direction == TextDirection.ltr ? x : totalWidth - x;
    var edge = 0.0;
    for (var index = 0; index < widths.length; index++) {
      edge += widths[index];
      if (logicalX <= edge || index == widths.length - 1) return index;
    }
    return null;
  }

  Rect rectAtCenter(double x) {
    final physical = physicalRects;
    final center = x.clamp(physical.first.center.dx, physical.last.center.dx);
    var width = physical.first.width;
    for (var index = 1; index < physical.length; index++) {
      final left = physical[index - 1];
      final right = physical[index];
      if (center > right.center.dx) {
        width = right.width;
        continue;
      }
      final distance = right.center.dx - left.center.dx;
      final progress = distance == 0
          ? 0.0
          : (center - left.center.dx) / distance;
      width = left.width + (right.width - left.width) * progress;
      break;
    }
    return Rect.fromCenter(
      center: Offset(center, physical.first.center.dy),
      width: width,
      height: physical.first.height,
    );
  }

  /// Converts physical track velocity into the spring's center/size axes.
  ///
  /// The scrub preview interpolates widths between neighboring centers, so
  /// unequal slots also have a width velocity. A clamped preview is stationary;
  /// at a clamp boundary only inward velocity can continue. Physical ordering
  /// already accounts for RTL, without reversing the recognizer's velocity.
  List<double> scrubReleaseVelocity(double x, double velocity) {
    const stationary = <double>[0, 0, 0, 0];
    if (!x.isFinite || !velocity.isFinite || velocity == 0) {
      return stationary;
    }
    final physical = physicalRects;
    final firstCenter = physical.first.center.dx;
    final lastCenter = physical.last.center.dx;
    if (x < firstCenter ||
        x > lastCenter ||
        (x == firstCenter && velocity < 0) ||
        (x == lastCenter && velocity > 0)) {
      return stationary;
    }
    for (var index = 1; index < physical.length; index++) {
      final left = physical[index - 1];
      final right = physical[index];
      // At an exact interior center, use the segment in the release direction.
      if (x > right.center.dx || (x == right.center.dx && velocity > 0)) {
        continue;
      }
      final distance = right.center.dx - left.center.dx;
      final widthVelocity = distance == 0
          ? 0.0
          : (right.width - left.width) / distance * velocity;
      if (!widthVelocity.isFinite) return stationary;
      return <double>[velocity, 0, widthVelocity, 0];
    }
    return stationary;
  }

  Rect clampCapsule(Rect rect) {
    final width = rect.width.clamp(0.0, totalWidth + horizontalOutset * 2);
    final height = rect.height.clamp(0.0, actionHeight);
    return Rect.fromCenter(
      center: Offset(
        rect.center.dx.clamp(
          width / 2 - horizontalOutset,
          totalWidth + horizontalOutset - width / 2,
        ),
        rect.center.dy.clamp(height / 2, actionHeight - height / 2),
      ),
      width: width,
      height: height,
    );
  }

  List<double> clampCapsuleVelocity(Rect rect, List<double> velocity) {
    // Retarget from the visible capsule's velocity, not momentum hidden beyond
    // its clamp. A size-changing boundary moves too, so its center velocity is
    // half the corresponding size velocity rather than necessarily zero.
    double project(
      double value,
      double speed,
      double lower,
      double upper, [
      double lowerSpeed = 0,
      double upperSpeed = 0,
    ]) {
      if (value < lower) return lowerSpeed;
      if (value > upper) return upperSpeed;
      if (value == lower) speed = math.max(speed, lowerSpeed);
      if (value == upper) speed = math.min(speed, upperSpeed);
      return speed;
    }

    final maximumWidth = totalWidth + horizontalOutset * 2;
    final width = rect.width.clamp(0.0, maximumWidth);
    final height = rect.height.clamp(0.0, actionHeight);
    final widthVelocity = project(rect.width, velocity[2], 0, maximumWidth);
    final heightVelocity = project(rect.height, velocity[3], 0, actionHeight);
    return <double>[
      project(
        rect.center.dx,
        velocity[0],
        width / 2 - horizontalOutset,
        totalWidth + horizontalOutset - width / 2,
        widthVelocity / 2,
        -widthVelocity / 2,
      ),
      project(
        rect.center.dy,
        velocity[1],
        height / 2,
        actionHeight - height / 2,
        heightVelocity / 2,
        -heightVelocity / 2,
      ),
      widthVelocity,
      heightVelocity,
    ];
  }

  Rect containHorizontalScale(
    Rect rect,
    double scale, {
    double extraMargin = 0,
  }) {
    // Pressure can expand a default zero-outset capsule into the outer gutter.
    // Preserve unexpanded geometry, but contain either source of expansion.
    if (horizontalOutset == 0 && scale <= 1) return rect;
    final margin = horizontalContentInset + extraMargin;
    final paintedWidth = math.min(rect.width * scale, totalWidth + margin * 2);
    return Rect.fromCenter(
      center: Offset(
        rect.center.dx.clamp(
          paintedWidth / 2 - margin,
          totalWidth + margin - paintedWidth / 2,
        ),
        rect.center.dy,
      ),
      width: paintedWidth / scale,
      height: rect.height,
    );
  }

  bool sameGeometry(_DockLayout other) =>
      direction == other.direction &&
      viewportWidth == other.viewportWidth &&
      usesScroll == other.usesScroll &&
      horizontalContentInset == other.horizontalContentInset &&
      outerHorizontalInset == other.outerHorizontalInset &&
      heldVerticalInset == other.heldVerticalInset &&
      listEquals(rects, other.rects);
}

/// Keeps decorative lens movement in paint; only size changes relayout Stack.
class _GlassLensPosition extends StatelessWidget {
  const _GlassLensPosition({required this.rect, required this.child});

  final Rect rect;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    width: rect.width,
    height: rect.height,
    // Backdrop composition resolves this ancestor translation before sampling.
    // The destination row and its input coordinates remain independently laid out.
    child: Transform.translate(offset: rect.topLeft, child: child),
  );
}

class _GlassDockSurface extends StatelessWidget {
  const _GlassDockSurface({
    required this.style,
    required this.highContrast,
    required this.pressure,
    required this.animateHeldTint,
    required this.contentInset,
    required this.horizontalContentInset,
    required this.clipContent,
    required this.backdropKey,
    required this.child,
  });

  final AppGlassNavigationStyle style;
  final bool highContrast;
  final Animation<double> pressure;
  final bool animateHeldTint;
  final double contentInset;
  final double horizontalContentInset;
  final bool clipContent;
  final BackdropKey? backdropKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(style.radius);
    // BoxDecoration's gradient replaces its color. Paint the resolved tint
    // separately so the specular wash retains light/dark surface behavior.
    final decoration = DecoratedBox(
      decoration: BoxDecoration(
        gradient: highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, style.highlightMidpoint, 1],
                colors: [
                  style.highlightColor,
                  style.highlightColor.withValues(alpha: 0),
                  style.highlightColor.withValues(
                    alpha: style.highlightColor.a * style.bottomHighlightFactor,
                  ),
                ],
              ),
        borderRadius: radius,
        border: Border.all(
          color: highContrast ? style.foregroundColor : style.outlineColor,
          width: style.outlineWidth,
        ),
      ),
    );
    final ordinaryColor = highContrast
        ? style.surfaceColor.withValues(alpha: 1)
        : style.surfaceColor;
    final heldColor = style.heldBarSurfaceColor;
    final Widget surface = animateHeldTint && heldColor != null
        ? AnimatedBuilder(
            animation: pressure,
            // Only the tint changes per contact tick. The existing wash/rim,
            // backdrop, viewport, row and recognizers retain their identity.
            child: decoration,
            builder: (context, child) => ColoredBox(
              color: Color.lerp(
                ordinaryColor,
                heldColor,
                pressure.value.clamp(0.0, 1.0),
              )!,
              child: child,
            ),
          )
        : ColoredBox(color: ordinaryColor, child: decoration);
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        // Only the backdrop is pill-clipped. A fitting, growing pressure lens
        // can rise above it without enlarging destination hit-test bounds.
        Positioned.fill(
          child: CustomGlassBackdropWidget(
            backdropKey: backdropKey,
            radius: style.radius,
            blurSigma: style.blurSigma,
            refractionStrength: style.refractionStrength,
            refractionEdge: style.refractionEdge,
            magnification: style.magnification,
            highContrast: highContrast,
            child: surface,
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalContentInset,
              vertical: contentInset,
            ),
            child: child,
          ),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: style.shadowColor,
            blurRadius: style.shadowBlur,
            // A shared scene input must not include a filled shadow beneath
            // the glass. Keep the existing default renderer unchanged.
            blurStyle: backdropKey == null ? BlurStyle.normal : BlurStyle.outer,
            offset: Offset(0, style.shadowOffset),
          ),
        ],
      ),
      child: clipContent
          ? ClipRRect(borderRadius: radius, child: content)
          : content,
    );
  }
}

/// Decorative moving lens only; the independent destination row stays sharp.
class _GlassSelectionSurface extends StatelessWidget {
  const _GlassSelectionSurface({
    required this.style,
    required this.highContrast,
    required this.pressure,
    required this.backdropKey,
  });

  final AppGlassNavigationStyle style;
  final bool highContrast;
  final double pressure;
  final BackdropKey? backdropKey;

  @override
  Widget build(BuildContext context) {
    final progress = pressure.clamp(0.0, 1.0);
    final samplesScene = backdropKey != null;
    final outline = highContrast
        ? style.selectedForegroundColor
        : style.pressedScale > 1
        ? Color.lerp(style.selectionOutlineColor, style.outlineColor, progress)!
        : style.selectionOutlineColor;
    final rimProgress =
        samplesScene && !highContrast && style.heldRimGradient != null
        ? progress
        : 0.0;
    // Shared input replaces the previously painted bar inside this lens.
    // At rest compose the selected tint over the bar tint once; on contact
    // transition to the caller's readable held material, not transparent raw
    // imagery. Only this lens's blur relaxes; the outer bar is unchanged.
    final tint = highContrast
        ? style.selectedSurfaceColor.withValues(alpha: 1)
        : samplesScene
        ? Color.lerp(
            Color.alphaBlend(style.selectedSurfaceColor, style.surfaceColor),
            style.resolvedHeldSurfaceColor,
            progress,
          )!
        : style.pressedScale > 1
        ? Color.lerp(style.selectedSurfaceColor, style.surfaceColor, pressure)!
        : style.selectedSurfaceColor;
    final surface = DecoratedBox(
      key: const Key('glass_navigation_selection'),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(style.radius),
        border: Border.all(
          color: outline.withValues(alpha: outline.a * (1 - rimProgress)),
          width: style.outlineWidth,
        ),
      ),
      child: style.refractionStrength == 0 || highContrast
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(style.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0, style.highlightMidpoint, 1],
                  colors: [
                    style.highlightColor,
                    style.highlightColor.withValues(alpha: 0),
                    style.highlightColor.withValues(
                      alpha:
                          style.highlightColor.a * style.bottomHighlightFactor,
                    ),
                  ],
                ),
              ),
            ),
    );
    final lens = style.refractionStrength == 0 || highContrast
        ? surface
        : CustomGlassBackdropWidget(
            backdropKey: backdropKey,
            radius: style.radius,
            blurSigma: samplesScene
                ? style.blurSigma +
                      (style.resolvedHeldBlurSigma - style.blurSigma) * progress
                : 0,
            // Even at full pressure the no-shader fallback must retain a
            // real keyed filter, or it would tint the already-treated bar.
            fallbackBlurSigma: samplesScene ? style.blurSigma : 0,
            refractionStrength: style.refractionStrength,
            refractionEdge: style.refractionEdge,
            dispersion: samplesScene
                ? style.resolvedSelectedBackdropDispersion * progress
                : 0,
            // Pressure already expands this lens's clip; the optional
            // foreground pass owns interaction optics, not backdrop zoom.
            magnification: style.magnification,
            child: surface,
          );
    if (style.pressedScale <= 1 || highContrast) return lens;
    // Paint elevation outside the lens's own clipped filter. Keep the wrapper
    // stable throughout the contact so its shader state is not recreated.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(style.radius),
        boxShadow: [
          BoxShadow(
            color: style.resolvedHeldShadowColor.withValues(
              alpha: style.resolvedHeldShadowColor.a * pressure,
            ),
            blurRadius: style.shadowBlur,
            // A filled shadow is visible through the translucent lens and
            // becomes part of its sampled backdrop. Elevation belongs outside
            // the glass, not beneath its center.
            blurStyle: BlurStyle.outer,
            offset: Offset(0, style.shadowOffset),
          ),
        ],
      ),
      child: lens,
    );
  }
}

/// Optional inset depth and rim within the existing selected-lens footprint.
class _GlassHeldEdgePainter extends CustomPainter {
  const _GlassHeldEdgePainter({
    required this.gradient,
    required this.innerShadow,
    required this.innerHighlight,
    required this.innerHighlightGradient,
    required this.pressure,
    required this.radius,
    required this.strokeWidth,
    required this.textDirection,
  });

  final Gradient? gradient;
  final BoxShadow? innerShadow;
  final BoxShadow? innerHighlight;
  final Gradient? innerHighlightGradient;
  final double pressure;
  final double radius;
  final double strokeWidth;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = pressure.clamp(0.0, 1.0);
    if (progress == 0) return;
    final bounds = Offset.zero & size;
    final lens = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    // One painter and clipping algorithm serve depth followed by inset light.
    // Both are local decoration, not additional backdrop/foreground passes.
    for (final shadow in [innerShadow, innerHighlight]) {
      if (shadow == null || shadow.color.a <= 0) continue;
      // Blur the outside of a shifted hole, then clip to the original lens.
      // This produces depth at the inside edge without a filled center, extra
      // scene sampling, offscreen saveLayer or an enlarged optical footprint.
      final extent =
          shadow.blurSigma * 3 +
          shadow.spreadRadius.abs() +
          math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs());
      final hole = lens.shift(shadow.offset).deflate(shadow.spreadRadius);
      final outerBounds = bounds.inflate(extent + size.longestSide);
      // Finite style inputs can still overflow when combined. Ignore only the
      // invalid shading; the independent edge and destination remain usable.
      if (extent.isFinite &&
          outerBounds.isFinite &&
          outerBounds.size.isFinite &&
          hole.outerRect.isFinite &&
          hole.outerRect.size.isFinite) {
        final occluder = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(outerBounds);
        if (hole.width > 0 && hole.height > 0) occluder.addRRect(hole);
        canvas.save();
        canvas.clipRRect(lens);
        canvas.drawPath(
          occluder,
          shadow.toPaint()
            ..color = shadow.color.withValues(alpha: shadow.color.a * progress),
        );
        canvas.restore();
      }
    }
    final bandGradient = innerHighlightGradient;
    final highlight = innerHighlight;
    if (bandGradient != null &&
        highlight != null &&
        highlight.color.a > 0 &&
        highlight.spreadRadius > 0) {
      // Align the chromatic band with the lip's outer edge; the independently
      // painted white highlight and inner depth retain their own geometry.
      final inset = highlight.spreadRadius / 4;
      if (inset.isFinite && inset < size.shortestSide / 2) {
        final band = lens.shift(highlight.offset).deflate(inset);
        if (band.outerRect.isFinite && band.width > 0 && band.height > 0) {
          final bandPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.min(
              highlight.spreadRadius / 2,
              size.shortestSide,
            )
            ..shader = bandGradient
                .scale(highlight.color.a * progress)
                .createShader(bounds, textDirection: textDirection);
          if (highlight.blurSigma > 0) {
            bandPaint.maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              highlight.blurSigma / 4,
            );
          }
          canvas.save();
          canvas.clipRRect(lens);
          canvas.drawRRect(band, bandPaint);
          canvas.restore();
        }
      }
    }
    final rim = gradient;
    if (rim == null || strokeWidth <= 0) return;
    final width = math.min(strokeWidth, size.shortestSide);
    final halfWidth = width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = rim
          .scale(progress)
          .createShader(bounds, textDirection: textDirection);
    // A thick stroke can lose the lens's rounded outer corners when its
    // centerline radius clamps to zero or its bounds collapse. Clip only that
    // case, preserving the ordinary thin-border antialiasing path exactly.
    final clipsRim = radius < halfWidth || width >= size.shortestSide;
    if (clipsRim) {
      canvas.save();
      canvas.clipRRect(lens);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.deflate(halfWidth),
        Radius.circular(math.max(0, radius - halfWidth)),
      ),
      paint,
    );
    if (clipsRim) canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassHeldEdgePainter oldDelegate) =>
      gradient != oldDelegate.gradient ||
      innerShadow != oldDelegate.innerShadow ||
      innerHighlight != oldDelegate.innerHighlight ||
      innerHighlightGradient != oldDelegate.innerHighlightGradient ||
      pressure != oldDelegate.pressure ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth ||
      textDirection != oldDelegate.textDirection;
}

class _GlassDockDestination extends StatelessWidget {
  const _GlassDockDestination({
    required this.item,
    required this.selected,
    required this.visuallySelected,
    required this.pointerFeedback,
    required this.style,
    required this.labelStyle,
    required this.textHeightBehavior,
    required this.iconOnly,
    required this.onTap,
    required this.onPointerTapUp,
    required this.onFocus,
  });

  final AppGlassNavigationItem item;
  final bool selected;
  final bool visuallySelected;
  final ValueListenable<bool> pointerFeedback;
  final AppGlassNavigationStyle style;
  final TextStyle labelStyle;
  final TextHeightBehavior? textHeightBehavior;
  final bool iconOnly;
  final VoidCallback? onTap;
  final VoidCallback? onPointerTapUp;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final usesGrowingPressFeedback =
        visuallySelected &&
        style.pressedScale > 1 &&
        style.duration > Duration.zero &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        !(MediaQuery.maybeHighContrastOf(context) ?? false);
    final foreground = !item.enabled
        ? style.disabledForegroundColor
        : visuallySelected
        ? style.selectedForegroundColor
        : style.foregroundColor;
    final label = item.semanticLabel ?? item.label;
    final badgeLabel = item.badgeLabel;
    final visual = visuallySelected && item.selectedIconWidget != null
        ? item.selectedIconWidget!
        : item.iconWidget ??
              (item.nativeImage != null
                  ? _GlassDockPortrait(image: item.nativeImage!, style: style)
                  : Icon(
                      visuallySelected
                          ? item.selectedIcon ?? item.icon
                          : item.icon,
                    ));
    final icon = SizedBox.square(
      dimension: style.iconArea,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ExcludeSemantics(
            child: IconTheme(
              data: IconThemeData(size: style.iconSize, color: foreground),
              child: visual,
            ),
          ),
          if (item.badge != null || badgeLabel != null)
            PositionedDirectional(
              top: -style.badgeOffset,
              end: -style.resolvedBadgeHorizontalOffset,
              child: ExcludeSemantics(
                child:
                    item.badge ??
                    _GlassDockBadge(label: badgeLabel!, style: style),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: item.enabled,
      label: badgeLabel == null ? label : '$label, $badgeLabel',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        // A held touch belongs to the lens, including a stationary press in a
        // fitting layout. Keep hover labels without cancelling that contact.
        triggerMode: TooltipTriggerMode.manual,
        child: Focus(
          skipTraversal: true,
          canRequestFocus: false,
          onFocusChange: (focused) {
            if (focused) onFocus();
          },
          child: ValueListenableBuilder<bool>(
            valueListenable: pointerFeedback,
            builder: (context, hasPointerContact, child) => InkWell(
              onTap: onTap,
              onTapUp: onPointerTapUp == null ? null : (_) => onPointerTapUp!(),
              canRequestFocus: item.enabled,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(style.radius),
              splashFactory: NoSplash.splashFactory,
              // The selected growing lens already owns touch feedback. A
              // second ink highlight leaves a dark target-shaped patch.
              // Keyboard and accessibility activation keep ordinary ink.
              highlightColor: usesGrowingPressFeedback && hasPointerContact
                  ? style.pressedSurfaceColor.withValues(alpha: 0)
                  : style.pressedSurfaceColor,
              hoverColor: style.pressedSurfaceColor,
              focusColor: style.focusColor,
              child: child,
            ),
            child: Center(
              child: iconOnly
                  ? icon
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        SizedBox(height: style.labelGap),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: style.labelPadding,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: labelStyle.copyWith(color: foreground),
                            textHeightBehavior: textHeightBehavior,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDockPortrait extends StatelessWidget {
  const _GlassDockPortrait({required this.image, required this.style});

  final AppGlassNavigationImage image;
  final AppGlassNavigationStyle style;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: style.avatarBackgroundColor,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            image.initials,
            maxLines: 1,
            style: style.initialsStyle.copyWith(
              color: style.avatarForegroundColor,
            ),
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: style.avatarSize,
      child: ClipOval(
        child: image.assetPath == null
            ? fallback
            : Image.asset(
                image.assetPath!,
                package: image.assetPackage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _GlassDockBadge extends StatelessWidget {
  const _GlassDockBadge({required this.label, required this.style});

  final String label;
  final AppGlassNavigationStyle style;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: style.badgeMinWidth,
      minHeight: style.badgeMinHeight,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(style.radius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: style.badgePadding),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: style.badgeStyle.copyWith(color: style.badgeForegroundColor),
          ),
        ),
      ),
    ),
  );
}
