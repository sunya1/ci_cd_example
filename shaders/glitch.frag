// Post-processing filter for LIVE widgets via ImageFilter.shader (Impeller only).
// Contract enforced by the engine:
//   * first float uniform is vec2 = size of the input texture (set by engine),
//   * first sampler2D = the rendered child (set by engine).
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;        // 0,1  engine-provided
uniform float uTime;       // 2
uniform float uPixel;      // 3   block size, px (1 = off)
uniform float uAberration; // 4   RGB split, px

uniform sampler2D uTexture; // engine-provided child snapshot

out vec4 fragColor;

void main() {
  vec2 pos = FlutterFragCoord().xy;

  // Pixelate: snap to the centre of a block.
  float block = max(uPixel, 1.0);
  vec2 snapped = (floor(pos / block) + 0.5) * block;
  vec2 uv = snapped / uSize;

#ifdef IMPELLER_TARGET_OPENGLES
  // Offscreen textures are y-flipped on the GLES backend.
  uv.y = 1.0 - uv.y;
#endif

  float wobble = 1.0 + 0.35 * sin(uTime * 4.0 + uv.y * 30.0);
  vec2 offset = vec2(uAberration * wobble / uSize.x, 0.0);

  vec4 base = texture(uTexture, uv);
  float r = texture(uTexture, uv + offset).r;
  float b = texture(uTexture, uv - offset).b;

  // Keep premultiplied invariant (rgb <= a).
  fragColor = vec4(min(r, base.a), base.g, min(b, base.a), base.a);
}
