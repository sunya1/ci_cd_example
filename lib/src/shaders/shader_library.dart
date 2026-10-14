import 'dart:ui' as ui;

/// Loads the compiled `plasma.frag` once.
///
/// * `FragmentProgram` = compiled program: expensive, load once, share.
/// * `FragmentShader`  = program + its own uniform values: cheap, one per
///   painter, reused every frame, `dispose()` when the screen goes away.
abstract final class ShaderLibrary {
  static ui.FragmentProgram? _plasma;

  /// Call before `runApp` so no screen ever has to await the program.
  static Future<void> preload() async {
    _plasma = await ui.FragmentProgram.fromAsset('shaders/plasma.frag');
  }

  /// The caller owns the result and must call [ui.FragmentShader.dispose].
  static ui.FragmentShader createPlasma() {
    assert(_plasma != null, 'ShaderLibrary.preload() must complete first');
    return _plasma!.fragmentShader();
  }
}
