part of '../cupertino_bottom_nav_bar.dart';

/// Owns only platform-view/channel and image-rasterization lifecycle.
///
/// Selection remains an external input. The native renderer is available only
/// on supported iOS versions; unsupported platforms, failed initialization and
/// large-text layouts retain the accessible Flutter dock.
class _NativeNavigationDockSurface extends StatefulWidget {
  const _NativeNavigationDockSurface({
    required this.items,
    required this.style,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.avatarSize,
    required this.labelSize,
    required this.captionMaxWidth,
    required this.semanticLabel,
    required this.fallback,
  });

  final List<AppGlassNavigationItem> items;
  final AppGlassNavigationStyle style;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final double width;
  final double height;
  final double iconSize;
  final double avatarSize;
  final double labelSize;
  final double captionMaxWidth;
  final String semanticLabel;
  final Widget fallback;

  @override
  State<_NativeNavigationDockSurface> createState() =>
      _NativeNavigationDockSurfaceState();
}

class _NativeNavigationDockSurfaceState
    extends State<_NativeNavigationDockSurface> {
  static const _discovery = MethodChannel(
    'cupertino_bottom_nav_bar/native_navigation',
  );
  static const _viewType = 'cupertino_bottom_nav_bar/native_navigation_dock';
  final Map<Object, Future<Uint8List>> _images = {};
  MethodChannel? _channel;
  Map<String, Object?>? _payload;
  List<Object?>? _signature;
  int _revision = 0;
  int _presentationRevision = 0;
  bool _supported = false;
  bool _nativeReady = false;
  bool _visible = true;
  double _minimumNativeHeight = 0;
  Map<String, Object?>? _successfulPayload;
  Map<String, num>? _layoutMetrics;
  int _lastMeasurementSequence = 0;
  bool _fitFailureScheduled = false;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    try {
      final supported = await _discovery.invokeMethod<bool>('supportsGlass');
      if (!mounted || supported != true) return;
      setState(() => _supported = true);
    } on PlatformException {
      // A supported Flutter dock stays visible if native setup is unavailable.
    } on MissingPluginException {
      // Widget previews/tests and older runners need no native registration.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    _synchronize();
  }

  @override
  void didUpdateWidget(_NativeNavigationDockSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _layoutMetrics = null;
      _setNativeReady(false);
    }
    _synchronize();
  }

  void _synchronize() {
    final style = widget.style;
    final media = MediaQuery.of(context);
    final signature = <Object?>[
      widget.selectedIndex,
      _visible,
      Theme.of(context).brightness,
      style,
      media.devicePixelRatio,
      media.textScaler,
      media.disableAnimations,
      widget.iconSize,
      widget.avatarSize,
      widget.labelSize,
      widget.captionMaxWidth,
      widget.semanticLabel,
      for (final item in widget.items) ...[
        item.label,
        item.semanticLabel,
        item.badgeLabel,
        item.enabled,
        item.icon,
        item.selectedIcon,
        item.nativeImage?.assetPath,
        item.nativeImage?.initials,
        item.nativeImage?.assetPackage,
      ],
    ];
    if (listEquals(signature, _signature)) return;
    _signature = signature;
    final revision = ++_revision;
    final snapshot = widget;
    final visible = _visible;
    final brightness = Theme.of(context).brightness;
    final initialsStyle = style.initialsStyle.copyWith(
      color: style.avatarForegroundColor,
    );
    Future<void>(() async {
      try {
        final items = <Map<String, Object?>>[];
        for (final item in snapshot.items) {
          final image = item.nativeImage;
          final icon = image == null
              ? await _glyph(
                  item.icon,
                  snapshot.iconSize,
                  media.devicePixelRatio,
                  style.foregroundColor,
                )
              : await _portrait(
                  image,
                  snapshot.avatarSize,
                  media.devicePixelRatio,
                  style.avatarBackgroundColor,
                  initialsStyle,
                );
          final selectedIcon = image == null
              ? await _glyph(
                  item.selectedIcon ?? item.icon,
                  snapshot.iconSize,
                  media.devicePixelRatio,
                  style.foregroundColor,
                )
              : icon;
          items.add({
            'label': item.label,
            'semanticLabel': item.semanticLabel ?? item.label,
            'badge': item.badgeLabel,
            'enabled': item.enabled,
            'icon': icon,
            'selectedIcon': selectedIcon,
            'originalImage': image != null,
          });
        }
        final payload = <String, Object?>{
          'layoutRevision': revision,
          'items': items,
          'semanticLabel': snapshot.semanticLabel,
          'selectedIndex': snapshot.selectedIndex,
          'selectedColor': style.selectedForegroundColor.toARGB32(),
          'foregroundColor': style.foregroundColor.toARGB32(),
          'badgeColor': style.badgeBackgroundColor.toARGB32(),
          'badgeForegroundColor': style.badgeForegroundColor.toARGB32(),
          'brightness': brightness.name,
          'labelSize': media.textScaler.scale(snapshot.labelSize),
          'captionMaxWidth': snapshot.captionMaxWidth,
          'imageScale': media.devicePixelRatio,
          'reduceMotion': media.disableAnimations,
          'visible': visible,
        };
        if (!mounted || revision != _revision) return;
        setState(() => _payload = payload);
        await _updateNative(payload);
      } catch (_) {
        if (!mounted || revision != _revision) return;
        setState(() => _supported = false);
      }
    });
    // Hide the native surface promptly, without waiting for asset decoding.
    final channel = _channel;
    if (channel != null) {
      _updateVisibility(channel, visible);
    }
  }

  Future<bool> _updateNative(Map<String, Object?> payload) async {
    final channel = _channel;
    if (channel == null) return false;
    try {
      await channel.invokeMethod<void>('update', payload);
      if (!mounted || !_supported || !identical(_channel, channel)) {
        return false;
      }
      if (identical(_payload, payload)) _successfulPayload = payload;
      _revealIfFitted();
      return true;
    } on PlatformException {
      if (mounted && identical(_channel, channel)) {
        setState(() => _supported = false);
      }
    } on MissingPluginException {
      if (mounted && identical(_channel, channel)) {
        setState(() => _supported = false);
      }
    }
    return false;
  }

  bool get _geometryFits {
    final metrics = _layoutMetrics;
    if (metrics == null ||
        _payload?['layoutRevision'] != _revision ||
        metrics['revision'] != _payload?['layoutRevision']) {
      return false;
    }
    final tolerance = 1 / MediaQuery.devicePixelRatioOf(context);
    return (metrics['width']! - widget.width).abs() <= tolerance &&
        (metrics['height']! - math.max(widget.height, _minimumNativeHeight))
                .abs() <=
            tolerance &&
        metrics['height']! + tolerance >= metrics['minimumHeight']! &&
        metrics['topOverflow']! <= tolerance;
  }

  void _revealIfFitted() {
    if (!mounted || !_supported || !_visible || _nativeReady) return;
    if (identical(_successfulPayload, _payload) && _geometryFits) {
      _setNativeReady(true);
    }
  }

  void _setNativeReady(bool ready) {
    if (_nativeReady == ready) return;
    setState(() => _nativeReady = ready);
    final channel = _channel;
    if (channel != null) _updatePresentation(channel, ready);
  }

  Future<void> _updatePresentation(MethodChannel channel, bool ready) async {
    final revision = ++_presentationRevision;
    try {
      final accepted = await channel.invokeMethod<bool>('presentation', {
        'ready': ready,
        'layoutRevision': _payload?['layoutRevision'],
      });
      if (!mounted ||
          !_supported ||
          !identical(_channel, channel) ||
          revision != _presentationRevision) {
        return;
      }
      if (ready && accepted != true) {
        _setNativeReady(false);
        _queryLayoutMetrics(channel);
      }
    } on PlatformException {
      if (mounted &&
          identical(_channel, channel) &&
          revision == _presentationRevision) {
        setState(() => _supported = false);
      }
    } on MissingPluginException {
      if (mounted &&
          identical(_channel, channel) &&
          revision == _presentationRevision) {
        setState(() => _supported = false);
      }
    }
  }

  void _acceptLayoutMetrics(Object? value, MethodChannel channel) {
    if (!mounted || !_supported || !identical(_channel, channel)) return;
    if (value is! Map ||
        _payload?['layoutRevision'] != _revision ||
        value['revision'] != _payload?['layoutRevision']) {
      return;
    }
    final metrics = <String, num>{};
    for (final key in ['width', 'height', 'minimumHeight', 'topOverflow']) {
      final number = value[key];
      if (number is! num ||
          !number.isFinite ||
          (key == 'topOverflow' ? number < 0 : number <= 0)) {
        return;
      }
      metrics[key] = number;
    }
    final revision = value['revision'];
    if (revision is! int || revision < 1) return;
    final tolerance = 1 / MediaQuery.devicePixelRatioOf(context);
    if ((metrics['width']! - widget.width).abs() > tolerance) return;
    metrics['revision'] = revision;
    // Query replies and callbacks can arrive out of order within one payload
    // revision. Only native measurement order may replace fitted geometry.
    final sequence = value['measurementSequence'];
    if (value.containsKey('measurementSequence')) {
      if (sequence is! int || sequence <= _lastMeasurementSequence) return;
      _lastMeasurementSequence = sequence;
    } else if (_lastMeasurementSequence != 0) {
      // Older plugins remain compatible until sequencing has been negotiated;
      // an unsequenced reply must never overwrite a sequenced measurement.
      return;
    }
    if (mapEquals(metrics, _layoutMetrics)) {
      _revealIfFitted();
      return;
    }
    final previousMinimum = _minimumNativeHeight;
    setState(() {
      _layoutMetrics = metrics;
      _minimumNativeHeight = math.max(
        _minimumNativeHeight,
        metrics['minimumHeight']!.toDouble(),
      );
    });
    if (!_geometryFits) _setNativeReady(false);
    _revealIfFitted();
    if (_minimumNativeHeight > previousMinimum) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _supported && identical(_channel, channel)) {
          _queryLayoutMetrics(channel);
        }
      });
    }
  }

  Future<void> _queryLayoutMetrics(MethodChannel channel) async {
    try {
      final metrics = await channel.invokeMethod<Object?>('layoutMetrics');
      _acceptLayoutMetrics(metrics, channel);
    } on PlatformException {
      if (mounted && identical(_channel, channel)) {
        setState(() => _supported = false);
      }
    } on MissingPluginException {
      if (mounted && identical(_channel, channel)) {
        setState(() => _supported = false);
      }
    }
  }

  void _rejectTightHeight() {
    if (_fitFailureScheduled) return;
    _fitFailureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _supported = false);
    });
  }

  Future<void> _updateVisibility(MethodChannel channel, bool visible) async {
    try {
      await channel.invokeMethod<void>('visibility', {'visible': visible});
    } on PlatformException {
      if (mounted) setState(() => _supported = false);
    } on MissingPluginException {
      if (mounted) setState(() => _supported = false);
    }
  }

  Future<Uint8List> _glyph(
    IconData icon,
    double size,
    double scale,
    Color color,
  ) => _images.putIfAbsent(
    'glyph:${icon.codePoint}:${icon.fontFamily}:${icon.fontPackage}:'
    '${icon.fontFamilyFallback}:$size:$scale:${color.toARGB32()}',
    () => _rasterize(size, scale, (canvas) {
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            fontFamilyFallback: icon.fontFamilyFallback,
            package: icon.fontPackage,
            color: color,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
      painter.dispose();
    }),
  );

  Future<Uint8List> _portrait(
    AppGlassNavigationImage source,
    double size,
    double scale,
    Color background,
    TextStyle style,
  ) => _images.putIfAbsent(
    // Diagnostic TextStyle strings omit properties and collapse in release.
    // Retain value equality for all typography inputs, including shadows.
    (
      assetPackage: source.assetPackage,
      assetPath: source.assetPath,
      initials: source.initials,
      size: size,
      scale: scale,
      background: background.toARGB32(),
      style: style,
    ),
    () async {
      ui.Image? image;
      final path = source.assetPath;
      if (path != null) {
        try {
          final asset = source.assetPackage == null
              ? path
              : 'packages/${source.assetPackage}/$path';
          final data = await rootBundle.load(asset);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            targetWidth: (size * scale).ceil(),
          );
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        } catch (_) {
          // Resolved initials remain available for missing local portraits.
        }
      }
      try {
        return await _rasterize(size, scale, (canvas) {
          canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size, size)));
          if (image != null) {
            final side = math.min(image.width, image.height).toDouble();
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                (image.width - side) / 2,
                (image.height - side) / 2,
                side,
                side,
              ),
              Rect.fromLTWH(0, 0, size, size),
              Paint()..filterQuality = FilterQuality.high,
            );
          } else {
            canvas.drawColor(background, BlendMode.src);
            final painter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(text: source.initials, style: style),
              maxLines: 1,
            )..layout(maxWidth: size);
            painter.paint(
              canvas,
              Offset((size - painter.width) / 2, (size - painter.height) / 2),
            );
            painter.dispose();
          }
        });
      } finally {
        image?.dispose();
      }
    },
  );

  Future<Uint8List> _rasterize(
    double size,
    double scale,
    void Function(Canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    paint(canvas);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(
        (size * scale).ceil(),
        (size * scale).ceil(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Unable to prepare dock image');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      picture.dispose();
      image?.dispose();
    }
  }

  void _onCreated(int id) {
    final channel = MethodChannel('$_viewType/$id');
    _channel = channel;
    _lastMeasurementSequence = 0;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'layoutMetrics') {
        _acceptLayoutMetrics(call.arguments, channel);
        return null;
      }
      if (!mounted ||
          !_visible ||
          !_nativeReady ||
          !identical(_channel, channel) ||
          call.method != 'select') {
        return null;
      }
      final index = call.arguments;
      if (index is int &&
          index >= 0 &&
          index < widget.items.length &&
          widget.items[index].enabled) {
        try {
          widget.onItemSelected(index);
        } catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'cupertino_bottom_nav_bar',
              context: ErrorDescription('while requesting native selection'),
            ),
          );
        }
        // UIKit may show immediate gesture feedback, but the owning widget
        // remains authoritative even when it declines a selection request.
        await WidgetsBinding.instance.endOfFrame;
        if (mounted &&
            _visible &&
            _nativeReady &&
            identical(_channel, channel)) {
          return widget.selectedIndex;
        }
      }
      return null;
    });
    final payload = _payload;
    _updatePresentation(channel, false);
    if (payload != null) _updateNative(payload);
    _updateVisibility(channel, _visible);
    _queryLayoutMetrics(channel);
  }

  @override
  void dispose() {
    ++_revision;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _images.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    if (!_supported || payload == null) return widget.fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(widget.height, _minimumNativeHeight);
        if (_minimumNativeHeight > constraints.maxHeight) {
          _rejectTightHeight();
          return widget.fallback;
        }
        final nativeDock = SizedBox(
          key: const Key('glass_navigation_native_dock'),
          width: widget.width,
          height: height,
          child: ExcludeFocus(
            excluding: !_visible || !_nativeReady,
            child: ExcludeSemantics(
              excluding: !_visible || !_nativeReady,
              child: IgnorePointer(
                ignoring: !_visible || !_nativeReady,
                // Keep the platform layer attached for public UIKit measurement.
                // Native presentation separately gates paint, input and semantics.
                child: UiKitView(
                  viewType: _viewType,
                  // This bounded dock is not inside a Flutter scroll gesture.
                  // UIKit owns its press/scrub sequence; Flutter hit testing and
                  // the explicit route-visibility boundary still guard overlays.
                  gestureBlockingPolicy:
                      UiKitViewGestureBlockingPolicy.doNotBlockGesture,
                  creationParams: payload,
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: _onCreated,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  },
                ),
              ),
            ),
          ),
        );
        return Stack(
          fit: StackFit.passthrough,
          children: [
            nativeDock,
            if (!_nativeReady) Positioned.fill(child: widget.fallback),
          ],
        );
      },
    );
  }
}
