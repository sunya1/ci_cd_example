import 'package:flutter/widgets.dart';

import 'bar_chart.dart';

/// Baseline: the same chart from ordinary widgets, for comparison with
/// [RenderBarChart].
///
/// Every data update rebuilds N bars (`Expanded` → `GestureDetector` →
/// `FractionallySizedBox` → `ColoredBox`), relays out the Row and repaints:
/// build ✓ layout ✓ paint ✓. Each bar is 7 widgets (counting
/// GestureDetector's internals) and 4 render objects.
///
/// Needs bounded height (no default height like [RenderBarChart]).
class RowBarChart extends StatelessWidget {
  const RowBarChart({
    super.key,
    required this.series,
    this.selectedIndex,
    this.onBarTap,
    this.barColor = const Color(0xFF3F51B5),
    this.selectedColor = const Color(0xFFFF6F00),
  });

  final BarSeries series;
  final int? selectedIndex;
  final ValueChanged<int>? onBarTap;
  final Color barColor;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: series,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBarTap == null ? null : () => onBarTap!(i),
                // Centered horizontally, standing on the bottom; the gap is
                // the 20% of the slot the bar does not cover.
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1 - BarGeometry.gapFraction,
                  heightFactor: series.values[i].clamp(0.0, 1.0),
                  child: ColoredBox(
                    key: ValueKey(i),
                    color: i == selectedIndex ? selectedColor : barColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
