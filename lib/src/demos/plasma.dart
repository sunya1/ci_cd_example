import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../shaders/shader_clock.dart';
import '../shaders/uniform_writer.dart';

typedef PlasmaPalette = ({String name, Color a, Color b});

const List<PlasmaPalette> plasmaPalettes = [
  (name: 'Aurora', a: Color(0xFF0B1E5B), b: Color(0xFF2EE6A8)),
  (name: 'Sunset', a: Color(0xFF3A0CA3), b: Color(0xFFFF8C42)),
  (name: 'Mono', a: Color(0xFF101010), b: Color(0xFFE0E0E0)),
];

/// Float uniform slots declared in `shaders/plasma.frag`.
const int plasmaFloatCount = 15;

/// Single place that knows the uniform layout of `plasma.frag`.
/// Order must match the declarations in the shader.
void writePlasmaUniforms(
  UniformWriter uniforms, {
  required Size size,
  required double time,
  required double layers,
  required PlasmaPalette palette,
  Offset touch = Offset.zero,
  double touchStrength = 0,
}) {
  uniforms
    ..size(size) // uSize
    ..float(time) // uTime
    ..float(layers) // uLayers
    ..offset(touch) // uTouch
    ..float(touchStrength) // uTouchStrength
    ..color(palette.a) // uColorA
    ..color(palette.b); // uColorB
  assert(
    uniforms.length == plasmaFloatCount,
    'plasma.frag expects $plasmaFloatCount floats, wrote ${uniforms.length}',
  );
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
