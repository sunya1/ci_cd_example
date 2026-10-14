// Water ripple distortion over a texture (sampler2D). Demonstrates:
//  * texture sampling with displaced UVs (texture-fetch bound),
//  * mixing float uniforms and samplers (separate index spaces in Dart).
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;       // 0,1
uniform vec2 uOrigin;     // 2,3   tap position, local px
uniform float uElapsed;   // 4     seconds since tap
uniform float uAmplitude; // 5     max displacement, px

uniform sampler2D uTexture; // sampler index 0 (setImageSampler)

out vec4 fragColor;

const float SPEED = 520.0;     // px / s
const float WAVELENGTH = 70.0; // px
const float PI2 = 6.2831853;

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 delta = pos - uOrigin;
  float dist = length(delta);
  vec2 dir = delta / max(dist, 0.0001);

  // Gaussian ring travelling outwards, decaying with time.
  float x = dist - uElapsed * SPEED;
  float envelope = exp(-(x * x) / (2.0 * 90.0 * 90.0)) * exp(-uElapsed * 1.4);
  float wave = sin(x / WAVELENGTH * PI2) * envelope;

  vec2 uv = (pos + dir * wave * uAmplitude) / uSize;
  vec4 color = texture(uTexture, clamp(uv, 0.0, 1.0));

  // Cheap fake lighting on wave crests (premultiplied: scale by alpha).
  color.rgb += vec3(wave * 0.18 * color.a);
  fragColor = color;
}
