import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';

void main() {
  for (final highContrast in [false, true]) {
    testWidgets(
        'static and high contrast glass skip expensive blur ($highContrast)',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
          theme: clearTokTheme(),
          home: MediaQuery(
              data: MediaQueryData(
                  disableAnimations: !highContrast, highContrast: highContrast),
              child: Scaffold(
                  body: LiquidGlassContainer(
                      onTap: () => tapped = true, child: const Text('Tap'))))));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.text('Tap'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'glass gradients paint both states and expose button interactions',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: AmbientBackground(
            child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        const LiquidGlassContainer(child: Text('Normal')),
        LiquidGlassContainer(
            isSelected: true,
            onTap: () => taps++,
            child: const Text('Selected')),
        GlassActionButton(
            primary: true,
            icon: const Icon(Icons.delete_outline),
            label: 'Action',
            onPressed: () => taps++),
        const GlassActionButton(
            icon: Icon(Icons.sync), label: 'Disabled', onPressed: null),
      ]),
    ))));
    await tester.tap(find.text('Selected'));
    await tester.tap(find.text('Action'));
    expect(taps, 2);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Disabled'))
            .onPressed,
        isNull);
    for (final box
        in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration &&
          decoration.gradient is LinearGradient) {
        final gradient = decoration.gradient! as LinearGradient;
        if (gradient.stops != null) {
          expect(gradient.colors.length, gradient.stops!.length);
        }
      }
    }
    expect(tester.takeException(), isNull);
  });
}
