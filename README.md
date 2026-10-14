# Render Lab — custom RenderObject vs standard widgets

Assessment task: *custom RenderObject* (layout / paint / hitTest, perf vs standard widgets).
Theory + results (RU): [`docs/RENDER_OBJECT.md`](docs/RENDER_OBJECT.md).

CI/CD (GitHub Actions → Fastlane → Firebase App Distribution), setup (RU): [`docs/CI_CD.md`](docs/CI_CD.md).

## Demos

| Screen | Shows |
|---|---|
| Bar chart | custom leaf `RenderBox` (`RenderBarChart`) vs `Row` of widgets, live data, 20–1000 bars |

## Structure

```
lib/src/render/
  bar_chart.dart            LeafRenderObjectWidget + RenderBarChart (layout/paint/hitTest)
  row_bar_chart.dart        same chart from ordinary widgets (Row + Expanded…)
lib/src/perf/               FrameTiming aggregation + on-screen panel
lib/src/demos/              the screens
test/                       RenderObject correctness, phases, benchmark
integration_test/ + test_driver/   automated frame-timing benchmark
```

## Run

```bash
flutter run                    # demos
flutter run --profile          # real numbers (device only)
flutter test                   # unit/widget tests

# RenderObject vs Row
flutter test test/bar_chart_benchmark_test.dart      # quick, headless (compare ratios)
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/bar_chart_perf_test.dart
```
