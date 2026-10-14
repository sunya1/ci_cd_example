// Frame-timing benchmark: custom RenderObject vs Row of widgets, same chart.
//
// Run on a REAL device in profile mode (debug numbers are meaningless):
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/bar_chart_perf_test.dart
//
// Results: build/perf/<scenario>.json + a comparison table in the console.
// The interesting column is "UI avg": build and layout live on the UI thread.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shaders_and_render_object/src/demos/bar_chart_demo.dart';

const _measureFor = Duration(seconds: 5);
const _warmUp = Duration(seconds: 1);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine drive frames at the display rate, like a real app.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final count in [200, 1000]) {
    for (final impl in BarChartImpl.values) {
      final name = '${impl.name}_$count';
      testWidgets(name, (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BarChartDemoPage(initialImpl: impl, initialCount: count, showControls: false),
          ),
        );
        await Future<void>.delayed(_warmUp);

        await binding.watchPerformance(() => Future<void>.delayed(_measureFor), reportKey: name);

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
