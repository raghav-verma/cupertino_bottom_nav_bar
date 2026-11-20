import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Clips a blurred, optionally refracted backdrop while keeping [child] sharp.
///
/// This package-internal component owns only a GPU resource lifecycle. Selection
/// and any animated lens parameters remain owned by its caller. It does not
/// capture widgets, copy a screen image, or animate independently.
///
/// Optical filtering requires Impeller. Unsupported renderers, pending/failed
/// shader loading and unsupported transforms retain ordinary backdrop blur.
/// High contrast bypasses all filters; zero [refractionStrength] or
/// [opticsProgress] disables both displacement and magnification. The shader
/// also bypasses displacement when
/// the engine supplies a cropped offscreen pass instead of the root-view texture:
/// Flutter does not expose that texture's origin to an image-filter shader.
/// Positive axis-aligned scaling is supported. The shader normalizes each axis
/// into the smaller scale's units before resolving the rounded lens and bevel,
/// then maps displacement back to physical pixels. This keeps nonuniformly
/// scaled elliptical corners aligned with the clip, not UIKit's optical model.
class CustomGlassBackdropWidget extends StatefulWidget {
  /// Receives already resolved logical-pixel geometry from the caller.
  const CustomGlassBackdropWidget({
    super.key,
    required this.radius,
    required this.blurSigma,
    this.fallbackBlurSigma = 0,
    required this.refractionStrength,
    required this.refractionEdge,
    required this.magnification,
    this.dispersion = 0,
    this.opticsProgress = 1,
    this.prepareWhenInactive = false,
    this.backdropKey,
    this.highContrast = false,
    this.child,
  }) : assert(radius >= 0 && radius < double.infinity),
       assert(blurSigma >= 0 && blurSigma < double.infinity),
       assert(fallbackBlurSigma >= 0 && fallbackBlurSigma < double.infinity),
       assert(refractionStrength >= 0 && refractionStrength < double.infinity),
       assert(refractionEdge > 0 && refractionEdge < double.infinity),
       assert(magnification >= 1 && magnification < double.infinity),
       assert(dispersion >= 0 && dispersion < double.infinity),
       assert(opticsProgress >= 0 && opticsProgress <= 1);

  /// Radius of the clipped surface, in logical pixels.
  final double radius;

  /// Gaussian backdrop blur sigma, in logical pixels.
  final double blurSigma;

  /// Minimum blur used only when no usable optics shader can be applied.
  ///
  /// Defaults to zero. Coordinated original-backdrop passes can retain a real
  /// keyed filter while the shader is pending, failed or unsupported, even
  /// when their active-shader [blurSigma] relaxes to zero. High contrast still
  /// bypasses all filtering. Must be finite and nonnegative.
  final double fallbackBlurSigma;

  /// Requested maximum outward sampling displacement, in logical pixels.
  ///
  /// This compresses visible bevel features toward the lens interior,
  /// independently of center magnification.
  /// The shader bounds displacement relative to bevel width and fades it to
  /// zero at the clipped edge, keeping foreground samples continuous there.
  /// Directional displacement/dispersion ends within the corner radius so
  /// interior normal switches cannot introduce a diagonal seam.
  final double refractionStrength;

  /// Width of the lens edge transition, in logical pixels.
  ///
  /// Bevel displacement/dispersion also respect [radius]; radius zero disables
  /// those directional effects. Center magnification retains this envelope.
  final double refractionEdge;

  /// Static magnification of the lens center.
  final double magnification;

  /// Maximum opposite red/blue bevel offsets, in logical pixels.
  ///
  /// Zero preserves shared RGB sampling. The shader bounds nonzero offsets by
  /// the effective bevel and fades them with [opticsProgress] and edge weight.
  /// Requires nonzero [refractionStrength], like the other optical effects.
  final double dispersion;

  /// Fraction of the effective bounded displacement and magnification to apply.
  ///
  /// Must be finite and between zero and one. Progress scales displacement
  /// after the shader clamps it to the effective bevel, so interaction feedback
  /// spans the full interval without reaching the displacement limit early.
  /// Zero retains configured blur without applying the optics shader; by default
  /// it also defers resource preparation. One preserves the full lens effect.
  final double opticsProgress;

  /// Prepares the private shader resource while configured optics are inactive.
  ///
  /// The interaction-only foreground pass opts in during normal mounting so it
  /// can retain its shader before first contact. This never applies
  /// a filter at zero [opticsProgress], draws a warm-up frame, or bypasses high
  /// contrast, zero strength or an unsupported renderer.
  final bool prepareWhenInactive;

  /// Optional identity for explicitly coordinated original-backdrop inputs.
  ///
  /// Null keeps this pass independent. Sharing with an earlier backdrop lets
  /// this filter use that pass's original input instead of its filtered result;
  /// foreground filters must remain independent to sample the painted row.
  final BackdropKey? backdropKey;

  /// Removes both blur and optics for the host's high-contrast surface.
  final bool highContrast;

  /// Surface tint and foreground; neither is sampled by the filter.
  final Widget? child;

  @override
  State<CustomGlassBackdropWidget> createState() => _GlassBackdropState();
}

// StatefulWidget exception: manages a private FragmentShader resource only.
// A FragmentProgram may be shared, but each widget needs isolated uniforms and
// must dispose its own FragmentShader when removed from the tree.
class _GlassBackdropState extends State<CustomGlassBackdropWidget> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;
  bool _loadAttempted = false;
  String _status = 'disabled';

  bool get _wantsOptics =>
      !widget.highContrast &&
      widget.refractionStrength > 0 &&
      widget.opticsProgress > 0;

  bool get _canPrepareShader =>
      !widget.highContrast &&
      widget.refractionStrength > 0 &&
      (widget.prepareWhenInactive || widget.opticsProgress > 0);

  @override
  void initState() {
    super.initState();
    _prepareShader();
  }

  @override
  void didUpdateWidget(CustomGlassBackdropWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareShader();
  }

  void _prepareShader() {
    if (!_canPrepareShader) {
      _status = widget.highContrast ? 'high contrast' : 'disabled';
      return;
    }
    if (!ui.ImageFilter.isShaderFilterSupported) {
      _status = 'unsupported renderer';
      return;
    }
    if (_shader != null) {
      _status = _wantsOptics ? 'ready' : 'disabled';
      return;
    }
    if (_loadAttempted) {
      return;
    }
    _loadAttempted = true;
    _status = 'loading';
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'packages/cupertino_bottom_nav_bar/shaders/glass_refraction.frag',
      ));
      if (!mounted) {
        return;
      }
      final shader = program.fragmentShader();
      // Validate the image-filter contract before retaining this GPU resource.
      try {
        ui.ImageFilter.shader(shader);
      } catch (_) {
        shader.dispose();
        rethrow;
      }
      void retainShader() {
        _shader = shader;
        _status = _wantsOptics
            ? 'ready'
            : widget.highContrast
            ? 'high contrast'
            : 'disabled';
      }

      // Retaining an inactive resource does not change the rendered subtree.
      // Its next normal update applies the shader only when optics are active.
      if (_wantsOptics) {
        setState(retainShader);
      } else {
        retainShader();
      }
    } catch (error, stack) {
      if (mounted) {
        setState(() => _status = 'shader failure');
      }
      // Retain usable blur and report the actual asset/contract failure through
      // the host's usual Flutter diagnostics rather than silently hiding it.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'cupertino_bottom_nav_bar',
          context: ErrorDescription(
            'loading the refracting backdrop; ordinary blur remains available',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('refractionStatus', _status));
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.expand();
    final shader = _wantsOptics ? _shader : null;
    final fallbackBlurSigma =
        widget.fallbackBlurSigma.isFinite && widget.fallbackBlurSigma >= 0
        ? widget.fallbackBlurSigma
        : 0.0;
    final fallbackSigma = math.max(widget.blurSigma, fallbackBlurSigma);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: widget.highContrast
          ? child
          : shader != null
          ? _RefractingBackdrop(
              key: const ValueKey('glass_backdrop_refracting'),
              shader: shader,
              radius: widget.radius,
              blurSigma: widget.blurSigma,
              fallbackBlurSigma: fallbackBlurSigma,
              strength: widget.refractionStrength,
              edge: widget.refractionEdge,
              magnification: widget.magnification,
              dispersion: widget.dispersion.isFinite && widget.dispersion >= 0
                  ? widget.dispersion
                  : 0,
              opticsProgress: widget.opticsProgress,
              backdropKey: widget.backdropKey,
              child: child,
            )
          : fallbackSigma == 0
          ? child
          : BackdropFilter(
              key: const ValueKey('glass_backdrop_blur_fallback'),
              backdropGroupKey: widget.backdropKey,
              filter: ui.ImageFilter.blur(
                sigmaX: fallbackSigma,
                sigmaY: fallbackSigma,
              ),
              child: child,
            ),
    );
  }
}

class _RefractingBackdrop extends SingleChildRenderObjectWidget {
  const _RefractingBackdrop({
    super.key,
    required this.shader,
    required this.radius,
    required this.blurSigma,
    required this.fallbackBlurSigma,
    required this.strength,
    required this.edge,
    required this.magnification,
    required this.dispersion,
    required this.opticsProgress,
    required this.backdropKey,
    required super.child,
  });

  final ui.FragmentShader shader;
  final double radius;
  final double blurSigma;
  final double fallbackBlurSigma;
  final double strength;
  final double edge;
  final double magnification;
  final double dispersion;
  final double opticsProgress;
  final BackdropKey? backdropKey;

  @override
  _RenderRefractingBackdrop createRenderObject(BuildContext context) =>
      _RenderRefractingBackdrop(this);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRefractingBackdrop renderObject,
  ) => renderObject.update(this);
}

class _RenderRefractingBackdrop extends RenderProxyBox {
  _RenderRefractingBackdrop(this.configuration);

  _RefractingBackdrop configuration;
  String _coordinateStatus = 'not composited';
  final CustomGlassBackdropFilterCache _filterCache =
      CustomGlassBackdropFilterCache();

  @override
  void detach() {
    _filterCache.clear();
    super.detach();
  }

  @override
  void dispose() {
    _filterCache.clear();
    super.dispose();
  }

  void update(_RefractingBackdrop value) {
    configuration = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  CustomGlassBackdropLayer? get layer =>
      super.layer as CustomGlassBackdropLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    if (layer != null &&
        !identical(layer!.backdropKey, configuration.backdropKey)) {
      // BackdropFilterLayer's key setter marks the layer dirty, which is not
      // valid once this composition-refreshing layer is always-needs. Replace
      // only the layer; the widget retains its shader and current uniforms.
      layer = null;
    }
    layer ??= CustomGlassBackdropLayer(
      resolveFilter: _resolveFilter,
      backdropKey: configuration.backdropKey,
    );
    context.pushLayer(layer!, super.paint, offset);
  }

  ui.ImageFilter? _resolveFilter() {
    if (!attached) {
      return null;
    }
    // Recompute just before composition: an ancestor Transform can move a
    // retained RepaintBoundary without invoking this render object's paint.
    // getTransformTo returns LOGICAL root coordinates; RenderView supplies
    // physical scaling. This refresh changes uniforms and filter objects only,
    // never render layout/paint state or the framework's widget tree.
    final root = owner?.rootNode;
    List<double>? uniforms;
    if (root is RenderView) {
      final transform = root.configuration.toMatrix()
        ..multiply(getTransformTo(null));
      final m = transform.storage;
      final scale = math.min(m[0], m[5]);
      final simpleTransform =
          m.every((value) => value.isFinite) &&
          scale > 0 &&
          m[1].abs() < 0.0001 &&
          m[4].abs() < 0.0001 &&
          m[3] == 0 &&
          m[7] == 0 &&
          m[15] == 1;
      if (simpleTransform && !size.isEmpty) {
        final rect = MatrixUtils.transformRect(transform, Offset.zero & size);
        final viewSize = MatrixUtils.transformRect(
          root.configuration.toMatrix(),
          Offset.zero & root.size,
        ).size;
        // Floats 0/1 and sampler 0 remain reserved for the actual pass texture.
        // Resolve every caller-owned uniform before looking up the last filter;
        // retained ancestor motion must still invalidate its native snapshot.
        uniforms = [
          rect.left,
          rect.top,
          rect.width,
          rect.height,
          configuration.radius * scale,
          configuration.strength * scale,
          configuration.edge * scale,
          configuration.magnification,
          viewSize.width,
          viewSize.height,
          m[0] / scale,
          m[5] / scale,
          configuration.opticsProgress,
          configuration.dispersion * scale,
        ];
        _coordinateStatus =
            'root physical coordinates; pass-size guard enabled';
      } else {
        _coordinateStatus = 'unsupported transform; blur fallback';
      }
    } else {
      _coordinateStatus = 'no RenderView; blur fallback';
    }
    // A valid shader owns the configured blur relaxation. When coordinates or
    // transforms prevent that shader, retain the caller's fallback floor so a
    // shared original-backdrop pass does not disappear at zero active blur.
    final blurSigma = uniforms == null
        ? math.max(configuration.blurSigma, configuration.fallbackBlurSigma)
        : configuration.blurSigma;
    return _filterCache.resolve(
      shader: uniforms == null ? null : configuration.shader,
      uniforms: uniforms,
      blurSigma: blurSigma,
      createFilter: () {
        ui.ImageFilter? filter;
        if (uniforms != null) {
          final shader = configuration.shader;
          for (var index = 0; index < uniforms.length; index++) {
            shader.setFloat(index + 2, uniforms[index]);
          }
          filter = ui.ImageFilter.shader(shader);
        }
        if (blurSigma > 0) {
          final blur = ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          );
          // Read the original pass before blur creates a cropped intermediate.
          filter = filter == null
              ? blur
              : ui.ImageFilter.compose(outer: blur, inner: filter);
        }
        return filter;
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('refractionCoordinates', _coordinateStatus));
  }
}

/// Latest exact filter inputs only; this cache never retains backdrop pixels.
///
/// Package-internal and exposed only for backend-independent lifecycle tests.
/// Composition still resolves geometry on every scene and submits the filter
/// against its live input. Native shader filters snapshot uniforms when the
/// scene consumes them, so changed inputs must create a new filter object.
@visibleForTesting
class CustomGlassBackdropFilterCache {
  ui.FragmentShader? _shader;
  List<double>? _uniforms;
  double? _blurSigma;
  ui.ImageFilter? _filter;

  /// Reuses only the immediately preceding, exactly matching filter snapshot.
  ui.ImageFilter? resolve({
    required ui.FragmentShader? shader,
    required List<double>? uniforms,
    required double blurSigma,
    required ui.ImageFilter? Function() createFilter,
  }) {
    if (_blurSigma == blurSigma &&
        identical(_shader, shader) &&
        listEquals(_uniforms, uniforms)) {
      return _filter;
    }
    final filter = createFilter();
    _shader = shader;
    _uniforms = uniforms == null ? null : List<double>.unmodifiable(uniforms);
    _blurSigma = blurSigma;
    _filter = filter;
    return filter;
  }

  /// Releases cached filter and shader references at a render lifecycle boundary.
  void clear() {
    _shader = null;
    _uniforms = null;
    _blurSigma = null;
    _filter = null;
  }
}

/// Package-internal layer that refreshes backdrop geometry during composition.
///
/// Exposed from this internal source file for focused retained-layer tests,
/// without exporting it from the package API. Each scene resolves current filter
/// inputs before submitting the live backdrop, including when an ancestor
/// retained the render subtree. This layer schedules no frame or repaint itself.
@visibleForTesting
class CustomGlassBackdropLayer extends BackdropFilterLayer {
  /// [resolveFilter] returns null when the filter should be bypassed.
  CustomGlassBackdropLayer({
    required this.resolveFilter,
    BackdropKey? backdropKey,
  }) {
    // Initialize inherited key storage while its normal dirty-marking setter
    // is still legal. After construction this layer refreshes every scene and
    // a different key requires a replacement layer, not another setter call.
    super.backdropKey = backdropKey;
    _readyForComposition = true;
  }

  /// Resolves the current scene's inputs, reusing only an exact filter snapshot.
  final ui.ImageFilter? Function() resolveFilter;

  ui.ImageFilter? _resolvedFilter;
  bool _readyForComposition = false;

  @override
  bool get alwaysNeedsAddToScene => _readyForComposition;

  @override
  ui.ImageFilter? get filter => _resolvedFilter;

  @override
  set filter(ui.ImageFilter? value) {
    // The base setter calls markNeedsAddToScene, which is forbidden on an
    // alwaysNeedsAddToScene layer. Our storage is already refreshed every scene.
    _resolvedFilter = value;
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    _resolvedFilter = resolveFilter();
    if (_resolvedFilter == null) {
      addChildrenToScene(builder);
      return;
    }
    super.addToScene(builder);
  }
}
