# Changelog

## Unreleased

- The Flutter renderer now keeps the selection capsule around the icon and
  caption. `selectionVerticalInset` and `heldSelectionVerticalInset` are capped
  at half the space the row has beyond its icon area, label gap and caption, so
  a large inset can no longer cut through the caption. The dock's size does not
  change. To keep a larger inset, raise `actionHeight`.
- The Flutter renderer now keeps the capsule off the surface's ends.
  `selectionHorizontalOutset` is capped at `horizontalContentInset` minus
  `contentInset`, so an end capsule keeps at least the same gap from the ends
  as the row has from the top and bottom. Previously an outset could fill the
  whole gutter, leaving the capsule flush with a rounded end. Default styles
  are unaffected. To keep an outset, widen `horizontalContentInset`.

## 0.2.2

- Clarified the floating tab bar, drag-to-select behavior, and platform support
  on the package page. Added the `tab-bar` topic.

## 0.2.1

- Linked the public source repository on GitHub.

## 0.2.0

- Migrated the Flutter renderer and example to Flutter's Material UI package.
  `AppGlassNavigationStyle.fromTheme` now takes the `ThemeData` type from
  `package:material_ui/material_ui.dart`. To integrate with your own theme
  system, pass colors and text styles through `AppGlassNavigationStyle`.
- Added a link to the package API reference and clarified the package summary.

## 0.1.0

Initial MIT-licensed release of `cupertino_bottom_nav_bar`. The floating
bottom navigation bar supports drag-to-select, a Flutter glass renderer, and
native UIKit glass on compatible iOS layouts.

### Added

- Optional Flutter-only `heldBarSurfaceColor` independently blends the outer
  bar's tint during eligible contact using the existing pressure animation.
  Null preserves existing behavior; `fromTheme` and sentinel `copyWith` support
  set/preserve/clear. It adds no filter or ticker and leaves stable decoration,
  backdrop, viewport and targets unchanged. Scrolling, reduced motion, zero
  duration, high contrast and non-growing layouts retain their ordinary surface;
  UIKit and capsule `heldSurfaceColor` are unchanged. Twelve regressions pass
  within the current 293-test package suite. The example offers an off-by-default
  trial, not accepted native optical calibration.
- Opt-in, passive comparison canvas in the standalone example keeps the
  synthetic backdrop fixed across scrolling and destination changes. Its
  example-only Balanced/inset19/visual-outset10 geometry improves bounded native
  and portable horizontal agreement at the measured viewport without enlarging
  hit regions. Package defaults and main-app tokens remain unchanged; this does
  not establish equal vertical placement, optics or motion.
- Exact-texel shader sampling fetches only the contributing texel when both
  bilinear weights are exactly zero. Fractional rays retain the complete
  reconstruction with no rounding or optics changes. Outside pixels return the
  identity sample at the existing physical antialiasing endpoint (distance ≥0.5),
  skipping inactive optical algebra while retaining the full transition and
  anisotropic geometry. A conservative padded-rectangle guard also skips
  distance/normal work only outside the existing AA region. Seven sampling/AA
  raster regressions cover identity/fallback,
  transparent pixels, fractional reconstruction and whole-fixture RGBA equivalence
  for rounded uniform/horizontal/vertical axes. All 270 package tests pass.
- Latest-only exact optical-filter cache keyed by shader identity, blur and all
  caller uniforms, with immutable input snapshots and detach/dispose invalidation.
  Geometry and live backdrop submission still refresh every scene; no pixels are
  captured or cached. Five tests cover reuse, invalidation, clear/failure behavior
  and live composition; they do not execute Impeller shader-filter reuse.
- Isolated example selection rebuilds for the title, status, card text and dock;
  controls, scrolling list, style and item inputs retain identity. Three example
  regressions cover rebuild isolation, held-contact continuity and host-owned
  rejection/configuration/Reset. The raw observer retains contact ownership but
  publishes no diagnostic notifier changes while the lens-switch probe is
  unarmed; nine further example regressions preserve armed/unarmed/Reset behavior.
  All 12 example tests pass; scoped analysis is clean and formatting checks 29
  files with no changes. Current IN2011 defaults and expressive presets pass
  all nonempty phase UI/raster p99 gates in three warmed windows each at observed
  60Hz (5,312 total frames, eight windows), without adjacent multi-frame stage
  overrun bursts or captured settled-held frames after 600ms. Initial and isolated
  tap/recovery outliers remain, including an initial expressive CANCEL-phase
  failure. This is a finite warmed pass, not zero jank or unconditional acceptance.
  Earlier Android release/AOT (71s) and iOS SwiftPM (31.4s) consumer builds are
  historical. The fresh actual archive passes independent consumer Android ARM64
  release/AOT with vital lint (37s) and iOS Simulator/SwiftPM (20.4s), with current
  filter-cache kernel dependencies, shader/intermediate and native/privacy
  provenance verified. Final build-status edits change only package docs; no
  additional executable build or consumer device launch is claimed for them.
- Approved SDK-only `flutter_test` development dependency for example tests;
  16 test transitive dependencies are added without changing any of the ten
  previously locked versions. An external SDK update moves current verification
  to Flutter 3.47.5 / Dart 3.13.4; the previously validated 3.47.2 / 3.13.2 floor
  remains unchanged.
- Eight release accessibility regressions for light/dark target size, labels,
  contrast, badge semantics, RTL keyboard traversal, disabled controls and
  reduced-motion activation. The preceding full suite passed 258 tests. Corrected
  formatting in an existing deformation test; runtime code was unchanged in that
  checkpoint. Native audit and finite Pixel profile results are documented with
  explicit performance limits.
- Optional `scrubMotionStretch` in `[0, 1]` and `scrubMotionFlattening` in
  `[0, 1)`, with neutral zero defaults through const construction, `fromTheme`
  and `copyWith`. Fitting Flutter drag movement excites bounded capsule
  deformation that recovers during a stationary hold through the existing
  spring or duration. Only capsule/optical painting changes; target geometry,
  semantics, host selection and request timing remain unchanged. Scrolling,
  reduced motion, zero duration and native UIKit ignore the options. The example
  supplies 0.20/0.30 through its Moving deformation control; these sample values
  are not package defaults or UIKit physics calibration.
- Optional `AppGlassNavigationStyle.foregroundRefractionEdge` through const
  construction, `fromTheme` and `copyWith`. Null retains shared `refractionEdge`;
  a positive finite override changes only the foreground optical envelope.
  Backdrop optics, native UIKit, layout and shader safety clamps are unchanged.
  The example opts into 6 with magnification 1.12: a bounded dark/radius-18 held
  check improves caption core height 14→23px, with an approximately 5px upward
  badge shift. Formal-API Pixel dark-rounded readability and light-pill
  hold/reversal/cancel/next-tap/inside-release checks pass. At this preceding
  foreground-edge checkpoint, all 214 package tests,
  scoped analysis and changed-file formatting checks pass. Android example
  debug (11.9s) and iOS Simulator debug/no-codesign SwiftPM (7.3s Xcode) builds
  pass; iOS was not launched. Native UIKit, app tokens and main-app optical
  inputs are unchanged. This is customization
  evidence, not UIKit parity acceptance; these builds and runtime checks predate
  the completed-held-tap renderer correction.
- Focused portable release-recovery regression coverage for light/dark owner UP,
  accepted scrubs, actual cancellation, new and unrelated contacts, and host
  retargeting before or during recovery. An existing hump remains continuous and
  finishes on its original timeline rather than restarting on host retarget.
  This adds coverage, not a rendering change or native motion-parity claim.
- Experimental `AppGlassNavigationStyle.scrubVerticalScale`, available through
  const construction, `fromTheme` and `copyWith`, with neutral default `1`.
  Finite values in `(0, 1]` compress only capsule/optical painting during a
  recognized fitting Flutter scrub, using existing duration/curve. Stationary
  pre-drag holds are unchanged; compression persists through pauses until
  up/cancel. It multiplies pressure-derived capsule paint height and compounds
  with `heldBarScale`, rather than setting an absolute height. Layout, targets,
  semantics and selection requests are unchanged.
  Scrolling, reduced motion, zero duration and UIKit ignore the option. This is
  experimental customization, not calibrated native motion or parity acceptance.
- Bounded portable caption-measurement reuse across selection/material-only
  rebuilds. The single immutable snapshot invalidates for shaping inputs and
  system-font changes; temporary painters are still immediately disposed.
  No geometry, optics or public API changes, and no measured FPS claim.
- SwiftPM-only example iOS runner without obsolete CocoaPods framework,
  workspace, build-phase or configuration references. Package-level CocoaPods
  support is unchanged; this removes an unused example tooling requirement.
- Complete consumer Scaffold recipe for content behind the glass and measured
  bottom scroll clearance, without double-counting system safe insets.
- Package regression coverage for touch-tooltip ownership and fitting
  release-to-select preview, commit, rejection, cancellation, disabled targets,
  exit/reentry and live policy changes, plus retained declarative cover/next-frame
  return, late covered release and same-microtask return with queued CANCEL or
  earlier UP for pending taps and owned release-only scrubs. These Flutter checks do not execute
  native UIKit or establish optical/motion parity.
- Optional fitting Flutter `scrubSelectionPolicy`, exposed through const style,
  `fromTheme` and `copyWith`. The default `continuous` preserves sampled move
  requests. `onReleaseWithinLane` previews while held and requests at most one
  final enabled destination on owner release within the visible surface's
  horizontal lane (including content padding, excluding exterior lens/shadow).
  Outside/cancelled releases retain host selection; policy changes invalidate
  contact. Taps, keyboard, scrolling and native UIKit remain unchanged.
- Controlled `CustomGlassNavigationDockWidget` with optional compatible
  native UIKit rendering and `CustomFlutterGlassNavigationDockWidget` for
  portable rendering. Selection, routes and business state remain caller-owned.
- Immutable item, local portrait and style models; resolved labels, selected
  glyphs, badges, disabled items and deterministic initials fallback.
- SDK-only theme factory and const style API for colors, typography, safe-area
  placement, targets, capsule geometry, motion and optical inputs.
- `AppGlassNavigationStyle.copyWith` covers all constructor inputs while
  retaining omitted theme values. Explicit null clears nullable effects and
  overrides; nullable numeric inputs accept integer literals. Invalid nullable
  override types report the field through `ArgumentError`.
- Consumer customization recipes and a Flutter/UIKit effects matrix, with
  example theme palettes, rounded Flutter corners and a blur slider.
- Measured complete-caption layout with minimum 48 × 48 targets, equal or
  content-balanced fitting widths, RTL, accessible scrolling overflow,
  long-press scrub, focus reveal and reduced-motion/high-contrast behavior.
- Optional spring settling, accepted-selection deformation, growing contact
  preview, guarded painted-lens regrab and owner-eligible release recovery.
  Host body/semantic selection never follows a preview alone.
- Opt-in fitting `trackVerticalDrag` pan tracking; raw first-contact ownership,
  actual-cancel settlement and geometry/recognizer-change invalidation guards.
- Spring drag handoff with independent center/size correction and projected
  SDK owner-pointer velocity. Pan release preserves SDK qualification/positions
  while bounding horizontal velocity independently of vertical speed.
- Direct pre-recognition owner-X tracking for enabled painted-lens hits in
  fitting growing pan mode, preserving grab offset/size without selection
  requests; recognition does not cancel already-tracked horizontal pointer
  velocity. Geometric center/size correction remains and can relax a captured
  endpoint overshoot even with stationary pointer X.
  Default horizontal, scrolling and distant unselected preview paths are unchanged.
- Captured raw moves retain a caught endpoint overshoot within size-dependent
  lane bounds instead of snapping it to a destination center. This changes no
  public API, selection request, style token or native implementation.
- Bundled Impeller refraction shader with edge-continuous elliptical sampling,
  bilinear texture sampling and optional independent foreground magnification,
  foreground dispersion and selected-backdrop dispersion.
- Stable per-dock shared scene input for eligible fitting growing lenses,
  independently interpolated held surface/blur, and composed blur fallback for
  unsupported shader/transform/cropped-input cases.
- Optional `heldSurfaceColor`, `heldBlurSigma`, `heldRimGradient`,
  `heldInnerShadow` and `heldInnerHighlight`, with finite-value/derived-bound
  guards and no added touch-target geometry. Two instances of the same clipped
  painter draw inset depth/light below artwork and the thin rim above the
  foreground shader, without another backdrop filter.
  Decorative rim/inset shading is not a reproduction of native material.
- Optional `heldShadowColor` in const/direct and theme styles, default null
  falling back to `shadowColor`. It independently colors only the growing
  Flutter capsule's outer shadow, with existing pressure multiplying color
  alpha. Blur, offset, geometry, resting bar shadow, inner bevel, native UIKit
  material and default appearance are unchanged. `copyWith` omission retains
  the override; explicit null restores the fallback, and invalid override types
  throw a field-named `ArgumentError`. Focused analysis and current-source
  Android/SwiftPM/CocoaPods build/resource checks pass with default-null hosts.
  A five-item app's light override has bounded stationary halo evidence, not
  complete customization/motion acceptance. The passing package suite does not
  imply exhaustive runtime coverage of this optical override.
- Optional `heldInnerHighlightGradient` in direct/theme styles, default null.
  It adds a colored inset band above the existing solid highlight, retaining
  the bright outer lip. A valid resolved highlight with positive spread is
  required. Band inset is one quarter of the spread (half its stroke width),
  aligning it with the outer lip; width is half the spread and
  blur sigma is one quarter the highlight's; it follows its offset and clips to
  the lens. Highlight color alpha and lens feedback multiply gradient opacity.
  Empty/non-finite bands are skipped; existing decoration eligibility and
  high-contrast suppression remain. No backdrop pass, save layer, targets,
  layout or UIKit changes are introduced. Earlier pre-layering normal five-item
  Android QA retained this narrower band: resting dock/checked body pixels were
  unchanged, held changes stayed edge-local, sampled band width was about halved
  at unchanged depth, and moving/reverse/regrab samples retained one coherent
  contour.
  Those measurements do not validate the later inset-layering or band-placement changes.
  Cancel/release endpoints are checked, not continuous timing or native physics.
  A current raster regression covers lip alignment and rounded-corner clipping;
  exact optics/motion, stress and consumer-runtime acceptance remain open.
- Theme factory `duration` override, retaining 200ms by default and exposing the
  existing portable zero-duration contract without reconstructing theme colors.
  UIKit keeps system-owned motion.
- Optional `heldBarScale`, default 1, scales the fitting growing bar/artwork/
  capsule/targets/semantics from actual contact pressure within existing exterior
  insets. Current-track input and projected SDK velocity follow that transform;
  reduced motion, zero duration, high contrast, scrolling and UIKit stay unchanged.
- Optional `heldSelectionVerticalInset` in direct/theme styles, default null
  preserving `selectionVerticalInset`. Fitting growing Flutter lenses interpolate
  this per-side visual inset with local pressure or accepted-selection
  deformation, without changing targets, row/surface/lane layout or UIKit.
  Static rest, scrolling, reduced motion, zero duration and nongrowing lenses
  do not interpolate. High contrast retains the same geometry eligibility;
  optical suppression remains separate. Inputs must be finite and nonnegative;
  invalid release-mode overrides retain the resting inset, and rendering clamps
  both insets to half the row height. Runtime acceptance of this option remains
  open.
- Scale-aware SDK pointer velocity includes the off-center scale-rate term;
  raw up preserves the incoming scale/rate/position before pressure reverses.
  This uses the SDK's timed finite-difference estimate, not exact curve
  derivatives, release-reversal compensation or full world-space C1 calibration.
- Native readiness/measurement fallback, noncurrent-route interaction
  exclusion, bundled iOS privacy manifest, CocoaPods and SwiftPM metadata.
- Standalone Android/iOS example with accept/reject feedback, disabled items,
  badge variants, renderer/sizing/foreground controls and local appearance
  options.

### Fixed

- Native layout callbacks and query replies now share a monotonic measurement
  sequence. A delayed same-revision query cannot replace newer fitted geometry
  and leave Flutter fallback covering the native bar. Channel/revision, geometry,
  overflow and presentation guards remain intact. Five regressions cover ordering,
  malformed measurements, legacy compatibility and native-view replacement;
  rebuilding the Swift plugin is required for ordered measurements.
- Raw portable contact now rejects non-primary button masks before claiming
  ownership or changing held feedback, matching SDK gesture admission. Four
  light/dark regressions cover secondary hold/caught-lens movement and the next
  valid primary selection. No touch motion or native UIKit changes.
- Caption measurement and rendered text now share resolved inherited
  `TextHeightBehavior`, including DefaultTextStyle precedence across the
  internal Material surface. Cache identity uses the effective value. Two
  light/dark regressions verify override/fallback geometry, reuse and disposal.
- Portable caption measurements now use the ambient `Localizations` locale,
  matching rendered text. Locale-only changes invalidate the latest-input cache;
  repeated unchanged locales reuse it. Two light/dark regressions verify locale
  propagation, change/restoration, immediate painter disposal and retained host
  state without claiming regional-font visual acceptance. No public API changes.
- The optional colored inner-highlight band now sits at the outer lip instead
  of forming a deeper inner hoop: its center inset is `spreadRadius / 4`, half
  the existing stroke width. Width, blur, offset, alpha multiplication and
  below-artwork layering are unchanged. Null remains the package default;
  native UIKit is unchanged. A raster regression covers placement and
  rounded-corner clipping, not composed shader or native optical parity.
- Completed nonscrub pointer holds on fitting growing Flutter lenses now reuse
  existing pressure recovery on matching first-frame host acknowledgement,
  avoiding a fresh accepted-selection shrink/regrow pulse. Qualification requires
  an owned hold lasting at least the motion duration, completed pressure and a
  matching pressed preview; raw UP is followed by pointer-only `InkWell.onTapUp`
  before arming the existing indexed, expiring feedback marker. Quick taps,
  programmatic changes, keyboard/semantics activation, rejection and late
  acknowledgement retain their existing behavior. Cancellation, new contact
  and geometry/lifecycle invalidation clear eligibility. No public API, motion
  constant, host-selection or native UIKit change is introduced.
- Native initials portrait cache keys now retain complete `TextStyle` value
  equality, avoiding stale PNG reuse when diagnostic strings omit typography
  inputs or collapse in profile/release. Two mocked bridge regressions cover
  shadow/font-size changes, equal-style restoration and stable host/native-view
  ownership. Public APIs and native UIKit rendering are unchanged.
- Bevel sampling now points outward, compressing visible edge features toward
  the lens interior independently of center magnification. This corrects the
  excessive held-badge lift/growth without badge-specific transforms or optical
  exemptions. Both portable optical passes change; native UIKit, geometry and
  host-selection behavior do not. The base-ray bound is not a universal
  no-fold guarantee for arbitrary magnification/dispersion.

- Active foreground/selected-backdrop dispersion now blends shared and offset
  premultiplied samples equally, reducing harsh chromatic fringes without extra
  reads, changed sample bounds or changed resting geometry. Zero dispersion
  and native UIKit are unchanged. This reduces effective channel-centroid
  displacement; it is a portable approximation, not native optical identity.

- Corner-bounded shader bevel displacement and dispersion avoid interior
  diagonal sampling seams for small-radius custom styles. Radius zero safely
  bypasses directional bevel effects while preserving center magnification's
  original edge envelope. Ordinary pill sampling and native UIKit are unchanged.
  Three actual-fragment-program raster regressions fail with the previous math
  and pass with the correction; these are not Impeller composition tests.
- Fitting scrub and caught-lens raw moves now remain anchored through ongoing
  whole-bar pressure expansion when the pointer is stationary. Repeating the
  identical pointer position no longer shifts the lens. Release/cancel and
  host/spring retargets retain the projected held origin. No API, theme token,
  shader, native UIKit or selection-ownership change.
- Thick held rims now remain inside small-radius lens corners when the stroke
  half-width exceeds the radius or its width reaches the lens's shortest side.
  Only that exceptional path clips to the existing outer lens; ordinary thin
  rounded/pill rims retain the original draw path and lens geometry.
- Held inset shadow/light and optional inner-highlight gradient now paint below
  the single artwork/caption row and enter the existing foreground-lens scene
  input. Only the thin `heldRimGradient` paints after that shader, preventing
  inset decoration from covering the row during compressed scrub painting.
  This reuses two instances of the same edge painter; no extra backdrop filter,
  public API, style value, geometry or native UIKit changes are introduced.
  It prevents opaque inset overdraw; optional foreground refraction can still
  distort captions/artwork and is not a guarantee of native optical parity.
- Portable capsule, foreground-lens and rim movement uses paint translation
  instead of changing Stack layout offsets. Dimension changes still relayout;
  geometry, clipping, hit targets and host-owned selection are unchanged.
  This removes a source-proven position-only layout cost, not a measured
  frame-rate or UIKit-motion parity claim.
- Corrected the Flutter/Dart requirements to the build-verified 3.47.2/3.13.2
  baseline. The earlier Flutter 3.44 declaration could not compile the newer
  `UiKitView.gestureBlockingPolicy` API; runtime platform checks cannot hide
  missing Dart symbols. Package and example agree; iOS deployment is unchanged.
- The automatic widget independently cancels tracked dock pointer streams on
  route cover/removal and guards late callbacks through queued cancellation,
  including declarative navigation that does not use Navigator's imperative
  cancellation path. Portable cancellation while tickers are disabled snaps
  feedback to host selection; visible cancellation still uses its spring.
  Direct-renderer visibility remains caller-owned. Portable declarative-cover
  tests verify late covered UP, immediate next-frame return and synchronous
  cover/return before queued cancellation for both taps and release-only scrubs.
  Native/device race checks remain open.
- Matching first-frame host acceptance after a release-policy scrub no longer
  starts an extra deformation pulse. Live spring retargeting is preserved;
  rejected/late acceptance cannot suppress later unrelated selection feedback.
  The example exposes Continuous / Release within lane through its existing
  immutable style configuration, with Continuous retained by Reset. Named
  package tests and Pixel demo release/cancel checks pass; the broader optical,
  transition and platform matrix remains separately scoped.
- Changing `pressedScale` across the growing-lens (`> 1`) boundary during fitting
  live contact cancels and settles before clipping ancestry replaces the
  recognizer, including after a host update cleared the preview. No API or token
  changes. Pixel checks cover both switch directions during an accepted scrub,
  no further old-owner requests and working subsequent taps. Other combinations
  and platforms still need independent verification.

### Validation and release limits

The checkpoints below are historical; they do not validate later edits. The
[package guide](README.md#technical-release-acceptance) contains the finite
final-snapshot acceptance checks and [documented limitations](README.md#documented-limitations).

Historical pre-motion checkpoint: **234 package tests** pass in 34s with clean scoped analysis,
including six input/text-height regressions, two ambient-locale cache regressions
and the colored-band raster regression. Each release must validate platform
artifacts and an independent consumer against its exact final archive/source
hashes. Earlier example/runtime evidence remains scoped to its recorded source;
passing widget tests does not establish native motion or material parity.

The preceding 225-test checkpoint covered completed held-tap recovery, with
clean scoped analysis and formatting. Its eleven held-tap cases retain their
scope; no spoken-accessibility, performance or native release-motion acceptance
is implied.

The preceding 209-test checkpoint passed scoped analysis and
Android/iOS Simulator example builds. Dark rounded-lens QA exposed a compressed
held caption; a weak strength-cap trial was rejected and reverted. Large-text/RTL
selection/reflow checks have bounded Pixel evidence, not complete accessibility
or optical acceptance.

Scoped analysis and 207 package tests pass, including seven shader-raster,
seven held-pointer projection and the earlier inset/rim-composition cases.
The current bevel-direction correction builds in the main Android app and
standalone iOS Simulator/SwiftPM example. A direction regression fails against
the prior inward sampling. Bounded Pixel QA improves held-badge height/position,
retains adjacent-badge refraction and passes cancel/next-tap/inside/outside
release checks. Body pixels are unchanged, but resting material is not identical.
The preceding weighted-dispersion refinement builds in the main Android app and
standalone iOS Simulator/SwiftPM example. Pixel resting/body pixels remain
unchanged, held differences stay lens-local, and cancel/next-tap/reverse QA passes.
The preceding small-radius correction builds in the main Android app and standalone
iOS Simulator/SwiftPM example. Pixel's normal pill resting/held captures remain
RGB-identical; cancellation, the following tap and reverse release work.
The iOS example's compiled shader/native/privacy resources are verified without
installing it. This is not optical parity or physical-device acceptance.
Earlier Android/SwiftPM example builds and bounded Pixel
host/gesture/accessibility checks retain their recorded source scope; the
latest example QA predates the small-radius/thick-outline guard. Historical isolated
Android/SwiftPM/CocoaPods source-copy checks retain their dated scope. No
exhaustive native, optical, performance or device-range acceptance is
claimed.

The preceding independent source-copy consumer of all eleven then-current runtime
inputs passes Android ARM64 (14.5s) and iOS Simulator/SwiftPM (14.6s) builds,
including shader/native/privacy resource verification. Source hashes match
before/after; its existing locked graph needs no CocoaPods tooling. This is
not an official publish archive, hosted installation or new device/UI check;
it predates the held-pointer projection correction.

Exact UIKit optics/physics, broad backend/runtime coverage, spoken accessibility,
trackpad behavior and broad performance guarantees are not accepted claims.
The [package guide](README.md) and [example matrix](example/README.md) describe
the supported contracts and checks.
