import 'package:flutter/material.dart';

import 'src/home_page.dart';
import 'src/shaders/shader_library.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load every FragmentProgram before the first frame: screens can create
  // shaders synchronously and no frame ever waits on an asset.
  await ShaderLibrary.preload();
  runApp(const ShaderLabApp());
}

class ShaderLabApp extends StatefulWidget {
  const ShaderLabApp({super.key});

  @override
  State<ShaderLabApp> createState() => _ShaderLabAppState();
}

class _ShaderLabAppState extends State<ShaderLabApp> {
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
        title: 'Shader Lab',
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: showOverlay,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: HomePage(performanceOverlay: _performanceOverlay),
      ),
    );
  }
}
