import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/ui/widgets/studio_chrome_slide.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('chrome reclaims space and reverses, reduced motion $reduced', (
      tester,
    ) async {
      var visible = true;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return Column(
                  children: [
                    StudioChromeSlide(
                      visible: visible,
                      child: const SizedBox(height: 120, width: 100),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final chrome = find.byType(StudioChromeSlide);
      expect(tester.getSize(chrome).height, 120);
      change(() => visible = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      change(() => visible = true);
      await tester.pumpAndSettle();
      expect(tester.getSize(chrome).height, 120);
      change(() => visible = false);
      await tester.pumpAndSettle();
      expect(tester.getSize(chrome).height, 0);
    });
  }
}
