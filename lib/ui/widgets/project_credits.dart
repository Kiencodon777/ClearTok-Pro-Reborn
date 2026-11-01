import 'package:flutter/material.dart';

class ProjectCredits extends StatelessWidget {
  final bool expanded;
  const ProjectCredits({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: expanded ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFE2C55), Color(0xFF25F4EE)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x55FE2C55), blurRadius: 20, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: const Color(0xFF151929),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: expanded ? null : () => showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog.fullscreen(
              backgroundColor: const Color(0xFF0B0E14),
              child: SafeArea(child: Column(children: [
                Align(alignment: Alignment.topRight, child: IconButton(
                  tooltip: 'Đóng credit', icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext))),
                const Expanded(child: Center(child: SingleChildScrollView(
                  padding: EdgeInsets.all(24), child: ProjectCredits(expanded: true)))),
              ])),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 24 : 16, vertical: expanded ? 44 : 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Project Name', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: expanded ? 40 : 23,
                  fontWeight: FontWeight.w900, letterSpacing: 1,
                  shadows: const [Shadow(color: Color(0xAAFE2C55), blurRadius: 16)])),
              SizedBox(height: expanded ? 24 : 4),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Designed & developed by '),
                const TextSpan(text: 'Viết Kiên', style: TextStyle(color: Color(0xFFFF8DA7), fontWeight: FontWeight.w800)),
                const TextSpan(text: ' and '),
                const TextSpan(text: 'Anh Dũng', style: TextStyle(color: Color(0xFF25F4EE), fontWeight: FontWeight.w800)),
                const TextSpan(text: '.'),
              ]), textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFFE6EAF2), fontSize: expanded ? 23 : 13, height: 1.5)),
              SizedBox(height: expanded ? 24 : 5),
              Text('A D&K Project · 2026', textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFF25F4EE), fontSize: expanded ? 17 : 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.3)),
            ]),
          ),
        ),
      ),
    );
  }
}
