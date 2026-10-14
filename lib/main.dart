import 'package:flutter/material.dart';

import 'src/home_page.dart';

void main() {
  runApp(const RenderLabApp());
}

class RenderLabApp extends StatefulWidget {
  const RenderLabApp({super.key});

  @override
  State<RenderLabApp> createState() => _RenderLabAppState();
}

class _RenderLabAppState extends State<RenderLabApp> {
  final ValueNotifier<bool> _performanceOverlay = ValueNotifier(false);

  @override
  void dispose() {
    _performanceOverlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _performanceOverlay,
      builder: (context, showOverlay, _) => MaterialApp(
        title: 'Render Lab',
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: showOverlay,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: HomePage(performanceOverlay: _performanceOverlay),
      ),
    );
  }
}
