import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaders_and_render_object/src/demos/bar_chart_demo.dart';
import 'package:shaders_and_render_object/src/render/bar_chart.dart';

const _width = 400.0;
const _height = 300.0;

/// The chart in a fixed 400×300 box in the middle of the test surface.
Widget _host(Widget chart) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: _width, height: _height, child: chart),
  ),
);

RenderBarChart _renderOf(WidgetTester tester) =>
    tester.renderObject<RenderBarChart>(find.byType(BarChart));

void main() {
  group('layout', () {
    testWidgets('fills bounded constraints', (tester) async {
      await tester.pumpWidget(_host(BarChart(series: BarSeries(10))));
      expect(_renderOf(tester).size, const Size(_width, _height));
    });

    testWidgets('uses the default height when height is unbounded', (tester) async {
      await tester.pumpWidget(_host(Column(children: [BarChart(series: BarSeries(10))])));
      expect(_renderOf(tester).size, const Size(_width, RenderBarChart.defaultHeight));
    });

    testWidgets('bar rectangles follow width, count and values', (tester) async {
      await tester.pumpWidget(_host(BarChart(series: BarSeries.of([0.5, 1.0, 0.0, 0.25]))));
      final chart = _renderOf(tester);

      const slot = _width / 4; // 100
      const gap = 20.0; // 20% of a slot
      expect(chart.barRect(0), const Rect.fromLTWH(gap / 2, 150, slot - gap, 150));
      expect(chart.barRect(1), const Rect.fromLTWH(slot + gap / 2, 0, slot - gap, 300));
      expect(chart.barRect(2).height, 0);
      expect(chart.barRect(3), const Rect.fromLTWH(3 * slot + gap / 2, 225, slot - gap, 75));
    });

    testWidgets('is a relayout boundary', (tester) async {
      await tester.pumpWidget(_host(BarChart(series: BarSeries(4))));
      final chart = _renderOf(tester);
      chart.markNeedsLayout();
      expect(chart.parent!.debugNeedsLayout, isFalse, reason: 'markNeedsLayout stops here');
    });
  });

  group('data updates', () {
    testWidgets('repaint only: no rebuild, no layout', (tester) async {
      final series = BarSeries(50);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              builds++;
              return BarChart(series: series);
            },
          ),
        ),
      );
      final chart = _renderOf(tester);

      series.update((v) => writeLiveWave(v, 1));
      expect(chart.debugNeedsPaint, isTrue);
      expect(chart.debugNeedsLayout, isFalse);

      await tester.pump();
      expect(builds, 1, reason: 'the widget is never rebuilt for new data');
      expect(chart.debugNeedsPaint, isFalse);
    });

    testWidgets('a different bar count triggers layout', (tester) async {
      await tester.pumpWidget(_host(BarChart(series: BarSeries(10))));
      final chart = _renderOf(tester);
      chart.series = BarSeries(20);
      expect(chart.debugNeedsLayout, isTrue);
    });
  });

  group('hit testing', () {
    testWidgets('tap on a bar reports its index', (tester) async {
      final tapped = <int>[];
      final series = BarSeries.of(List.filled(8, 0.5));
      await tester.pumpWidget(_host(BarChart(series: series, onBarTap: tapped.add)));
      final chart = _renderOf(tester);
      final origin = tester.getTopLeft(find.byType(BarChart));

      await tester.tapAt(origin + chart.barRect(3).center);
      await tester.tapAt(origin + chart.barRect(7).center);
      expect(tapped, [3, 7]);
    });

    testWidgets('tap above a short bar selects its column', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _host(BarChart(series: BarSeries.of([0.1, 0.1, 0.1, 0.1]), onBarTap: tapped.add)),
      );
      final origin = tester.getTopLeft(find.byType(BarChart));
      await tester.tapAt(origin + const Offset(250, 10)); // slot 2, far above the bar
      expect(tapped, [2]);
    });

    testWidgets('indexAt maps positions to columns', (tester) async {
      await tester.pumpWidget(_host(BarChart(series: BarSeries(4))));
      final chart = _renderOf(tester);
      expect(chart.indexAt(const Offset(0, 0)), 0);
      expect(chart.indexAt(const Offset(99.9, 299)), 0);
      expect(chart.indexAt(const Offset(100, 150)), 1);
      expect(chart.indexAt(const Offset(399.9, 150)), 3);
      expect(chart.indexAt(const Offset(-1, 150)), isNull);
      expect(chart.indexAt(const Offset(150, 301)), isNull);
    });
  });

  testWidgets('RenderObject and Row draw the same bars', (tester) async {
    final series = BarSeries(40)..update((v) => writeLiveWave(v, 0.7));

    await tester.pumpWidget(_host(buildBarChart(impl: BarChartImpl.renderObject, series: series)));
    final chart = _renderOf(tester);
    final origin = tester.getTopLeft(find.byType(BarChart));
    final expected = [for (var i = 0; i < 40; i++) chart.barRect(i).shift(origin)];

    await tester.pumpWidget(_host(buildBarChart(impl: BarChartImpl.row, series: series)));
    for (var i = 0; i < 40; i++) {
      expect(
        tester.getRect(find.byKey(ValueKey(i))),
        rectMoreOrLessEquals(expected[i]),
        reason: 'bar $i',
      );
    }
  });

  for (final impl in BarChartImpl.values) {
    testWidgets('demo page animates: ${impl.label}', (tester) async {
      await tester.pumpWidget(MaterialApp(home: BarChartDemoPage(initialImpl: impl)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
