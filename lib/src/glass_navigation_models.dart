import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Resolved local portrait information shared by the dock renderers.
///
/// The bundled image is cropped to a circle. A missing image falls back to
/// [initials]; the dock performs no network requests or persistence.
@immutable
class AppGlassNavigationImage {
  /// Creates a local portrait with a deterministic text fallback.
  const AppGlassNavigationImage({
    this.assetPath,
    this.assetPackage,
    required this.initials,
  });

  /// A bundled image asset, or null to display [initials].
  final String? assetPath;

  /// The Flutter asset package, when [assetPath] belongs to a package.
  final String? assetPackage;

  /// Resolved fallback text, usually synthetic initials.
  final String initials;
}

/// One resolved destination in a glass navigation dock.
///
/// Labels, badge meaning, artwork and navigation intent belong to the caller.
@immutable
class AppGlassNavigationItem {
  /// Creates a destination without owning its selected state.
  const AppGlassNavigationItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.iconWidget,
    this.selectedIconWidget,
    this.nativeImage,
    this.badge,
    this.badgeLabel,
    this.semanticLabel,
    this.enabled = true,
  });

  /// The ordinary resolved glyph.
  final IconData icon;

  /// An optional glyph for the externally selected destination.
  final IconData? selectedIcon;

  /// A custom resolved visual rendered in place of [icon] by Flutter.
  final Widget? iconWidget;

  /// A custom selected visual, falling back to [iconWidget].
  final Widget? selectedIconWidget;

  /// Local portrait data that can be rendered by Flutter and native iOS.
  ///
  /// Supply this alongside custom portrait widgets for equivalent native
  /// artwork. Arbitrary widgets without equivalent data use Flutter rendering.
  final AppGlassNavigationImage? nativeImage;

  /// The complete resolved caption and default accessible label.
  final String label;

  /// An optional caller-rendered badge, excluded from duplicate semantics.
  final Widget? badge;

  /// Resolved badge text, also appended to the destination's accessible label.
  final String? badgeLabel;

  /// A resolved accessible label that overrides [label].
  final String? semanticLabel;

  /// Whether taps, keyboard activation and scrubbing may request this item.
  final bool enabled;
}

/// How Flutter distributes destination widths when the whole track fits.
///
/// UIKit continues to allocate its native destinations independently. Narrow
/// and large-text Flutter tracks retain their measured, scrollable layout.
enum AppGlassNavigationItemSizing {
  /// Gives every destination the same width, preserving the original layout.
  equal,

  /// Gives each measured minimum the same share of the remaining track space.
  ///
  /// Longer captions can have wider destinations and selected capsules without
  /// separating the artwork from its touch target or reducing minimum targets.
  contentBalanced,
}

/// When a fitting Flutter scrub may request a destination from its host.
///
/// Ordinary taps, keyboard activation, scrolling long-press scrubs and native
/// UIKit gestures retain their existing selection behavior.
enum AppGlassNavigationScrubSelectionPolicy {
  /// Requests enabled destinations as the adjusted capsule center crosses them.
  continuous,

  /// Requests only the enabled destination at a successful owner release.
  ///
  /// The raw pointer's release X must be within the visible bar's inclusive
  /// horizontal bounds: the current track plus its horizontal content insets,
  /// excluding exterior lens growth and shadow. The grab-adjusted center
  /// determines the destination. Vertical position does not cancel a release,
  /// and leaving then re-entering the lane is allowed. Pointer cancellation or
  /// an outside release requests nothing and settles to the latest host index.
  onReleaseWithinLane,
}

/// Immutable, resolved visual inputs for a glass navigation dock.
///
/// These SDK-only values are independent of any application's theme tokens,
/// sizing extensions, routes and state management. Resolve application tokens
/// before constructing this style. [bottomInset] is the final reserved space
/// beneath the surface; safe-area ownership belongs to the caller.
/// Native UIKit owns its material, capsule geometry and motion; fields described
/// as Flutter-specific customize only the Flutter renderer.
@immutable
class AppGlassNavigationStyle {
  /// Creates a neutral floating treatment with accessible minimum targets.
  ///
  /// To preserve const construction, nested [selectionSpring] parameters are
  /// validated by [resolvedSelectionSpring] when a transition resolves them.
  const AppGlassNavigationStyle({
    this.surfaceColor = const Color(0xBDFFFFFF),
    this.heldBarSurfaceColor,
    this.selectedSurfaceColor = const Color(0xBDEDEDEF),
    this.heldSurfaceColor,
    this.heldRimGradient,
    this.heldInnerShadow,
    this.heldInnerHighlight,
    this.heldInnerHighlightGradient,
    this.trackVerticalDrag = false,
    this.scrubSelectionPolicy =
        AppGlassNavigationScrubSelectionPolicy.continuous,
    this.foregroundColor = const Color(0xFF27272A),
    this.selectedForegroundColor = const Color(0xFF18181B),
    this.disabledForegroundColor = const Color(0xFF89898D),
    this.outlineColor = const Color(0x66FFFFFF),
    this.shadowColor = const Color(0x24000000),
    this.heldShadowColor,
    this.pressedSurfaceColor = const Color(0x1427272A),
    this.badgeBackgroundColor = const Color(0xFF27272A),
    this.badgeForegroundColor = const Color(0xFFFFFFFF),
    this.avatarBackgroundColor = const Color(0xFFE4E4E7),
    this.avatarForegroundColor = const Color(0xFF27272A),
    this.highlightColor = const Color(0x70FFFFFF),
    this.selectionOutlineColor = const Color(0x80FFFFFF),
    this.focusColor = const Color(0x3327272A),
    this.labelStyle = const TextStyle(
      fontSize: 10,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
    this.badgeStyle = const TextStyle(
      fontSize: 10,
      height: 1,
      fontWeight: FontWeight.w700,
    ),
    this.initialsStyle = const TextStyle(
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w700,
    ),
    this.actionHeight = 48,
    this.minTargetSize = minimumTouchTarget,
    this.itemSizing = AppGlassNavigationItemSizing.equal,
    this.iconSize = 24,
    this.iconArea = 32,
    this.avatarSize = 24,
    this.horizontalInset = 16,
    this.topInset = 4,
    this.bottomInset = 8,
    this.contentInset = 4,
    this.horizontalContentInset,
    this.labelGap = 2,
    this.labelPadding = 4,
    this.radius = 999,
    this.blurSigma = 20,
    this.heldBlurSigma = 0,
    this.refractionStrength = 0,
    this.refractionEdge = 12,
    this.foregroundRefractionEdge,
    this.magnification = 1.03,
    this.foregroundMagnification,
    this.foregroundDispersion = 0,
    this.selectedBackdropDispersion = 0,
    this.outlineWidth = 0.75,
    this.shadowBlur = 20,
    this.shadowOffset = 2,
    this.badgeMinWidth = 20,
    this.badgeMinHeight = 16,
    this.badgePadding = 2,
    this.badgeOffset = 2,
    this.badgeHorizontalOffset,
    this.selectionHorizontalInset = 2,
    this.selectionHorizontalOutset = 0,
    this.selectionVerticalInset = 0,
    this.heldSelectionVerticalInset,
    this.largeTextScale = 1.3,
    this.highlightMidpoint = 0.5,
    this.bottomHighlightFactor = 0.12,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.selectionSpring,
    this.animateSelectionDeformation = false,
    this.refractForegroundDuringInteraction = false,
    this.selectionScale = 1,
    this.pressedScale = 0.97,
    this.heldBarScale = 1,
    this.pressureStretch = 0.04,
    this.scrubVerticalScale = 1,
    this.scrubMotionStretch = 0,
    this.scrubMotionFlattening = 0,
    this.releaseVerticalStretch = 0,
  }) : assert(actionHeight > 0),
       assert(minTargetSize >= minimumTouchTarget),
       assert(iconSize > 0 && iconArea > 0 && avatarSize > 0),
       assert(horizontalInset >= 0 && topInset >= 0 && bottomInset >= 0),
       assert(contentInset >= 0 && labelGap >= 0 && labelPadding >= 0),
       assert(
         horizontalContentInset == null ||
             (horizontalContentInset >= 0 &&
                 horizontalContentInset < double.infinity),
       ),
       assert(radius >= 0 && blurSigma >= 0 && outlineWidth >= 0),
       assert(heldBlurSigma >= 0 && heldBlurSigma < double.infinity),
       assert(refractionStrength >= 0 && refractionStrength < double.infinity),
       assert(refractionEdge > 0 && refractionEdge < double.infinity),
       assert(
         foregroundRefractionEdge == null ||
             (foregroundRefractionEdge > 0 &&
                 foregroundRefractionEdge < double.infinity),
       ),
       assert(magnification >= 1 && magnification < double.infinity),
       assert(
         foregroundMagnification == null ||
             (foregroundMagnification >= 1 &&
                 foregroundMagnification < double.infinity),
       ),
       assert(
         foregroundDispersion >= 0 && foregroundDispersion < double.infinity,
       ),
       assert(
         selectedBackdropDispersion >= 0 &&
             selectedBackdropDispersion < double.infinity,
       ),
       assert(shadowBlur >= 0),
       assert(badgeMinWidth > 0 && badgeMinHeight > 0),
       assert(badgePadding >= 0 && badgeOffset >= 0),
       assert(
         badgeHorizontalOffset == null ||
             (badgeHorizontalOffset >= 0 &&
                 badgeHorizontalOffset < double.infinity),
       ),
       assert(selectionHorizontalInset >= 0 && selectionVerticalInset >= 0),
       assert(
         heldSelectionVerticalInset == null ||
             (heldSelectionVerticalInset >= 0 &&
                 heldSelectionVerticalInset < double.infinity),
       ),
       assert(
         selectionHorizontalOutset >= 0 &&
             selectionHorizontalOutset < double.infinity,
       ),
       assert(largeTextScale >= 1),
       assert(highlightMidpoint > 0 && highlightMidpoint < 1),
       assert(bottomHighlightFactor >= 0 && bottomHighlightFactor <= 1),
       assert(selectionScale > 0 && pressedScale > 0 && pressureStretch >= 0),
       assert(heldBarScale >= 1 && heldBarScale < double.infinity),
       assert(scrubVerticalScale > 0 && scrubVerticalScale <= 1),
       assert(scrubMotionStretch >= 0 && scrubMotionStretch <= 1),
       assert(scrubMotionFlattening >= 0 && scrubMotionFlattening < 1),
       assert(
         releaseVerticalStretch >= 0 &&
             releaseVerticalStretch < double.infinity,
       );

  /// Returns a style with selected overrides, retaining all omitted values.
  ///
  /// This also preserves values resolved by [AppGlassNavigationStyle.fromTheme].
  /// Null retains the current value for nonnullable fields. For nullable fields,
  /// omission retains the value while explicit null clears it:
  ///
  /// * [heldBarSurfaceColor], [heldSurfaceColor] and [heldShadowColor] accept a
  ///   [Color] or null.
  /// * [heldRimGradient] and [heldInnerHighlightGradient] accept a [Gradient]
  ///   or null.
  /// * [heldInnerShadow] and [heldInnerHighlight] accept a [BoxShadow] or null.
  /// * [horizontalContentInset], [foregroundRefractionEdge],
  ///   [foregroundMagnification],
  ///   [badgeHorizontalOffset] and [heldSelectionVerticalInset] accept a
  ///   [num] (including integer literals), converted to [double], or null.
  /// * [selectionSpring] accepts a [SpringDescription] or null.
  ///
  /// Nullable overrides use [Object] parameters to distinguish omission from
  /// explicit null and throw [ArgumentError] for any other value type.
  /// The constructor's assertions and runtime resolution remain unchanged.
  /// Flutter-only overrides do not retune UIKit's system-owned material,
  /// capsule geometry or motion.
  AppGlassNavigationStyle copyWith({
    Color? surfaceColor,
    Object? heldBarSurfaceColor = _unchangedStyleValue,
    Color? selectedSurfaceColor,
    Object? heldSurfaceColor = _unchangedStyleValue,
    Object? heldRimGradient = _unchangedStyleValue,
    Object? heldInnerShadow = _unchangedStyleValue,
    Object? heldInnerHighlight = _unchangedStyleValue,
    Object? heldInnerHighlightGradient = _unchangedStyleValue,
    bool? trackVerticalDrag,
    AppGlassNavigationScrubSelectionPolicy? scrubSelectionPolicy,
    Color? foregroundColor,
    Color? selectedForegroundColor,
    Color? disabledForegroundColor,
    Color? outlineColor,
    Color? shadowColor,
    Object? heldShadowColor = _unchangedStyleValue,
    Color? pressedSurfaceColor,
    Color? badgeBackgroundColor,
    Color? badgeForegroundColor,
    Color? avatarBackgroundColor,
    Color? avatarForegroundColor,
    Color? highlightColor,
    Color? selectionOutlineColor,
    Color? focusColor,
    TextStyle? labelStyle,
    TextStyle? badgeStyle,
    TextStyle? initialsStyle,
    double? actionHeight,
    double? minTargetSize,
    AppGlassNavigationItemSizing? itemSizing,
    double? iconSize,
    double? iconArea,
    double? avatarSize,
    double? horizontalInset,
    double? topInset,
    double? bottomInset,
    double? contentInset,
    Object? horizontalContentInset = _unchangedStyleValue,
    double? labelGap,
    double? labelPadding,
    double? radius,
    double? blurSigma,
    double? heldBlurSigma,
    double? refractionStrength,
    double? refractionEdge,
    Object? foregroundRefractionEdge = _unchangedStyleValue,
    double? magnification,
    Object? foregroundMagnification = _unchangedStyleValue,
    double? foregroundDispersion,
    double? selectedBackdropDispersion,
    double? outlineWidth,
    double? shadowBlur,
    double? shadowOffset,
    double? badgeMinWidth,
    double? badgeMinHeight,
    double? badgePadding,
    double? badgeOffset,
    Object? badgeHorizontalOffset = _unchangedStyleValue,
    double? selectionHorizontalInset,
    double? selectionHorizontalOutset,
    double? selectionVerticalInset,
    Object? heldSelectionVerticalInset = _unchangedStyleValue,
    double? largeTextScale,
    double? highlightMidpoint,
    double? bottomHighlightFactor,
    Duration? duration,
    Curve? curve,
    Object? selectionSpring = _unchangedStyleValue,
    bool? animateSelectionDeformation,
    bool? refractForegroundDuringInteraction,
    double? selectionScale,
    double? pressedScale,
    double? heldBarScale,
    double? pressureStretch,
    double? scrubVerticalScale,
    double? scrubMotionStretch,
    double? scrubMotionFlattening,
    double? releaseVerticalStretch,
  }) => AppGlassNavigationStyle(
    surfaceColor: surfaceColor ?? this.surfaceColor,
    heldBarSurfaceColor: _resolveNullableStyleOverride<Color>(
      heldBarSurfaceColor,
      this.heldBarSurfaceColor,
      'heldBarSurfaceColor',
    ),
    selectedSurfaceColor: selectedSurfaceColor ?? this.selectedSurfaceColor,
    heldSurfaceColor: _resolveNullableStyleOverride<Color>(
      heldSurfaceColor,
      this.heldSurfaceColor,
      'heldSurfaceColor',
    ),
    heldRimGradient: _resolveNullableStyleOverride<Gradient>(
      heldRimGradient,
      this.heldRimGradient,
      'heldRimGradient',
    ),
    heldInnerShadow: _resolveNullableStyleOverride<BoxShadow>(
      heldInnerShadow,
      this.heldInnerShadow,
      'heldInnerShadow',
    ),
    heldInnerHighlight: _resolveNullableStyleOverride<BoxShadow>(
      heldInnerHighlight,
      this.heldInnerHighlight,
      'heldInnerHighlight',
    ),
    heldInnerHighlightGradient: _resolveNullableStyleOverride<Gradient>(
      heldInnerHighlightGradient,
      this.heldInnerHighlightGradient,
      'heldInnerHighlightGradient',
    ),
    trackVerticalDrag: trackVerticalDrag ?? this.trackVerticalDrag,
    scrubSelectionPolicy: scrubSelectionPolicy ?? this.scrubSelectionPolicy,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    selectedForegroundColor:
        selectedForegroundColor ?? this.selectedForegroundColor,
    disabledForegroundColor:
        disabledForegroundColor ?? this.disabledForegroundColor,
    outlineColor: outlineColor ?? this.outlineColor,
    shadowColor: shadowColor ?? this.shadowColor,
    heldShadowColor: _resolveNullableStyleOverride<Color>(
      heldShadowColor,
      this.heldShadowColor,
      'heldShadowColor',
    ),
    pressedSurfaceColor: pressedSurfaceColor ?? this.pressedSurfaceColor,
    badgeBackgroundColor: badgeBackgroundColor ?? this.badgeBackgroundColor,
    badgeForegroundColor: badgeForegroundColor ?? this.badgeForegroundColor,
    avatarBackgroundColor: avatarBackgroundColor ?? this.avatarBackgroundColor,
    avatarForegroundColor: avatarForegroundColor ?? this.avatarForegroundColor,
    highlightColor: highlightColor ?? this.highlightColor,
    selectionOutlineColor: selectionOutlineColor ?? this.selectionOutlineColor,
    focusColor: focusColor ?? this.focusColor,
    labelStyle: labelStyle ?? this.labelStyle,
    badgeStyle: badgeStyle ?? this.badgeStyle,
    initialsStyle: initialsStyle ?? this.initialsStyle,
    actionHeight: actionHeight ?? this.actionHeight,
    minTargetSize: minTargetSize ?? this.minTargetSize,
    itemSizing: itemSizing ?? this.itemSizing,
    iconSize: iconSize ?? this.iconSize,
    iconArea: iconArea ?? this.iconArea,
    avatarSize: avatarSize ?? this.avatarSize,
    horizontalInset: horizontalInset ?? this.horizontalInset,
    topInset: topInset ?? this.topInset,
    bottomInset: bottomInset ?? this.bottomInset,
    contentInset: contentInset ?? this.contentInset,
    horizontalContentInset: _resolveNullableDoubleStyleOverride(
      horizontalContentInset,
      this.horizontalContentInset,
      'horizontalContentInset',
    ),
    labelGap: labelGap ?? this.labelGap,
    labelPadding: labelPadding ?? this.labelPadding,
    radius: radius ?? this.radius,
    blurSigma: blurSigma ?? this.blurSigma,
    heldBlurSigma: heldBlurSigma ?? this.heldBlurSigma,
    refractionStrength: refractionStrength ?? this.refractionStrength,
    refractionEdge: refractionEdge ?? this.refractionEdge,
    foregroundRefractionEdge: _resolveNullableDoubleStyleOverride(
      foregroundRefractionEdge,
      this.foregroundRefractionEdge,
      'foregroundRefractionEdge',
    ),
    magnification: magnification ?? this.magnification,
    foregroundMagnification: _resolveNullableDoubleStyleOverride(
      foregroundMagnification,
      this.foregroundMagnification,
      'foregroundMagnification',
    ),
    foregroundDispersion: foregroundDispersion ?? this.foregroundDispersion,
    selectedBackdropDispersion:
        selectedBackdropDispersion ?? this.selectedBackdropDispersion,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    shadowOffset: shadowOffset ?? this.shadowOffset,
    badgeMinWidth: badgeMinWidth ?? this.badgeMinWidth,
    badgeMinHeight: badgeMinHeight ?? this.badgeMinHeight,
    badgePadding: badgePadding ?? this.badgePadding,
    badgeOffset: badgeOffset ?? this.badgeOffset,
    badgeHorizontalOffset: _resolveNullableDoubleStyleOverride(
      badgeHorizontalOffset,
      this.badgeHorizontalOffset,
      'badgeHorizontalOffset',
    ),
    selectionHorizontalInset:
        selectionHorizontalInset ?? this.selectionHorizontalInset,
    selectionHorizontalOutset:
        selectionHorizontalOutset ?? this.selectionHorizontalOutset,
    selectionVerticalInset:
        selectionVerticalInset ?? this.selectionVerticalInset,
    heldSelectionVerticalInset: _resolveNullableDoubleStyleOverride(
      heldSelectionVerticalInset,
      this.heldSelectionVerticalInset,
      'heldSelectionVerticalInset',
    ),
    largeTextScale: largeTextScale ?? this.largeTextScale,
    highlightMidpoint: highlightMidpoint ?? this.highlightMidpoint,
    bottomHighlightFactor: bottomHighlightFactor ?? this.bottomHighlightFactor,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    selectionSpring: _resolveNullableStyleOverride<SpringDescription>(
      selectionSpring,
      this.selectionSpring,
      'selectionSpring',
    ),
    animateSelectionDeformation:
        animateSelectionDeformation ?? this.animateSelectionDeformation,
    refractForegroundDuringInteraction:
        refractForegroundDuringInteraction ??
        this.refractForegroundDuringInteraction,
    selectionScale: selectionScale ?? this.selectionScale,
    pressedScale: pressedScale ?? this.pressedScale,
    heldBarScale: heldBarScale ?? this.heldBarScale,
    pressureStretch: pressureStretch ?? this.pressureStretch,
    scrubVerticalScale: scrubVerticalScale ?? this.scrubVerticalScale,
    scrubMotionStretch: scrubMotionStretch ?? this.scrubMotionStretch,
    scrubMotionFlattening: scrubMotionFlattening ?? this.scrubMotionFlattening,
    releaseVerticalStretch:
        releaseVerticalStretch ?? this.releaseVerticalStretch,
  );

  /// Resolves the SDK's ordinary light/dark theme into neutral dock inputs.
  ///
  /// Applications with semantic tokens can construct the style directly.
  /// Optics and physical settling are opt-in, just as in the main constructor.
  /// Pressure/release customization retains the main constructor's defaults.
  /// [duration] retains its 200ms default; zero enables Flutter's existing
  /// nonanimated selection contract without reconstructing theme colors.
  /// Native UIKit retains system-owned motion.
  factory AppGlassNavigationStyle.fromTheme(
    ThemeData theme, {
    Color? heldBarSurfaceColor,
    Color? heldSurfaceColor,
    Color? heldShadowColor,
    Gradient? heldRimGradient,
    BoxShadow? heldInnerShadow,
    BoxShadow? heldInnerHighlight,
    Gradient? heldInnerHighlightGradient,
    double? heldSelectionVerticalInset,
    bool trackVerticalDrag = false,
    AppGlassNavigationScrubSelectionPolicy scrubSelectionPolicy =
        AppGlassNavigationScrubSelectionPolicy.continuous,
    double heldBlurSigma = 0,
    AppGlassNavigationItemSizing itemSizing =
        AppGlassNavigationItemSizing.equal,
    double refractionStrength = 0,
    double? foregroundRefractionEdge,
    double? foregroundMagnification,
    double foregroundDispersion = 0,
    double selectedBackdropDispersion = 0,
    SpringDescription? selectionSpring,
    bool animateSelectionDeformation = false,
    bool refractForegroundDuringInteraction = false,
    double pressedScale = 0.97,
    double heldBarScale = 1,
    double pressureStretch = 0.04,
    double scrubVerticalScale = 1,
    double scrubMotionStretch = 0,
    double scrubMotionFlattening = 0,
    double releaseVerticalStretch = 0,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    assert(
      _isValidSelectionSpring(selectionSpring),
      'selectionSpring mass, stiffness and damping must be finite and positive',
    );
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return AppGlassNavigationStyle(
      surfaceColor: colors.surface.withValues(alpha: 0.74),
      heldBarSurfaceColor: heldBarSurfaceColor,
      selectedSurfaceColor: colors.surfaceContainerHighest.withValues(
        alpha: 0.78,
      ),
      heldSurfaceColor: heldSurfaceColor,
      heldShadowColor: heldShadowColor,
      heldRimGradient: heldRimGradient,
      heldInnerShadow: heldInnerShadow,
      heldInnerHighlight: heldInnerHighlight,
      heldInnerHighlightGradient: heldInnerHighlightGradient,
      heldSelectionVerticalInset: heldSelectionVerticalInset,
      trackVerticalDrag: trackVerticalDrag,
      scrubSelectionPolicy: scrubSelectionPolicy,
      heldBlurSigma: heldBlurSigma,
      foregroundColor: colors.onSurface,
      selectedForegroundColor: colors.primary,
      disabledForegroundColor: colors.onSurface.withValues(alpha: 0.45),
      outlineColor: colors.outlineVariant.withValues(alpha: 0.55),
      shadowColor: colors.shadow.withValues(alpha: dark ? 0.24 : 0.14),
      pressedSurfaceColor: colors.onSurface.withValues(alpha: 0.08),
      badgeBackgroundColor: colors.primary,
      badgeForegroundColor: colors.onPrimary,
      avatarBackgroundColor: colors.primaryContainer,
      avatarForegroundColor: colors.onPrimaryContainer,
      highlightColor: Colors.white.withValues(alpha: dark ? 0.12 : 0.44),
      selectionOutlineColor: Colors.white.withValues(alpha: dark ? 0.1 : 0.5),
      focusColor: colors.primary.withValues(alpha: 0.2),
      itemSizing: itemSizing,
      refractionStrength: refractionStrength,
      foregroundRefractionEdge: foregroundRefractionEdge,
      foregroundMagnification: foregroundMagnification,
      foregroundDispersion: foregroundDispersion,
      selectedBackdropDispersion: selectedBackdropDispersion,
      selectionSpring: selectionSpring,
      animateSelectionDeformation: animateSelectionDeformation,
      refractForegroundDuringInteraction: refractForegroundDuringInteraction,
      pressedScale: pressedScale,
      heldBarScale: heldBarScale,
      pressureStretch: pressureStretch,
      scrubVerticalScale: scrubVerticalScale,
      scrubMotionStretch: scrubMotionStretch,
      scrubMotionFlattening: scrubMotionFlattening,
      releaseVerticalStretch: releaseVerticalStretch,
      duration: duration,
      labelStyle: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: 10,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
      badgeStyle: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
      initialsStyle: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Minimum logical-pixel target enforced even in release builds.
  static const double minimumTouchTarget = 48;

  /// Flutter's outer surface tint; high contrast makes it opaque.
  final Color surfaceColor;

  /// Optional full-contact outer-bar tint for a fitting, growing Flutter lens.
  ///
  /// Null preserves [surfaceColor]. Actual contact pressure blends only the
  /// outer tint using [duration] and [curve], independently of accepted-selection
  /// feedback and the capsule's [heldSurfaceColor]. This adds no backdrop pass
  /// and changes no decoration, geometry, targets or selection requests.
  /// Scrolling, reduced motion, zero duration and high contrast keep the ordinary
  /// surface. Native UIKit ignores this Flutter-only customization. Resolve
  /// semantic light/dark colors and contrast in the caller's theme; this is not
  /// native optical calibration.
  final Color? heldBarSurfaceColor;

  /// Flutter's moving capsule fill; high contrast makes it opaque.
  final Color selectedSurfaceColor;

  /// Full-pressure tint for a portable fitting, growing lens sharing the
  /// original backdrop.
  ///
  /// Null resolves to [surfaceColor]. The caller's UI kit owns semantic color
  /// conversion; this does not change the outer bar or resting selected fill.
  /// Native UIKit owns its material and is unaffected by this Flutter input.
  final Color? heldSurfaceColor;

  /// Held-lens tint with the backward-compatible surface fallback resolved.
  Color get resolvedHeldSurfaceColor => heldSurfaceColor ?? surfaceColor;

  /// Optional decorative edge gradient for a fitting, growing Flutter held
  /// lens, faded with local pressure or accepted-selection feedback.
  ///
  /// Null preserves the ordinary outline. This is an edge-appearance
  /// approximation, not native optical reproduction, and does not change lens
  /// dimensions or motion. Native UIKit and high-contrast rendering ignore it.
  /// The caller's UI kit owns semantic light/dark gradient resolution.
  final Gradient? heldRimGradient;

  /// Optional inset shading inside a fitting, growing Flutter held lens.
  ///
  /// Null leaves the lens unchanged. The shadow fades with pressure, is clipped
  /// inside the existing capsule, beneath destination artwork and captions. Its
  /// offset shifts the clear center (positive Y shades the top edge); positive
  /// spread narrows it. Resolve color and geometry in the caller's theme.
  /// Non-finite geometry is ignored. Native UIKit and high contrast ignore it.
  /// This is decorative depth, not another backdrop blur or native material.
  final BoxShadow? heldInnerShadow;

  /// Optional inset light above [heldInnerShadow], beneath destination artwork.
  ///
  /// Uses the same clipped outside-hole geometry as the shadow, with a
  /// caller-resolved highlight color, blur, spread and offset. This separates
  /// a bright lip from deeper shading without widening the outline or changing
  /// scene blur, capsule geometry, input or semantics. Null preserves the
  /// existing appearance. Pressure fades it; native UIKit and high contrast
  /// ignore it. Invalid geometry disables only this decorative treatment.
  /// Only the thin rim is painted after foreground refraction, so opaque inset
  /// light cannot erase a caption when the lens crosses it.
  final BoxShadow? heldInnerHighlight;

  /// Optional colored inset band above the solid [heldInnerHighlight].
  ///
  /// Null preserves the existing solid highlight. A valid
  /// [resolvedHeldInnerHighlight] with positive spread must exist; the gradient
  /// does not paint by itself or replace the bright outer lip. The band is
  /// centered inward by one quarter of the highlight's spread, half its stroke
  /// width. Its stroke width is half the spread and its blur sigma is one quarter
  /// of the highlight's; it follows the highlight offset and clips to the lens.
  /// Highlight color alpha and pressure multiply gradient opacity.
  /// Empty or non-finite band geometry is ignored. The caller resolves semantic
  /// light/dark colors.
  /// Existing held-decoration eligibility and high-contrast suppression apply.
  /// This Flutter-only decoration changes no layout, input, backdrop pass or
  /// native UIKit material, and does not reproduce native optics.
  final Gradient? heldInnerHighlightGradient;

  /// Keeps a fitting Flutter dock gesture active when it starts vertically.
  ///
  /// Defaults to false: a vertical escape cancels horizontal selection. When
  /// true, a pan beginning on an enabled destination tracks its horizontal
  /// position even outside the bar and may request that destination. The host
  /// still accepts/rejects every request; actual pointer cancellation restores
  /// its selection. Scrolling layouts retain long-press scrubbing. This does
  /// not change native UIKit gestures or reduced-motion accessibility behavior.
  final bool trackVerticalDrag;

  /// Selection-request timing for fitting Flutter scrubs, continuous by default.
  ///
  /// [AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane] preserves
  /// local tracking without requests until an owner releases inside the visible
  /// bar's horizontal bounds, including content insets but not exterior lens
  /// growth or shadow. Only its final enabled, grab-adjusted destination may be
  /// requested, and the host still accepts or rejects it. Outside/cancelled
  /// releases settle with zero cancellation velocity. No vertical bound is
  /// imposed. Scrolling long-press scrubs, taps, keyboard activation and native
  /// UIKit behavior are unchanged. Changing this policy cancels a fitting
  /// contact before it can commit under the new policy.
  final AppGlassNavigationScrubSelectionPolicy scrubSelectionPolicy;

  /// Finite inset-shadow input, or null when disabled or invalid.
  BoxShadow? get resolvedHeldInnerShadow => _finiteInset(heldInnerShadow);

  /// Finite inset-highlight input, or null when disabled or invalid.
  BoxShadow? get resolvedHeldInnerHighlight => _finiteInset(heldInnerHighlight);

  static BoxShadow? _finiteInset(BoxShadow? shadow) {
    if (shadow == null ||
        !shadow.blurRadius.isFinite ||
        shadow.blurRadius < 0 ||
        !shadow.spreadRadius.isFinite ||
        !shadow.offset.dx.isFinite ||
        !shadow.offset.dy.isFinite) {
      return null;
    }
    return shadow;
  }

  /// Ordinary caption and glyph color, also Flutter's high-contrast border.
  final Color foregroundColor;

  /// Selected caption and glyph color, also Flutter's high-contrast capsule edge.
  final Color selectedForegroundColor;

  /// Flutter caption and glyph color for disabled destinations.
  final Color disabledForegroundColor;

  /// Flutter's outer surface border color outside high-contrast mode.
  final Color outlineColor;

  /// Flutter's outer surface shadow color.
  final Color shadowColor;

  /// Optional outer shadow color for a growing Flutter held capsule.
  ///
  /// Null resolves to [shadowColor], preserving the existing appearance.
  /// Pressure multiplies its alpha without changing the shadow's blur, offset
  /// or geometry, the resting bar shadow, or the inner bevel. Native UIKit
  /// owns its material and is unaffected by this Flutter-only input.
  final Color? heldShadowColor;

  /// Held-capsule shadow color with the backward-compatible fallback resolved.
  Color get resolvedHeldShadowColor => heldShadowColor ?? shadowColor;

  /// Flutter destination press and hover overlay color.
  final Color pressedSurfaceColor;

  /// Background color of built-in Flutter and native text badges.
  final Color badgeBackgroundColor;

  /// Text color of built-in Flutter and native text badges.
  final Color badgeForegroundColor;

  /// Background color of the local portrait's initials fallback.
  final Color avatarBackgroundColor;

  /// Text color of the local portrait's initials fallback.
  final Color avatarForegroundColor;

  /// Color at the upper-left edge of Flutter's diagonal specular wash.
  final Color highlightColor;

  /// Flutter's capsule border color outside high-contrast mode.
  final Color selectionOutlineColor;

  /// Flutter destination keyboard-focus overlay color.
  final Color focusColor;

  /// Caption typography, merged with the inherited text style in Flutter.
  ///
  /// Destination foreground colors override its color. Native iOS uses the
  /// resolved font size with a system font rather than the complete text style.
  final TextStyle labelStyle;

  /// Built-in Flutter badge typography; [badgeForegroundColor] sets its color.
  final TextStyle badgeStyle;

  /// Portrait fallback typography; [avatarForegroundColor] sets its color.
  final TextStyle initialsStyle;

  /// Nominal interactive row height, excluding [contentInset].
  final double actionHeight;

  /// Minimum target dimension, never below [minimumTouchTarget].
  final double minTargetSize;

  /// Width allocation for a fitting Flutter track; defaults to equal targets.
  ///
  /// [AppGlassNavigationItemSizing.contentBalanced] adds equal spare space to
  /// each caption/artwork minimum. Foreground, hit targets, semantics, scrubbing
  /// and capsule interpolation all use those same resulting widths. Overflow
  /// and large-text tracks retain measured scrolling; native eligibility and
  /// UIKit destination allocation are unchanged.
  final AppGlassNavigationItemSizing itemSizing;

  /// Logical-pixel glyph size used by Flutter and native glyph rasterization.
  final double iconSize;

  /// Flutter's square artwork slot and minimum item width in logical pixels.
  final double iconArea;

  /// Logical-pixel size used for local portrait rendering and rasterization.
  final double avatarSize;

  /// Nominal outside margin on each horizontal edge of the Flutter surface.
  ///
  /// Narrow layouts reduce this margin to preserve room for a minimum target.
  final double horizontalInset;

  /// Logical-pixel space above the Flutter surface, included in [dockHeight].
  final double topInset;

  /// Final bottom reserve in logical pixels, included in [dockHeight].
  ///
  /// The caller must include any required device safe-area reserve.
  final double bottomInset;

  /// Vertical padding inside the Flutter surface, included in [surfaceHeight].
  ///
  /// Also supplies horizontal padding unless [horizontalContentInset] is set.
  /// Narrow layouts reduce padding to preserve room for a minimum target.
  final double contentInset;

  /// Optional horizontal padding inside the Flutter surface, in logical pixels.
  ///
  /// Null preserves [contentInset]. This changes available destination width,
  /// not vertical height. Native caption eligibility uses the resolved value;
  /// UIKit continues to own native surface and capsule geometry.
  final double? horizontalContentInset;

  /// Horizontal content padding with the backward-compatible default resolved.
  double get resolvedHorizontalContentInset =>
      horizontalContentInset ?? contentInset;

  /// Logical-pixel vertical gap between Flutter's artwork slot and caption.
  final double labelGap;

  /// Logical-pixel padding on each side of a complete Flutter caption.
  ///
  /// This padding contributes to the destination's measured minimum width.
  final double labelPadding;

  /// Flutter corner radius for the surface, capsule, targets and text badges.
  final double radius;

  /// Flutter backdrop-blur sigma on both axes; zero or high contrast omits blur.
  final double blurSigma;

  /// Full-pressure blur sigma for a fitting, growing Flutter selected lens
  /// sharing the original scene backdrop.
  ///
  /// Defaults to zero, preserving the clear held endpoint. Local pressure or
  /// accepted-selection feedback interpolates from [blurSigma] toward
  /// [resolvedHeldBlurSigma]. Must be finite and nonnegative. This does not
  /// change the base bar, foreground optics or UIKit material.
  final double heldBlurSigma;

  /// Safe held blur, never greater than the finite, valid resting [blurSigma].
  ///
  /// Invalid release-mode held inputs resolve to zero. An invalid resting blur
  /// also resolves this endpoint to zero.
  double get resolvedHeldBlurSigma {
    if (!heldBlurSigma.isFinite ||
        heldBlurSigma < 0 ||
        !blurSigma.isFinite ||
        blurSigma < 0) {
      return 0;
    }
    return math.min(heldBlurSigma, blurSigma);
  }

  /// Requested maximum bevel displacement for the Impeller backdrop lens.
  ///
  /// Zero keeps the original blur-only treatment. Unsupported backends, failed
  /// shader loading and high contrast retain deterministic usable fallback.
  /// Native UIKit owns its optical material and ignores this Flutter input.
  /// Displacement fades to zero at the clipped edge and is bounded relative to
  /// the resolved bevel width to prevent an excessively steep sampling bend.
  /// Tune together with [refractionEdge], whose effective width is clamped to
  /// the lens's inscribed half extent and corner radius. A zero radius disables
  /// directional bevel displacement/dispersion, not center magnification.
  /// Values are in logical pixels.
  final double refractionStrength;

  /// Requested logical-pixel optical edge width, clamped to the half extent.
  ///
  /// Directional bevel effects additionally clamp to [radius] to avoid a seam
  /// where nearest-edge normals meet. Center magnification keeps the original
  /// half-extent-clamped envelope, including for square corners.
  final double refractionEdge;

  /// Optional logical-pixel edge width for Flutter's interaction foreground.
  ///
  /// Null preserves [refractionEdge]. This independently controls the bevel
  /// and center-magnification transition of the foreground pass without
  /// changing the static backdrop lenses, layout or hit targets. The shader
  /// retains its half-extent and corner-radius bounds. Requires
  /// [refractForegroundDuringInteraction]; native UIKit ignores this input.
  /// Must be finite and greater than zero.
  final double? foregroundRefractionEdge;

  /// Safe foreground edge width, preserving the shared width when unset.
  ///
  /// Invalid release-mode overrides fall back to [refractionEdge], or its
  /// constructor default of 12 logical pixels if that input is also invalid.
  double get resolvedForegroundRefractionEdge {
    final foreground = foregroundRefractionEdge;
    if (foreground != null && foreground.isFinite && foreground > 0) {
      return foreground;
    }
    return refractionEdge.isFinite && refractionEdge > 0 ? refractionEdge : 12;
  }

  /// Center magnification for the Flutter backdrop lens, never below one.
  ///
  /// Foreground remains sharp unless [refractForegroundDuringInteraction] is
  /// enabled and local pressure or accepted-selection feedback is active.
  final double magnification;

  /// Optional center magnification for Flutter's interaction-only foreground.
  ///
  /// Null preserves [magnification]. When [refractForegroundDuringInteraction]
  /// is enabled, local pressure or accepted-selection feedback blends from
  /// neutral to this value without changing the static backdrop lenses.
  /// Must be finite and at least one. Native UIKit ignores this input.
  final double? foregroundMagnification;

  /// Safe foreground magnification, preserving the shared default when unset.
  ///
  /// Invalid release-mode overrides fall back to [magnification], or one when
  /// that legacy backdrop input is also invalid.
  double get resolvedForegroundMagnification {
    final foreground = foregroundMagnification;
    if (foreground != null && foreground.isFinite && foreground >= 1) {
      return foreground;
    }
    return magnification.isFinite && magnification >= 1 ? magnification : 1;
  }

  /// Maximum Flutter interaction-foreground channel offset, in logical pixels.
  ///
  /// Defaults to zero, preserving shared RGB sampling. When
  /// [refractForegroundDuringInteraction] is enabled, red and blue sample on
  /// opposite sides of the bevel normal, bounded by the effective bevel width
  /// and faded to identity at the clip boundary and at rest. Static backdrop
  /// lenses and UIKit material remain unchanged. Must be finite and nonnegative.
  /// This is a portable edge-dispersion approximation, not UIKit optics.
  final double foregroundDispersion;

  /// Safe foreground dispersion; invalid release-mode inputs disable it.
  double get resolvedForegroundDispersion =>
      foregroundDispersion.isFinite && foregroundDispersion >= 0
      ? foregroundDispersion
      : 0;

  /// Maximum selected-backdrop channel offset, in logical pixels.
  ///
  /// Defaults to zero. Applies only to a fitting, growing Flutter selected lens
  /// sharing the original scene backdrop, scaled with local pressure or
  /// accepted-selection feedback. It never changes the base bar, foreground
  /// optics or UIKit material. Must be finite and nonnegative.
  final double selectedBackdropDispersion;

  /// Safe selected-backdrop dispersion; invalid release-mode inputs disable it.
  double get resolvedSelectedBackdropDispersion =>
      selectedBackdropDispersion.isFinite && selectedBackdropDispersion >= 0
      ? selectedBackdropDispersion
      : 0;

  /// Logical-pixel stroke width of Flutter's surface and capsule borders.
  final double outlineWidth;

  /// Logical-pixel blur radius of Flutter's outer surface shadow.
  final double shadowBlur;

  /// Logical-pixel vertical offset of Flutter's outer surface shadow.
  final double shadowOffset;

  /// Minimum logical-pixel width of the built-in Flutter text badge.
  final double badgeMinWidth;

  /// Minimum logical-pixel height of the built-in Flutter text badge.
  final double badgeMinHeight;

  /// Horizontal logical-pixel padding inside the built-in Flutter text badge.
  final double badgePadding;

  /// Distance beyond Flutter's artwork slot at the badge's top and trailing edge.
  final double badgeOffset;

  /// Optional Flutter trailing-edge badge offset, independent of its top offset.
  ///
  /// Null preserves [badgeOffset] on both axes. This mirrors with text direction,
  /// changes only badge painting/layout and never enlarges destination targets.
  /// Native UIKit retains its own badge placement.
  final double? badgeHorizontalOffset;

  /// Effective trailing-edge offset, preserving the legacy default.
  double get resolvedBadgeHorizontalOffset =>
      badgeHorizontalOffset ?? badgeOffset;

  /// Flutter capsule inset from each horizontal destination edge.
  ///
  /// Clamped to half the target width, in logical pixels.
  final double selectionHorizontalInset;

  /// Additional Flutter-only visual capsule extent on each horizontal side.
  ///
  /// Defaults to zero. Clamped to the available horizontal content gutter;
  /// destination targets and slot centres do not expand. Pressure and spring
  /// overshoot remain bounded by the outer surface. Reduced motion retains
  /// this static geometry. Vertical geometry and native UIKit are unchanged.
  final double selectionHorizontalOutset;

  /// Flutter capsule inset from each vertical destination edge.
  ///
  /// Clamped to half the target height, in logical pixels.
  final double selectionVerticalInset;

  /// Optional Flutter-only per-side visual inset at full capsule feedback.
  ///
  /// In fitting, growing lenses, interpolates from [selectionVerticalInset]
  /// with local pressure or accepted-selection deformation. Null preserves the
  /// fixed resting inset. Static rest, reduced motion, zero duration and
  /// scrolling retain [selectionVerticalInset]. This changes no destination
  /// target, row/surface layout or native UIKit geometry. Values are logical
  /// pixels, must be finite and nonnegative, and are clamped to half the row
  /// height when rendered.
  final double? heldSelectionVerticalInset;

  /// Safe full-feedback inset, preserving the resting inset when unset.
  ///
  /// Invalid release-mode overrides fall back to [selectionVerticalInset].
  double get resolvedHeldSelectionVerticalInset {
    final inset = heldSelectionVerticalInset;
    return inset != null && inset.isFinite && inset >= 0
        ? inset
        : selectionVerticalInset;
  }

  /// Text-scale threshold that forces labeled docks into Flutter's viewport.
  ///
  /// Compared against the inherited text scaler's scale of one logical pixel;
  /// reaching this threshold also disables native rendering.
  final double largeTextScale;

  /// Gradient stop where Flutter's diagonal specular wash becomes transparent.
  final double highlightMidpoint;

  /// Fraction of [highlightColor]'s alpha at Flutter's lower-right wash edge.
  final double bottomHighlightFactor;

  /// Flutter timed capsule, pressure, release and destination-reveal duration.
  ///
  /// Reduced motion bypasses these animations while retaining selection requests.
  /// When [selectionSpring] is set, settling uses physics instead of this timed
  /// duration; a zero duration still snaps all movement immediately.
  final Duration duration;

  /// Curve for Flutter capsule, pressure and destination-reveal animations.
  final Curve curve;

  /// Optional physical spring for Flutter capsule settling and interruption.
  ///
  /// Null preserves timed [duration]/[curve] movement. Reduced motion or zero
  /// [duration] snaps immediately. This is not a UIKit spring calibration.
  /// Mass, stiffness and damping must each be finite and positive. Const styles
  /// validate these nested inputs when [resolvedSelectionSpring] is read;
  /// [AppGlassNavigationStyle.fromTheme] validates them during construction.
  final SpringDescription? selectionSpring;

  /// Brief Flutter capsule deformation after an accepted selection change.
  ///
  /// Defaults to false. Outside an active scrub, a changed `selectedIndex`
  /// supplied by the host pulses the existing [pressureStretch]/[pressedScale]
  /// axes over [duration]. Rejected requests do not change selection and do not
  /// pulse. Retargeting preserves current deformation; pointer pressure and
  /// this pulse combine by maximum, never addition. Reduced motion and zero
  /// duration suppress it. UIKit owns its own motion and ignores this input.
  ///
  /// The host index is supplied to the dock widget; this style owns no state.
  final bool animateSelectionDeformation;

  /// Opt-in foreground lens while portable interaction feedback is active.
  ///
  /// A transparent pass above the single destination row refracts already
  /// painted glyphs, captions and badges within the moving capsule. It uses
  /// [refractionStrength], [resolvedForegroundRefractionEdge] and
  /// [resolvedForegroundMagnification],
  /// weighted by local feedback. It never duplicates widgets, semantics or hit
  /// targets.
  /// Resting, reduced-motion, zero-duration and high-contrast content stays
  /// sharp. Unsupported/cropped filter inputs retain the ordinary foreground.
  /// Defaults to false; native UIKit owns its optics and ignores this input.
  final bool refractForegroundDuringInteraction;

  /// Safe spring for the renderer, or null for timed movement.
  ///
  /// Invalid configured parameters fall back to [duration]/[curve] in every
  /// mode, avoiding NaN geometry and a permanently running undamped simulation.
  /// The theme factory additionally asserts invalid inputs in debug builds.
  SpringDescription? get resolvedSelectionSpring {
    final spring = selectionSpring;
    final valid = _isValidSelectionSpring(spring);
    return valid ? spring : null;
  }

  static bool _isValidSelectionSpring(SpringDescription? spring) =>
      spring == null ||
      (spring.mass.isFinite &&
          spring.mass > 0 &&
          spring.stiffness.isFinite &&
          spring.stiffness > 0 &&
          spring.damping.isFinite &&
          spring.damping > 0);

  /// Base scale on both axes of Flutter's capsule.
  ///
  /// This is local to [heldBarScale]. Reduced motion uses an unscaled capsule.
  final double selectionScale;

  /// Vertical multiplier at full Flutter capsule press, on [selectionScale].
  ///
  /// Values above one let a fitting dock's decorative lens rise outside the
  /// bar, using its exterior horizontal inset for pressure width. Scrolling
  /// docks remain clipped. This capsule-only input does not expand destination
  /// targets or semantics; [heldBarScale] can separately scale the whole bar.
  /// Growing lenses blend their selected tint toward [surfaceColor] while held.
  /// Reduced motion disables this press response.
  final double pressedScale;

  /// Whole-bar multiplier at full pointer pressure in a fitting, growing
  /// Flutter dock, including its artwork, capsule, targets and semantics.
  ///
  /// Defaults to one. Expansion is bounded by the existing horizontal, top and
  /// bottom exterior insets; no layout space is added. Scrolling, high contrast,
  /// reduced motion and zero duration retain an unscaled bar. This uses actual
  /// contact pressure, not accepted-selection deformation, and does not affect
  /// native UIKit. Capsule geometry inputs remain local to this transform, so
  /// their painted scale compounds with the bar scale. Must be finite and >= 1.
  final double heldBarScale;

  /// Safe whole-bar multiplier; invalid release-mode styles leave it unscaled.
  double get resolvedHeldBarScale =>
      heldBarScale.isFinite && heldBarScale >= 1 ? heldBarScale : 1;

  /// Fractional width increase at full Flutter capsule press, on [selectionScale].
  ///
  /// Reduced motion disables this press response.
  final double pressureStretch;

  /// Experimental vertical paint multiplier during a fitting Flutter scrub.
  ///
  /// Defaults to one, preserving the existing capsule exactly. Values in
  /// (0, 1] compress the pressure-derived height once a drag is recognized,
  /// blending in and out with [duration]/[curve]. A stationary contact before
  /// recognition keeps its ordinary press height; a recognized scrub retains
  /// compression until release or cancellation, even when the pointer pauses.
  /// This is a customization experiment, not a calibrated UIKit motion curve.
  ///
  /// Only capsule/optical painting changes. Destination layout, hit targets,
  /// focus, semantics and selection requests remain unchanged. Scrolling,
  /// reduced motion, zero duration and native UIKit ignore this input. Live
  /// changes retarget from the current multiplier; one restores the neutral
  /// treatment. Must be finite and greater than zero, and at most one.
  final double scrubVerticalScale;

  /// Safe scrub multiplier; invalid release-mode values keep neutral painting.
  double get resolvedScrubVerticalScale =>
      scrubVerticalScale.isFinite &&
          scrubVerticalScale > 0 &&
          scrubVerticalScale <= 1
      ? scrubVerticalScale
      : 1;

  /// Maximum additional horizontal growth from fitting Flutter drag motion.
  ///
  /// Zero preserves existing painting. Values in [0, 1] multiply capsule width
  /// by up to `1 + scrubMotionStretch`, within available lane containment.
  /// Motion excites a recovering follower: continued movement deforms the lens,
  /// while a pause recovers its ordinary held shape without ending contact.
  /// Recovery uses [selectionSpring] or a spring derived from [duration]. This
  /// paint-only
  /// approximation changes no targets, semantics or selection requests and is
  /// not a UIKit physics calibration. Scrolling, reduced motion, zero duration
  /// and native UIKit ignore it.
  final double scrubMotionStretch;

  /// Safe drag stretch; invalid release-mode values disable it.
  double get resolvedScrubMotionStretch =>
      scrubMotionStretch.isFinite &&
          scrubMotionStretch >= 0 &&
          scrubMotionStretch <= 1
      ? scrubMotionStretch
      : 0;

  /// Maximum fractional height reduction from fitting Flutter drag motion.
  ///
  /// Zero preserves existing painting. Finite values in [0, 1) multiply height
  /// by up to `1 - scrubMotionFlattening`, after pressure and
  /// [scrubVerticalScale]. Unlike that sustained scrub option, this deformation
  /// recovers during a stationary hold. It shares [scrubMotionStretch]'s motion
  /// and eligibility contract; native UIKit retains its own geometry and motion.
  final double scrubMotionFlattening;

  /// Safe drag flattening; invalid release-mode values disable it.
  double get resolvedScrubMotionFlattening =>
      scrubMotionFlattening.isFinite &&
          scrubMotionFlattening >= 0 &&
          scrubMotionFlattening < 1
      ? scrubMotionFlattening
      : 0;

  /// Optional Flutter-only fractional height recovery after a pointer release.
  ///
  /// Defaults to zero, preserving existing motion. A bounded zero-to-zero hump
  /// over [duration] is weighted by pressure captured at release and added to
  /// the capsule's vertical scale while ordinary pressure decays. This changes
  /// only decorative capsule/optical painting, never destination targets,
  /// focus, semantics or native UIKit. New input, cancellation, reflow, reduced
  /// motion and zero duration suppress recovery. Must be finite and nonnegative.
  final double releaseVerticalStretch;

  /// Safe release recovery amplitude; invalid release-mode styles disable it.
  double get resolvedReleaseVerticalStretch =>
      releaseVerticalStretch.isFinite && releaseVerticalStretch >= 0
      ? releaseVerticalStretch
      : 0;

  /// Nominal height of the rounded glass surface.
  ///
  /// The Flutter renderer grows beyond this when complete scaled labels need
  /// additional height. Native UIKit may require a larger measured lane.
  double get surfaceHeight =>
      math.max(actionHeight, math.max(minTargetSize, minimumTouchTarget)) +
      contentInset * 2;

  /// Nominal total lane height, including the caller's final bottom reserve.
  ///
  /// This is not an exact rendered-height contract: scaled Flutter labels or
  /// UIKit's public system-bar measurement may require more space. Let the
  /// scaffold measure the widget and reserve matching body clearance.
  double get dockHeight => surfaceHeight + topInset + bottomInset;
}

class _UnchangedStyleValue {
  const _UnchangedStyleValue();
}

const _unchangedStyleValue = _UnchangedStyleValue();

double? _resolveNullableDoubleStyleOverride(
  Object? value,
  double? currentValue,
  String argumentName,
) => _resolveNullableStyleOverride<num>(
  value,
  currentValue,
  argumentName,
)?.toDouble();

T? _resolveNullableStyleOverride<T extends Object>(
  Object? value,
  T? currentValue,
  String argumentName,
) {
  if (identical(value, _unchangedStyleValue)) return currentValue;
  if (value == null) return null;
  if (value is T) return value;
  throw ArgumentError.value(value, argumentName, 'Expected $T or null');
}
