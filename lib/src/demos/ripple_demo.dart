import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shaders/shader_clock.dart';
import '../shaders/shader_library.dart';
import '../shaders/shader_surface.dart';
import '../shaders/uniform_writer.dart';

/// Texture-sampling shader: tap anywhere to send a ripple through an image.
class RippleDemoPage extends StatefulWidget {
  const RippleDemoPage({super.key});

  @override
  State<RippleDemoPage> createState() => _RippleDemoPageState();
}

class _RippleDemoPageState extends State<RippleDemoPage> with SingleTickerProviderStateMixin {
  late final ShaderClock _clock = ShaderClock(this);
  final ui.FragmentShader _shader = ShaderLibrary.create(AppShader.ripple);

  ui.Image? _texture;
  Size? _textureSize;

  Offset? _origin;
  double _tappedAt = 0;
  double _amplitude = 18;

  /// Rasterises the content once per size into a GPU texture
  /// (`toImageSync` returns immediately; the work happens on the raster thread).
  void _ensureTexture(Size size, double pixelRatio) {
    if (_textureSize == size) return;
    _texture?.dispose();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    _paintTextureContent(canvas, size);
    final picture = recorder.endRecording();
    _texture = picture.toImageSync(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    _textureSize = size;
  }

  void _writeUniforms(UniformWriter uniforms, Size size) {
    uniforms
      ..size(size) // uSize
      ..offset(_origin ?? size.center(Offset.zero)) // uOrigin
      ..float(_clock.seconds - _tappedAt) // uElapsed
      ..float(_amplitude); // uAmplitude
    // Samplers have their own index space, starting at 0.
    _shader.setImageSampler(0, _texture!);
  }

  @override
  void dispose() {
    _clock.dispose();
    _shader.dispose();
    _texture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ripple (sampler2D)')),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _ensureTexture(constraints.biggest, pixelRatio);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _origin = details.localPosition;
                    _tappedAt = _clock.seconds;
                  },
                  child: ShaderSurface(
                    shader: _shader,
                    repaint: _clock,
                    onUniforms: _writeUniforms,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Amplitude'),
                  Expanded(
                    child: Slider(
                      value: _amplitude,
                      max: 40,
                      onChanged: (v) => setState(() => _amplitude = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _paintTextureContent(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A237E), Color(0xFF00897B)],
      ).createShader(rect),
  );

  final grid = Paint()
    ..color = Colors.white.withValues(alpha: 0.14)
    ..strokeWidth = 1;
  for (var x = 0.0; x < size.width; x += 32) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
  }
  for (var y = 0.0; y < size.height; y += 32) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }

  final bubble = Paint()..color = Colors.white.withValues(alpha: 0.10);
  canvas
    ..drawCircle(Offset(size.width * 0.2, size.height * 0.25), 70, bubble)
    ..drawCircle(Offset(size.width * 0.85, size.height * 0.7), 110, bubble);

  final text = TextPainter(
    text: const TextSpan(
      text: 'Flutter\nFragment\nShaders',
      style: TextStyle(
        color: Colors.white,
        fontSize: 52,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  text.paint(canvas, size.center(Offset.zero) - text.size.center(Offset.zero));
  text.dispose();
}
