import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Bar values in 0..1, updated in place. One [notifyListeners] per update,
/// however many bars changed.
class BarSeries extends ChangeNotifier {
  BarSeries(int length) : values = Float64List(length);

  BarSeries.of(List<double> values) : values = Float64List.fromList(values);

  final Float64List values;

  int get length => values.length;

  void update(void Function(Float64List values) change) {
    change(values);
    notifyListeners();
  }
}

/// Shared bar geometry, so the custom RenderObject and the Row-based chart
/// draw exactly the same bars.
abstract final class BarGeometry {
  /// Share of a slot left empty between two bars.
  static const double gapFraction = 0.2;
}

/// A bar chart drawn by a single render object.
///
/// The widget is only configuration: [createRenderObject] /
/// [updateRenderObject] hand it to [RenderBarChart], which does the work.
class BarChart extends LeafRenderObjectWidget {
  const BarChart({
    super.key,
    required this.series,
    this.selectedIndex,
    this.onBarTap,
    this.barColor = const Color(0xFF3F51B5),
    this.selectedColor = const Color(0xFFFF6F00),
  });

  /// Read by the render object itself: a data update repaints the chart only —
  /// no widget is rebuilt and nothing is laid out again.
  final BarSeries series;
  final int? selectedIndex;
  final ValueChanged<int>? onBarTap;
  final Color barColor;
  final Color selectedColor;

  @override
  RenderBarChart createRenderObject(BuildContext context) => RenderBarChart(
    series: series,
    selectedIndex: selectedIndex,
    onBarTap: onBarTap,
    barColor: barColor,
    selectedColor: selectedColor,
  );

  @override
  void updateRenderObject(BuildContext context, RenderBarChart renderObject) {
    renderObject
      ..series = series
      ..selectedIndex = selectedIndex
      ..onBarTap = onBarTap
      ..barColor = barColor
      ..selectedColor = selectedColor;
  }
}

class RenderBarChart extends RenderBox {
  RenderBarChart({
    required BarSeries series,
    int? selectedIndex,
    this.onBarTap,
    Color barColor = const Color(0xFF3F51B5),
    Color selectedColor = const Color(0xFFFF6F00),
  }) : _series = series,
       _selectedIndex = selectedIndex,
       _barPaint = Paint()..color = barColor,
       _selectedPaint = Paint()..color = selectedColor {
    _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = _handleTapUp;
  }

  /// Height used when the parent does not limit ours (e.g. inside a Column).
  static const double defaultHeight = 200;

  // ---------------------------------------------------------------------------
  // Properties. Each setter marks exactly the phase that depends on it.
  // ---------------------------------------------------------------------------

  BarSeries _series;
  set series(BarSeries value) {
    if (identical(value, _series)) return;
    final lengthChanged = value.length != _series.length;
    if (attached) _series.removeListener(markNeedsPaint);
    _series = value;
    if (attached) _series.addListener(markNeedsPaint);
    // Bar width depends on the number of bars, not on their values.
    lengthChanged ? markNeedsLayout() : markNeedsPaint();
  }

  int? _selectedIndex;
  set selectedIndex(int? value) {
    if (value == _selectedIndex) return;
    _selectedIndex = value;
    markNeedsPaint();
  }

  /// Not used by layout or paint: a plain field, no markNeeds*.
  ValueChanged<int>? onBarTap;

  final Paint _barPaint;
  set barColor(Color value) {
    if (value == _barPaint.color) return;
    _barPaint.color = value;
    markNeedsPaint();
  }

  final Paint _selectedPaint;
  set selectedColor(Color value) {
    if (value == _selectedPaint.color) return;
    _selectedPaint.color = value;
    markNeedsPaint();
  }

  late final TapGestureRecognizer _tap;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _series.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _series.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Layout: size from the constraints, bar geometry from size + bar count.
  // ---------------------------------------------------------------------------

  /// Our size depends only on the constraints (and the bar count), so it is
  /// computed in [computeDryLayout] and this box is a relayout boundary.
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(
      constraints.hasBoundedWidth ? constraints.maxWidth : _series.length * 8.0,
      constraints.hasBoundedHeight ? constraints.maxHeight : defaultHeight,
    ),
  );

  /// Width of one bar slot (bar + gap). Written by layout, read by paint and hit testing.
  double _slot = 0;
  double _gap = 0;

  @override
  void performLayout() {
    // Only what depends on size and count is computed here. Values change
    // 60 times per second and are read in paint, so layout runs only when
    // the size or the number of bars changes.
    _slot = _series.length == 0 ? 0 : size.width / _series.length;
    _gap = _slot * BarGeometry.gapFraction;
  }

  /// Bar [index] in local coordinates. Used by paint, and by tests to check
  /// the exact rectangles that get drawn.
  Rect barRect(int index) {
    final height = size.height * _series.values[index].clamp(0.0, 1.0);
    return Rect.fromLTWH(index * _slot + _gap / 2, size.height - height, _slot - _gap, height);
  }

  // ---------------------------------------------------------------------------
  // Paint: N rectangles straight on the canvas, no child objects.
  // ---------------------------------------------------------------------------

  /// Own layer: repainting 60 times per second does not repaint the screen
  /// around us, and the screen around us does not repaint the chart.
  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // `offset` is where the parent put us in the layer: draw relative to it.
    final canvas = context.canvas;
    for (var i = 0; i < _series.length; i++) {
      canvas.drawRect(barRect(i).shift(offset), i == _selectedIndex ? _selectedPaint : _barPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // Hit testing: which bar is under the finger is pure arithmetic.
  // ---------------------------------------------------------------------------

  /// Index of the bar column at [position] (local), or null outside the chart.
  int? indexAt(Offset position) {
    if (_slot == 0 || !size.contains(position)) return null;
    return (position.dx ~/ _slot).clamp(0, _series.length - 1);
  }

  /// The whole rectangle is ours: a tap above a short bar still selects its column.
  @override
  bool hitTestSelf(Offset position) => true;

  /// Called for every pointer event that hit us. Hand the pointer to a tap
  /// recognizer so we take part in the gesture arena: a drag in a scrollable
  /// parent wins over us instead of firing a tap.
  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is PointerDownEvent && onBarTap != null) _tap.addPointer(event);
  }

  void _handleTapUp(TapUpDetails details) {
    final index = indexAt(details.localPosition);
    if (index != null) onBarTap?.call(index);
  }

  // ---------------------------------------------------------------------------
  // DevTools / debugDumpRenderTree()
  // ---------------------------------------------------------------------------

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('bars', _series.length))
      ..add(IntProperty('selectedIndex', _selectedIndex, defaultValue: null))
      ..add(ColorProperty('barColor', _barPaint.color))
      ..add(ColorProperty('selectedColor', _selectedPaint.color));
  }
}
