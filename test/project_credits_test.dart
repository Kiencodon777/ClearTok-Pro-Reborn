import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/ui/widgets/project_credits.dart';

void main() {
  testWidgets('creator footer shows both names on a narrow screen without an overlay', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter,
      child: SizedBox(width: 320, child: ProjectCreditFooter(onTap: () {}))))));
    expect(find.text('Viết Kiên & Anh Dũng', findRichText: true), findsOneWidget);
    expect(find.text('D&K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('credits preserve exact copy and open a dismissible full-screen view', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: SizedBox(width: 320, child: ProjectCredits())))));
    expect(find.text('Project Name'), findsOneWidget);
    expect(find.text('A D&K Project · 2026'), findsOneWidget);
    expect(find.text('Designed & developed by Viết Kiên and Anh Dũng.', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Project Name'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đóng credit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Đóng credit'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đóng credit'), findsNothing);
  });
}
