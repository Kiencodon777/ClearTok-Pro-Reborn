import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

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

ThemeData clearTokTheme() {
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(ClearTokTokens.radius),
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
        shape: shape,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ClearTokTokens.largeRadius),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
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
        decoration: BoxDecoration(
          color: ClearTokColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: isSelected ? ClearTokColors.pink : ClearTokColors.border,
            width: .6,
          ),
        ),
        child: content,
      );
    }
    // Keep the optical platter behind its content so interactive glass children retain refraction.
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: glass.GlassContainer(
                shape: glass.LiquidRoundedSuperellipse(
                  borderRadius: borderRadius,
                ),
                settings: glass.LiquidGlassSettings.ios27Dark,
                quality: glass.GlassQuality.premium,
                useOwnLayer: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          content,
        ],
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

  @override
  Widget build(BuildContext context) => glass.GlassButton.custom(
    onTap: onPressed ?? () {},
    enabled: onPressed != null,
    label: label,
    width: double.infinity,
    height: 56,
    shape: const glass.LiquidRoundedSuperellipse(
      borderRadius: ClearTokTokens.radius,
    ),
    settings: primary
        ? glass.LiquidGlassSettings.ios27Dark.copyWith(
            glassColor: ClearTokColors.pink.withValues(alpha: .32),
          )
        : glass.LiquidGlassSettings.ios27Dark,
    quality: glass.GlassQuality.premium,
    useOwnLayer: true,
    stretch: MediaQuery.disableAnimationsOf(context) ? 0 : .18,
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
  );
}
