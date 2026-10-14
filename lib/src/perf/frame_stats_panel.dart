import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'frame_stats.dart';

/// Compact on-screen readout of [FrameStatsMonitor].
class FrameStatsPanel extends StatelessWidget {
  const FrameStatsPanel({super.key, required this.monitor});

  final FrameStatsMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall!.copyWith(
      fontFamily: 'Menlo',
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Colors.white,
    );

    // The panel itself repaints when stats change; isolate it so it never
    // dirties the content it floats over.
    return RepaintBoundary(
      child: ValueListenableBuilder<FrameStats>(
        valueListenable: monitor,
        builder: (context, s, _) {
          Color tone(double ms) => ms <= s.budgetMs * 0.5
              ? Colors.greenAccent
              : ms <= s.budgetMs
              ? Colors.amberAccent
              : Colors.redAccent;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: DefaultTextStyle(
                style: mono,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kDebugMode)
                      Text(
                        'DEBUG build: measure with --profile',
                        style: mono.copyWith(color: Colors.orangeAccent),
                      ),
                    Text(
                      '${s.fps.toStringAsFixed(1)} fps   '
                      'budget ${s.budgetMs.toStringAsFixed(1)} ms   '
                      'n=${s.sampleCount}',
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'UI     avg '),
                          TextSpan(
                            text: s.avgBuildMs.toStringAsFixed(2),
                            style: TextStyle(color: tone(s.avgBuildMs)),
                          ),
                          const TextSpan(text: ' ms'),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Raster avg '),
                          TextSpan(
                            text: s.avgRasterMs.toStringAsFixed(2),
                            style: TextStyle(color: tone(s.avgRasterMs)),
                          ),
                          TextSpan(
                            text:
                                '  p90 ${s.p90RasterMs.toStringAsFixed(2)}'
                                '  max ${s.worstRasterMs.toStringAsFixed(2)} ms',
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'jank ${s.jankPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: s.jankPercent < 1 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
