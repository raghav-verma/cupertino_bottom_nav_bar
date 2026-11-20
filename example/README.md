# Glass navigation dock example

A standalone Flutter host for the [glass navigation dock](../README.md).
It demonstrates externally accepted/rejected selection, native-versus-Flutter
rendering and local appearance controls. It contains synthetic destinations and
bundled/local artwork, no account data, network integration or routing framework.

## Run

Use the Dart/Flutter and iOS SDK requirements in the package guide. From this
directory:

~~~sh
flutter pub get
flutter run
~~~

Choose an existing Android device or iOS simulator. iOS device signing belongs
to the caller; no development-team identity is supplied. Native UIKit requires
a compatible iOS 26+ layout/runtime and iOS 26.1+ build SDK. Otherwise Auto uses
Flutter. This example enables Swift Package Manager only for its own project;
it does not change global Flutter settings. Its iOS runner uses SwiftPM without
a Podfile, Pods framework links or CocoaPods build phases, so this example does
not require CocoaPods. The package's separate podspec remains available for
consumer apps that use CocoaPods.

## Controls and reset baseline

| Control | Purpose |
| --- | --- |
| Accept requests | Accept a requested index or leave the host/body unchanged. Numbered live feedback distinguishes requests from accepted state. |
| Messages enabled | Exercise disabled tap/scrub/semantics behavior. Changing this control is not a selection request. |
| Badge | None, 3, 99+ or NEW; verify visible text and one meaningful accessible item label. |
| Auto / Flutter | Prefer compatible native UIKit or force the portable renderer without changing host selection/request count. |
| Comparison canvas | Off by default. Paint fixed, original vertical color bars behind the dock, independent of controls scrolling, destination updates and viewport/native lane height. Both renderers see the same caller-owned canvas for a matching theme and logical width. |
| Equal / Balanced | Balanced is the default/reset fitting Flutter allocation; Equal remains available for comparison. Switching preserves selection/request count. UIKit retains its own allocation. |
| Continuous / Release within lane | Choose fitting Flutter scrub request timing through the immutable style. The control itself preserves host selection/request count; native system selection, scrolling long-press scrubs and ordinary taps are unchanged. |
| Indigo / Teal / Plum | Resolve a new host color scheme and preserve selection/request count. Native foreground/badge colors follow the resolved theme. |
| Rounded Flutter corners | Use radius 18 instead of the pill-shaped 999 default through `copyWith`. UIKit retains its system geometry. |
| Flutter blur | Adjust backdrop sigma from 0 to 30 through `copyWith`; default 20. UIKit supplies its own material. |
| Foreground lens | A/B the optional artwork/caption post-process, not the backdrop alone. |
| Flatten scrub | Opt into experimental `scrubVerticalScale: 0.74` during recognized fitting Flutter scrubs; off uses neutral 1. Stationary pre-drag holds retain ordinary height. Selection/request count persist. This sample factor is not calibrated to UIKit. |
| Moving deformation | On by default; supplies Flutter-only `scrubMotionStretch: 0.20` and `scrubMotionFlattening: 0.30`. Movement stretches/flattens the capsule; a stationary held pause recovers its ordinary held shape. Off supplies zero for both. Selection/request count persist. |
| Inner bevel | A/B the optional theme-derived colored inner band during eligible Flutter lens feedback. The solid white highlight remains enabled in both states. Choose Flutter to compare it on iOS. |
| Held bar tint | Off by default. Experimental Flutter-only whole-bar tint during eligible held contact: white alpha 0.82 in light mode, theme surface alpha 0.90 in dark mode. This is not calibrated native parity. |
| Zero duration | Set the caller-owned Flutter dock style duration to zero, or restore its ordinary duration. Selection/request count persist. UIKit retains its own animation. |
| High contrast | Enable a local MediaQuery high-contrast preference. Turning it off preserves inherited system high contrast. Auto follows its existing eligibility rules and uses Flutter while high contrast is active. |
| Arm 2s lens switch | Off by default. A one-shot local diagnostic toggles only `pressedScale` across `> 1` two seconds after the next owner dock DOWN. Separate status reports arming, pending, firing and cancellation; it generates no selection request. |
| Appearance controls | Local light/dark, larger text, long labels, RTL and reduced motion. System reduced motion is respected even when the local switch is off. |
| Reset | Auto, Explore index 0, no requests, Accept on, Messages enabled, badge 3, comparison canvas off, Balanced, Continuous scrub selection, Indigo palette, pill corners, blur 20, foreground lens on, Flatten scrub off (neutral 1), Moving deformation on, inner bevel off, held bar tint off, zero duration off, local high contrast off, lens probe disarmed with original growing scale, light, text 1.0×, LTR and ordinary local motion. Inherited system motion/contrast preferences remain active. |

The controls are separate semantic containers from the live feedback and badge
button. A dropdown opening must not turn the whole controls area into one
accessible button. Badge changes must not request a destination.

The example builds its style with `AppGlassNavigationStyle.fromTheme(theme)`
and `copyWith` overrides. This preserves resolved theme values while varying
ordinary geometry and the existing expressive treatment. Nullable effects can
be cleared explicitly, as the Inner bevel control does when off. The palette,
corner and blur controls are caller-owned and emit no destination request.

For horizontal refraction and width comparisons, enable **Comparison canvas**
near the top of Demo controls. Its opaque lower band covers scrolling artwork
behind the dock with original vertical color bars: widths 12, 24, 6 and 18
logical pixels in a centered 96-pixel cadence, separated by neutral gaps. Every
row is identical. The canvas extends 240 logical pixels above the resolved
bottom reserve `max(system bottom reserve, style.bottomInset)` and through that
reserve. Changing viewport height, reserve or measured native lane height
therefore does not shift the pattern's phase behind either dock. Controls
scrolling and accepted destination changes do not move or repaint its content.
Theme and palette changes deliberately recolor it.

The passive canvas contributes no gestures, focus targets, semantic content,
animation or extra backdrop filter. The existing list and controls remain
scrollable, and the dock keeps its existing key, ancestry and contact observer.
The toggle does not request selection or change the renderer preference,
style, pressure or optical tuning. Reset restores the ordinary scrolling demo.
Match logical width, theme, text baseline and owned contact phase when comparing
Auto/native with Flutter. This Y-invariant fixture supports controlled horizontal
refraction and width inspection; it does not establish equal measured UIKit
geometry, general optical calibration or motion parity. Different logical widths
expose different amounts of the centered pattern.

Flatten scrub is off by default and Reset restores `scrubVerticalScale: 1`.
Turning it on passes the experimental sample factor 0.74 through `copyWith`,
preserving selection, request count and all other resolved style inputs. Choose
Flutter and a fitting track with ordinary motion and nonzero duration for A/B.
After drag recognition, only capsule/optical paint height blends down; a paused
recognized scrub remains flattened until release or cancellation. A stationary
pre-drag hold retains ordinary pressure height. Reduced motion, zero duration,
scrolling tracks and native UIKit ignore this input. The local summary reports
the chosen factor, not renderer detection or native calibration.

The scrub-policy control also uses this host-owned configuration and `copyWith`;
Continuous is the default and Reset value. Choose Flutter and a fitting track
to compare it with Release within lane. Continuous can request enabled
destinations during a scrub. Release within lane previews locally without
changing the host body or selected semantics until owner UP inside the visible
bar's horizontal bounds (including content padding, excluding exterior lens
growth/shadow). Its final enabled, grab-adjusted destination may request once;
outside UP or actual CANCEL requests nothing. Leaving and re-entering is allowed,
and an above-bar release at an inside X can commit. The host still accepts or
rejects requests. Policy changes cancel an active fitting contact; they do not
generate a request. Native UIKit owns its selection behavior, and scrolling
long-press scrubs, taps and keyboard activation keep their existing behavior.
The visible local-style summary reports the chosen Flutter policy, not renderer
detection. Verify accepted/rejected inside releases, outside release, actual
cancellation and held preview without a host change on the final artifact.
See [verification limits](#verification-limits) for the recorded evidence scope.

Moving deformation uses `scrubMotionStretch: 0.20` and
`scrubMotionFlattening: 0.30`; turning it off supplies zero for both. Choose a
fitting Flutter track and compare movement, a pause while still held, reverse
movement and release/cancellation. Recovery uses the configured spring or
duration; it changes capsule painting without changing accepted selection or
request timing. The independent Flatten scrub control keeps its sustained
multiplier during a recognized pause. Reduced motion, zero duration, scrolling
and native UIKit ignore movement deformation. Reset restores Moving deformation
on. These example values are demonstration choices, not package defaults.

Zero duration changes only the dock style; it does not set a system motion
preference or change native UIKit animation. Choose Flutter for this check on
iOS. High contrast combines the local switch with inherited
`MediaQuery.highContrast` using logical OR, so Reset cannot disable a system
preference. Both controls retain host selection, feedback and request count.
Each chip exposes its own control semantics; the local status text reports the
effective motion/contrast preferences and the selected duration mode.

The current comparison preset uses action height 54 and the resolved 4-point
vertical content insets, giving a 62-point surface. Captions resolve from the
theme with weight w400 and zero letter spacing; the outline width is 0.5.
These are example-only overrides, not package defaults or main-app token edits.
The caller-owned horizontal trial uses `horizontalContentInset: 19`,
`selectionHorizontalInset: 0` and `selectionHorizontalOutset: 10`, with Balanced
as the default/reset allocation. At width 402 and the resolved 16-point outer
insets, this leaves a 332-point target-center track. The selected visual capsule
extends 10 points beyond its target on each side; action targets remain separate
and do not overlap. Equal remains an explicit comparison choice. The trial
addresses measured example width/center differences without changing pressure,
physics, shaders, vertical geometry or colors. It is a bounded caller preset,
not a guarantee of UIKit's private allocation or native optical/performance
parity. Final device-width measurements remain a separate check.

The example's optional portable treatment uses a growing fitting lens with
whole-bar scale 1.04, local vertical scale `1.24 / 1.04` and local horizontal
stretch `1.25 / 1.04 - 1`. When the requested bar scale fits the exterior insets,
these retain nominal painted Y1.24/X1.25 endpoints; tighter insets can limit it.
The bar transform includes artwork, targets and semantics, but adds no layout
space and does not run from accepted-selection deformation. Release recovery is 0,
foreground magnification 1.12, foreground edge width 6, foreground dispersion
0.25, selected-backdrop
dispersion 1 and held blur 4 logical pixels. It opts into fitting vertical-start
pan tracking, a theme-resolved held surface, subdued rim and inset shadow
(blur 10, spread 1, Y offset 1), followed by inset highlight (blur 1, spread 2,
zero offset; white alpha 0.98 light / 0.16 dark). Inset shadow/light and the
optional colored inner band paint below the single artwork/caption row and are
included in the existing foreground-lens scene input. Only the thin rim paints
after the foreground shader. Two instances reuse the same clipped outside-hole
painter without another backdrop filter, keeping inset painting below the row
during flattened scrubs. No API, style values, geometry or UIKit changes are
introduced by the layering fix itself. The later example preset changes noted
above are separate caller-owned tuning. Invalid geometry or overflowing derived bounds
disables only the affected decoration.
Both package APIs, `heldInnerShadow` and `heldInnerHighlight`, default to null in
direct and theme construction. These caller-resolved values and the example's
theme-derived rim are demonstration choices, not package defaults or a
calibration of UIKit optics. Native rendering ignores portable material tuning.

Inner bevel defaults off and passes null for `heldInnerHighlightGradient`,
preserving the solid-highlight baseline. Turning it on supplies an original
diagonal gradient resolved from the example theme's tertiary/primary colors
(alpha 0.5 / 0.45 / 0.25). The existing valid positive-spread highlight supplies
the band geometry and scales its opacity with highlight alpha and lens feedback;
the white lip remains. This caller-owned portable decoration adds no backdrop
pass and changes no layout, targets, selection, request count or native
eligibility. It follows the existing decoration eligibility and high-contrast
suppression. Reset turns it off. These values demonstrate the API in both theme
modes; they are not a UIKit calibration or a runtime-verification claim.

Held bar tint is a separate off-by-default experiment using
`heldBarSurfaceColor`. On supplies `Colors.white.withValues(alpha: 0.82)` in
light mode or `theme.colorScheme.surface.withValues(alpha: 0.90)` in dark mode;
off supplies null. The package blends the outer bar using actual contact
pressure for eligible fitting, growing Flutter contacts. The capsule-only held
surface keeps its existing styling. Reduced motion, zero duration, high
contrast, scrolling tracks and native UIKit retain the ordinary outer surface.
The chip and local summary label this as experimental whole-bar tint; these
caller-owned colors are not calibrated native parity. It changes no selection
request, comparison-canvas choice, geometry, optics, pressure or blur setting.
The example's default/reset blur remains 20; a local blur-slider experiment
must be selected independently. Reset turns Held bar tint off.

During bar-scale changes, pointer positions resolve against the current track.
SDK velocity projection includes the off-center scale-rate term, and raw up
captures the incoming scale/rate/position before pressure reverses so recognizer
end uses the correct phase. The rate is an SDK finite-difference estimate; the
bar's deliberate release reversal is not compensated. This is not an exact
world-space C1 or native-physics claim.

### Live growing-lens diagnostic

Pixel manual checks cover both switch directions during an accepted scrub,
no further old-owner requests, the following new tap, and early owner CANCEL
cancelling the timer. Extra-contact takeover and other hosts still need checks;
adding the probe alone does not establish cancellation correctness.
It changes no system setting, native material or account state.

Choose Reset, Flutter, Balanced and Continuous scrub selection, with short labels, ordinary text/motion,
nonzero duration and high contrast off. Confirm that all destinations fit.
The always-present passive `Listener` adds no gesture recognizer, hit-test
absorption or conditional dock key/ancestry. It observes raw contact only;
selection-request feedback must establish that a real scrub was accepted.

1. Arm **Arm 2s lens switch**, then press an enabled destination and drag far
   enough to obtain an accepted request before the two-second deadline. Keep
   that pointer down. The probe changes `pressedScale` from `1.24 / 1.04` to
   `1.0`, auto-disarms and reports the switch separately from selection feedback.
   The diagnostic also records the host index and request count at firing, so
   a later observation can distinguish a pre-switch acceptance from a later input.
   Verify the dock settles to the accepted host index, clears pressed expansion
   and emits no stale scrub requests from subsequent movement of that contact.
2. Release or actually cancel the owner, then verify a new tap works. Rearm and
   repeat an accepted held drag for the reverse `1.0 → 1.24 / 1.04` transition.
   Check settlement and a subsequent tap again; do not compare callback totals
   across separate pointer runs as timing evidence.
3. Arm again and end the owner with UP or CANCEL before two seconds. Verify
   the pending switch is cancelled and the scale does not change. Disarming
   or Reset also cancels pending work. The probe never changes selection or
   request count itself; Reset retains its ordinary full-host reset behavior.
4. Reset and visually inspect the documented baseline after the check.

The first raw pointer owns the probe until its UP/CANCEL. Extra contacts cannot
replace it, arm another probe or start another timer. Disarm, firing and Reset
retain that physical owner until it ends, so an already-down secondary contact
cannot take over. After firing, the original contact must end before rearming.
Unarmed contacts retain this ownership silently: ordinary dock DOWN/UP/CANCEL
does not update the diagnostic status or animate its chip. Trying to arm during
an existing unarmed contact reports that it must be released first; no timer
starts, and the chip becomes available again when that owner ends. Armed
diagnostics still publish pending, firing and cancellation status normally.
Only `pressedScale` toggles; bar-scale, stretch and optical inputs remain fixed,
and the probe itself leaves host selection and request count unchanged.
Inherited accessibility preferences remain respected and may make this fitting
ordinary-motion regression inapplicable.

## Manual verification matrix

This is a checklist, not a claim that every row has passed on the current
source, all platforms or every appearance. Use equivalent destinations,
scroll positions, theme/text baseline and input phases when comparing renderers.
Zero-duration and local high-contrast checks use the corresponding local
controls. The one-shot lens probe covers the growing-eligibility transition;
changing horizontal-versus-pan recognition still requires a custom host or
source configuration because the example always enables fitting pan tracking.

| Scenario | Expected contract / observation to verify |
| --- | --- |
| Accepted tap / drag | Host index, body and semantic selection follow accepted requests. In Continuous mode, sampled drag callbacks may occur before release and may skip destinations. |
| Continuous / Release within lane | Force a fitting Flutter track. Compare request timing with Accept and Reject. Release mode previews without a held request, commits only an enabled final candidate on inside UP, and makes no request for outside UP or actual CANCEL. Check exit/reentry and a subsequent tap. The control preserves selection/count; native and scrolling behavior are unchanged. Named Pixel release/cancel cases pass; other combinations still need checks. |
| Rejected tap / drag | Feedback records requests, but host index/body remain unchanged and the capsule settles to the latest accepted index. Do not compare callback counts from different input methods as timing evidence. |
| Unselected owned hold | Growing lens/artwork preview may move to the contacted item; host body and selected semantics stay unchanged until an accepted request. |
| Painted-lens capture / small move | In fitting growing pan mode, an actual enabled painted hit follows owner X before recognition with its grab offset/size. No request or semantic-selection change occurs before recognition; the handoff does not cancel already-tracked horizontal pointer velocity. Geometric center/size correction remains and can relax a captured endpoint overshoot even with stationary pointer X. Distant unselected previews retain their separate handoff. |
| Whole-bar pressure scale | Bar, artwork, capsule, targets and semantic bounds transform together within exterior insets; current-track input stays aligned while scale changes. Rest/reduced motion/zero duration/high contrast/scrolling remain unscaled. Use the local Zero duration and High contrast controls for those variants. This is not a blur or trajectory-parity check. |
| Held inset depth / light | Inset shadow/light and optional colored band paint below the single artwork/caption row, within the existing foreground-lens scene input; only the thin rim paints after the shader. No extra backdrop filter, scene-blur, capsule-size or target change; high contrast/native ignore the decorations. Use High contrast to check local suppression. |
| Inner bevel A/B | Force Flutter and compare equivalent held/drag/release phases with the chip off/on. Off retains the solid highlight; on adds the theme-colored inner band above it but below artwork, retaining the white lip. Resting geometry, host index and request count remain unchanged by the control; native eligibility is unchanged. Check both themes and restore Reset's off baseline afterward. |
| Held bar tint A/B | Force a fitting Flutter track and compare the same owned contact phase with the chip off/on in light/dark mode. Only the experimental outer-bar tint changes; host selection, request count, canvas and blur choice persist. This is not native parity acceptance. Reset restores off and blur 20. |
| Flatten scrub A/B | Force a fitting Flutter track and compare the same contact phases with the chip off/on. On blends recognized scrub paint height to the experimental 0.74 multiplier; pre-drag stationary holds, targets and request policy stay unchanged. Check release/cancel, regrab, live off/on, reduced motion and zero duration; restore Reset's neutral 1 afterward. |
| Moving deformation A/B | Force a fitting Flutter track. Compare forward/reverse movement, a stationary pause while still down, release and actual cancellation. On stretches/flattens during movement and recovers during the pause; off retains ordinary held geometry. Host acceptance/rejection, selected semantics and request timing remain controlled. Check reduced motion/zero duration suppress it; Reset restores on. |
| Vertical-start pan | This example opts in: track X even when motion starts vertically/outside the bar. A vertical exit is not inherently cancellation. |
| Actual pointer cancel | Capsule/pressure settle to the host with zero cancellation velocity; previously accepted host changes are not rolled back. |
| Live growing eligibility switch | Use the one-shot diagnostic above for both `>1 → 1.0` and `1.0 → >1` during an accepted held scrub. Check cancellation/settlement, early owner UP/CANCEL, no extra-pointer takeover and the next tap. Pixel checks cover both switch directions, early CANCEL and following taps; extra-pointer takeover and other hosts remain open. |
| Disabled Messages | No tap/scrub request for Messages; disabled semantics are exposed. Other enabled items remain usable. |
| Badge variants | None/3/99+/NEW fit without duplicate spoken labels; badge changes do not request selection. |
| Auto / Flutter switch | Host state/count persist. Native is used only when eligible, and fallback stays usable if preparation fails. |
| Comparison canvas | Enable on both hosts with matching theme/text/width. Scroll controls and change accepted destinations; vertical bars stay fixed behind the dock and host feedback remains controlled. Compare equivalent owned hold/movement/release phases, then Reset to the normal scrolling demo. |
| Equal / Balanced | Selection/count persist; artwork, targets and capsule share measured boundaries. Longer captions can receive more space. |
| Palette / corners / blur | Theme changes update resolved colors; rounded corners and blur affect Flutter only. Selection/count persist. Reset restores Indigo, pill corners and blur 20. |
| Narrow / large text / RTL | Complete captions and 48 × 48 targets remain usable; overflow scrolls, long-press scrub selects, focus/external selection reveal the destination. |
| Foreground A/B | Compare the same phase; rest stays sharp. Unsupported shader/crop/transform paths retain usable blur/tint fallback. |
| Reduced motion / zero duration | Force Flutter and use Reduce motion / Zero duration to check equivalent controlled selection without decorative movement or leftover ticking/pressure. Toggle during settling/feedback and verify immediate cleanup. Restore both local controls off afterward; inherited system reduced motion remains respected. |
| High contrast | Enable the local control and verify usable opaque portable navigation without decorative optics/inset light. Host selection/count persist. Disable it and verify Auto can regain native eligibility only when other inherited preferences and layout permit; inherited system high contrast remains active. |
| Live reflow / mode / enabled changes | No stale coordinate callback, ownership transfer or lingering preview. Live recognizer-mode changes require a custom host or source configuration because this example always enables fitting pan tracking. Recognizer-toggle/trackpad behavior still needs explicit runtime checks. |
| Keyboard / screen reader | Labels, badges, selected/disabled state, focus order and activation are clear; covered/inactive content is excluded. |
| Covered route / return | Automatic dock retains layout but excludes paint/input/focus/semantics/tickers until current again. |
| Reset | Restore the baseline above and inspect it visually, not only through logs. |

A stationary contact and a drag/release are different checks. Hold screenshots
must be captured while the contact is still owned, not after release. Do not
treat a restored endpoint as evidence of the intervening trajectory, matched
material, speed cap or rapid-regrab timing.

## Verification limits

The dated results below describe earlier snapshots. They do not validate later
package edits. See the package's [verification status](../README.md#verification-status--10-october-2026)
and [technical release acceptance](../README.md#technical-release-acceptance)
for the current release boundary and final-snapshot checks.

### Current ordered-measurement and preset checkpoint — October 10

Current package/example checks pass **281 / 17 tests** and scoped analysis/
formatting. The calibrated portable example builds on Android profile (26s);
Pixel hold and separate forward/reverse endpoints pass. After a native pregesture
failure retained as comparison04, ordered native measurement publication now
rejects stale callbacks/query replies without weakening fit or overflow guards.
The rebuilt iOS example passes (15.7s), and native05 passes one test / zero
failures with five genuine UIKit buttons and stationary hold/separate forward/
reverse endpoints. Different capture phases/backgrounds and a narrower Android
held capsule/distinct edge remain, so no exact optical/motion parity follows.

The post-fix main iOS build passes (21.3s); both normal comparison apps are
visually restored to light Discover, top scroll and normal text with keyboard
capture off. Earlier physical timings used an older example/package source and
do not accept this preset/fix. Raster/initial coverage, optics/motion, fresh
archive/consumer and public name/license/publisher/spoken QA gates remain open
or deferred. This is not launch-ready.

### Historical completed-held-tap checkpoint — 9–10 October 2026

The completed-held-tap renderer builds in this example on Android debug
(12.8s) and iOS Simulator/SwiftPM debug/no-codesign (6.2s Xcode). Android APK
SHA-256: `7a58537e9b8eea454e9918d3e3a8e7d390f47d27fd7847b7c9cf5ca67e0045c5`.
The iOS privacy resource is valid and byte-identical to its source.

Pixel accepts held Messages, rejects held Profile while retaining Messages,
rejects a continuous move to Explore, cancels without an additional request,
then accepts the next Likes tap (requests 1–4). iOS Auto accepts held Messages
and rejects held Profile (1–2); forced Flutter accepts held Featured and rejects
held Profile (3–4). Both return through Reset to Auto/Equal/Continuous/Accept,
Explore and no requests. Both examples are stopped and the normal main-app
Discover baselines are visually restored; native keyboard capture remains off.

This snapshot passed **225 tests** and clean scoped analysis.
These are bounded input/endpoint checks, not phase-matched motion,
optical parity, spoken accessibility or performance acceptance. Independent
consumer/archive/hosted and public identity/license/publisher gates remain open.

### Earlier foreground-edge checkpoint

The example explicitly sets optional `foregroundRefractionEdge: 6` while
retaining magnification 1.12 and shared backdrop edge 12. Package callers default
to null, which retains the shared `refractionEdge`. A matched dark/radius-18
held check increases Likes caption core height from 14 to 23px; the badge shifts
upward approximately 5px. Refraction remains active. This is bounded caption
readability evidence, not UIKit parity or broad customization acceptance.
All 214 package tests pass; direct analysis of `lib`, `test` and `example/lib`
is clean, and formatting checks report zero changes across seven changed Dart
files. The formal API's dark/radius-18 GPU capture confirms readable captions.
Light-pill hold/reversal/CANCEL emits no request; the following Messages tap
emits request 1 and inside-release Profile emits request 2, with consistent
host state. Android example debug (11.9s) and iOS Simulator debug/no-codesign
SwiftPM (7.3s Xcode) builds pass. Final APK SHA256:
`64ce696b338fbf5801309599df93943f14883ec32ce2b8441eccdc3676598686`.
At that checkpoint it was installed on Pixel but stopped, with the existing
main app visually/AX restored to normal light Discover; subsequent scrolling
checks are recorded below. iOS was not launched. Native UIKit, app
tokens and main-app optical inputs remain unchanged.

On that final APK, Pixel local 2× text plus long labels and RTL now also verifies
scrolling long-press selection: Profile tap emits request 1, held Profile→Messages
emits 2, actual CANCEL adds none and reveals complete Messages, and the next
Profile tap emits 3. With Release within lane selected while still scrolling,
held Profile→Messages emits 4 and reverse→Profile emits 5; UP adds none.
Scrolling therefore retains its documented continuous long-press semantics
despite that fitting-only policy. Final AX request 5/Profile was followed by
visible Reset to Explore/no requests, Auto/Equal/Continuous/Light/1×/LTR. The
example process is stopped and the existing main Discover is visually/AX
restored. Android font_scale 1.0 is unchanged; native Discover is freshly
visible at Light/Text Size 3 with Capture Keyboard off. This is bounded Pixel interaction
evidence, not spoken-accessibility or native-motion acceptance.

The preceding accepted source passes 209 package tests and scoped analysis; Android
debug (3.7s) and iOS Simulator/SwiftPM debug (4.6s Xcode) builds pass. Pixel's local
dark/radius-18/foreground-lens configuration verifies held preview, cancellation,
next tap and inside release, but compresses its held Likes caption. Foreground-off
restores readability; inner-band-off does not. A smaller-strength optical trial
improved caption height only 14→15px versus 21px with foreground off, so it was
rejected and reverted. Do not treat this combination as visually accepted.

At that preceding checkpoint, 2× text plus long labels and RTL preserve/reveal the
selected Profile, scrolling exposes earlier items, and tapping Likes selects it.
Returning to normal text/fitting layout retains selection; Reset is visually/AX
confirmed. That pass did not cover scrolling long-press; the later final-APK
check above does. No spoken-accessibility, trackpad or performance acceptance
follows. At that checkpoint the example artifact was installed but stopped; the
normal main app is restored to light Discover. iOS builds were not launched.

The latest bevel-direction correction passes all 207 package tests and scoped
analysis. This example's iOS Simulator debug/no-codesign SwiftPM build passes
(6.2s Xcode), with compiled shader and valid privacy resources included. No
example runtime acceptance follows: it was not installed or launched.

The preceding weighted-dispersion refinement passes all 206 package tests and
scoped analysis. This example's iOS Simulator debug/no-codesign SwiftPM build
passes (7.6s Xcode), with its compiled shader and valid source-identical privacy
manifest included. It was not installed or launched; current main-app Pixel
checks do not substitute for fresh example runtime checks.

The preceding package correction bounds directional shader bevel effects by corner
radius while preserving center magnification. The full package suite passes
203 tests, including three shipping-shader raster regressions. This example's
iOS Simulator debug/no-codesign SwiftPM build passes (12.0s Xcode), with compiled
shader, native registration and matching privacy resources verified. Its source,
configuration and lock hashes remain unchanged; it was not installed or launched.
This checks current integration, not native optical parity or a hosted archive.

Earlier package hardening adds conditional rim clipping for small radii/thick
outlines. All 185 package tests and scoped analysis pass, including two new
corner-containment/original-pixel regressions. A refreshed independent minimal
consumer builds on Android (14.5s) and iOS Simulator/SwiftPM (14.6s), with all
eleven runtime inputs matched and shader/native/privacy resources checked.
That host uses neutral scrub scale 1 and is not this full controls screen;
neither consumer was launched. Current-source compilation is not runtime parity.

Before that rim-containment guard, the example builds for Android ARM64 debug (12.7s) and iOS
Simulator/SwiftPM (16.7s). Formatting, scoped analysis and all 183 package tests
pass, including 11 scrub-height and two inset-composition regressions. Pixel
Flutter/Balanced/Release-within-lane QA covers Flatten scrub off/on, cancellation
without a request, a dark-mode inside release, reduced-motion reverse release,
and Reset to the documented light/neutral baseline. The toggle preserves host
selection and request count. Inset light no longer paints over caption ink;
foreground optics may still distort it. These are bounded local checks, not
UIKit motion/optical calibration, spoken accessibility or performance acceptance.
No new iOS runtime check is implied by the build.

Earlier input checkpoint (before the Flatten scrub and inset-layering changes):

That Android example rebuilds in 26.1s. A bounded Pixel light/1×/LTR check
with Flutter/Equal/Release within lane verifies two quick accepted requests,
two quick rejected requests preserving the host, repeated held reversals without
a request, actual cancellation and a working following tap. Ordered system input
entries indicate approximately 138/106 ms inter-contact gaps for the two quick
sequences, not Flutter frame timing or a proven painted-lens spring-phase hit.
Reset and normal main-app Discover are visually/semantically restored; the demo
is stopped. This is not native animation, continuous-border or performance parity.

After removing the example runner's obsolete Pods wiring, a clean minimal
consumer using that runner and an independent pre-scrub-height package copy builds
on Android (43.7s) and iOS Simulator/SwiftPM (65.6s). No CocoaPods executable or
Pods directory is needed for the iOS build. Compiled shader, native registration/
symbols and valid privacy resources are verified. This host uses its own small
entry point, not the example's full controls screen; no new simulator interaction
or visual acceptance is claimed. Package CocoaPods metadata remains unchanged,
and a fresh CocoaPods integration build remains a separate release check.

The preceding caption-cache checkpoint passed all 170 package tests and
library/test analysis. This
includes seven caption-cache tests and four subsequent binding-order tests for
pending taps/release-only scrubs across synchronous cover/return. The cache
changes neither the example API nor the material/geometry inputs; the later
cancellation follow-up changes tests only, without new example runtime evidence.
The example build and runtime evidence below predates that change; a bounded
profile-mode on/off comparison was too variable to accept performance or
attribute cost to foreground refraction. No FPS improvement is claimed.

The subsequent arm64 Android release/AOT build passes in 34.35s with vital lint
enabled, the compiled shader included and `debuggable=false`. Its existing debug
certificate is retained for local QA, not store distribution. Resolving an
uncached configured Android lint tool required no source/configuration/lock
changes. On Pixel 10, Flutter/Equal/Release-within-lane inside commit,
outside-left release, actual CANCEL, host rejection and the following accepted
tap pass. Reset and the normal main-app return are visually/semantically
verified. This small release-mode smoke check does not repeat the full debug
appearance matrix below. The run includes skipped-frame warnings under heavy
host load, so it is not performance or continuous-motion acceptance.

October 9 current-source checkpoint: Android debug builds in 25.59s and iOS
Simulator/SwiftPM in 10.50s, with compiled shaders and native registration/privacy
resources verified. The Android artifact was installed on the existing Pixel 10;
the iOS artifact remains build-only. Initial iOS builds failed because generated
plugin/framework integration was stale after cache loss. Locked offline Flutter
preparation repaired it without changing dependency versions; no CocoaPods or
hosted-consumer result is implied.

Pixel checks pass for release-only accepted/rejected requests, no request during
held preview, outside release and actual cancellation. Both live growing-lens
switch directions stop subsequent old-owner requests; the next tap works, and
early CANCEL prevents the timer firing. Combined local dark/reduced-motion/high-
contrast remains usable, as do 2× long labels in RTL with horizontal scrolling
and revealed-item activation. Zero-duration selection and disabled Messages
also behave correctly. Reset restores the documented baseline, after which the
main app was visually restored to normal light Discover. These are bounded
checks, not an exhaustive toggle/multi-pointer matrix, spoken accessibility or
animation/performance proof. At that checkpoint, all 170 package regression tests passed;
main-app tests remain deferred.

Historical evidence below retains its earlier source and interaction scope.

The preceding one-shot live growing-lens probe checkpoint passed formatting, focused analysis and
Android debug (37.4s) / direct-Xcode iOS simulator debug (52.86s) builds. Source
SHA-256 is `ef600d5164a7d780d0958de8dd546fa23527fc076134979591bc5cf8635a47ac`.
Android artifact SHA-256 is
`f27d94250e0b51be6e7d8ce1c0fec139b22433b223db9caccb58808e553b0b35`.
Neither new artifact was installed or launched. Both switch directions, pending
cancellation, extra-contact handling, settlement and subsequent activation
still need explicit manual verification. No automated tests ran.

Development checkpoints include selected-toolchain Android/iOS builds, focused
analysis and bounded native/portable accepted/rejected diagonal, actual-cancel
and reset checks. These and older disabled/badge/appearance observations retain
their source scope; they are not blanket acceptance of later changes.
The held-bar checkpoint's no-pre-recognition-request check remains historical.
The inset/release-projection checkpoint checks portable accepted/rejected
scrubs and Reset on both Android/iOS. Native accepted/rejected scrubs, switching
to portable rendering and portable reverse drag were checked before the final
highlight-spread-only adjustment, which did not change UIKit or gesture code.
Callback totals differ with sampling and are not a native-timing comparison.
Default example sizing is not an assertion that UIKit's measured lane and the
portable nominal lane match.
The subsequent endpoint-regrab correction has current Android Balanced-mode
evidence: a small vertical raw move retains Explore with no requests, and a
rejected scrub retains host index 0, an accepted scrub reaches Profile/index 4,
and Reset restores the documented baseline. Its exact endpoint-overshoot trajectory
still needs targeted verification; current iOS builds are build-only.

At the earlier October 8 Inner bevel, Zero duration and High contrast checkpoint,
the example source/wording passed formatting, focused direct `dart analyze lib`, and
sequential no-pub debug builds with Flutter 3.47.2 / Dart 3.13.2. Android's
Gradle task took 8.1s; the iOS simulator Xcode build took 17.3s with code signing
disabled. Android emitted no warnings. iOS emitted a nonfatal notice that
CocoaPods integration remains although its plugins use Swift packages; no
integration cleanup was performed. The example `lib/main.dart` SHA-256 was
unchanged before and after both builds:
`3468c46c7b1e3ee1f65cdfeb34a9498d82d2934388f6290a1b1171166c8db6b6`.

Those were compilation/static checks only. Neither artifact was installed or
launched, and no device interaction or automated test ran for that update.
Earlier example observations do not validate the new band or these local
control interactions.

The subsequent October 8 customization checkpoint uses `fromTheme.copyWith`
and adds the palette, radius and blur controls. The final example source passes
formatting and focused analysis; sequential no-pub debug builds completed with
Android's Gradle task at 5.5s and the iOS simulator Xcode build at 6.9s. Its
`lib/main.dart` SHA-256 is
`1bc1464cc6fbb8e1b837c731c7156387d58406f2e3f8c0056659f4fd848dc687`.
The iOS artifact is build-only for this checkpoint.

The final Android artifact was installed on the existing Pixel 10. Ordinary
light/1.0× checks accepted Likes as request 1/index 2, then changed Teal to Plum,
enabled radius 18 and set blur to 10 while preserving the selection/request
count. The radius change was visually confirmed, and blur exposes one resolved
slider announcement. Reset was visually and semantically verified to restore
Explore/index 0, no requests, Indigo, pill corners and blur 20. These bounded
checks do not validate every optical override, native styling, inner-bevel A/B, zero duration,
high contrast or the other stress controls. No automated tests ran.

No exhaustive stress/accessibility, minimum SDK/runtime, physical-device,
performance or exact native optical/motion result is claimed.
Live reflow/style-toggle/trackpad, rapid regrab and fallback variants remain open.
After diagnostic controls, restore and visually inspect the intended ordinary
host baseline. The package remains local and unreleased.
