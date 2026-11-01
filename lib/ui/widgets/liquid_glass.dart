import 'dart:ui';
import 'package:flutter/material.dart';

class ClearTokColors {
  static const background = Color(0xFF07080C);
  static const surface = Color(0xFF161926);
  static const pink = Color(0xFFFE2C55);
  static const cyan = Color(0xFF25F4EE);
}

class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(children: [
    const Positioned.fill(child: ColoredBox(color: ClearTokColors.background)),
    Positioned(top: -80, right: -60, child: _glow(320, ClearTokColors.pink, .22)),
    Positioned(bottom: 80, left: -80, child: _glow(380, ClearTokColors.cyan, .16)),
    child,
  ]);

  Widget _glow(double size, Color color, double opacity) => IgnorePointer(
    child: SizedBox(width: size, height: size, child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent])),
    )),
  );
}

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isSelected;
  final bool blur;
  final VoidCallback? onTap;

  const LiquidGlassContainer({super.key, required this.child, this.borderRadius = 20,
    this.padding, this.margin, this.isSelected = false, this.blur = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isSelected
            ? [ClearTokColors.pink.withOpacity(.25), ClearTokColors.pink.withOpacity(.08), ClearTokColors.surface.withOpacity(.75)]
            : [Colors.white.withOpacity(.14), Colors.white.withOpacity(.04), ClearTokColors.surface.withOpacity(.70), Colors.white.withOpacity(.08)],
          stops: isSelected ? const [0, .35, 1] : const [0, .35, .70, 1]),
        border: Border.all(color: isSelected ? ClearTokColors.pink.withOpacity(.8) : Colors.white.withOpacity(.18), width: .8),
      ),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: onTap, borderRadius: radius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      )),
    );
    if (blur && !MediaQuery.of(context).disableAnimations) {
      surface = BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: surface);
    }
    return Container(margin: margin,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 20, offset: const Offset(0, 8)),
        if (isSelected) BoxShadow(color: ClearTokColors.pink.withOpacity(.16), blurRadius: 12),
      ]),
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}

class GlassActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  const GlassActionButton({super.key, required this.icon, required this.label,
    required this.onPressed, this.primary = false});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: primary && onPressed != null
          ? const [Color(0xFFFF3B65), Color(0xFFD60036)]
          : const [Color(0xFF303549), ClearTokColors.surface]),
      border: Border.all(color: Colors.white.withOpacity(onPressed == null ? .08 : .25), width: .8),
      boxShadow: primary && onPressed != null
        ? [BoxShadow(color: ClearTokColors.pink.withOpacity(.28), blurRadius: 18, offset: const Offset(0, 6))] : [],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent, foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38, shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent, elevation: 0, minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), shape: const StadiumBorder()),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconTheme(data: const IconThemeData(size: 20), child: icon),
        const SizedBox(width: 6),
        Flexible(child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    ),
  );
}
