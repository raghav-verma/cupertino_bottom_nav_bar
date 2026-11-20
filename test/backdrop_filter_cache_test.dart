import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/src/custom_glass_backdrop_widget.dart';

void main() {
  testWidgets('exact filter inputs reuse only the latest immutable snapshot', (
    tester,
  ) async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/glass_refraction.frag',
    );
    final shader = program.fragmentShader();
    addTearDown(shader.dispose);
    final cache = CustomGlassBackdropFilterCache();
    addTearDown(cache.clear);
    final uniforms = List<double>.generate(14, (index) => index + 1.0);
    var creations = 0;
    ui.ImageFilter? resolve() => cache.resolve(
      shader: shader,
      uniforms: uniforms,
      blurSigma: 4,
      // Skia widget tests exercise the real cache without claiming Impeller
      // image-filter execution. A distinct filter records every factory call.
      createFilter: () => ui.ImageFilter.blur(sigmaX: (++creations).toDouble()),
    );

    final first = resolve();
    expect(resolve(), same(first));
    expect(creations, 1);
    for (var index = 0; index < uniforms.length; index++) {
      final original = uniforms[index];
      uniforms[index] += 0.125;
      final changed = resolve();
      expect(changed, isNot(same(first)));
      expect(resolve(), same(changed));
      uniforms[index] = original;
      final restored = resolve();
      expect(restored, isNot(same(first)));
      expect(resolve(), same(restored));
    }
    expect(creations, 29);
  });

  testWidgets('shader identity and active/fallback transitions invalidate', (
    tester,
  ) async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/glass_refraction.frag',
    );
    final firstShader = program.fragmentShader();
    final secondShader = program.fragmentShader();
    addTearDown(firstShader.dispose);
    addTearDown(secondShader.dispose);
    final cache = CustomGlassBackdropFilterCache();
    addTearDown(cache.clear);
    final uniforms = List<double>.filled(14, 1);
    var creations = 0;
    ui.ImageFilter? resolve(ui.FragmentShader? shader, double blur) =>
        cache.resolve(
          shader: shader,
          uniforms: shader == null ? null : uniforms,
          blurSigma: blur,
          createFilter: () {
            creations++;
            return blur == 0 ? null : ui.ImageFilter.blur(sigmaX: blur);
          },
        );

    final first = resolve(firstShader, 4);
    expect(resolve(firstShader, 4), same(first));
    final second = resolve(secondShader, 4);
    expect(second, isNot(same(first)));
    final fallback = resolve(null, 4);
    expect(fallback, isNot(same(second)));
    expect(resolve(null, 4), same(fallback));
    final floor = resolve(null, 20);
    expect(floor, isNot(same(fallback)));
    expect(resolve(null, 20), same(floor));
    expect(resolve(null, 0), isNull);
    expect(resolve(null, 0), isNull);
    expect(creations, 5);
    expect(resolve(firstShader, 4), isNot(same(first)));
    expect(creations, 6);
  });

  test('clear releases the latest entry, including a cached bypass', () {
    final cache = CustomGlassBackdropFilterCache();
    var creations = 0;
    ui.ImageFilter? resolve() => cache.resolve(
      shader: null,
      uniforms: null,
      blurSigma: 0,
      createFilter: () {
        creations++;
        return null;
      },
    );
    expect(resolve(), isNull);
    expect(resolve(), isNull);
    expect(creations, 1);
    cache.clear();
    expect(resolve(), isNull);
    expect(creations, 2);
  });

  test(
    'failed creation cannot cache changed inputs or discard valid entry',
    () {
      final cache = CustomGlassBackdropFilterCache();
      final original = cache.resolve(
        shader: null,
        uniforms: null,
        blurSigma: 4,
        createFilter: () => ui.ImageFilter.blur(sigmaX: 4),
      );
      expect(
        () => cache.resolve(
          shader: null,
          uniforms: null,
          blurSigma: 7,
          createFilter: () => throw StateError('Synthetic factory failure'),
        ),
        throwsStateError,
      );
      expect(
        cache.resolve(
          shader: null,
          uniforms: null,
          blurSigma: 4,
          createFilter: () => throw StateError('Must reuse the valid snapshot'),
        ),
        same(original),
      );
      cache.clear();
    },
  );

  test('filter reuse still resolves and submits every live composition', () {
    final cache = CustomGlassBackdropFilterCache();
    var compositions = 0;
    var creations = 0;
    var sigma = 4.0;
    final layer = CustomGlassBackdropLayer(
      resolveFilter: () {
        compositions++;
        return cache.resolve(
          shader: null,
          uniforms: null,
          blurSigma: sigma,
          createFilter: () {
            creations++;
            return ui.ImageFilter.blur(sigmaX: sigma);
          },
        );
      },
    );
    layer.buildScene(ui.SceneBuilder()).dispose();
    final first = layer.filter;
    layer.buildScene(ui.SceneBuilder()).dispose();
    expect(layer.filter, same(first));
    expect(compositions, 2);
    expect(creations, 1);
    sigma = 7;
    layer.buildScene(ui.SceneBuilder()).dispose();
    expect(layer.filter, isNot(same(first)));
    expect(compositions, 3);
    expect(creations, 2);
    layer.dispose();
    cache.clear();
  });
}
