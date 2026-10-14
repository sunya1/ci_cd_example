import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shaders/shader_clock.dart';
import '../shaders/shader_library.dart';
import 'plasma.dart';

/// Full-screen procedural shader. Animation never calls setState:
/// the clock repaints the painter directly.
class PlasmaDemoPage extends StatefulWidget {
  const PlasmaDemoPage({super.key});

  @override
  State<PlasmaDemoPage> createState() => _PlasmaDemoPageState();
}

class _PlasmaDemoPageState extends State<PlasmaDemoPage> with SingleTickerProviderStateMixin {
  late final ShaderClock _clock = ShaderClock(this);
  final ui.FragmentShader _shader = ShaderLibrary.createPlasma();

  double _layers = 2;
  PlasmaPalette _palette = plasmaPalettes.first;

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
            // Own layer: repainting the shader every frame does not repaint
            // the controls, and vice versa.
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PlasmaShaderPainter(
                  shader: _shader,
                  clock: _clock,
                  layers: _layers.round(),
                  palette: _palette,
                ),
              ),
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
                        'Detail layers: ${_layers.round()}',
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
