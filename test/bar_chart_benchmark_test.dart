// Headless micro-benchmark: UI-thread cost (build + layout + paint) of one
// data update for each implementation.
//
//   flutter test test/bar_chart_benchmark_test.dart
//
// `flutter test` runs JIT with asserts enabled and no raster thread, so the
// absolute numbers are inflated: compare the RATIOS only. Real numbers come
// from integration_test/bar_chart_perf_test.dart on a device in --profile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaders_and_render_object/src/demos/bar_chart_demo.dart';
import 'package:shaders_and_render_object/src/render/bar_chart.dart';

const _warmUpFrames = 30;
const _measuredFrames = 200;

void main() {
  for (final count in [100, 500, 1000]) {
    testWidgets('µs per frame, $count bars', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final results = <BarChartImpl, double>{};
      final mount = <BarChartImpl, double>{};
      // Throwaway mount of both: JIT-compile the code paths before timing.
      for (final impl in BarChartImpl.values) {
        final warm = BarSeries(count);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: buildBarChart(impl: impl, series: warm),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        warm.dispose();
      }
      for (final impl in BarChartImpl.values) {
        final series = BarSeries(count);
        var seconds = 0.0;
        final mountWatch = Stopwatch()..start();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              child: buildBarChart(impl: impl, series: series, onBarTap: (_) {}),
            ),
          ),
        );
        // First frame: mount the whole tree (what you see as a hitch on switch).
        mount[impl] = mountWatch.elapsedMicroseconds.toDouble();

        Future<void> tick() {
          seconds += 1 / 60;
          series.update((v) => writeLiveWave(v, seconds));
          return tester.pump();
        }

        for (var i = 0; i < _warmUpFrames; i++) {
          await tick();
        }
        final watch = Stopwatch()..start();
        for (var i = 0; i < _measuredFrames; i++) {
          await tick();
        }
        results[impl] = watch.elapsedMicroseconds / _measuredFrames;
        await tester.pumpWidget(const SizedBox.shrink());
        series.dispose();
      }

      final base = results[BarChartImpl.renderObject]!;
      final table = StringBuffer('\n$count bars (debug/JIT, compare ratios):\n');
      for (final MapEntry(key: impl, value: us) in results.entries) {
        table.writeln(
          '  ${impl.label.padRight(13)}${us.toStringAsFixed(0).padLeft(7)} µs/frame'
          '   ×${(us / base).toStringAsFixed(2)}   first frame ${mount[impl]!.toStringAsFixed(0)} µs'
          '   ${impl.phases}',
        );
      }
      // ignore: avoid_print
      print(table);
    });
  }
}
