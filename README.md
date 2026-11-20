# Liquid Glass Bottom Navigation for Flutter

A controlled floating bottom-navigation dock with native UIKit glass on
compatible iOS layouts and a Flutter renderer on Android. The caller owns
selection, navigation, theme, labels and
artwork. The package owns only local rendering, focus and gesture mechanics.

Native UIKit and Flutter rendering have distinct optics and motion.

## Install and run

~~~sh
flutter pub add cupertino_bottom_nav_bar
~~~

Import the public library:

~~~dart
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
~~~

Use Flutter's [Material UI package](https://pub.dev/packages/material_ui) for
`MaterialApp` and `AppGlassNavigationStyle.fromTheme` with the examples below.
Add it to the host's direct dependencies with `flutter pub add material_ui`.
If the host uses its own theme system, supply the resolved colors and text
styles to `AppGlassNavigationStyle`.

Enable `uses-material-design: true` in the host when using Material glyphs.
The package declares its bundled `shaders/glass_refraction.frag` shader; keep
that declaration when copying the package. Shader or plugin metadata changes
require a full rebuild, not only hot reload.

The [standalone example](example/README.md) includes Android/iOS runners,
controlled-selection feedback and a manual verification matrix. Its iOS runner
uses Swift Package Manager without requiring CocoaPods; the package still
provides both integration paths for other consumers.
For branding and geometry recipes, start with
[theme-based customization](#start-with-your-theme-then-customize) and the
[Flutter/UIKit support table](#which-customizations-affect-each-renderer).
See [CHANGELOG.md](CHANGELOG.md) for release details.

## Requirements and platform behavior

| Area | Contract |
| --- | --- |
| Dart / Flutter | Dart `^3.13.2`, Flutter `>=3.47.2`: the previously build-verified floor. Current checks use Flutter 3.47.5 / Dart 3.13.4 after an external SDK update. Older Flutter is not supported; the native wrapper uses `UiKitView.gestureBlockingPolicy`. |
| Dependencies | Flutter SDK and the Material UI toolkit. |
| Android | Flutter renderer. Selected debug and arm64 release-mode checks used Impeller/OpenGLES; other renderer/backend combinations need their own validation. |
| iOS | Plugin deployment target 15.0. Genuine UIKit glass requires compatible iOS 26+ runtime/layout; earlier or incompatible cases use Flutter. Building the native implementation requires an iOS 26.1+ SDK. |
| iOS integration | CocoaPods and Swift Package Manager metadata are included. Selected current-toolchain simulator builds validate both integration paths, not physical-device signing or every SDK/runtime. |
| Other targets | Flutter fallback exists in source; desktop/web runtime support is not accepted. |

Native iOS owns its material, capsule geometry and animation. Flutter-specific
style fields do not retune UIKit. The portable material remains an approximation
of UIKit, not a reproduction of its private optics or physics.

The earlier Flutter 3.44 declaration was too low: its `UiKitView` constructor
does not provide the gesture-blocking policy used by the native wrapper.
Platform checks cannot hide missing Dart symbols from compilation. The floor
retains the previously validated Flutter 3.47.2 / Dart 3.13.2 baseline. The later
external update to Flutter 3.47.5 / Dart 3.13.4 does not raise the declared floor
or the separate iOS deployment and native-glass runtime requirements; this
follow-up is not a fresh execution on the older toolchain.

## Controlled usage

~~~dart
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

Widget buildDock(
  BuildContext context, {
  required int selectedIndex,
  required ValueChanged<int> onSelectionRequested,
}) {
  return CustomGlassNavigationDockWidget(
    selectedIndex: selectedIndex,
    onItemSelected: onSelectionRequested,
    style: AppGlassNavigationStyle.fromTheme(Theme.of(context)),
    items: const [
      AppGlassNavigationItem(icon: Icons.explore_outlined, label: 'Explore'),
      AppGlassNavigationItem(icon: Icons.star_outline, label: 'Featured'),
      AppGlassNavigationItem(
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        label: 'Likes',
        badgeLabel: '3',
      ),
      AppGlassNavigationItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
      AppGlassNavigationItem(
        icon: Icons.person_outline,
        label: 'Profile',
        nativeImage: AppGlassNavigationImage(initials: 'AR'),
      ),
    ],
  );
}
~~~

Accept a request by rebuilding with the requested `selectedIndex`; reject it
by retaining the previous index. The dock does not change routes, persist
selection or choose a state-management framework. Keep the destination body and
dock driven by the same accepted host index.

### Public widgets and items

- `CustomGlassNavigationDockWidget`: automatic renderer selection, three to
  five items, `preferNative: true`, `iconOnly: false` and container
  `semanticLabel: 'Primary navigation'` by default.
- `CustomFlutterGlassNavigationDockWidget`: direct portable renderer, at least
  two items, the same controlled selection/style inputs and caller-owned route
  visibility. Use it, or `preferNative: false`, for consistent Flutter rendering.
- `AppGlassNavigationItem`: required `icon` and resolved `label`; optional
  `selectedIcon`, `iconWidget`, `selectedIconWidget`, `nativeImage`,
  `badge`, `badgeLabel`, `semanticLabel`; `enabled` defaults to true.
  Selection must be a valid item index.
- `AppGlassNavigationImage`: optional bundled `assetPath`/`assetPackage`
  and required fallback `initials`. Missing assets fall back to initials.
  Supply equivalent `nativeImage` data alongside custom portrait widgets
  when native rendering is wanted.
- `AppGlassNavigationItemSizing`: `equal` (default) or `contentBalanced`.
- `AppGlassNavigationScrubSelectionPolicy`: `continuous` (default) or
  `onReleaseWithinLane` for fitting Flutter tracks.

A custom badge replaces the built-in text badge visually and has duplicate
semantics excluded. Supply `badgeLabel` for its meaning. That text is appended
to the resolved item accessibility label; `semanticLabel` overrides the
caption's label. Disabled items cannot request selection through taps, keyboard
activation or scrubbing. Arbitrary icon widgets without equivalent portrait
data and custom badge widgets use Flutter rendering.

Portable pointer feedback admits only the primary button, matching its tap and
drag recognizers. Secondary and combined-button presses cannot claim contact,
preview a destination or move/grow the lens. Keyboard and semantics activation
retain their independent paths.

## Layout, safe areas and visibility

Flutter measures complete captions and artwork while enforcing targets of at
least 48 × 48 logical pixels. Equal fitting tracks divide widths evenly.
Content-balanced tracks allocate each measured minimum plus an equal share of
remaining space; paint, input, semantics and capsule geometry share those
boundaries. This is not UIKit's private width-allocation formula.

Narrow or large-text tracks scroll instead of truncating destinations or
shrinking targets. Ordinary swipes scroll; long-press dragging scrubs selection.
Focus and external selection reveal an item, deferring that reveal during an
active scrub. RTL uses logical destination order and directional badge placement.
Caption measurement uses the ambient `Localizations` locale, matching rendered
text. Locale-only changes invalidate cached measurements; unchanged inputs
reuse them. Regional-font appearance still needs host verification.
Caption height also resolves `DefaultTextStyle.textHeightBehavior` before
`DefaultTextHeightBehavior`. That same resolved value reaches both measurement
and rendered text, including across the dock's internal Material surface.
Only effective behavior changes invalidate the measurement cache.

The caller owns safe-area and keyboard clearance. `bottomInset` is the final
reserved space below the surface, not an automatic safe-area addition. Avoid
counting the system bottom inset twice. `surfaceHeight` and `dockHeight` are
nominal measurements: scaled captions and publicly measured native lane height
can grow. Let a parent such as `Scaffold.bottomNavigationBar` measure the dock
rather than forcing a height that clips captions or UIKit.

### Put scrolling content behind the glass

With `Scaffold.bottomNavigationBar`, set `extendBody: true` so the body paints
behind the dock. Otherwise the dock filters the scaffold background, not the
scrolling content. Reserve the **measured** dock height at the end of the scroll
view so its final content can move fully above the dock:

~~~dart
Widget buildGlassPage(
  BuildContext context, {
  required String title,
  required int selectedIndex,
  required ValueChanged<int> onSelectionRequested,
  required List<AppGlassNavigationItem> items,
  required List<Widget> children,
}) {
  final style = AppGlassNavigationStyle.fromTheme(Theme.of(context)).copyWith(
    bottomInset: MediaQuery.viewPaddingOf(context).bottom + 8,
  );

  return Scaffold(
    extendBody: true,
    appBar: AppBar(title: Text(title)),
    body: Builder(
      builder: (bodyContext) => ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(bodyContext).bottom + 16,
        ),
        children: children,
      ),
    ),
    bottomNavigationBar: CustomGlassNavigationDockWidget(
      selectedIndex: selectedIndex,
      onItemSelected: onSelectionRequested,
      items: items,
      style: style,
    ),
  );
}
~~~

Use the imports from [Controlled usage](#controlled-usage). The inner `Builder`
reads the body-specific `MediaQuery` supplied by `Scaffold`, whose bottom
padding includes the actual dock height. The outer context supplies the system
safe inset once through the style; do not wrap this dock in another bottom
`SafeArea`. The scroll padding is content clearance, not a second dock inset.
Avoid replacing it with a fixed `style.dockHeight`: larger labels or the measured
native lane can make the dock taller. If building a custom stack, paint the
backdrop content before the dock and provide equivalent measured clearance.

The automatic widget retains layout but hides paint and excludes pointer input,
focus, semantics and animation ticks when its Flutter modal route is not
current. With no modal route, custom overlays, or the direct Flutter widget,
visibility is caller-owned. Retained inactive destination bodies also need
their own input, focus, semantics and animation exclusions.

The automatic widget also tracks pointer streams hit-tested through its own
subtree and requests SDK cancellation when its route becomes noncurrent or
the subtree is removed. A callback guard rejects late requests while covered,
inactive, disposed, or awaiting cancellation dispatch. This does not cancel
unrelated pointers or own navigation state. Cancellation with disabled tickers
snaps portable feedback to the latest host selection, so deferred animation
cannot revive the cancelled gesture on return; visible cancellation still
settles normally. Portable widget tests cover late UP while declaratively
covered and an immediate next-frame return with retained state. They also cover
synchronous cover/return before queued cancellation dispatch: pending taps and
owned release-only scrubs reject stale requests with either CANCEL or an
earlier UP, then accept the next tap. These are portable Flutter binding-order
checks; native/device races remain separate release checks.

## Selection and gesture contract

Requests are not accepted state. With the default `continuous` policy, the enabled item under
the sampled, grab-offset-adjusted capsule center is requested when it changes.
Callbacks can occur before release, and sparse input can skip destinations.
There is no promise of one callback per crossed slot, equal callback counts
across input devices, or native callback timing.

Set `style.scrubSelectionPolicy` to
`AppGlassNavigationScrubSelectionPolicy.onReleaseWithinLane` to preview a fitting
scrub without changing the host's page while held. Owner release requests the
final enabled destination once, only if it differs from the latest host index
and the raw pointer is horizontally within the visible surface, including its
content padding. Exterior lens/shadow overflow is excluded. Releasing outside
that lane or cancelling makes no request and settles to the host's index with
zero cancellation momentum. Exiting and re-entering before release is allowed.
Vertical exit alone does not cancel an opted-in pan. Taps, keyboard activation,
scrolling long-press scrubs and UIKit retain their existing behavior. Changing
policy during contact cancels the current scrub; this option does not establish
identical UIKit callback timing or motion.

A matching fitting-scrub host acceptance through the first post-release frame
continues the existing pressure recovery without adding another
accepted-selection deformation pulse. The capsule still retargets from its live
spring geometry and velocity.
The marker expires after that frame; rejected or later accepted requests cannot
suppress an unrelated selection pulse. This is a portable feedback correction,
not a guarantee of UIKit timing. Continuous-policy scrub feedback is unchanged.

The same first-frame acknowledgement rule applies to a completed, nonscrub
pointer hold on a fitting growing lens (`pressedScale > 1`). The owner must have
held for at least the configured motion duration, pressure must have completed
expansion, and its preview must still match its pressed destination. Raw UP
records that eligibility; only the matching pointer-only `InkWell.onTapUp`
qualifies it before the selection callback. Accepted selection then continues
the existing pressure recovery instead of launching a second shrink/regrow
pulse. Quick taps, programmatic changes, keyboard/semantics activation, rejected
requests and late acknowledgement retain their existing behavior. Cancellation,
new contact and geometry/lifecycle invalidation clear eligibility. Selection
remains host-owned; this does not establish native release-motion parity.

For an ordinary-motion fitting growing lens (`pressedScale > 1`), raw contact
on an enabled item may preview its lens and artwork without a selection
callback. The host body and semantic selection remain unchanged. Tap activation
still requests on release; cancellation/rejection settles toward the latest
accepted host index. Cancellation does not undo requests already accepted by
the host.

The first raw contact owns a gesture until up/cancel; a second already-down
pointer cannot take it over. This is component gesture ownership, not global
multi-touch suppression. Manual touch-tooltip handling avoids a stationary
tooltip stealing either fitting or scrolling gestures; hover tooltips and
accessible labels remain available.

`trackVerticalDrag` defaults to false: fitting layouts use horizontal
recognition and vertical rejection. Opting in uses SDK pan recognition and
tracks X even after initially vertical motion or movement outside the bar.
A vertical exit can therefore request a destination; it is not inherently
cancellation. Actual pointer cancellation uses zero release velocity and
settles toward the host. Scrolling tracks retain long-press scrubbing.

Painted-lens regrabs can cache a grab offset and freeze a moving capsule across
enabled slots. Only fitting, growing `trackVerticalDrag` contacts that actually
hit the painted lens follow owner-pointer X before recognition, preserving the
captured offset/size without callbacks or semantic selection changes. At
raw-move time, captured geometry uses size-dependent lane containment, not an
extra clamp to the first/last destination center. A narrower settling lens can
legally sit beyond those centers; regrabbing it must not snap it inward. At
recognition, the handoff does not cancel already-tracked horizontal pointer
velocity. Geometric center/size correction remains: a captured endpoint
overshoot can relax toward the destination-center bound even with stationary
pointer X. Distant unselected previews, default horizontal recognition and
scrolling behavior are unchanged.
Remaining preview handoffs use independent center/size corrections seeded
from projected preview motion minus SDK owner-pointer velocity; early release
retains their derivatives. The timed fallback preserves position continuity
only. Release qualification stays SDK-owned; finite horizontal pan velocity is
capped independently of vertical speed. These mechanics do not establish native
trajectory, speed-cap execution or timing identity.

With `heldBarScale > 1`, fitting scrub and caught-lens raw-move positions stay
projected through the current bar expansion even when the pointer stops moving.
A repeated sample at the same position does not repair a stale local anchor.
Release, cancellation and host/spring retargeting continue from the projected
held rectangle. This is pointer-following correctness, not native spring tuning.

Geometry changes invalidate live scrub/raw-down coordinates before deferred
owner-gated cleanup. Changing `trackVerticalDrag` cancels contact before
recognizer replacement. During fitting live contact, crossing the
`pressedScale > 1` boundary also cancels and settles before changed clipping
ancestry replaces the recognizer, even if a host update already cleared the
preview. Pixel demo checks cover both directions of this live style switch:
later movement from the old owner makes no request, and the next new tap works.
These bounded checks and package tests do not replace
runtime verification of live reflow, style toggles, trackpads and rapid regrabs.

## Style and customization

`AppGlassNavigationStyle` is immutable and has a const constructor.
Resolve application design tokens before construction. The
`AppGlassNavigationStyle.fromTheme(ThemeData)` factory derives light/dark
colors and caption styles; direct construction exposes every field.

### Start with your theme, then customize

`copyWith` covers every constructor input. Omitted fields retain their resolved
values, so changing a margin does not discard your theme's colors or typography.
Resolve the style inside a theme-aware build method to follow theme changes.

~~~dart
final theme = Theme.of(context);
final themed = AppGlassNavigationStyle.fromTheme(theme);
final branded = themed.copyWith(
  selectedForegroundColor: theme.colorScheme.tertiary,
  badgeBackgroundColor: theme.colorScheme.tertiary,
  badgeForegroundColor: theme.colorScheme.onTertiary,
  labelStyle: themed.labelStyle.copyWith(fontWeight: FontWeight.w600),
);
~~~

Choose portable geometry independently of branding. The 48-pixel minimum target
still applies; safe-area space is owned by your host. This example includes it
in `bottomInset`, so do not add it a second time around the dock.

~~~dart
final compact = branded.copyWith(
  horizontalInset: 12,
  bottomInset: MediaQuery.viewPaddingOf(context).bottom + 8,
  radius: 28,
  iconSize: 22,
  horizontalContentInset: 6,
  badgeHorizontalOffset: 4,
  itemSizing: AppGlassNavigationItemSizing.contentBalanced,
);
~~~

For a more expressive Flutter treatment, opt into motion and optics. These
sample values are customization examples; assess contrast and performance over
your own content. Choose `preferNative: false` on the dock to use these controls
on iOS too; eligible native UIKit keeps its system material and motion.

~~~dart
final expressive = branded.copyWith(
  blurSigma: 18,
  refractionStrength: 5,
  pressedScale: 1.12,
  pressureStretch: 0.12,
  animateSelectionDeformation: true,
  selectionSpring: const SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 34,
  ),
);

// Explicit null clears a nullable option and restores its documented fallback.
final timed = expressive.copyWith(
  selectionSpring: null,
  heldRimGradient: null,
  heldShadowColor: null, // Restore the shared shadowColor fallback.
  duration: const Duration(milliseconds: 180),
);
~~~

All thirteen nullable options support explicit clearing. Their override parameters
accept their documented field type or null; nullable numeric overrides also
accept integer literals and convert them to double. A wrong value type throws
an `ArgumentError` naming the field. For nonnullable fields, null retains the
current value. `copyWith` preserves the constructor's validation and accessible
target requirements.

The standalone example demonstrates theme palettes, rounded versus pill-shaped
Flutter corners and a blur slider through this same API. Its expressive glass
settings are demonstration choices rather than package defaults.

Accepted selection in the example rebuilds only its title, status, card text and
dock. The control panel, scrolling list, resolved style and item inputs remain
stable across selection changes. This preserves focus, scroll position and live
contact while reducing unrelated host rebuild work. Configuration changes still
update the full configuration-dependent surface; rejection and Reset remain
host-owned. Three example regressions cover rebuild isolation, held-contact
continuity and those selection/configuration boundaries.

### Which customizations affect each renderer?

| Control | Flutter | Native UIKit |
| --- | --- | --- |
| Selection, enabled state, labels and semantic labels | Caller-controlled | Caller-controlled |
| Selected/ordinary foreground and built-in badge colors | Configurable | Forwarded to UIKit |
| Glyphs and bundled portraits | Configurable | Rasterized from resolved inputs |
| Caption font | Full resolved text style | Resolved size with system font |
| Arbitrary icon widgets or custom badges | Supported | Uses Flutter when native-equivalent content is unavailable |
| Shape, capsule allocation, badge offsets, border and shadow | Configurable | System-owned geometry/material |
| Blur, refraction, inner bevel, spring, duration and pressure | Configurable | System-owned optics/motion |
| Experimental `scrubVerticalScale` | Paint-only vertical compression during recognized fitting scrubs | Ignored; system-owned motion |
| `scrubMotionStretch`, `scrubMotionFlattening` | Motion-driven capsule deformation that recovers during a held pause | Ignored; system-owned motion |
| Scrolling-content response | Live filtered backdrop with caller-resolved fixed tint | UIKit-owned material response |
| Fitting scrub selection policy | Continuous requests or release within lane | System-owned gesture timing/boundary |
| Safe-bottom reserve | Caller-owned | Caller-owned; measured native height may grow |

Fallback selection remains automatic for unsupported content, layout or
accessibility preferences. Style overrides cannot force native rendering or
bypass minimum targets and explicit accessibility fallback checks;
`largeTextScale` remains a caller-configurable native text-scale threshold.

The portable tint is deliberately predictable for caption contrast. It is not
UIKit's material algorithm: photo-background comparisons can still look flatter
and less locally varied, even when geometry and backdrop updates align. Lowering
opacity alone is not an accepted fix if it loses readable foreground contrast.
Exact optical identity is not promised by these controls.

### Geometry and typography defaults

All numbers below are logical pixels unless noted.

| Fields | Defaults / meaning |
| --- | --- |
| `actionHeight`, `minTargetSize` | 48, 48; the enforced minimum target is 48. |
| `itemSizing` | `equal`; `contentBalanced` affects fitting Flutter tracks only. |
| `iconSize`, `iconArea`, `avatarSize` | 24, 32, 24. |
| `horizontalInset`, `topInset`, `bottomInset` | 16, 4, 8; outer placement/clearance. |
| `contentInset`, `horizontalContentInset` | 4, null → `contentInset`; independent vertical/horizontal content padding. |
| `labelGap`, `labelPadding`, `radius` | 2, 4, 999. |
| `selectionHorizontalInset`, `selectionHorizontalOutset`, `selectionVerticalInset` | 2, 0, 0; resting capsule geometry, not target size. Outset is bounded by available gutter. |
| `heldSelectionVerticalInset` | null → `selectionVerticalInset`; optional per-side visual inset at full feedback in fitting growing Flutter lenses. |
| `outlineWidth`, `shadowBlur`, `shadowOffset` | 0.75, 20, 2. |
| `badgeMinWidth`, `badgeMinHeight`, `badgePadding` | 20, 16, 2. |
| `badgeOffset`, `badgeHorizontalOffset` | 2, null → `badgeOffset`; horizontal placement is directional trailing, finite and nonnegative. |
| `largeTextScale` | 1.3; native eligibility threshold, not a cap on accessible Flutter text. |
| `highlightMidpoint`, `bottomHighlightFactor` | 0.5, 0.12. |
| `labelStyle` | Size 10, height 1.35, weight 500. |
| `badgeStyle`, `initialsStyle` | Size 10/11, height 1, weight 700. |

`surfaceHeight = max(actionHeight, minTargetSize, 48) + contentInset × 2`;
`dockHeight` adds top/bottom insets. Destination foreground colors override
caption-style color. UIKit uses resolved font size with a system font, not the
complete Flutter font family/weight/metrics.

### Color defaults

| Fields | Const-constructor defaults (ARGB) |
| --- | --- |
| `surfaceColor`, `selectedSurfaceColor` | `BDFFFFFF`, `BDEDEDEF` |
| `heldBarSurfaceColor` | null; optional full-contact outer-bar tint, ordinary surface unchanged by default. |
| `heldSurfaceColor` | null → `surfaceColor` |
| `foregroundColor`, `selectedForegroundColor`, `disabledForegroundColor` | `FF27272A`, `FF18181B`, `FF89898D` |
| `outlineColor`, `selectionOutlineColor`, `highlightColor` | `66FFFFFF`, `80FFFFFF`, `70FFFFFF` |
| `shadowColor`, `pressedSurfaceColor`, `focusColor` | `24000000`, `1427272A`, `3327272A` |
| `heldShadowColor` | null → `shadowColor`; Flutter held capsule's outer shadow only. |
| `badgeBackgroundColor`, `badgeForegroundColor` | `FF27272A`, `FFFFFFFF` |
| `avatarBackgroundColor`, `avatarForegroundColor` | `FFE4E4E7`, `FF27272A` |

The theme factory resolves these from the supplied theme rather than retaining
the const palette. Applications remain responsible for contrast and semantic
light/dark tokens.

### Motion, optics and held appearance defaults

| Fields | Defaults / meaning |
| --- | --- |
| `duration`, `curve` | 200 ms, `Curves.easeOutCubic`. |
| `selectionSpring` | null → timed settling; optional SDK `SpringDescription`. |
| `animateSelectionDeformation` | false; optional accepted-host-selection pulse. |
| `selectionScale`, `pressedScale`, `pressureStretch` | 1, 0.97, 0.04; resting scale, vertical pressure scale, horizontal pressure growth. |
| `heldBarScale` | 1; optional whole-bar scale from actual contact pressure in fitting growing layouts, bounded by exterior insets. |
| `scrubVerticalScale` | 1; experimental fitting-scrub vertical paint multiplier in `(0, 1]`, neutral by default. |
| `scrubMotionStretch`, `scrubMotionFlattening` | 0, 0; optional movement-driven width growth `[0, 1]` and fractional height reduction `[0, 1)`. |
| `releaseVerticalStretch` | 0; optional owner-eligible vertical release recovery. |
| `trackVerticalDrag` | false; fitting pan tracking is opt-in. |
| `scrubSelectionPolicy` | `continuous`; opt-in `onReleaseWithinLane` commits a fitting scrub only on valid owner release. |
| `blurSigma`, `heldBlurSigma` | 20, 0; shared selected-scene blur moves from base to held endpoint. |
| `refractionStrength`, `refractionEdge`, `magnification` | 0, 12, 1.03; backdrop refraction is opt-in. |
| `refractForegroundDuringInteraction` | false; optional foreground post-process only during interaction. |
| `foregroundMagnification` | null → `magnification`; independently configurable foreground magnification. |
| `foregroundDispersion`, `selectedBackdropDispersion` | 0, 0; independent pressure-only edge dispersion. |
| `heldRimGradient`, `heldInnerShadow` | null, null; optional pressure-faded decorative edge/depth. |
| `heldInnerHighlight` | null; optional clipped inset light above the shadow and below the rim. |
| `heldInnerHighlightGradient` | null; optional colored inset band above the solid highlight, requiring a valid highlight with positive spread. |

The theme factory accepts item sizing, held outer-bar/capsule surface/outer shadow/rim/inner shadow/highlight
and highlight-gradient,
held selection vertical inset, vertical tracking, held blur, refraction strength,
foreground magnification/dispersion, selected-backdrop dispersion, spring,
deformation, foreground refraction, pressed scale, held-bar scale, pressure
stretch, experimental scrub vertical scale, motion stretch/flattening, release recovery and duration
overrides. Duration retains 200ms by default; zero suppresses portable movement,
not UIKit's system-owned motion.
Use `fromTheme(...).copyWith(...)` to override other geometry, typography and
optical controls while retaining theme values, or construct a complete style
directly.

Optional `heldBarSurfaceColor` blends the outer Flutter bar from `surfaceColor`
to a caller-resolved tint using actual contact pressure, the existing `duration`
and `curve`. It applies only to fitting growing contacts (`pressedScale > 1`),
not accepted-selection feedback. Null preserves existing behavior; scrolling,
reduced motion, zero duration and high contrast retain the ordinary surface.
Only the outer color changes: the wash/outline, backdrop input and blur,
viewport, labels, targets and host-owned selection remain unchanged. There is
no additional ticker or backdrop pass. UIKit ignores this input, and the
capsule-only `heldSurfaceColor` retains its separate meaning. Resolve light/dark
tokens and check contrast over your own content; this customization is not
native optical calibration. `copyWith` omission preserves the override,
explicit `heldBarSurfaceColor: null` clears it, and other types throw a
field-named `ArgumentError`.

Optional `heldShadowColor` independently colors the growing Flutter capsule's
outer shadow. Direct construction and the theme factory default to null, which
resolves to `shadowColor` and preserves existing behavior. Existing capsule
pressure multiplies the resolved color's alpha; blur, offset, shadow geometry,
resting bar shadow and inner bevel are unchanged. Native UIKit owns its material
and ignores this input. `copyWith` omission retains the override, while explicit
`heldShadowColor: null` restores the fallback; a non-Color, non-null override
throws a field-named `ArgumentError`.

Spring mass, stiffness and damping must be finite and positive; invalid spring
inputs resolve to timed settling (the theme factory also asserts in debug).
Held blur resolves into 0…valid base blur; invalid held/base values resolve to
zero. Dispersion and release recovery resolve invalid values to zero.
Held-bar scale must be finite and ≥1; invalid release-mode inputs resolve to 1.
Held selection vertical inset must be finite and nonnegative; null or invalid
release-mode values resolve to `selectionVerticalInset`. Both vertical insets
are clamped to half the resolved row height when rendered.
Foreground magnification requires a finite value ≥1 and otherwise falls back to
the valid backdrop value. Inset shadow and highlight require finite spread/offset
and finite nonnegative blur; invalid input disables only that decoration. The
painter also skips individual treatments whose derived bounds overflow. These
guards do not make arbitrary invalid styles supported.

Capsule-only growth can paint above the bar and into exterior horizontal
gutter without enlarging touch targets. Default and scrolling clip behavior is
unchanged. Accepted-selection deformation and contact pressure share a bounded
maximum, not additive pulses; rejected requests alone do not pulse. Release
recovery occurs once per eligible owner release, never transfers residual
pressure to an untouched item, and resets on cancellation, a new press, reflow,
reduced motion or zero duration. App-specific tuning is not a UIKit calibration.

Experimental `scrubVerticalScale` is available through the const constructor,
`fromTheme` and `copyWith`. Its default `1` preserves existing painting. Finite
values in `(0, 1]` compress the pressure-derived capsule height only after a
fitting Flutter drag is recognized, blending with the existing `duration` and
`curve`. This multiplies the pressure-derived paint height, not an absolute
height; it compounds with the ancestor `heldBarScale` and other capsule scale/
release inputs. A stationary pre-drag hold keeps its ordinary height; recognized
scrubs retain compression through pauses until up/cancel. Live changes retarget
from the current multiplier; invalid release-mode values resolve to `1`.
Only capsule/optical painting changes, not layout, targets, focus, semantics or
selection requests. Scrolling, reduced motion, zero duration and native UIKit
ignore this option. It is a customization experiment, not UIKit calibration or
motion-parity evidence.

`scrubMotionStretch` and `scrubMotionFlattening` opt into deformation driven by
fitting Flutter drag movement. Both default to zero through the constructor,
`fromTheme` and `copyWith`. Finite stretch in `[0, 1]` increases capsule width by
up to `1 + scrubMotionStretch`, bounded by the available lane. Finite flattening
in `[0, 1)` reduces height by up to `1 - scrubMotionFlattening`, after pressure
and `scrubVerticalScale` are applied. Invalid release-mode values resolve to zero.

Movement excites a recovering follower; a stationary pause restores the ordinary
held shape while contact remains down. Recovery uses the existing
`selectionSpring` or a critically damped spring derived from `duration`.
This differs from `scrubVerticalScale`,
which stays compressed throughout a recognized scrub. Only capsule and optical
painting change: targets, semantics, host selection and request timing retain
their existing contracts. Scrolling, reduced motion, zero duration and native
UIKit ignore these inputs. This bounded portable treatment is not a calibration
of UIKit physics.

Optional `heldSelectionVerticalInset` interpolates the capsule's visual inset
from `selectionVerticalInset` using the bounded maximum of local pressure and
accepted-selection deformation, before capsule scaling. A smaller held inset
can restore visual height during feedback without increasing `pressedScale`.
Null preserves the existing fixed inset. Static rest, scrolling, reduced motion,
zero duration and nongrowing lenses (`pressedScale <= 1`) do not interpolate.
High contrast follows the same capsule-geometry eligibility; its optical
suppression is separate. Destination targets, row/surface/lane layout and
native UIKit geometry remain unchanged. This is a portable styling option,
not a claim of calibrated UIKit motion.

Optional `heldBarScale` instead transforms the whole fitting growing bar,
including artwork, capsule, targets and semantics. It uses actual contact
pressure, not accepted-selection deformation, and preserves child/backdrop
identity. Growth is bounded by existing horizontal/top/bottom exterior insets;
the capsule uses only the remaining gutter converted back to child-local units,
not the original inset twice. It adds no layout space. Scrolling, reduced motion, zero duration and high
contrast leave the bar unscaled; UIKit is unchanged. Capsule scales compound
with this ancestor transform, so compensate local values when preserving a
painted endpoint. Input resolves global positions against the current track
rather than its stale down-time hit transform; SDK X velocity is projected from
down-time to current scale and includes the off-center scale-rate term, without
replacing its tracker or qualification. Raw up captures the incoming scale,
estimated rate and relative position before pressure reverses; recognizer end
uses that owner snapshot once, and invalidation clears it. The rate uses the
SDK timed simulation's finite-difference estimate, not an exact curve derivative.
This does not compensate the bar's deliberate release-direction change or
establish full world-space C1 or native trajectory calibration.

Held edges reuse the same clipped outside-hole painter in two instances.
`heldInnerShadow`, `heldInnerHighlight` and optional
`heldInnerHighlightGradient` paint below the single artwork/caption row and
are included in the existing foreground lens's scene input. Only the thin
`heldRimGradient` paints after the foreground shader, inside the existing
outline width while the scalar outline fades out. Inset decoration therefore
does not paint over the row, including when scrub paint height is compressed.
This prevents opaque inset overdraw, not foreground-refraction distortion:
the optional shader can still bend or separate caption/artwork pixels. Set
`refractForegroundDuringInteraction: false` to isolate that optical treatment
from the inset layering.
The optional highlight uses caller-resolved color, blur, spread and offset to
add a bright inner lip without widening the outline. Positive Y shifts the
clear center downward; positive spread narrows it. These decorations fade with
lens feedback and add no backdrop filter. The layering fix changes no API,
style values, geometry, scene blur, input, semantics or native UIKit behavior.
High contrast ignores the decorations; null preserves existing appearance.

For a thick held rim with a small corner radius, the renderer clips the rim to
the existing outer lens when the stroke's half-width exceeds that radius or
the stroke reaches the lens's shortest side. This contains corner ink without
changing lens geometry. Ordinary thin rounded/pill rims retain their original
unclipped draw path.

Optional `heldInnerHighlightGradient` adds a colored inset band above the solid
highlight but below the artwork/caption row, preserving its bright outer lip.
Both direct construction and the theme factory default this input to null.
A valid resolved `heldInnerHighlight` with positive spread is required.
The band center is inset by one quarter of the
highlight's spread, half the existing stroke width, placing it at the outer lip.
Its stroke width is half the spread and its blur sigma is one quarter the
highlight's blur sigma. It follows the highlight offset and is
clipped to the lens. Gradient alpha is multiplied by highlight color alpha and
lens feedback. Empty or non-finite band geometry is skipped. Existing held
decoration eligibility and high-contrast suppression apply. It adds no backdrop
pass or save layer and changes no targets, layout or native UIKit behavior.
A raster regression covers lip placement and rounded-corner clipping; it does
not establish composed shader or native optical parity.

## Native eligibility and fallbacks

Native rendering is a preference, not a force switch. It requires visible
captions, LTR, ordinary motion/text preferences, compatible artwork/badges,
complete caption/minimum-target fit and enough measured lane height.
Icon-only, large text, reduced motion, bold text, high contrast, custom badges,
unsupported artwork and MediaQuery line-height/letter-/word-spacing
accessibility overrides use Flutter. A spacing override of zero is still explicit.

The native platform view prepares behind the fallback. Native paint, input and
accessibility become active only after the current payload revision succeeds
and public UIKit measurement confirms width/height fit. The lane can grow; a
parent that cannot accommodate it uses Flutter. Missing plugin discovery or
failed native updates use Flutter. Platform-view creation errors retain normal
Flutter diagnostics; they are not silently swallowed.

### Portable glass implementation

The bundled shader uses `ImageFilter.shader` on supported Impeller paths.
Other renderers use blur/tint fallback. Shader loading alone does not prove
pixel correctness or backend readiness.

Eligible fitting growing lenses (positive base blur/refraction, not high
contrast) share one stable per-dock backdrop input with the outer bar throughout
rest/contact. The selected lens replaces the bar treatment once: tint moves
from `alphaBlend(selectedSurfaceColor, surfaceColor)` to held surface, and blur
moves toward the held endpoint. Foreground remains unkeyed and uses the single
painted artwork row; no duplicate widgets, hit targets or semantics are added.

`foregroundRefractionEdge` optionally gives that foreground pass its own
positive finite edge width. Its default `null` resolves to `refractionEdge`;
`copyWith(foregroundRefractionEdge: null)` restores the shared value. The override
changes the foreground bevel and center-magnification envelope, retaining the
shader's radius/extent/displacement clamps. Static backdrop optics, native
UIKit, layout and selection are unaffected. The example uses 6 with
magnification 1.12. Refraction can alter caption shape and badge position;
check readability against the host's chosen typography and geometry.

Unsupported/no-shader shared paths retain a real keyed base-blur floor instead
of dropping the filter and tinting twice. Positive axis-aligned/nonuniform
transforms are supported; rotation, skew, reflection or unknown cropped-input
origins bypass refraction while retaining composed blur.

Bevel rays sample outward, so visible edge features compress toward the lens
interior rather than enlarging outward; center magnification is independent.
This applies to both backdrop and foreground optics, without badge-specific
transforms or exemptions. The renderer remains an approximation of glass, not
UIKit's private optical model.
Refraction displacement and its slope return continuously to zero at the
ellipse boundary; effective bevel/displacement are bounded to the available
capsule and corner radius. Small-radius custom styles therefore do not carry
directional refraction across an interior corner's nearest-edge-normal seam.
Radius zero disables bevel displacement and dispersion; center magnification
retains its independently resolved edge envelope. Ordinary pills with a radius
at least as large as the optical edge do not need the additional corner bound.
The strength bound protects the base ray at unit magnification; it does not
promise fold-free output for arbitrary magnification or dispersed channel rays.
Manual bilinear sampling smooths fractional glyph edges. Active dispersion mixes
the shared ray and opposite red/blue ray reconstruction equally, including
premultiplied coverage. This attenuates chromatic contrast without additional
samples; the maximum ray offsets remain bounded, while the effective channel
centroid displacement decreases. It affects both opted-in optical passes, not
UIKit, and is not a physical model of native glass. Zero dispersion retains the
original shared sampling. Fractional rays retain four texel reads per bilinear
sample, including all three dispersed rays where applicable. At an exact texel
center, all neighboring interpolation weights are zero, so the shader fetches
only the contributing texel. The check uses exact zero without rounding nearby
fractional coordinates. Pixels at or beyond the existing outside antialiasing
endpoint (physical edge distance ≥0.5) also return the identity sample before
inactive optical algebra. The rounded/anisotropic distance calculation and the
entire antialiasing transition remain unchanged. A conservative half-pixel-padded
rectangle guard skips distance/normal evaluation only where the full path is
already identity; normalized axes below one retain the complete path. Seven
sampling/AA raster regressions cover
identity/fallback reconstruction, transparent pixels, fractional sampling and
whole-fixture RGBA equivalence for rounded uniform and both nonuniform axes. These
shortcuts remove redundant work without changing configured optics; they do not
by themselves establish composed GPU cost or a frame-rate improvement.

Each optical render object retains only its latest exact filter description,
keyed by shader identity, blur and all caller-owned uniforms. Geometry resolves
and the live backdrop is submitted on every composition, even on a cache hit;
no scene pixels are captured or cached. Changed inputs create a new native
snapshot; detach/dispose clears the cache. Five backend-independent regressions
cover immutable inputs, invalidation, clear/failure behavior and live composition.
They do not execute Impeller shader-filter reuse.

The foreground is sharp at rest and in reduced-motion, zero-duration,
high-contrast or unsupported-input cases. High contrast uses opaque surfaces
without decorative blur/specular treatment. Reduced motion snaps decorative
movement while preserving controlled selection; static backdrop treatment can
remain. Zero duration resets live pressure/motion immediately.

## Accessibility, privacy and release status

Supply localized, resolved labels and meaningful badge text. Verify contrast,
focus traversal, screen readers, scaled text and reduced motion in the host;
style configuration alone is not acceptance. Tooltips remain available for
icon-only navigation. Host content must not remain focusable under covered or
retained inactive destinations.

The package performs no network requests, tracking, analytics or persistence.
Artwork is local/caller-provided. Its iOS privacy manifest declares no tracking,
tracking domains, collected data or accessed API types; the host remains
responsible for its own permissions, disclosures and data practices.

### Historical verification — 11 October 2026

Current source passes **293 package tests and 27 example tests**, scoped analysis
and 33-file formatting. The optional held outer-bar tint has twelve package
regressions; the example exposes it through an off-by-default trial control.
Its refreshed iOS build passes in 17.1s and forced-Flutter held taps and separate
forward/reverse endpoints pass (one test / zero failures, 26.120s). These bounded
checks do not accept exact optics, continuous motion or physical performance.

The fixed synthetic comparison canvas and example-only Balanced geometry reduce
measured horizontal capsule/center differences from UIKit. The 13-point native
versus portable lane-center difference remains. Runtime blur/tint trials are not
package defaults or main-app changes. Current Android follow-up and refreshed
exact-archive consumer verification remain pending. Earlier physical evidence
below used earlier source. Spoken TalkBack verification remained open at this checkpoint.

#### Historical October 10 checkpoint

That package/example checkpoint passed **281 package tests and 17 example tests**,
scoped package/example analysis and formatting pass. Private
foreground shader preparation now happens while the mounted pass is inactive;
zero-progress optics remain unfiltered, with no warm-up draw or claim of GPU
pipeline prewarming. The example isolates stable control paint under feedback
reflow. No package API, optical values or runtime dependency changed.

Earlier pre-calibration/pre-ordering IN2011 data at observed 60Hz retain 2,920 candidate frames (0 UI / 70
raster-stage overruns) and 938 baseline frames (0 / 10). Unequal launch counts and
sparse initial tap coverage prevent causal improvement/regression claims. Empty
settled-held overrun bins do not accept the observed strict frame-budget failures or
prove complete launch coverage. Pre-calibration native03 hold/separate forward/reverse
endpoints passed; Pixel stock-ADB endpoints are observed. Unsynchronized normalized
synthetic demo crops retain held-size, rim and caption differences. Fresh
token-matched app rest comparison has closer geometry/captions, so the demo
sizing mismatch is not a main-app geometry finding. Different viewport/safe-area
backgrounds and unverified fresh main-app hold/motion remain limitations;
later example-only height/caption/rim calibration passes three new regressions,
but its render/performance acceptance is not established by the earlier
14-test physical fixture. Calibrated Android/iOS builds and Pixel hold/forward/
reverse endpoints pass, but a native repeat fails before gestures with zero
native tab-bar buttons while Auto persists on Flutter fallback. Readiness cause
is under diagnosis, not established as calibration-caused; no new native held
capture from that failed run is claimed. A later ordered native measurement
publication fix passes five new regressions. The rebuilt iOS example (15.7s)
passes native05 with five genuine UIKit buttons and stationary hold/separate
forward/reverse endpoints (one test / zero failures, 32.373s). Fresh demo held crops
still show a narrower Android capsule and distinct edge/halo; differing
backgrounds/phases prevent exact motion or optical acceptance. The post-fix main
iOS build passes in 21.3s and both normal apps are visually restored to light
Discover/top scroll/normal text with keyboard capture off; Pixel's portable main
APK is unchanged. Package defaults and main-app tokens are unchanged.
Optics, motion and performance remain open: **this candidate is not launch-ready**.
The previous archive/build proof below certifies its old runtime only; no fresh
archive/consumer acceptance is claimed for these source changes. TalkBack and
name/license/publisher remain deferred; publication stays disabled.

#### Historical 270-test archive checkpoint

The current source passes **270 package tests** and **12 example tests**. Analysis
of `lib`, `test`, `example/lib` and `example/test` is clean; formatting checks 29
files with no changes. Seven sampling/AA raster regressions include whole-fixture
uniform/horizontal/vertical antialiasing-equivalence cases; five cache tests
cover exact filter reuse and lifecycle. The example tests cover isolated selection
rebuilds, retained interaction state and diagnostic ownership. An unarmed raw
contact observer no longer publishes diagnostic notifier updates; armed live
lens-switch behavior and owner cancellation remain intact. Current checks use Flutter
3.47.5 / Dart 3.13.4. The example adds only the approved SDK `flutter_test` development
dependency and its 16 test transitive dependencies; all ten previously locked
versions remain unchanged, including `meta` 1.18.3 and `vector_math` 2.4.0.
Runtime dependencies remain Flutter SDK-only. Eight release accessibility tests
cover target size, labels, contrast, unique badge
announcements, keyboard traversal/activation, disabled controls and reduced
motion across light/dark and relevant RTL configurations. Coverage also includes
movement/pause deformation, controlled selection, owned cancellation and next
tap, route visibility, light/dark and reduced motion, caption measurement,
native bridge failures and shipping-shader raster cases. Mocked bridge tests
do not execute UIKit; shader raster tests do not validate Impeller composition.

The preceding 258-test candidate's actual pub archive built in an independent
SDK-only consumer: Android debug (21s), Android release/AOT with vital lint (45s), and iOS
Simulator/SwiftPM (12.9s). Source/extraction hashes, compiled shader, native
registration and privacy resources passed provenance checks. Those builds
predate the changed shader and example entry and are historical.

The preceding 264-test optimized archive built in a new independent SDK-only consumer
using Flutter 3.47.5 / Dart 3.13.4: Android ARM64 release/AOT with vital lint
(71s) and iOS Simulator/SwiftPM debug/no-codesign (31.4s). Both packaged shaders
match their fresh build intermediates and asset dependencies reference the
archive's shader source. Android AOT matches its stripped intermediate; iOS
native registration is present in both simulator architectures and the plugin
privacy manifest matches the archive. All archive/source/extraction hashes match
after builds. Final README/CHANGELOG status updates are documentation-only
differences from the build-tested archive, with runtime/test/example bytes
unchanged; no additional platform build is claimed for those status updates.
These consumer products were not installed or visually checked. This is historical
build proof: it predates the exact-filter cache, rectangle guard and latest example
observer change.

The current actual archive builds in a fresh independent SDK-only consumer:
Android ARM64 release/AOT with vital lint (37s) and iOS Simulator/SwiftPM
debug/no-codesign (20.4s). The changed filter-cache source is referenced in each
platform's kernel dependency file; packaged shaders match fresh intermediates
and asset dependencies reference the archive shader. Android AOT matches its
stripped intermediate; iOS native registration is present in arm64/x86_64 and
plugin privacy bytes match the archive. Source/extraction hashes remain exact.
Final build-status edits affect only README/CHANGELOG, with every executable,
test, manifest and example file unchanged from the build-tested archive. No
second build is claimed for that docs-only delta, nor a consumer device launch.

The preceding candidate's bounded Pixel checks covered movement, a pause while
held, reversal, actual cancellation, rejection followed by acceptance, light/dark,
and 2× text with RTL scrolling. The independent release consumer accepted an Inbox
tap and Profile drag. On the selected iPhone, its native XCTest passed
**1 test, 0 failures in 16s**, covering forward and separate reverse contacts.
Native rejection/cancellation evidence remains from earlier checks of the
unchanged native implementation; that XCTest did not revalidate those paths or
same-contact reversal. Both normal main-app Discover baselines were visually
restored, with keyboard capture off at that checkpoint.

That candidate's native iOS consumer also passed **2 accessibility tests, 0 failures**:
ordered labels, selected state, a single badge value, enabled/hittable 94×54pt
targets, and an unfiltered XCTest audit for contrast, element detection, hit
regions, descriptions, text clipping and traits. VoiceOver speech and a separate
Dynamic Type audit were not run. TalkBack remains user-deferred. A later bounded
physical-phone profile check is recorded below; no accessibility or
keyboard-capture settings were changed.

### Historical Pixel performance measurements

The measurements in this section predate the shader and example rebuild
optimizations. Their named artifact results remain diagnostic history; the
current IN2011 before/after results are recorded below.

An ARM64 profile build on the existing Pixel 10 emulator (60Hz, Impeller/OpenGLES)
ran the same finite tap, held forward/pause/reversal/release/cancel and body-scroll
workload twice per configuration. Measurements cover the whole example, not
isolated dock GPU cost, hardware FPS or cold startup. The initial window starts
after the VM event subscription; the second is a warmed repeat.

| Configuration | Initial / warmed frames | Initial / warmed raster p99 | Initial / warmed raster frames over 16.667ms |
| --- | --- | --- | --- |
| Plain `AppGlassNavigationStyle.fromTheme` | 602 / 604 | 16.512 / 6.033ms | 5 / 0 |
| Expressive example preset | 901 / 902 | 18.820 / 18.461ms | 102 / 107 |

The plain defaults' warmed UI p99 was 3.251ms and raster maximum 11.912ms,
with no UI/raster/total-span budget exceedance in that bounded sample. Five
initial raster spikes occurred during destination taps. The expressive example
opts into refraction, foreground lens and moving/growing deformation; these are
not the package defaults. Its raster budget is **not accepted**. Disabling only
the foreground lens or only moving deformation did not eliminate exceedances;
variable host/scroll costs prevent reliable causal attribution. No visual effect
was silently downgraded. Profile each chosen configuration on target hardware
before making a production performance claim.

### Historical physical-phone performance measurements

These measurements also predate the shader and example rebuild optimizations.

The approved IN2011 on Android 13 ran both configurations in ARM64 profile mode
at 1080×2400 and density 480. The app's observed display mode was 60Hz before,
during and after each workload; the panel was at 90Hz before app launch. No phone
display setting was changed. Renderer logs contain both Impeller Vulkan and
OpenGLES initialization, so these measurements do not establish a single backend.

Each first/warmed window used the same 65-input whole-example sequence: taps,
held movement/pause/reversal, UP/CANCEL and body scrolling. Collection starts
after VM subscription, excluding cold startup. These timings are not isolated
dock GPU cost or presented/dropped-frame counts.

| Configuration | First / warmed frames | First / warmed UI p99 | First / warmed raster p99 | UI frames >16.667ms | Raster frames >16.667ms |
| --- | --- | --- | --- | --- | --- |
| Plain `AppGlassNavigationStyle.fromTheme` | 498 / 492 | 12.211 / 14.572ms | 10.558 / 8.919ms | 1 / 3 | 0 / 0 |
| Expressive example preset | 988 / 979 | 9.689 / 10.623ms | 15.831 / 15.833ms | 3 / 2 | 5 / 4 |

That sample completed the bounded physical-phone profile check. The defaults had no
raster-stage budget exceedance in these windows, but both configurations had UI
spikes and the expressive preset had raster spikes. Neither result establishes
jank-free behavior, broad hardware/backend acceptance or a production frame-rate
guarantee. The Pixel measurements above remain separate emulator diagnostics;
the phone results do not erase their configuration-specific exceedances.

### Historical IN2011 optimization replay

The final expressive preset ran the same matched 65-input workload twice on
IN2011 at observed 60Hz, using Flutter 3.47.5 / Dart 3.13.4. Across 995 first and
990 warmed frames, UI stages exceeded 16.667ms zero times; raster stages exceeded
it three and one times, with maxima 17.787 and 17.488ms. Matched destination-tap
UI p99 improved from 17.429 to 10.981ms initially and 21.351 to 12.616ms warmed.
Held raster p99 changed from 16.482 to 15.797ms initially and 15.811 to 15.991ms
warmed, so the held-raster result is mixed.

The final plain defaults sample has 498/497 frames, UI-budget exceedances 0/1
and raster exceedances 1/6, with raster p99 16.382/17.142ms. The earlier defaults
used a different SDK and are not a causal before/after comparison. These are
finite whole-example measurements after VM subscription, not cold startup,
isolated GPU cost or presented/dropped-frame counts. Residual raster attribution
and performance acceptance remain open; no visual effect was downgraded.

### Historical IN2011 continuous-input check

The final plain defaults and expressive example preset each completed one first
measured interaction window and three same-process warmed windows on IN2011 at
observed 60Hz, using Flutter 3.47.5 / Dart 3.13.4: 5,312 unique frames across eight
windows. Each used 15 actions: destination taps, native 1,800ms forward/reverse
swipes, a 1,500ms stationary DOWN/CANCEL, body swipes and a final tap. No held/crop
preconditioning or phone-setting change was used.

Both styles pass the finite warmed gate: every nonempty input phase's UI/raster
p99 remains within 16.667ms in all three warmed windows; no adjacent multi-frame
stage-overrun burst appears, and no frames are captured in the settled held bins
after 600ms. This is a qualified sampled pass, not a zero-jank guarantee.

Outliers remain. Defaults have initial raster maximum 22.639ms and warmed-window-2
UI maximum 17.393ms. Expressive initial forward recovery reaches 25.511ms raster;
initial CANCEL raster 16.736ms fails that small phase's p99 gate. Expressive
warmed window 1 retains tap UI 22.122ms and raster 21.808ms on different frames;
warmed windows 2/3 have no observed stage overruns. Sparse p99 cohorts can exclude
a single maximum: these maxima and the initial failure are not discarded.

Independent raw-frame/input-order checks support this finite result, not causal
attribution to any one optimization. Phases use command intervals and an affine
VM-clock mapping, not exact pointer timestamps. Collection excludes startup;
same-process repeats are not independent cold launches. Timings do not measure
isolated GPU cost or presentation/drop counts, nor establish 90/120Hz or broad
hardware/backend acceptance. Unconditional release/performance acceptance remains
open, and configured optics were not downgraded.

The current actual archive extraction's pub client dry-run reports the deferred
missing `LICENSE` as its only validation error, plus a homepage/repository advisory.
Archive, hash, build-provenance and no-upload validation evidence is preserved
separately from prior candidates.
Publication remains disabled. Earlier CocoaPods results are historical; no hosted
install is claimed.

### Technical release acceptance

The current candidate passes the automated checks stated above, not launch
acceptance. Its focused physical raster gate, live optical/motion calibration
and refreshed exact-archive platform verification remain open. The preceding
270-test source's platform and finite warmed results retain their historical
scope only. The historical
build, interaction/accessibility and profile results retain their named artifact
scope. They do not establish jank-free performance, cold-start performance, broad
hardware/backend coverage or spoken assistive-technology acceptance.
For later code changes, match archive and artifact hashes to the changed source
and repeat relevant build/interaction checks; earlier results cannot accept
later code.

Run the automated checks from this package directory:

~~~sh
dart format --output=none --set-exit-if-changed lib test example/lib example/test
dart analyze lib test example/lib example/test
flutter test --no-pub
~~~

Run `flutter test --no-pub` from the `example` directory for its seventeen separate
regressions.

Use the selected installed SDK and resolve dependencies before running these
commands. The example's [manual checks](example/README.md#manual-verification-matrix)
describe the controls and expected selection behavior.

### Documented limitations

The Flutter material and motion are approximations; exact UIKit optics and
physics are not promised. Desktop/web runtime support, exhaustive style/backend
and minimum-runtime coverage, spoken accessibility, trackpad behavior and broad
physical-device performance are not accepted. The finite emulator and phone
results above are diagnostic evidence, not a general frame-rate guarantee.
CocoaPods integration metadata is
included, but older CocoaPods build evidence must not be described as validation
of a later source snapshot. Hosts must verify their own artwork, typography,
contrast and screen-reader experience.

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 Raghav Verma.
