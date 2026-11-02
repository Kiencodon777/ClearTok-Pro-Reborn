import 'dart:ui';
import 'package:flutter/material.dart';

class ClearTokColors {
  static const background = Color(0xFF07080C);
  static const surface = Color(0xFF161926);
  static const pink = Color(0xFFFE2C55);
  static const cyan = Color(0xFF25F4EE);
  static const raised = Color(0xFF202431);
  static const text = Color(0xFFF5F6FA);
  static const secondary = Color(0xFFB6BDCC);
  static const muted = Color(0xFF9AA4B5);
  static const border = Color(0xFF424957);
  static const success = Color(0xFF80DCC4);
  static const warning = Color(0xFFFFD18A);
}

class ClearTokTokens {
  static const radius = 24.0;
  static const largeRadius = 28.0;
  static const gap = 8.0;
  static const inset = 16.0;
  static const borderWidth = .6;
  static const touchTarget = 48.0;
  static const dockClearance = 136.0;
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ClearTokColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: ClearTokColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: ClearTokColors.secondary,
  );
}

ShapeBorder gboxSquircleShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) => ContinuousRectangleBorder(
  borderRadius: BorderRadius.circular(radius * 2.15),
  side: side,
);

ThemeData clearTokTheme() {
  final shape = gboxSquircleShape(
    ClearTokTokens.radius,
    side: const BorderSide(
      color: ClearTokColors.border,
      width: ClearTokTokens.borderWidth,
    ),
  );
  return ThemeData(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: ClearTokColors.pink,
      secondary: ClearTokColors.cyan,
      surface: ClearTokColors.surface,
      onSurface: ClearTokColors.text,
      onPrimary: Colors.white,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: ClearTokColors.text,
      displayColor: ClearTokColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: ClearTokTokens.title,
      iconTheme: IconThemeData(color: ClearTokColors.secondary),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: ClearTokColors.secondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: ClearTokColors.text,
        backgroundColor: ClearTokColors.raised,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape as OutlinedBorder,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: ClearTokColors.cyan,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: ClearTokColors.text,
        shape: shape,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ClearTokColors.cyan.withValues(alpha: .12),
      labelTextStyle: WidgetStateProperty.all(
        ClearTokTokens.caption.copyWith(fontSize: 11),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ClearTokTokens.largeRadius * 2.15),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ClearTokColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    chipTheme: ChipThemeData(
      checkmarkColor: ClearTokColors.cyan,
      backgroundColor: ClearTokColors.surface.withValues(alpha: .8),
      selectedColor: ClearTokColors.pink.withValues(alpha: .18),
      side: const BorderSide(color: ClearTokColors.border),
      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(36)),
      labelStyle: ClearTokTokens.caption,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClearTokColors.surface.withValues(alpha: .8),
      hintStyle: ClearTokTokens.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ClearTokTokens.radius),
        borderSide: const BorderSide(color: ClearTokColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ClearTokTokens.radius),
        borderSide: const BorderSide(color: ClearTokColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ClearTokTokens.radius),
        borderSide: const BorderSide(color: ClearTokColors.cyan),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ClearTokColors.raised,
      contentTextStyle: ClearTokTokens.body,
      shape: shape,
    ),
  );
}

class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: ColoredBox(color: ClearTokColors.background),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.1,
                colors: [
                  ClearTokColors.pink.withValues(alpha: .20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomLeft,
                radius: 1.1,
                colors: [
                  ClearTokColors.cyan.withValues(alpha: .16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      child,
    ],
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

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = ClearTokTokens.radius,
    this.padding,
    this.margin,
    this.isSelected = false,
    this.blur = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final media = MediaQuery.of(context);
    final borderShape = gboxSquircleShape(
      borderRadius,
      side: BorderSide(
        color: isSelected
            ? ClearTokColors.pink
            : Colors.white.withValues(alpha: .22),
        width: isSelected ? 1.1 : .7,
      ),
    );
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        customBorder: borderShape,
        splashColor: ClearTokColors.cyan.withValues(alpha: .10),
        child: Container(
          padding: padding,
          constraints: onTap == null
              ? null
              : const BoxConstraints(minHeight: ClearTokTokens.touchTarget),
          child: child,
        ),
      ),
    );
    if (!blur || media.highContrast) {
      return Container(
        margin: margin,
        decoration: ShapeDecoration(
          color: ClearTokColors.surface,
          shape: gboxSquircleShape(
            borderRadius,
            side: BorderSide(
              color: isSelected ? ClearTokColors.pink : ClearTokColors.border,
              width: .7,
            ),
          ),
        ),
        child: content,
      );
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: gboxSquircleShape(borderRadius),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: gboxSquircleShape(borderRadius)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: borderShape,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.42, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      ClearTokColors.surface.withValues(alpha: .80),
                      const Color(0xFF0D101A).withValues(alpha: .88),
                    ],
                  ),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GBoxDockItem {
  final Widget icon;
  final Widget activeIcon;
  final String label;

  const GBoxDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class GBoxLiquidDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<GBoxDockItem> items;

  const GBoxLiquidDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: List.generate(items.length, (idx) {
            final item = items[idx];
            final active = idx == selectedIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTabSelected(idx),
                    customBorder: gboxSquircleShape(22),
                    splashColor: ClearTokColors.cyan.withValues(alpha: .14),
                    highlightColor: ClearTokColors.pink.withValues(alpha: .08),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: ShapeDecoration(
                        shape: gboxSquircleShape(
                          22,
                          side: BorderSide(
                            color: active
                                ? ClearTokColors.pink.withValues(alpha: .50)
                                : Colors.transparent,
                            width: .8,
                          ),
                        ),
                        gradient: active
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: const [0.0, 1.0],
                                colors: [
                                  ClearTokColors.pink.withValues(alpha: .26),
                                  ClearTokColors.cyan.withValues(alpha: .14),
                                ],
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme.merge(
                            data: IconThemeData(
                              size: 21,
                              color: active
                                  ? ClearTokColors.cyan
                                  : ClearTokColors.secondary,
                            ),
                            child: active ? item.activeIcon : item.icon,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : ClearTokColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class GBoxSegment {
  final String label;
  final IconData icon;

  const GBoxSegment({required this.label, required this.icon});
}

class GBoxSegmentedControl extends StatelessWidget {
  final List<GBoxSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;

  const GBoxSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      blur: false,
      borderRadius: 22,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 46,
        child: Row(
          children: List.generate(segments.length, (idx) {
            final seg = segments[idx];
            final active = idx == selectedIndex;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSegmentSelected(idx),
                  customBorder: gboxSquircleShape(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: ShapeDecoration(
                      shape: gboxSquircleShape(
                        18,
                        side: BorderSide(
                          color: active
                              ? ClearTokColors.pink.withValues(alpha: .48)
                              : Colors.transparent,
                          width: .8,
                        ),
                      ),
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 1.0],
                              colors: [
                                ClearTokColors.pink.withValues(alpha: .28),
                                ClearTokColors.cyan.withValues(alpha: .14),
                              ],
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          seg.icon,
                          size: 16,
                          color: active
                              ? ClearTokColors.cyan
                              : ClearTokColors.secondary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            seg.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : ClearTokColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class GlassSheet extends StatelessWidget {
  final Widget child;
  const GlassSheet({super.key, required this.child});
  @override
  Widget build(BuildContext context) => LiquidGlassContainer(
    borderRadius: ClearTokTokens.largeRadius,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * .9,
      ),
      child: SingleChildScrollView(child: SafeArea(top: false, child: child)),
    ),
  );
}

class GlassActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  bool get enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final shape = gboxSquircleShape(
      ClearTokTokens.radius,
      side: BorderSide(
        color: primary
            ? ClearTokColors.pink.withValues(alpha: .65)
            : Colors.white.withValues(alpha: .20),
        width: .8,
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : .55,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 1.0],
              colors: primary
                  ? [
                      ClearTokColors.pink.withValues(alpha: .42),
                      const Color(0xFF8C1635).withValues(alpha: .68),
                    ]
                  : [
                      Colors.white.withValues(alpha: .12),
                      ClearTokColors.raised.withValues(alpha: .88),
                    ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: shape,
              splashColor: ClearTokColors.cyan.withValues(alpha: .14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme.merge(
                      data: const IconThemeData(size: 20, color: Colors.white),
                      child: icon,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
