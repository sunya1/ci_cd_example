import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../shaders/shader_clock.dart';

typedef PlasmaPalette = ({String name, Color a, Color b});

const List<PlasmaPalette> plasmaPalettes = [
  (name: 'Aurora', a: Color(0xFF0B1E5B), b: Color(0xFF2EE6A8)),
  (name: 'Sunset', a: Color(0xFF3A0CA3), b: Color(0xFFFF8C42)),
  (name: 'Mono', a: Color(0xFF101010), b: Color(0xFFE0E0E0)),
];

/// Float uniform slots declared in `shaders/plasma.frag`.
const int plasmaFloatCount = 12;

/// GPU version: one `drawRect` whose every pixel is computed by `plasma.frag`.
///
/// `repaint: clock` makes every tick call `markNeedsPaint` on the
/// RenderCustomPaint directly: no `setState`, no build, no layout.
class PlasmaShaderPainter extends CustomPainter {
  PlasmaShaderPainter({
    required this.shader,
    required this.clock,
    required this.layers,
    required this.palette,
  }) : super(repaint: clock);

  final ui.FragmentShader shader;
  final ShaderClock clock;
  final int layers;
  final PlasmaPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Indices follow declaration order in plasma.frag.
    shader
      ..setFloat(0, size.width) // uSize.x
      ..setFloat(1, size.height) // uSize.y
      ..setFloat(2, clock.seconds) // uTime
      ..setFloat(3, layers.toDouble()) // uLayers
      ..setFloat(4, palette.a.r) // uColorA
      ..setFloat(5, palette.a.g)
      ..setFloat(6, palette.a.b)
      ..setFloat(7, palette.a.a)
      ..setFloat(8, palette.b.r) // uColorB
      ..setFloat(9, palette.b.g)
      ..setFloat(10, palette.b.b)
      ..setFloat(11, palette.b.a);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(PlasmaShaderPainter old) =>
      old.shader != shader || old.layers != layers || old.palette != palette;
}

/// CPU twin of `plasma.frag`: identical math evaluated in Dart once per cell
/// and drawn as rects. Exists only to benchmark against the GPU version.
class CpuPlasmaPainter extends CustomPainter {
  CpuPlasmaPainter({
    required this.clock,
    required this.layers,
    required this.cellSize,
    required this.palette,
  }) : super(repaint: clock);

  final ShaderClock clock;
  final int layers;
  final double cellSize;
  final PlasmaPalette palette;

  final Paint _paint = Paint()..isAntiAlias = false;

  static double _plasma(double px, double py, double t) {
    var v = math.sin(px + t);
    v += math.sin((py + t) * 0.5);
    v += math.sin((px + py + t) * 0.5);
    final cx = px + math.sin(t / 3) * 1.5;
    final cy = py + math.cos(t / 2) * 1.5;
    v += math.sin(math.sqrt(cx * cx + cy * cy + 1) + t);
    return v * 0.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.seconds;
    final aspect = size.width / size.height;
    final a = palette.a;
    final b = palette.b;

    for (var y = 0.0; y < size.height; y += cellSize) {
      final py = ((y + cellSize / 2) / size.height - 0.5) * 6;
      for (var x = 0.0; x < size.width; x += cellSize) {
        final px = ((x + cellSize / 2) / size.width - 0.5) * aspect * 6;

        var v = 0.0, amp = 1.0, norm = 0.0;
        for (var i = 0; i < layers; i++) {
          v += _plasma(px * (1 + i * 0.7), py * (1 + i * 0.7), t * (1 + i * 0.15)) * amp;
          norm += amp;
          amp *= 0.5;
        }
        v /= norm;

        final k = 0.5 + 0.5 * math.sin(math.pi * v);
        final s = math.pi * v;
        _paint.color = Color.from(
          alpha: 1,
          red: (a.r + (b.r - a.r) * k + 0.12 * math.sin(s)).clamp(0, 1),
          green: (a.g + (b.g - a.g) * k + 0.12 * math.sin(s + 2.094)).clamp(0, 1),
          blue: (a.b + (b.b - a.b) * k + 0.12 * math.sin(s + 4.188)).clamp(0, 1),
        );
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), _paint);
      }
    }
  }

  @override
  bool shouldRepaint(CpuPlasmaPainter old) =>
      old.layers != layers || old.cellSize != cellSize || old.palette != palette;
}
