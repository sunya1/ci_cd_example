import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Aggregated engine frame timings over a sliding window.
@immutable
class FrameStats {
  const FrameStats({
    required this.sampleCount,
    required this.fps,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.p90RasterMs,
    required this.worstRasterMs,
    required this.jankPercent,
    required this.budgetMs,
  });

  static const empty = FrameStats(
    sampleCount: 0,
    fps: 0,
    avgBuildMs: 0,
    avgRasterMs: 0,
    p90RasterMs: 0,
    worstRasterMs: 0,
    jankPercent: 0,
    budgetMs: 1000 / 60,
  );

  final int sampleCount;
  final double fps;

  /// UI thread: build + layout + paint (record display list).
  final double avgBuildMs;

  /// Raster thread CPU time: Impeller/Skia turning the layer tree into GPU
  /// commands. NOT the GPU execution time (that runs asynchronously; use
  /// Xcode Metal capture / Android GPU Inspector). Heavy shaders surface
  /// here only once the GPU falls behind and back-pressures the raster thread.
  final double avgRasterMs;
  final double p90RasterMs;
  final double worstRasterMs;

  /// Share of frames where either thread exceeded [budgetMs].
  final double jankPercent;
  final double budgetMs;
}

/// Collects [FrameTiming]s reported by the engine.
///
/// The engine batches timings (roughly once per second in profile/release),
/// so values update in steps. Numbers taken in debug mode are meaningless:
/// debug uses JIT and extra assertions. Measure with `--profile` on a device.
class FrameStatsMonitor extends ValueNotifier<FrameStats> {
  FrameStatsMonitor({this.windowSize = 180, double? refreshRate})
    : _budgetMs = 1000 / (refreshRate ?? _displayRefreshRate()),
      super(FrameStats.empty) {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  final int windowSize;
  final double _budgetMs;
  final Queue<FrameTiming> _window = Queue();

  static double _displayRefreshRate() {
    final displays = ui.PlatformDispatcher.instance.displays;
    final rate = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    return rate > 0 ? rate : 60.0;
  }

  /// Frames still to ignore after [reset].
  int _skip = 0;

  /// Clears the window. [skipFrames] drops the next frames too: right after a
  /// switch the first frame mounts the new tree (one-off cost) and would
  /// otherwise dominate the stats for seconds.
  void reset({int skipFrames = 0}) {
    _window.clear();
    _skip = skipFrames;
    value = FrameStats.empty;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      if (_skip > 0) {
        _skip--;
        continue;
      }
      _window.addLast(timing);
      if (_window.length > windowSize) _window.removeFirst();
    }
    if (_window.length < 2) return;

    double ms(Duration d) => d.inMicroseconds / 1000;

    final build = [for (final t in _window) ms(t.buildDuration)];
    final raster = [for (final t in _window) ms(t.rasterDuration)]..sort();
    final janky = _window.where(
      (t) => ms(t.buildDuration) > _budgetMs || ms(t.rasterDuration) > _budgetMs,
    );

    final firstVsync = _window.first.timestampInMicroseconds(ui.FramePhase.vsyncStart);
    final lastVsync = _window.last.timestampInMicroseconds(ui.FramePhase.vsyncStart);
    final spanSeconds = (lastVsync - firstVsync) / Duration.microsecondsPerSecond;

    value = FrameStats(
      sampleCount: _window.length,
      fps: spanSeconds > 0 ? (_window.length - 1) / spanSeconds : 0,
      avgBuildMs: build.reduce((a, b) => a + b) / build.length,
      avgRasterMs: raster.reduce((a, b) => a + b) / raster.length,
      p90RasterMs: raster[(raster.length * 0.9).floor().clamp(0, raster.length - 1)],
      worstRasterMs: raster.last,
      jankPercent: janky.length / _window.length * 100,
      budgetMs: _budgetMs,
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }
}
