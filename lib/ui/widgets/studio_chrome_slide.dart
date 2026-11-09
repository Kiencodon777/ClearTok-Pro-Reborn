import 'package:flutter/material.dart';

class StudioChromeSlide extends StatelessWidget {
  const StudioChromeSlide({
    super.key,
    required this.visible,
    required this.child,
    this.bottom = false,
  });
  final bool visible;
  final bool bottom;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: visible ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => ClipRect(
      child: Align(
        alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
        heightFactor: value,
        child: FractionalTranslation(
          translation: Offset(0, (bottom ? 1 : -1) * (1 - value)),
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    ),
  );
}
