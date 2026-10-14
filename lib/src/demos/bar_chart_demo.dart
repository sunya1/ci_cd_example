import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../perf/frame_stats.dart';
import '../perf/frame_stats_panel.dart';
import '../render/bar_chart.dart';
import '../render/row_bar_chart.dart';

enum BarChartImpl {
  renderObject('RenderObject', 'build ✗  layout ✗  paint ✓', '1 RenderBarChart, N × drawRect'),
  row('Row', 'build ✓  layout ✓  paint ✓', 'Row + N × (Expanded, Padding, FractionallySizedBox…)');

  const BarChartImpl(this.label, this.phases, this.description);

  final String label;

  /// Which frame phases a data update goes through.
  final String phases;
  final String description;
}

const barCounts = [20, 50, 100, 200, 500, 1000];

/// The same chart, drawn by one of the two implementations.
Widget buildBarChart({
  required BarChartImpl impl,
  required BarSeries series,
  int? selectedIndex,
  ValueChanged<int>? onBarTap,
}) {
  return switch (impl) {
    BarChartImpl.renderObject => BarChart(
      series: series,
      selectedIndex: selectedIndex,
      onBarTap: onBarTap,
    ),
    BarChartImpl.row => RowBarChart(
      series: series,
      selectedIndex: selectedIndex,
      onBarTap: onBarTap,
    ),
  };
}

/// "Live" data: two travelling waves, values stay within 0.05..0.95.
void writeLiveWave(Float64List values, double seconds) {
  for (var i = 0; i < values.length; i++) {
    values[i] =
        0.5 + 0.3 * math.sin(i * 0.18 + seconds * 2.2) + 0.15 * math.sin(i * 0.051 - seconds * 3.7);
  }
}

/// Custom RenderObject vs the ordinary widget way, same chart, live data.
class BarChartDemoPage extends StatefulWidget {
  const BarChartDemoPage({
    super.key,
    this.initialImpl = BarChartImpl.renderObject,
    this.initialCount = 100,
    this.showControls = true,
  });

  final BarChartImpl initialImpl;
  final int initialCount;
  final bool showControls;

  @override
  State<BarChartDemoPage> createState() => _BarChartDemoPageState();
}

class _BarChartDemoPageState extends State<BarChartDemoPage> with SingleTickerProviderStateMixin {
  // A Ticker writes new values every frame. Nobody calls setState for it:
  // the chart listens to the series directly.
  late final Ticker _ticker;
  final FrameStatsMonitor _monitor = FrameStatsMonitor();
  final ValueNotifier<int?> _selected = ValueNotifier(null);

  late BarChartImpl _impl = widget.initialImpl;
  late BarSeries _series = BarSeries(widget.initialCount);
  bool _live = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _series.update((v) => writeLiveWave(v, elapsed.inMicroseconds / 1e6)),
    )..start();
  }

  void _update(VoidCallback change) {
    setState(change);
    _selected.value = null;
    // Skip ~1 s: the first frame after a switch mounts the whole new tree
    // (thousands of widgets for Row) — a one-off cost, not the per-update cost.
    _monitor.reset(skipFrames: 60);
  }

  void _setCount(int count) {
    if (count == _series.length) return;
    final old = _series;
    _update(() => _series = BarSeries(count));
    // Dispose after the frame: the old chart still listens until it rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _series.dispose();
    _monitor.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bar chart (RenderObject)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FrameStatsPanel(monitor: _monitor),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                // Rebuilds only on tap (selection), never per data tick.
                child: ValueListenableBuilder(
                  valueListenable: _selected,
                  builder: (context, selected, _) => buildBarChart(
                    impl: _impl,
                    series: _series,
                    selectedIndex: selected,
                    onBarTap: (i) => _selected.value = i,
                  ),
                ),
              ),
            ),
          ),
          if (widget.showControls) _controls(context),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final countIndex = barCounts.indexOf(_series.length).clamp(0, barCounts.length - 1);
    final small = Theme.of(context).textTheme.bodySmall;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: _selected,
              builder: (context, i, _) => Text(
                i == null ? 'Tap a bar' : 'Bar #$i: ${_series.values[i].toStringAsFixed(2)}',
                style: small?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<BarChartImpl>(
                    segments: [
                      for (final m in BarChartImpl.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_impl},
                    onSelectionChanged: (s) => _update(() => _impl = s.single),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: _live ? 'Pause data' : 'Resume data',
                  icon: Icon(_live ? Icons.pause : Icons.play_arrow),
                  // Muted ticker → no updates → the chart does no work at all.
                  onPressed: () => setState(() => _ticker.muted = !(_live = !_live)),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(width: 84, child: Text('Bars ${_series.length}')),
                Expanded(
                  child: Slider(
                    value: countIndex.toDouble(),
                    max: barCounts.length - 1.0,
                    divisions: barCounts.length - 1,
                    onChanged: (v) => _setCount(barCounts[v.round()]),
                  ),
                ),
              ],
            ),
            Text(
              '${_impl.description}\nper data update: ${_impl.phases}',
              style: small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
