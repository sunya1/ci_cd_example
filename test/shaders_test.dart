import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaders_and_render_object/src/demos/benchmark_demo.dart';
import 'package:shaders_and_render_object/src/demos/plasma.dart';
import 'package:shaders_and_render_object/src/demos/plasma_demo.dart';
import 'package:shaders_and_render_object/src/shaders/shader_library.dart';

void main() {
  setUpAll(ShaderLibrary.preload);

  test('plasma.frag compiles and has the expected uniform layout', () {
    final shader = ShaderLibrary.createPlasma();
    // Last declared slot is writable...
    shader.setFloat(plasmaFloatCount - 1, 0);
    // ...and one past the end fails: Dart and GLSL agree on the layout.
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
  testWidgets('benchmark GPU mode', (t) => pumpFrames(t, const BenchmarkPage()));
  testWidgets(
    'benchmark CPU mode',
    (t) => pumpFrames(t, const BenchmarkPage(initialMode: RenderMode.cpuPainter)),
  );
}
