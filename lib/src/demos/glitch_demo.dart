import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shaders/shader_clock.dart';
import '../shaders/shader_library.dart';
import '../shaders/uniform_writer.dart';

/// Post-processing of a live, interactive widget subtree via
/// [ui.ImageFilter.shader] (Impeller only).
class GlitchDemoPage extends StatefulWidget {
  const GlitchDemoPage({super.key});

  @override
  State<GlitchDemoPage> createState() => _GlitchDemoPageState();
}

class _GlitchDemoPageState extends State<GlitchDemoPage> with SingleTickerProviderStateMixin {
  late final ShaderClock _clock = ShaderClock(this);
  final ui.FragmentShader _shader = ShaderLibrary.create(AppShader.glitch);
  late final UniformWriter _uniforms = UniformWriter(_shader);

  bool _enabled = true;
  double _pixel = 1;
  double _aberration = 6;

  @override
  void dispose() {
    _clock.dispose();
    _shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget filter (ImageFilter.shader)')),
      body: !ui.ImageFilter.isShaderFilterSupported
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ImageFilter.shader requires the Impeller renderer.\n'
                  'Skia / web / flutter_tester are not supported.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _clock,
                    // The filtered subtree is built once and reused every tick;
                    // only the ImageFiltered wrapper is rebuilt.
                    child: const _SampleUi(),
                    builder: (context, child) {
                      _uniforms
                        ..reset()
                        ..skip(2) // uSize is filled by the engine
                        ..float(_clock.seconds) // uTime
                        ..float(_pixel) // uPixel
                        ..float(_aberration); // uAberration
                      // The native filter snapshots the uniforms, so a new
                      // ImageFilter per frame is what makes it animate.
                      return ImageFiltered(
                        enabled: _enabled,
                        imageFilter: ui.ImageFilter.shader(_shader),
                        child: child,
                      );
                    },
                  ),
                ),
                _Controls(
                  enabled: _enabled,
                  pixel: _pixel,
                  aberration: _aberration,
                  onEnabled: (v) => setState(() => _enabled = v),
                  onPixel: (v) => setState(() => _pixel = v),
                  onAberration: (v) => setState(() => _aberration = v),
                ),
              ],
            ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.enabled,
    required this.pixel,
    required this.aberration,
    required this.onEnabled,
    required this.onPixel,
    required this.onAberration,
  });

  final bool enabled;
  final double pixel;
  final double aberration;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<double> onPixel;
  final ValueChanged<double> onAberration;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shader filter'),
                value: enabled,
                onChanged: onEnabled,
              ),
              Row(
                children: [
                  SizedBox(width: 120, child: Text('Pixel ${pixel.round()}px')),
                  Expanded(
                    child: Slider(value: pixel, min: 1, max: 24, onChanged: onPixel),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 120, child: Text('RGB split ${aberration.round()}px')),
                  Expanded(
                    child: Slider(value: aberration, max: 30, onChanged: onAberration),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ordinary interactive UI. Stays fully functional under the filter:
/// an ImageFilter changes pixels only, hit testing still uses the real layout.
class _SampleUi extends StatefulWidget {
  const _SampleUi();

  @override
  State<_SampleUi> createState() => _SampleUiState();
}

class _SampleUiState extends State<_SampleUi> {
  int _counter = 0;
  bool _toggle = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Taps: $_counter', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => setState(() => _counter++),
                    icon: const Icon(Icons.add),
                    label: const Text('Tap me'),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Still interactive'),
            value: _toggle,
            onChanged: (v) => setState(() => _toggle = v),
          ),
          const TextField(decoration: InputDecoration(labelText: 'Type here')),
          const SizedBox(height: 16),
          for (final (i, color) in Colors.primaries.take(6).indexed)
            ListTile(
              leading: CircleAvatar(backgroundColor: color, child: Text('${i + 1}')),
              title: Text('List item ${i + 1}'),
              subtitle: const Text('Rendered normally, filtered on the GPU'),
            ),
        ],
      ),
    );
  }
}
