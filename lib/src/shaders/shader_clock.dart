import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Vsync-driven time source for shaders.
///
/// Uses a [Ticker] (not a `Timer`), so it fires exactly once per frame and
/// stops automatically when the route is hidden ([TickerMode]). Listeners are
/// expected to call `markNeedsPaint` — never `setState` — so animating a
/// shader skips the build and layout phases entirely.
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
