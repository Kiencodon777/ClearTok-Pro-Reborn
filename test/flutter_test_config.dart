import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(
    enablePerformanceMonitor: false,
    warmUpMode: GlassWarmUpMode.never,
  );
  await testMain();
}
