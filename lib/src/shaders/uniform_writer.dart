import 'dart:ui' as ui;

/// Writes float uniforms sequentially, mirroring their declaration order in
/// the `.frag` file.
///
/// `setFloat` takes a flat index over all float components (a `vec4` takes
/// 4 slots) and samplers are not counted. Hand-maintained magic indices
/// are the most common shader integration bug; writing in declaration order
/// removes that class of error.
final class UniformWriter {
  UniformWriter(this.shader);

  final ui.FragmentShader shader;
  int _index = 0;

  /// Number of float slots written since the last [reset].
  int get length => _index;

  void reset([int start = 0]) => _index = start;

  /// Skips slots that the engine fills itself (e.g. `uSize` in an
  /// `ImageFilter.shader`).
  void skip(int slots) => _index += slots;

  void float(double value) => shader.setFloat(_index++, value);

  void vec2(double x, double y) {
    float(x);
    float(y);
  }

  void size(ui.Size size) => vec2(size.width, size.height);

  void offset(ui.Offset offset) => vec2(offset.dx, offset.dy);

  /// Straight (non-premultiplied) RGBA in the 0..1 range.
  void color(ui.Color color) {
    float(color.r);
    float(color.g);
    float(color.b);
    float(color.a);
  }
}
