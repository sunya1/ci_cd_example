import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../perf/frame_stats.dart';
import '../perf/frame_stats_panel.dart';
import '../shaders/shader_clock.dart';
import '../shaders/shader_library.dart';
import 'plasma.dart';

enum RenderMode {
  gpuShader('GPU shader'),
  cpuPainter('CPU painter');

  const RenderMode(this.label);

  final String label;
}

/// Same plasma, two implementations, live frame timings.
///
/// * GPU: one `drawRect` with a fragment shader, per-pixel math on the GPU.
/// * CPU: Dart computes each cell and issues one `drawRect` per cell.
class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({
    super.key,
    this.initialMode = RenderMode.gpuShader,
    this.initialLayers = 2,
    this.initialCellSize = 8,
    this.showControls = true,
  });

  final RenderMode initialMode;
  final int initialLayers;
  final double initialCellSize;
  final bool showControls;

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> with SingleTickerProviderStateMixin {
  late final ShaderClock _clock = ShaderClock(this);
  final ui.FragmentShader _shader = ShaderLibrary.createPlasma();
  final FrameStatsMonitor _monitor = FrameStatsMonitor();

  late RenderMode _mode = widget.initialMode;
  late int _layers = widget.initialLayers;
  late double _cellSize = widget.initialCellSize;

  void _update(VoidCallback change) {
    setState(change);
    _monitor.reset();
  }

  @override
  void dispose() {
    _clock.dispose();
    _shader.dispose();
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = plasmaPalettes.first;
    final surface = switch (_mode) {
      RenderMode.gpuShader => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: PlasmaShaderPainter(
            shader: _shader,
            clock: _clock,
            layers: _layers,
            palette: palette,
          ),
        ),
      ),
      RenderMode.cpuPainter => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: CpuPlasmaPainter(
            clock: _clock,
            layers: _layers,
            cellSize: _cellSize,
            palette: palette,
          ),
        ),
      ),
    };

    final screen = MediaQuery.sizeOf(context);
    final cells = (screen.width / _cellSize).ceil() * (screen.height / _cellSize).ceil();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CPU vs GPU benchmark'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: surface),
          Positioned(
            left: 12,
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
            child: FrameStatsPanel(monitor: _monitor),
          ),
          if (widget.showControls)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: SafeArea(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<RenderMode>(
                          segments: [
                            for (final m in RenderMode.values)
                              ButtonSegment(value: m, label: Text(m.label)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (s) => _update(() => _mode = s.single),
                        ),
                        Row(
                          children: [
                            SizedBox(width: 110, child: Text('Layers $_layers')),
                            Expanded(
                              child: Slider(
                                value: _layers.toDouble(),
                                min: 1,
                                max: 8,
                                divisions: 7,
                                onChanged: (v) => _update(() => _layers = v.round()),
                              ),
                            ),
                          ],
                        ),
                        if (_mode == RenderMode.cpuPainter)
                          Row(
                            children: [
                              SizedBox(width: 110, child: Text('Cell ${_cellSize.round()}px')),
                              Expanded(
                                child: Slider(
                                  value: _cellSize,
                                  min: 2,
                                  max: 32,
                                  divisions: 15,
                                  onChanged: (v) => _update(() => _cellSize = v),
                                ),
                              ),
                            ],
                          ),
                        Text(
                          _mode == RenderMode.gpuShader
                              ? '1 draw call, every physical pixel evaluated on GPU'
                              : '$cells draw calls, math on the UI thread (Dart)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
