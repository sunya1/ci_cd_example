import 'package:flutter/material.dart';

import 'demos/bar_chart_demo.dart';
import 'demos/benchmark_demo.dart';
import 'demos/plasma_demo.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.performanceOverlay});

  /// Toggles Flutter's built-in UI/raster graphs (MaterialApp.showPerformanceOverlay).
  final ValueNotifier<bool> performanceOverlay;

  @override
  Widget build(BuildContext context) {
    final demos = <(IconData, String, String, WidgetBuilder)>[
      (
        Icons.blur_on,
        'Procedural plasma',
        'plasma.frag · uniforms, CustomPainter(repaint: clock), no rebuilds',
        (_) => const PlasmaDemoPage(),
      ),
      (
        Icons.speed,
        'CPU vs GPU benchmark',
        'Same effect in Dart vs shader, live FrameTiming stats',
        (_) => const BenchmarkPage(),
      ),
      (
        Icons.bar_chart,
        'Bar chart',
        'Custom RenderBox: layout, paint, hitTest, live data vs Row of widgets',
        (_) => const BarChartDemoPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shader Lab'),
        actions: [
          ValueListenableBuilder(
            valueListenable: performanceOverlay,
            builder: (context, on, _) => IconButton(
              tooltip: 'Performance overlay',
              isSelected: on,
              icon: const Icon(Icons.monitor_heart_outlined),
              selectedIcon: const Icon(Icons.monitor_heart),
              onPressed: () => performanceOverlay.value = !on,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (icon, title, subtitle, builder) in demos)
            Card(
              child: ListTile(
                leading: Icon(icon, size: 32),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
              ),
            ),
        ],
      ),
    );
  }
}
