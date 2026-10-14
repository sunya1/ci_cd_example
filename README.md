# Shader Lab — custom fragment shaders in the Flutter rendering pipeline

Assessment task: *shaders & Flutter graphics pipeline* (FragmentProgram, `.frag`, performance).
Theory notes (RU): [`docs/THEORY.md`](docs/THEORY.md).

Assessment task: *custom RenderObject* (layout / paint / hitTest, perf vs standard widgets).
Theory + results (RU): [`docs/RENDER_OBJECT.md`](docs/RENDER_OBJECT.md).

CI/CD (GitHub Actions → Fastlane → Firebase App Distribution), setup (RU): [`docs/CI_CD.md`](docs/CI_CD.md).

## Demos

| Screen | Shader | Shows |
|---|---|---|
| Procedural plasma | `shaders/plasma.frag` | uniforms via `setFloat`, `CustomPainter(repaint: clock)` + `RepaintBoundary` (no rebuilds) |
| CPU vs GPU benchmark | `plasma.frag` vs `CpuPlasmaPainter` | identical math on GPU vs Dart, live `FrameTiming` stats |
| Bar chart | — | custom leaf `RenderBox` (`RenderBarChart`) vs `Row` of widgets, live data, 20–1000 bars |

## Structure

```
shaders/                    GLSL sources, compiled by impellerc at build time
lib/src/shaders/
  shader_library.dart       loads the FragmentProgram once (before runApp)
  shader_clock.dart         vsync Ticker as a Listenable (repaint trigger)
lib/src/demos/plasma.dart   PlasmaShaderPainter (GPU) + CpuPlasmaPainter (same math in Dart)
lib/src/render/
  bar_chart.dart            LeafRenderObjectWidget + RenderBarChart (layout/paint/hitTest)
  row_bar_chart.dart        same chart from ordinary widgets (Row + Expanded…)
lib/src/perf/               FrameTiming aggregation + on-screen panel
lib/src/demos/              the screens
test/                       shader compiles, uniform layout, smoke frames
integration_test/ + test_driver/   automated frame-timing benchmark
```

## Run

```bash
flutter run                    # demos
flutter run --profile          # real numbers (device only)
flutter test                   # unit/widget tests

# Benchmark → build/perf/*.json + table in console (use a real device, profile mode)
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/shader_perf_test.dart

# RenderObject vs Row
flutter test test/bar_chart_benchmark_test.dart      # quick, headless (compare ratios)
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/bar_chart_perf_test.dart
```
