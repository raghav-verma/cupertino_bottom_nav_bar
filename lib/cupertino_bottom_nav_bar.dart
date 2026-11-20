/// Reusable floating glass navigation with an optional native iOS renderer.
///
/// The owning application supplies theme values, destinations and selection;
/// this library performs no routing, networking or persistent state changes.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'src/flutter_glass_navigation_dock.dart';
import 'src/glass_navigation_models.dart';

export 'src/flutter_glass_navigation_dock.dart';
export 'src/glass_navigation_models.dart';

part 'src/native_glass_navigation_dock.dart';

/// A controlled floating navigation dock for three to five destinations.
///
/// Compatible iOS 26+ layouts use native UIKit glass. Android and other
/// platforms use the same resolved design with Flutter glass and scrubbing.
/// Set [preferNative] to false to choose Flutter rendering consistently.
/// Selection stays owned by the caller; gestures emit requests only.
/// Complete captions that exceed an equal native target use Flutter's
/// accessible measured-width layout instead.
/// Native lane height may grow to fit UIKit's publicly measured system bar;
/// a parent that cannot accommodate that height uses Flutter rendering.
/// Bold-text and high-contrast preferences use Flutter because the native
/// bridge does not forward those MediaQuery preferences to UIKit.
///
/// When its Flutter modal route is not current, the dock retains its layout
/// space while hiding both renderers and excluding pointer input, focus,
/// semantics and animation ticks. Existing dock contacts are cancelled when
/// covered, including when declarative navigation does not cancel them.
/// Without a modal route, visibility remains
/// caller-owned.
class CustomGlassNavigationDockWidget extends StatelessWidget {
  /// Creates a dock from resolved theme values and immutable destinations.
  const CustomGlassNavigationDockWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.style,
    this.iconOnly = false,
    this.semanticLabel = 'Primary navigation',
    this.preferNative = true,
  }) : assert(items.length >= 3 && items.length <= 5),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  /// Three to five destinations in the caller's canonical order.
  final List<AppGlassNavigationItem> items;

  /// The caller's accepted selection, within the bounds of [items].
  final int selectedIndex;

  /// Requests an enabled destination by index without changing selection.
  ///
  /// The caller accepts a request by rebuilding with a new [selectedIndex].
  final ValueChanged<int> onItemSelected;

  /// Resolved colors, typography, geometry and motion for the renderers.
  final AppGlassNavigationStyle style;

  /// Hides visual captions, preserves labels and tooltips, and uses Flutter.
  final bool iconOnly;

  /// Resolved accessible label for the navigation container.
  final String semanticLabel;

  /// Uses compatible native iOS chrome when available; never forces it.
  final bool preferNative;

  @override
  Widget build(BuildContext context) => _DockRouteVisibilityBoundary(
    onItemSelected: onItemSelected,
    builder: _buildSurface,
  );

  Widget _buildSurface(
    BuildContext context,
    ValueChanged<int> guardedSelection,
  ) {
    final fallback = CustomFlutterGlassNavigationDockWidget(
      items: items,
      selectedIndex: selectedIndex,
      onItemSelected: guardedSelection,
      style: style,
      iconOnly: iconOnly,
      semanticLabel: semanticLabel,
    );
    if (!preferNative ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        iconOnly ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.boldTextOf(context) ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.maybeLineHeightScaleFactorOverrideOf(context) != null ||
        MediaQuery.maybeLetterSpacingOverrideOf(context) != null ||
        MediaQuery.maybeWordSpacingOverrideOf(context) != null ||
        MediaQuery.textScalerOf(context).scale(1) >= style.largeTextScale ||
        Directionality.of(context) != TextDirection.ltr ||
        items.any(
          (item) =>
              item.badge != null ||
              (item.nativeImage == null &&
                  (item.iconWidget != null || item.selectedIconWidget != null)),
        )) {
      return fallback;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final contentWidth = math.max(
          0.0,
          width -
              (style.horizontalInset + style.resolvedHorizontalContentInset) *
                  2,
        );
        final minimumTarget = math.max(
          AppGlassNavigationStyle.minimumTouchTarget,
          style.minTargetSize,
        );
        final targetWidth = contentWidth / items.length;
        if (targetWidth < minimumTarget) return fallback;
        final labelStyle = DefaultTextStyle.of(context).style
            .merge(style.labelStyle);
        final textScaler = MediaQuery.textScalerOf(context);
        for (final item in items) {
          final painter = TextPainter(
            text: TextSpan(text: item.label, style: labelStyle),
            textScaler: textScaler,
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final labelWidth = painter.width + style.labelPadding * 2;
          painter.dispose();
          if (math.max(style.iconArea, labelWidth) > targetWidth) {
            return fallback;
          }
        }
        return _NativeNavigationDockSurface(
          items: items,
          selectedIndex: selectedIndex,
          onItemSelected: guardedSelection,
          style: style,
          width: width,
          height: style.dockHeight,
          iconSize: style.iconSize,
          avatarSize: style.avatarSize,
          labelSize:
              style.labelStyle.fontSize ??
              DefaultTextStyle.of(context).style.fontSize ??
              style.iconSize,
          captionMaxWidth: targetWidth - style.labelPadding * 2,
          semanticLabel: semanticLabel,
          fallback: fallback,
        );
      },
    );
  }
}

/// Private lifecycle boundary only; accepted selection stays with the host.
///
/// Its listener ancestry stays intact across cover/return so SDK cancellation
/// reaches pending taps, accepted drags and secondary contacts without remounting
/// the dock. The direct Flutter renderer keeps caller-owned route visibility.
class _DockRouteVisibilityBoundary extends StatefulWidget {
  const _DockRouteVisibilityBoundary({
    required this.builder,
    required this.onItemSelected,
  });

  final Widget Function(BuildContext, ValueChanged<int>) builder;
  final ValueChanged<int> onItemSelected;

  @override
  State<_DockRouteVisibilityBoundary> createState() =>
      _DockRouteVisibilityBoundaryState();
}

class _DockRouteVisibilityBoundaryState
    extends State<_DockRouteVisibilityBoundary> {
  final Set<int> _pointers = <int>{};
  final Map<int, Object> _cancellingPointers = <int, Object>{};
  ModalRoute<dynamic>? _route;
  bool _visible = true;
  bool _active = true;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _visible;
    _route = ModalRoute.of(context);
    _visible = _route?.isCurrent ?? true;
    if (wasVisible && !_visible) _cancelPointers();
  }

  void _cancelPointers() {
    // cancelPointer queues CANCEL before subsequent input, not synchronously.
    // Keep requests blocked until that terminal event finishes dispatching,
    // even if the route reappears before the queued cancellation is delivered.
    for (final pointer in _pointers.toList()) {
      if (_cancellingPointers.containsKey(pointer)) continue;
      _cancellingPointers[pointer] = Object();
      GestureBinding.instance.cancelPointer(pointer);
    }
  }

  void _onPointerStarted(PointerEvent event) {
    if (_disposed) return;
    _pointers.add(event.pointer);
    if (!_active || !_visible || !(_route?.isCurrent ?? true)) {
      _cancelPointers();
    }
  }

  void _onPointerEnded(PointerEvent event) {
    _pointers.remove(event.pointer);
    final token = _cancellingPointers[event.pointer];
    if (token == null) return;
    // Listener delivery precedes recognizer routing. A real UP racing queued
    // CANCEL must remain blocked through its tap/end callbacks, not merely
    // until this listener runs. Identity also protects a later cancellation.
    scheduleMicrotask(() {
      if (identical(_cancellingPointers[event.pointer], token)) {
        _cancellingPointers.remove(event.pointer);
      }
    });
  }

  void _onItemSelected(int index) {
    if (!mounted ||
        _disposed ||
        !_active ||
        !_visible ||
        !(_route?.isCurrent ?? true) ||
        _cancellingPointers.isNotEmpty) {
      return;
    }
    widget.onItemSelected(index);
  }

  @override
  void deactivate() {
    _active = false;
    _cancelPointers();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    _visible = false;
    _cancelPointers();
    _pointers.clear();
    _cancellingPointers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerStarted,
    onPointerUp: _onPointerEnded,
    onPointerCancel: _onPointerEnded,
    onPointerPanZoomStart: _onPointerStarted,
    onPointerPanZoomEnd: _onPointerEnded,
    child: TickerMode(
      enabled: _visible,
      child: IgnorePointer(
        ignoring: !_visible,
        child: ExcludeFocus(
          excluding: !_visible,
          child: ExcludeSemantics(
            excluding: !_visible,
            child: Opacity(
              opacity: _visible ? 1 : 0,
              child: widget.builder(context, _onItemSelected),
            ),
          ),
        ),
      ),
    ),
  );
}
