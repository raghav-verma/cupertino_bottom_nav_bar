import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// Run the shipping fragment program as a paint shader over a synthetic texture.
// This verifies its actual sampling math without pretending that the software
// test backend supports Impeller's ImageFilter.shader composition path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.FragmentProgram program;
  late ui.Image texture;
  var textureReady = false;

  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset(
      'shaders/glass_refraction.frag',
    );
    final pixels = Uint8List(_width * _height * 4);
    for (var y = 0; y < _height; y++) {
      for (var x = 0; x < _width; x++) {
        final offset = (y * _width + x) * 4;
        pixels[offset] = x * 2;
        pixels[offset + 1] = y * 4;
        pixels[offset + 2] = x + y;
        pixels[offset + 3] = 255;
      }
    }
    texture = await _decodePixels(pixels);
    textureReady = true;
  });

  tearDownAll(() {
    if (textureReady) texture.dispose();
  });

  for (final dispersion in [0.0, 1.0]) {
    test(
      'small-radius bevel is corner-bounded, dispersion $dispersion',
      () async {
        final wide = await _render(
          program,
          texture,
          radius: 4,
          edge: 12,
          dispersion: dispersion,
        );
        final bounded = await _render(
          program,
          texture,
          radius: 4,
          edge: 4,
          dispersion: dispersion,
        );
        final identity = await _render(
          program,
          texture,
          radius: 4,
          strength: 0,
        );
        for (var y = 6; y <= 12; y++) {
          for (var x = 6; x <= 12; x++) {
            for (final corner in [
              (x, y),
              (_width - 1 - x, y),
              (x, _height - 1 - y),
              (_width - 1 - x, _height - 1 - y),
            ]) {
              final offset = (corner.$2 * _width + corner.$1) * 4;
              expect(
                wide.sublist(offset, offset + 4),
                identity.sublist(offset, offset + 4),
                reason: 'No normal-switch seam at $corner',
              );
            }
          }
        }
        expect(wide, bounded);
        expect(wide, isNot(identity), reason: 'The safe edge still refracts');
      },
    );
  }

  test(
    'square corners bypass bevel but preserve center magnification',
    () async {
      final identity = await _render(program, texture, radius: 0, strength: 0);
      final square = await _render(program, texture, radius: 0, dispersion: 1);
      expect(square, identity);
      final magnified = await _render(
        program,
        texture,
        radius: 0,
        dispersion: 1,
        magnification: 1.2,
      );
      final magnificationOnly = await _render(
        program,
        texture,
        radius: 0,
        strength: 0,
        magnification: 1.2,
      );
      expect(magnified, magnificationOnly);
      expect(magnified, isNot(identity));
      final narrowerEnvelope = await _render(
        program,
        texture,
        radius: 0,
        edge: 4,
        magnification: 1.2,
      );
      expect(
        magnified,
        isNot(narrowerEnvelope),
        reason: 'The center envelope retains the requested edge width',
      );
    },
  );

  test('outward bevel samples compress visible edge features inward', () async {
    final step = await _decodePixels(_stepPixels(transparent: false));
    addTearDown(step.dispose);
    final identity = await _render(program, step, radius: 12, strength: 0);
    final outward = await _render(program, step, radius: 12);
    // This pixel is black without refraction. The outward ray crosses the
    // white edge at x94, moving its visible boundary toward the lens interior.
    // The previous inward ray instead stays in the solid black region.
    expect(_rgba(identity, 93, 30), [0, 0, 0, 255]);
    expect(_rgba(outward, 93, 30), [255, 255, 255, 255]);
  });

  test(
    'held physical geometry narrows the foreground caption compression band',
    () async {
      // Measured Pixel held lens: source 70.3 x 48, minimum physical scale
      // 3.255, horizontal/vertical axis ratio 3.28125 / 3.255. The synthetic
      // stripe occupies the independently captured unfiltered caption bounds.
      final wide = await _renderHeldCaptionStripe(program, edge: 12);
      final narrow = await _renderHeldCaptionStripe(program, edge: 6);
      int stripeHeight(Uint8List pixels) {
        var count = 0;
        for (var y = 2300; y < 2355; y++) {
          if (pixels[(y * 1080 + 535) * 4] > 127) count++;
        }
        return count;
      }

      final wideHeight = stripeHeight(wide);
      final narrowHeight = stripeHeight(narrow);
      expect(wideHeight, inInclusiveRange(12, 15));
      expect(narrowHeight, inInclusiveRange(20, 24));
      expect(narrowHeight - wideHeight, greaterThanOrEqualTo(6));
    },
  );

  for (final transparent in [false, true]) {
    test(
      'weighted dispersion attenuates ${transparent ? 'transparent' : 'opaque'} step fringe',
      () async {
        final pixels = _stepPixels(transparent: transparent);
        final step = await _decodePixels(pixels);
        addTearDown(step.dispose);
        final dispersed = await _render(
          program,
          step,
          radius: 12,
          strength: 0,
          dispersion: 4,
        );
        // The base ray is on the black side, the red ray reaches solid white,
        // and the blue ray stays black. A half-weight reconstruction is about
        // 128 red, not the hard-selected 255 or a shortened ray's interpolation.
        final fringe = _rgba(dispersed, 93, 30);
        expect(fringe[0], closeTo(128, 1));
        expect(fringe[1], 0);
        expect(fringe[2], 0);
        expect(fringe[3], transparent ? closeTo(128, 1) : 255);
        for (var offset = 0; offset < dispersed.length; offset += 4) {
          final alpha = dispersed[offset + 3];
          for (var channel = 0; channel < 3; channel++) {
            expect(
              dispersed[offset + channel],
              lessThanOrEqualTo(alpha),
              reason: 'Premultiplied channel at byte ${offset + channel}',
            );
          }
        }
      },
    );
  }

  test(
    'zero dispersion and inactive bevel preserve the original samples',
    () async {
      final pixels = _stepPixels(transparent: false);
      final step = await _decodePixels(pixels);
      addTearDown(step.dispose);
      final identity = await _render(program, step, radius: 12, strength: 0);
      expect(identity, pixels);
      final dispersed = await _render(
        program,
        step,
        radius: 12,
        strength: 0,
        dispersion: 4,
      );
      // This inner rectangle lies beyond the complete radius-12 bevel. The
      // outer corner pixels are outside the rounded lens, where it is inactive.
      for (var y = 12; y < _height - 12; y++) {
        for (var x = 12; x < _width - 12; x++) {
          expect(_rgba(dispersed, x, y), _rgba(identity, x, y));
        }
      }
      for (final corner in [(0, 0), (99, 0), (0, 59), (99, 59)]) {
        expect(
          _rgba(dispersed, corner.$1, corner.$2),
          _rgba(identity, corner.$1, corner.$2),
        );
      }
      final inactive = await _render(
        program,
        step,
        radius: 12,
        strength: 0,
        dispersion: 4,
        opticsProgress: 0,
      );
      expect(inactive, identity);
    },
  );
}

const _width = 100;
const _height = 60;

Future<Uint8List> _renderHeldCaptionStripe(
  ui.FragmentProgram program, {
  required double edge,
}) async {
  final inputRecorder = ui.PictureRecorder();
  final inputCanvas = ui.Canvas(inputRecorder);
  inputCanvas.drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
  inputCanvas.drawRect(
    const ui.Rect.fromLTRB(503, 2321, 576, 2341),
    ui.Paint()..color = const ui.Color(0xffffffff),
  );
  final inputPicture = inputRecorder.endRecording();
  final input = await inputPicture.toImage(1080, 2424);
  final shader = program.fragmentShader();
  final outputRecorder = ui.PictureRecorder();
  ui.Picture? outputPicture;
  ui.Image? output;
  try {
    final uniforms = <double>[
      1080,
      2424,
      419.7,
      2209.4,
      650.3 - 419.7,
      2365.6 - 2209.4,
      18 * 3.255,
      6 * 3.255,
      edge * 3.255,
      1.12,
      1080,
      2424,
      3.28125 / 3.255,
      1,
      1,
      0.25 * 3.255,
    ];
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
    shader.setImageSampler(0, input);
    ui.Canvas(outputRecorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1080, 2424),
      ui.Paint()..shader = shader,
    );
    outputPicture = outputRecorder.endRecording();
    output = await outputPicture.toImage(1080, 2424);
    final bytes = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    output?.dispose();
    outputPicture?.dispose();
    if (outputRecorder.isRecording) outputRecorder.endRecording().dispose();
    shader.dispose();
    input.dispose();
    inputPicture.dispose();
  }
}

Uint8List _stepPixels({required bool transparent}) {
  final pixels = Uint8List(_width * _height * 4);
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final offset = (y * _width + x) * 4;
      final value = x >= 94 ? 255 : 0;
      pixels[offset] = value;
      pixels[offset + 1] = value;
      pixels[offset + 2] = value;
      pixels[offset + 3] = transparent ? value : 255;
    }
  }
  return pixels;
}

Future<ui.Image> _decodePixels(Uint8List pixels) {
  final decoded = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    _width,
    _height,
    ui.PixelFormat.rgba8888,
    decoded.complete,
  );
  return decoded.future;
}

List<int> _rgba(Uint8List pixels, int x, int y) {
  final offset = (y * _width + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

Future<Uint8List> _render(
  ui.FragmentProgram program,
  ui.Image texture, {
  required double radius,
  double edge = 12,
  double strength = 3,
  double dispersion = 0,
  double magnification = 1,
  double opticsProgress = 1,
}) async {
  final shader = program.fragmentShader();
  final uniforms = <double>[
    _width.toDouble(), _height.toDouble(), // Engine input texture dimensions.
    0, 0, // Origin.
    _width.toDouble(), _height.toDouble(), // Surface.
    radius, strength, edge, magnification,
    _width.toDouble(), _height.toDouble(), // Root view.
    1, 1, // Axis scale.
    opticsProgress, dispersion, // Interaction progress, channel offset.
  ];
  final recorder = ui.PictureRecorder();
  ui.Picture? picture;
  ui.Image? image;
  try {
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
    shader.setImageSampler(0, texture);
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 100, 60),
      ui.Paint()..shader = shader,
    );
    picture = recorder.endRecording();
    image = await picture.toImage(_width, _height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    image?.dispose();
    picture?.dispose();
    if (recorder.isRecording) recorder.endRecording().dispose();
    shader.dispose();
  }
}
