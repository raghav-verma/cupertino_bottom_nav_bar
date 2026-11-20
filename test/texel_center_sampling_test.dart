import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// Exercise the shipping program on synthetic pixels, including transparent
// edges and high-frequency colors. The software paint-shader backend does not
// establish Impeller image-filter composition or physical-device performance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.FragmentProgram program;
  late ui.Image texture;

  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset(
      'shaders/glass_refraction.frag',
    );
    texture = await _decode(_pixels());
  });
  tearDownAll(() => texture.dispose());

  test(
    'inactive optics preserve every centered opaque and transparent texel',
    () async {
      final result = await _render(program, texture, progress: 0);
      expect(result, await _rgba(texture));
    },
  );

  test('cropped-pass guard preserves every original centered texel', () async {
    final result = await _render(program, texture, viewWidth: _width + 20);
    expect(result, await _rgba(texture));
  });

  test('active optics preserve texel centers outside the lens', () async {
    final original = await _rgba(texture);
    final refracted = await _render(program, texture, inset: 8);
    for (var y = 0; y < _height; y++) {
      for (var x = 0; x < _width; x++) {
        if (x < 7 || y < 7 || x >= _width - 7 || y >= _height - 7) {
          expect(_pixel(refracted, x, y), _pixel(original, x, y));
        }
      }
    }
    expect(refracted, isNot(original));
  });

  test('fractional magnification still reconstructs all four neighbors', () async {
    final refracted = await _render(program, texture);
    // Center magnification 2 maps this pixel to (18.25, 14.25). The four
    // surrounding texels are white, blue, green and red at weights
    // 1/16, 3/16, 3/16 and 9/16: a nearest or two-texel shortcut cannot match.
    final pixel = _pixel(refracted, 16, 12);
    expect(pixel[0], closeTo(159, 1));
    expect(pixel[1], closeTo(64, 1));
    expect(pixel[2], closeTo(64, 1));
    expect(pixel[3], 255);
  });

  for (final axisX in [1.0, 2.0]) {
    test(
      'rounded axis-$axisX lens retains outside pixels and AA band',
      () async {
        final original = await _rgba(texture);
        final refracted = await _render(
          program,
          texture,
          inset: 4,
          radius: 6,
          originX: 0.25,
          originY: 0.25,
          axisX: axisX,
        );
        for (final corner in [(4, 4), (35, 4), (4, 27), (35, 27)]) {
          expect(
            _pixel(refracted, corner.$1, corner.$2),
            _pixel(original, corner.$1, corner.$2),
          );
        }
        // These side pixels are 0.25 physical pixels inside the boundary, so
        // they exercise its AA transition rather than the fully inside lens.
        expect(_pixel(refracted, 4, 16), isNot(_pixel(original, 4, 16)));
        expect(_pixel(refracted, 20, 4), isNot(_pixel(original, 20, 4)));
        // Compare the whole fixture against the preceding shader's raw pixels,
        // including both sides, rounded corners and the quarter-pixel AA band.
        expect(
          refracted,
          zlib.decode(base64.decode(_roundedReferences[axisX.toInt()]!)),
        );
      },
    );
  }

  test('vertical anisotropy retains the full rounded AA fixture', () async {
    final refracted = await _render(
      program,
      texture,
      inset: 4,
      radius: 6,
      originX: 0.25,
      originY: 0.25,
      axisY: 2,
    );
    expect(refracted, zlib.decode(base64.decode(_verticalRoundedReference)));
    final original = await _rgba(texture);
    expect(_pixel(refracted, 4, 16), isNot(_pixel(original, 4, 16)));
    expect(_pixel(refracted, 20, 4), isNot(_pixel(original, 20, 4)));
  });
}

const _width = 40;
const _height = 32;

// Added before rectangle rejection to preserve vertical axis scaling as well
// as the original horizontal fixture, including its quarter-pixel AA band.
const _verticalRoundedReference =
    'eJztmH9MlGUcwCHECQRPigE5irMsypprsx9mucw1J7QxbS+68gd3L3UcPywgg0NA4eA4UHxMEg6EdRpSq8ao5ay1FquZjFhjbk23xrrwAS1McQ7FFPk0sk3/0N1h3IGt54/32ee/d5999j7P9w0ImPoL4Opzau3XXvBvYMrt/xF/ocPBHI8RzBkQnIwURA0KTkUIZg4JzoYIwi8Kzk8TzLgiuBgoCBkRDAULIoYFg6GCWecEA0IQfVpwYrYg9ndBX1TEhPirP/Y2r59uIulORctRRU6KIi9DsfcHRUKgwtWpyM9S5GxQtBxTJIUr9nytKLIqMlcpPulTaHMUu9sUNrvC/KLi07OKdbEKe2Eci59Qt+zP/mgr+upz7EpdQIWuYz6js7VMpzFEZ3OtTkaPzraVOjuf03mzUyfvI526e3XKsnVSR3RseTr10Tr5zTobu3XkMp3qRJ3MozoFdevJ/HAJW+xPMc8txu3PYjnC2qEEXnv2AFajC6fbhcPlwmJwTSg3tXUxv3fhuP1V7Wkj+aeldBgMOI0GFrkNWFwGn/CDoX3szH3Ma39dPw6S/302VpcRp8GIw2jE4jb6jMtzV1OXEem1v5KaUt7/shuny80igxuL0U2H2+1TXtEZ7bW/2pwwn/V2M96U/TNN9b955e+Vhz73aW834if757IrN9Gjv7CwUZLb5/u0t5txaU6dR3+dz0wj4eFun/d2I67MTfHoz2i+TGpMs9/7G+OO4W6P/mpzAjl8f5zf+xvje/64y6O/pJcv4QywTEp/Dd8d8OivNy4Is/nKpPT3Xmi6R3+BgZDSsXxS+mu9vM+r71/j/sN+7y++L4J2w+NenR+FZU/7vb+Vy47T1/+nV/4+eH4JL8V3+bW/og3FXp+/o6MwO/iC3/pbMbIc2Zo3rvtf4f4WitZs93l/J0Jn8lZNHBdmBI3r/hwUNMqWgn2cvHQKx6os0n8xYd1rom6uCUeK6RobrrLFbcLqMuEcY+N1HPcP/3odm0xYek3kr2lkIHw6a2Mqb2n+eOHQfaTNM5Oyvp/KjyVpd0gcLZKqzySWEEmFS7L9C0m6kJQ3SKq/kWREScpqJDsOSbJiJbZqieySbHxAUmqXvHNE8sYjEpujnubIzWztOfiv5re7Z50nK9FGZY9GwWKN8jaN4jSNEptG6W6NomSNim818uM1tp3R2DRdo0ppWBdq2A9qFBs1Sqo0SndoFK3TsH+lYV2gUe1+lXcb2idk/v3//8Ht7W8qr78AJRUDpg==';

// Losslessly compressed synthetic RGBA references from the shipping shader
// before the outside-AA early return. These are paint-shader backend fixtures,
// not device screenshots or acceptance of another renderer's rounding.
const _roundedReferences = <int, String>{
  1: 'eJztmE1IVFEYhsXVaSFjIi4U9OJFBAs0OMZEWCkm0USozMlQyVv+MKSWXBuSHAqLUSp0/KNBLC6ZqdXCdAyRQQJF/ENMcWFK3HIhp40UjGVKvVEt2hR3TGbuFH2L8/HuDg8Ph+87QUGBXwDw4wys/vOC3wMCrv8j/LLGKJpOM5x/ytCWwXBuhOE+ZchdYHgUy5C9ytAXynB8g2EwmOGEh6E3nMG8wtAdz5A/y6AcYCgaZnCaGMqeMLTkZCFqzbAjfmUzlyEVfMFqSAjODFLkjFJ0HaZ4kE7BJijOuih6EynazBSmRYrSDoqhGApHMUUqp7jUTDFqoKi1Uhg/UVy9TjEVTGGzUxjfJ6En4iQKBuLReNe1bX6Fz8xo71qCUVBhkVSMqyqciuqTfMUeimsz9V7zS946iLaXnahTFFgEBVWSAqeq+DSXuFLh2dj0ip/N9gZGVYBFETAuCHBKgl9yp/udJr/sjGVM7N4LiyqhSpHgFCTUSZJfsv1ejya/2zKFSZzwqW+/y6XcoslPlheQJ7p87tuvMuOZmvwa5FgMiYm6+Mf5uia/i/IqFNGsi3/pPEWTX5MciiPioi7+2Xi1Jr8yeQMlYocu/o3wKU1+LXIwxsQYXfyL5mGa/MplD1rEYl386+Ddmvwa5XBQkeviXztXNPlVyCuQxWZd/IvjkV68f/GYEw26+DfJ5zX5VcqzqBOtuvhn5ZWa/BzlyYiN3tLFv8wPJk1+UeEeWB0Juvjn2Ffi1fyX9na/3/3L7Y9BbVGeV/Nzwx03WPqSX/17vflxW/tHzWQzHqYm+dy/U4de4HlCwh/tb9/2gYrGDNjzGLL7CS60EszFEex5RdBqIXicSRCxTuBOIbhRTZAyRbASRpDfTVCoECxHEiTPE9yqJBg4SmD4TNB3jKC+giBtehem59ZQc7N+x/vv//+Dv5tfINdXfREPeg==',
  2: 'eJztmH9MlHUcgAXTXlDU4PVlOyMvrDnD9VYc05n0Q01SaHDK+7Zl6Hs63bFomSEcJeRO8eIibGd4UeGb2qZQG9EMumWUyLIXGuVao03nBZdU6txUNMfQp63+aGutF4N7R63vH+93z3/vnj1/fD7fcePG/gH4/Tu27j9+8DdgzN3/UX+TBgW6pbvIO5lDQ6rCin6F5mkKy68qtMYq5AwoNIkK+X0KB+/MZ0lvJn2Tk4khJir+uiMnuPvcHewcrCD4wWf4Zz2L2jieVa1pNMkO6vIdZH/n4Kl9DkIzHexc7+DhnxwUBxx0TEmnwmsjr+seHptjUOueS+nmbsqfKeY610fkryC0jI/i5pB/Jpv9R48S1MPMt4dxa2GOhcMj4rLdBeTMPc7XDDD+WuwN+8sbzCDrygI2ODvwaDrBsI5P13Hb9VFl/VQDgX0hMtN6hu2v/MFqAmmFPPHJfRyz2wlqduaH7bh1e1S4ur6FDQ+8zvQLk039xd88yOLPM/jKNgOPrhG0a/g0DXdYixpv36Sy0hmhfGWNqb+IOIVStZNNcu2o9vZ3XOg6xUNGHBWS19SfTRygRo3hEflkVHr7S3a9zauGznPSa6b+fhTjKFUN9sh5Uevtz7zbZafeaOUNSTH1J4lX8apFNMoLLevP51rDYmMqj0tHTP2dFW9im7oap2xY2F+YV4w6WqTZpv4SxWuUqD2slxss7E9nr9HGQum8qb/zYgzVagJtcoql/WUZEp3SRFN/SeIQZeph/PJGC/vTqDICLJIipv7OiBPYqnq4Vx6ytL93jA6apHRTf8niL1SqTnbIJZb2t9y4ldVSi6m/fjGeYvUH2uVkC/ubyQ6jml2SZupvhniRl1UbhfJ+S/s7aHTxvFRl6u90YgIvrm0he3aXdf2t/R7lcApbUnzDmv8CLyXgak63rL+yDzdS6+/lrQNtw5r/5vWk4vXnUuErinp//fG3EGwK8e5Q+w3Nz6nSz3i+8OBdV4LPWRSV/u6ffhz/N14qc9f84/2t/tEVlDYuoerTGvZc2su8WZER9ZYQO4ASup2t299k6W0XuDJh4qjtvw1fHqLg/WlkpfRS2byZ9xYlIV0W+DhTYNsLApmdAn2JAk8eEFinC5ywCWR8K7ArdwGHjrRTl7QF79OrOH3xXFT33//fD/5d/sby+RUESftr',
};

Uint8List _pixels() {
  final bytes = Uint8List(_width * _height * 4);
  const colors = [
    [255, 0, 0, 255],
    [0, 255, 0, 255],
    [0, 0, 255, 255],
    [255, 255, 255, 255],
  ];
  for (var y = 0; y < _height; y++) {
    for (var x = 0; x < _width; x++) {
      final offset = (y * _width + x) * 4;
      // A transparent border checks coverage preservation at clamped edges.
      if (x == 0 || y == 0 || x == _width - 1 || y == _height - 1) {
        continue;
      }
      bytes.setRange(offset, offset + 4, colors[(y % 2) * 2 + x % 2]);
    }
  }
  return bytes;
}

Future<ui.Image> _decode(Uint8List bytes) {
  final decoded = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    _width,
    _height,
    ui.PixelFormat.rgba8888,
    decoded.complete,
  );
  return decoded.future;
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return Uint8List.fromList(data!.buffer.asUint8List());
}

List<int> _pixel(Uint8List bytes, int x, int y) {
  final offset = (y * _width + x) * 4;
  return bytes.sublist(offset, offset + 4);
}

Future<Uint8List> _render(
  ui.FragmentProgram program,
  ui.Image texture, {
  double progress = 1,
  double viewWidth = 40,
  double inset = 0,
  double radius = 0,
  double originX = 0,
  double originY = 0,
  double axisX = 1,
  double axisY = 1,
}) async {
  final shader = program.fragmentShader();
  final recorder = ui.PictureRecorder();
  ui.Picture? picture;
  ui.Image? image;
  try {
    final uniforms = <double>[
      _width.toDouble(),
      _height.toDouble(),
      inset + originX,
      inset + originY,
      _width - inset * 2,
      _height - inset * 2,
      radius,
      3,
      1,
      2,
      viewWidth,
      _height.toDouble(),
      axisX,
      axisY,
      progress,
      1,
    ];
    for (var index = 0; index < uniforms.length; index++) {
      shader.setFloat(index, uniforms[index]);
    }
    shader.setImageSampler(0, texture);
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 40, 32),
      ui.Paint()..shader = shader,
    );
    picture = recorder.endRecording();
    image = await picture.toImage(_width, _height);
    return await _rgba(image);
  } finally {
    image?.dispose();
    picture?.dispose();
    if (recorder.isRecording) recorder.endRecording().dispose();
    shader.dispose();
  }
}
