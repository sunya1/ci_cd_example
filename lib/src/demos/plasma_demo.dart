import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shaders/shader_clock.dart';
import '../shaders/shader_library.dart';
import '../shaders/shader_surface.dart';
import '../shaders/uniform_writer.dart';
import 'plasma.dart';

/// Procedural full-screen shader. Animation and touch never call setState:
/// the clock marks the render object dirty and uniforms are read during paint.
class PlasmaDemoPage extends StatefulWidget {
  const PlasmaDemoPage({super.key});

  @override
  State<PlasmaDemoPage> createState() => _PlasmaDemoPageState();
}

class _PlasmaDemoPageState extends State<PlasmaDemoPage> with SingleTickerProviderStateMixin {
  late final ShaderClock _clock = ShaderClock(this);
  final ui.FragmentShader _shader = ShaderLibrary.create(AppShader.plasma);

  double _layers = 2;
  PlasmaPalette _palette = plasmaPalettes.first;

  // Pointer state is consumed in paint, so plain fields are enough.
  Offset _touch = Offset.zero;
  bool _pressed = false;
  double _releasedAt = double.negativeInfinity;

  void _onPointer(PointerEvent event) {
    _touch = event.localPosition;
    if (event is PointerDownEvent) _pressed = true;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pressed = false;
      _releasedAt = _clock.seconds;
    }
  }

  void _writeUniforms(UniformWriter uniforms, Size size) {
    final time = _clock.seconds;
    final fade = (1 - (time - _releasedAt) * 2).clamp(0.0, 1.0);
    writePlasmaUniforms(
      uniforms,
      size: size,
      time: time,
      layers: _layers,
      palette: _palette,
      touch: _touch,
      touchStrength: _pressed ? 1 : fade,
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Procedural plasma'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: _onPointer,
              onPointerMove: _onPointer,
              onPointerUp: _onPointer,
              onPointerCancel: _onPointer,
              child: ShaderSurface(shader: _shader, repaint: _clock, onUniforms: _writeUniforms),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Card(
                color: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail layers: ${_layers.round()}  (drag to light up)',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: _layers,
                        min: 1,
                        max: 8,
                        divisions: 7,
                        onChanged: (v) => setState(() => _layers = v),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in plasmaPalettes)
                            ChoiceChip(
                              label: Text(p.name),
                              selected: p == _palette,
                              onSelected: (_) => setState(() => _palette = p),
                            ),
                        ],
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
