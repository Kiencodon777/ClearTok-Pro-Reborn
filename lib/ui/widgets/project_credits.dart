import 'liquid_glass.dart';
import 'package:flutter/material.dart';

class ProjectCreditFooter extends StatelessWidget {
  const ProjectCreditFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 2),
    child: Opacity(
      opacity: 0.40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Viết Kiên',
                  style: TextStyle(
                    color: ClearTokColors.pink.withValues(alpha: 0.9),
                  ),
                ),
                const TextSpan(
                  text: ' & ',
                  style: TextStyle(color: ClearTokColors.text),
                ),
                TextSpan(
                  text: 'Anh Dũng',
                  style: TextStyle(
                    color: ClearTokColors.cyan.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 1),
          const Text(
            'Designed & developed · A D&K Project · 2026',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ClearTokColors.secondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
      ),
    ),
  );
}
