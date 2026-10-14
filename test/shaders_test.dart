import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaders_and_render_object/src/demos/benchmark_demo.dart';
import 'package:shaders_and_render_object/src/demos/plasma.dart';
import 'package:shaders_and_render_object/src/demos/plasma_demo.dart';
import 'package:shaders_and_render_object/src/demos/ripple_demo.dart';
import 'package:shaders_and_render_object/src/shaders/shader_library.dart';
import 'package:shaders_and_render_object/src/shaders/uniform_writer.dart';

void main() {
  setUpAll(ShaderLibrary.preload);

  test('every declared .frag compiles and instantiates', () {
    for (final shader in AppShader.values) {
      ShaderLibrary.create(shader).dispose();
    }
  });

  test('plasma uniform layout matches plasma.frag', () {
    final shader = ShaderLibrary.create(AppShader.plasma);
    final writer = UniformWriter(shader);
    writePlasmaUniforms(
      writer,
      size: const Size(100, 100),
      time: 1,
      layers: 2,
      palette: plasmaPalettes.first,
    );
    expect(writer.length, plasmaFloatCount);
    // Writing past the end of the uniform buffer must fail loudly.
    expect(() => shader.setFloat(plasmaFloatCount, 0), throwsA(anything));
    shader.dispose();
  });

  Future<void> pumpFrames(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('plasma page animates', (t) => pumpFrames(t, const PlasmaDemoPage()));
  testWidgets('ripple page animates', (t) => pumpFrames(t, const RippleDemoPage()));
  testWidgets('benchmark GPU mode', (t) => pumpFrames(t, const BenchmarkPage()));
  testWidgets(
    'benchmark CPU mode',
    (t) => pumpFrames(t, const BenchmarkPage(initialMode: RenderMode.cpuPainter)),
  );
}
