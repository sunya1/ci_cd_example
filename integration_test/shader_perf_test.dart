// Frame-timing benchmark: GPU shader vs CPU painter rendering the same plasma.
//
// Run on a REAL device in profile mode (debug numbers are meaningless):
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/shader_perf_test.dart
//
// Results: build/perf/<scenario>.json + a comparison table in the console.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shaders_and_render_object/src/demos/benchmark_demo.dart';
import 'package:shaders_and_render_object/src/shaders/shader_library.dart';

const _measureFor = Duration(seconds: 5);
const _warmUp = Duration(seconds: 1);

const _scenarios = <String, BenchmarkPage>{
  'gpu_layers1': BenchmarkPage(initialLayers: 1, showControls: false),
  'gpu_layers8': BenchmarkPage(initialLayers: 8, showControls: false),
  'cpu_layers1_cell8': BenchmarkPage(
    initialMode: RenderMode.cpuPainter,
    initialLayers: 1,
    initialCellSize: 8,
    showControls: false,
  ),
  'cpu_layers1_cell4': BenchmarkPage(
    initialMode: RenderMode.cpuPainter,
    initialLayers: 1,
    initialCellSize: 4,
    showControls: false,
  ),
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine drive frames at the display rate, like a real app.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(ShaderLibrary.preload);

  for (final MapEntry(key: name, value: page) in _scenarios.entries) {
    testWidgets(name, (tester) async {
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: page));
      // Skip first frames: texture upload, pipeline creation, JIT/caches.
      await Future<void>.delayed(_warmUp);

      await binding.watchPerformance(() => Future<void>.delayed(_measureFor), reportKey: name);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
