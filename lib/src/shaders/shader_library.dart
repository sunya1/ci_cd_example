import 'dart:ui' as ui;

/// Every `.frag` declared in pubspec.yaml.
enum AppShader {
  plasma('shaders/plasma.frag'),
  ripple('shaders/ripple.frag'),
  glitch('shaders/glitch.frag');

  const AppShader(this.asset);

  final String asset;
}

/// Loads each [ui.FragmentProgram] exactly once and hands out
/// [ui.FragmentShader] instances.
///
/// * `FragmentProgram` = compiled program (expensive, shareable, cached by engine).
/// * `FragmentShader`  = program + its own uniform buffer (cheap, mutable).
///   Reuse one per painter and mutate uniforms every frame instead of
///   allocating a new one per frame.
abstract final class ShaderLibrary {
  static final Map<AppShader, ui.FragmentProgram> _programs = {};

  /// Call before `runApp` so no screen ever has to await a program.
  static Future<void> preload() async {
    await Future.wait([
      for (final shader in AppShader.values)
        ui.FragmentProgram.fromAsset(shader.asset).then((program) => _programs[shader] = program),
    ]);
  }

  /// The caller owns the result and must call [ui.FragmentShader.dispose].
  static ui.FragmentShader create(AppShader shader) {
    final program = _programs[shader];
    assert(program != null, 'ShaderLibrary.preload() must complete before creating $shader');
    return program!.fragmentShader();
  }
}
