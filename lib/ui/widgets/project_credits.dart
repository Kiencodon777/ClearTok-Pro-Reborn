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
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Viết Kiên', style: TextStyle(color: Color(0xFFFF8DA7))),
          TextSpan(text: ' & ', style: TextStyle(color: Color(0xFFE0E7F0))),
          TextSpan(text: 'Anh Dũng', style: TextStyle(color: Color(0xFF25F4EE))),
        ]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.25)),
        SizedBox(height: 3),
        Text('Designed & developed · A D&K Project · 2026',
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Color(0xFFBDC9DA), fontSize: 10.5,
            fontWeight: FontWeight.w500, height: 1.3)),
      ],
    ),
  );
}
