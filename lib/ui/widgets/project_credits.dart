import 'liquid_glass.dart';
import 'package:flutter/material.dart';

class ProjectCreditFooter extends StatelessWidget {
  const ProjectCreditFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Viết Kiên',
                      style: TextStyle(color: ClearTokColors.pink)),
                  TextSpan(
                      text: ' & ',
                      style: TextStyle(color: ClearTokColors.text)),
                  TextSpan(
                      text: 'Anh Dũng',
                      style: TextStyle(color: ClearTokColors.cyan)),
                ]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, height: 1.25)),
            SizedBox(height: 3),
            Text('Designed & developed · A D&K Project · 2026',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ClearTokColors.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3)),
          ],
        ),
      );
}
