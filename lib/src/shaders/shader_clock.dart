import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Vsync-driven time source for shaders.
///
/// Uses a [Ticker] (not a `Timer`), so it fires exactly once per frame and
/// stops automatically when the route is hidden ([TickerMode]).
/// Passed as `CustomPainter(repaint: clock)`: every tick only repaints the
/// painter, so build and layout are skipped entirely.
class ShaderClock extends ChangeNotifier {
  ShaderClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick)..start();
  }

  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  double get seconds => _elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
