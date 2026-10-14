import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'uniform_writer.dart';

/// Fills [UniformWriter] for the current frame. Called from the paint phase.
typedef UniformsCallback = void Function(UniformWriter uniforms, Size size);

/// Paints a [ui.FragmentShader] over its whole box.
///
/// Implemented as a custom [RenderBox] (instead of a `CustomPaint`) to make
/// the pipeline explicit: on each [repaint] tick only `markNeedsPaint` is
/// called, so the frame skips build, layout and the paint of everything
/// outside this repaint boundary.
class ShaderSurface extends LeafRenderObjectWidget {
  const ShaderSurface({super.key, required this.shader, required this.onUniforms, this.repaint});

  final ui.FragmentShader shader;
  final UniformsCallback onUniforms;
  final Listenable? repaint;

  @override
  RenderShaderSurface createRenderObject(BuildContext context) =>
      RenderShaderSurface(shader: shader, onUniforms: onUniforms, repaint: repaint);

  @override
  void updateRenderObject(BuildContext context, RenderShaderSurface renderObject) {
    renderObject
      ..shader = shader
      ..onUniforms = onUniforms
      ..repaint = repaint;
  }
}

class RenderShaderSurface extends RenderBox {
  RenderShaderSurface({
    required ui.FragmentShader shader,
    required UniformsCallback onUniforms,
    Listenable? repaint,
  }) : _shader = shader,
       _writer = UniformWriter(shader),
       _onUniforms = onUniforms,
       _repaint = repaint;

  final Paint _paint = Paint();

  ui.FragmentShader _shader;
  UniformWriter _writer;
  set shader(ui.FragmentShader value) {
    if (identical(value, _shader)) return;
    _shader = value;
    _writer = UniformWriter(value);
    markNeedsPaint();
  }

  UniformsCallback _onUniforms;
  set onUniforms(UniformsCallback value) {
    // Closures are recreated on every build, so identity is meaningless here.
    // A rebuild implies new inputs anyway: repaint.
    _onUniforms = value;
    markNeedsPaint();
  }

  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// Own layer: repainting the shader 60-120x/s must not repaint the
  /// surrounding UI, and the surrounding UI must not repaint the shader.
  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _writer.reset();
    _onUniforms(_writer, size);
    _paint.shader = _shader;

    // FlutterFragCoord() is in local coordinates, so translate instead of
    // passing the offset as a uniform.
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawRect(Offset.zero & size, _paint)
      ..restore();
  }
}
