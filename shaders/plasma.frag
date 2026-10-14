// Procedural animated plasma. No textures: every pixel is pure math.
// The CPU twin of this function lives in lib/src/demos/plasma.dart
// (CpuPlasmaPainter) so the benchmark compares identical work.
#version 460 core

#include <flutter/runtime_effect.glsl>

// highp: uTime grows unbounded; mediump (fp16) would make sin(t) visibly step.
precision highp float;

// setFloat indices follow declaration order (vec2 = 2 slots, vec4 = 4 slots):
uniform vec2 uSize;    // 0, 1
uniform float uTime;   // 2
uniform float uLayers; // 3   1..8, detail octaves (GPU cost knob)
uniform vec4 uColorA;  // 4..7
uniform vec4 uColorB;  // 8..11

out vec4 fragColor;

const float PI = 3.14159265;
const int MAX_LAYERS = 8;

float plasma(vec2 p, float t) {
  float v = sin(p.x + t);
  v += sin((p.y + t) * 0.5);
  v += sin((p.x + p.y + t) * 0.5);
  vec2 c = p + vec2(sin(t / 3.0), cos(t / 2.0)) * 1.5;
  v += sin(sqrt(dot(c, c) + 1.0) + t);
  return v * 0.5;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Aspect-correct coordinates centred on the rect.
  vec2 p = (uv - 0.5) * vec2(uSize.x / uSize.y, 1.0) * 6.0;

  // Loop bound must be a compile-time constant, so the uniform-controlled
  // count is enforced with an early break.
  float v = 0.0;
  float amp = 1.0;
  float norm = 0.0;
  for (int i = 0; i < MAX_LAYERS; i++) {
    if (float(i) >= uLayers) break;
    float fi = float(i);
    v += plasma(p * (1.0 + fi * 0.7), uTime * (1.0 + fi * 0.15)) * amp;
    norm += amp;
    amp *= 0.5;
  }
  v /= norm;

  float k = 0.5 + 0.5 * sin(PI * v);
  vec3 col = mix(uColorA.rgb, uColorB.rgb, k);
  col += 0.12 * vec3(sin(PI * v), sin(PI * v + 2.094), sin(PI * v + 4.188));

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
