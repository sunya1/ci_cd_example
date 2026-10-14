// Where does one data update spend its time? Runs each frame phase by hand
// and times it separately (build / layout / paint).
//
//   flutter test test/bar_chart_phases_test.dart
//
// Debug/JIT numbers: compare the proportions, not the absolute values.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaders_and_render_object/src/demos/bar_chart_demo.dart';
import 'package:shaders_and_render_object/src/render/bar_chart.dart';

const _frames = 200;

void main() {
  for (final count in [100, 1000]) {
    testWidgets('phase breakdown, $count bars', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final binding = tester.binding;
      final table = StringBuffer('\n$count bars, µs per data update (debug/JIT):\n')
        ..writeln(
          '  ${''.padRight(13)}${'build'.padLeft(8)}${'layout'.padLeft(8)}'
          '${'paint'.padLeft(8)}${'total'.padLeft(8)}',
        );

      for (final impl in BarChartImpl.values) {
        final series = BarSeries(count);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              child: buildBarChart(impl: impl, series: series),
            ),
          ),
        );

        var seconds = 0.0;
        final watch = Stopwatch();
        var build = 0, layout = 0, paint = 0;
        for (var i = 0; i < _frames + 30; i++) {
          seconds += 1 / 60;
          series.update((v) => writeLiveWave(v, seconds));
          final measure = i >= 30; // first 30 frames: warm-up

          // The same steps as WidgetsBinding.drawFrame, timed one by one.
          watch
            ..reset()
            ..start();
          binding.buildOwner!.buildScope(binding.rootElement!);
          if (measure) build += watch.elapsedMicroseconds;

          watch
            ..reset()
            ..start();
          binding.rootPipelineOwner.flushLayout();
          if (measure) layout += watch.elapsedMicroseconds;

          watch
            ..reset()
            ..start();
          binding.rootPipelineOwner
            ..flushCompositingBits()
            ..flushPaint();
          if (measure) paint += watch.elapsedMicroseconds;

          await tester.pump(); // finish the frame normally (nothing left dirty)
        }

        String col(int us) => (us / _frames).toStringAsFixed(0).padLeft(8);
        table.writeln(
          '  ${impl.label.padRight(13)}${col(build)}${col(layout)}${col(paint)}'
          '${col(build + layout + paint)}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        series.dispose();
      }
      // ignore: avoid_print
      print(table);
    });
  }
}
