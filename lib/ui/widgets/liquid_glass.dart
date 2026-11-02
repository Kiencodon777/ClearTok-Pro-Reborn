import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class ClearTokColors {
  // GBox / iOS 19 Obsidian & Emerald Liquid Glass Palette
  static const background = Color(0xFF06070A);
  static const surface = Color(0xFF13161E);
  static const pink = Color(0xFFFF453A); // iOS Native Coral Red
  static const cyan = Color(0xFF32D74B); // GBox Emerald Green
  static const neonCyan = Color(0xFF34E865); // Luminous GBox Liquid Emerald
  static const neonPink = Color(0xFFFF453A);
  static const dockGlass = Color(0xFF151820);
  static const raised = Color(0xFF1C202B);
  static const text = Color(0xFFF5F7FA);
  static const secondary = Color(0xFFB4BCCB);
  static const muted = Color(0xFF8E97A8);
  static const border = Color(0xFF2E3442);
  static const success = Color(0xFF32D74B);
  static const warning = Color(0xFFFFD60A);
}

class ClearTokTokens {
  static const radius = 24.0;
  static const largeRadius = 28.0;
  static const gap = 8.0;
  static const inset = 16.0;
  static const borderWidth = .6;
  static const touchTarget = 48.0;
  static const dockClearance = 118.0;
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
}) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side,
);

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
        shape: const StadiumBorder(
          side: BorderSide(color: Colors.white24, width: 0.8),
        ),
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
      backgroundColor: ClearTokColors.surface.withValues(alpha: .9),
      selectedColor: ClearTokColors.cyan.withValues(alpha: .18),
      side: const BorderSide(color: ClearTokColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: ClearTokTokens.caption,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClearTokColors.surface.withValues(alpha: .88),
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
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.85),
                  radius: 1.25,
                  colors: [
                    ClearTokColors.cyan.withValues(alpha: .07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.95),
                  radius: 1.1,
                  colors: [
                    const Color(0xFF1E2638).withValues(alpha: .22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// Reusable iOS Spring Bounce wrapper for pills, chips, and action buttons.
class BouncyTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const BouncyTapWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.93,
  });

  @override
  State<BouncyTapWrapper> createState() => _BouncyTapWrapperState();
}

class _BouncyTapWrapperState extends State<BouncyTapWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  static const _releaseSpring = SpringDescription(
    mass: 1.0,
    stiffness: 420.0,
    damping: 18.0,
  );

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(
      value: 1.0,
      vsync: this,
    );
  }

  void _onDown() {
    if (widget.onTap == null) return;
    _scaleController.animateTo(
      widget.pressedScale,
      duration: const Duration(milliseconds: 85),
      curve: Curves.easeOutQuad,
    );
  }

  void _onRelease({bool triggered = false}) {
    if (widget.onTap == null) return;
    if (triggered) {
      HapticFeedback.lightImpact();
    }
    final sim = SpringSimulation(
      _releaseSpring,
      _scaleController.value,
      1.0,
      triggered ? 2.2 : 1.0,
      tolerance: const Tolerance(distance: 0.002, velocity: 0.01),
    );
    _scaleController.animateWith(sim);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onRelease(triggered: true),
      onPointerCancel: (_) => _onRelease(triggered: false),
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) => Transform.scale(
          scale: _scaleController.value.clamp(0.84, 1.12).toDouble(),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
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
            color: isSelected
                ? ClearTokColors.cyan
                : Colors.white.withValues(alpha: .12),
            width: isSelected ? 1.2 : .8,
          ),
        ),
        child: content,
      );
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: isSelected
                        ? ClearTokColors.cyan
                        : Colors.white.withValues(alpha: .16),
                    width: isSelected ? 1.2 : .8,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.38, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: .11),
                      ClearTokColors.dockGlass.withValues(alpha: .68),
                      ClearTokColors.dockGlass.withValues(alpha: .82),
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

class _StaticPillGlassBackdrop extends StatelessWidget {
  final double borderRadius;
  final bool blur;
  const _StaticPillGlassBackdrop({
    required this.borderRadius,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: ClearTokColors.dockGlass.withValues(alpha: 0.65),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.85,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.12),
            const Color(0xFF171A22).withValues(alpha: 0.68),
            const Color(0xFF0E1015).withValues(alpha: 0.84),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
    if (!blur) return RepaintBoundary(child: box);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: box,
          ),
        ),
      ),
    );
  }
}

/// Authentic GBox Liquid Glass Water-Droplet Painter.
/// Runs 100% on GPU Canvas with zero widget rebuilds, smooth lens inflation
/// (`lensSwell`), elastic edge squish/bounce on Left & Right ends, and
/// GBox's signature Crystal White + Emerald Prism refraction!
class _WaterDropletPillPainter extends CustomPainter {
  final Animation<double> position;
  final Animation<double> lensSwell;
  final int itemCount;
  final double baseHeight;
  final double Function() getSmoothedVelocity;

  _WaterDropletPillPainter({
    required this.position,
    required this.lensSwell,
    required this.itemCount,
    required this.baseHeight,
    required this.getSmoothedVelocity,
  }) : super(repaint: Listenable.merge([position, lensSwell]));

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0 || size.width <= 0) return;
    final itemWidth = size.width / itemCount;
    final maxIdx = math.max(0, itemCount - 1).toDouble();

    // Raw position WITH spring overshoot preserved at left (< 0) and right (> maxIdx)!
    final rawPos = position.value;
    final swell = lensSwell.value.clamp(0.0, 1.45).toDouble();
    final vel = getSmoothedVelocity().abs().clamp(0.0, 1.5).toDouble();

    // Calculate elastic edge overshoot (when bouncing on Left tab 0 or Right tab maxIdx)
    double edgeOvershoot = 0.0;
    double displayPos = rawPos;
    if (rawPos < 0.0) {
      edgeOvershoot = (-rawPos).clamp(0.0, 0.45).toDouble();
      displayPos = -edgeOvershoot * 0.35;
    } else if (rawPos > maxIdx) {
      edgeOvershoot = (rawPos - maxIdx).clamp(0.0, 0.45).toDouble();
      displayPos = maxIdx + edgeOvershoot * 0.35;
    }

    // Smooth liquid stretch & GBox droplet magnification (no per-frame jitter!)
    final widthStretch =
        (swell * 0.08) + (vel * 0.14) - (edgeOvershoot * 0.18);
    final heightStretch =
        (swell * 0.16) - (vel * 0.05) + (edgeOvershoot * 0.14);

    final pillW = (itemWidth * (1.0 + widthStretch))
        .clamp(itemWidth * 0.78, size.width * 0.92)
        .toDouble();
    final pillH = (baseHeight * (1.0 + heightStretch))
        .clamp(baseHeight * 0.86, size.height + 6.0)
        .toDouble();

    final centerX = (displayPos + 0.5) * itemWidth;
    const minLeft = -3.0;
    final maxLeft = math.max(minLeft, size.width - pillW + 3.0);
    final left = (centerX - pillW / 2).clamp(minLeft, maxLeft).toDouble();
    final top = (size.height - pillH) / 2;

    final rect = Rect.fromLTWH(left, top, pillW, pillH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(pillH / 2));

    // Active optical energy (0.0 when resting -> 1.0 when pressed/sliding/bouncing)
    final opticalEnergy = (swell * 0.85 + vel * 0.6 + edgeOvershoot * 1.4)
        .clamp(0.0, 1.0)
        .toDouble();

    // 1. GBox Emerald Caustic Glow under the droplet when active
    if (opticalEnergy > 0.02) {
      final glowPaint = Paint()
        ..color = ClearTokColors.neonCyan.withValues(
          alpha: 0.22 * opticalEnergy,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(rrect.shift(const Offset(0, 2)), glowPaint);
    }

    // 2. GBox Smoked-Crystal Body:
    // Resting: sleek dark smoked glass capsule (`#252932`).
    // Active/Sliding: crystal-clear magnified water lens with bright meniscus!
    final topAlpha = lerpDouble(0.16, 0.34, opticalEnergy)!;
    final midAlpha = lerpDouble(0.42, 0.10, opticalEnergy)!;
    final botAlpha = lerpDouble(0.55, 0.22, opticalEnergy)!;
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.32, 0.72, 1.0],
        colors: [
          Colors.white.withValues(alpha: topAlpha),
          const Color(0xFF282D37).withValues(alpha: midAlpha),
          const Color(0xFF1E222B).withValues(alpha: botAlpha),
          Color.lerp(
            const Color(0xFF2A303C).withValues(alpha: 0.45),
            ClearTokColors.neonCyan.withValues(alpha: 0.26),
            opticalEnergy,
          )!,
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Top Water Meniscus Specular Arc (Khúc xạ vòm kính phía trên)
    final glossRect = Rect.fromLTWH(
      left + pillW * 0.08,
      top + 1.2,
      pillW * 0.84,
      pillH * 0.38,
    );
    final glossRRect = RRect.fromRectAndRadius(
      glossRect,
      Radius.circular(pillH * 0.22),
    );
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(
            alpha: lerpDouble(0.20, 0.46, opticalEnergy)!,
          ),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(glossRect);
    canvas.drawRRect(glossRRect, glossPaint);

    // 4. GBox Chromatic Prism Rim (Silver-White top rim + GBox Emerald bottom/side refraction)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(1.0, 1.5, opticalEnergy)!
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.45, 0.78, 1.0],
        colors: [
          Colors.white.withValues(
            alpha: lerpDouble(0.38, 0.82, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.14, 0.35, opticalEnergy)!,
          ),
          Color.lerp(
            Colors.white.withValues(alpha: 0.18),
            ClearTokColors.neonCyan.withValues(alpha: 0.75),
            opticalEnergy,
          )!,
          Color.lerp(
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFF80FFAA).withValues(alpha: 0.90),
            opticalEnergy,
          )!,
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.5), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropletPillPainter oldDelegate) =>
      oldDelegate.itemCount != itemCount ||
      oldDelegate.baseHeight != baseHeight;
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

class GBoxLiquidDock extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<GBoxDockItem> items;
  final EdgeInsetsGeometry margin;

  const GBoxLiquidDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
    this.margin = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  State<GBoxLiquidDock> createState() => _GBoxLiquidDockState();
}

class _GBoxLiquidDockState extends State<GBoxLiquidDock>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _lensController;
  double _smoothedVelocity = 0.0;
  bool _isDragging = false;
  int _lastAnimatedTarget = 0;

  // Underdamped GBox liquid spring so Left (0), Middle (1), and Right (2) ALL bounce!
  static const _moveSpring = SpringDescription(
    mass: 1.0,
    stiffness: 290.0,
    damping: 19.5,
  );

  static const _swellSpring = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 17.5,
  );

  static const _springTolerance = Tolerance(distance: 0.002, velocity: 0.01);

  @override
  void initState() {
    super.initState();
    _lastAnimatedTarget = widget.selectedIndex;
    _controller = AnimationController.unbounded(
      value: widget.selectedIndex.toDouble(),
      vsync: this,
    );
    _lensController = AnimationController.unbounded(
      value: 0.0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant GBoxLiquidDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        !_isDragging &&
        widget.selectedIndex != _lastAnimatedTarget) {
      _animateToIndex(widget.selectedIndex);
    }
  }

  void _swellUp() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        _lensController.value,
        1.0,
        2.2,
        tolerance: _springTolerance,
      ),
    );
  }

  void _swellDownWithBounce() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        math.max(_lensController.value, 0.85),
        0.0,
        -2.6,
        tolerance: _springTolerance,
      ),
    );
  }

  void _animateToIndex(int targetIndex, {double? dragVelocity}) {
    _lastAnimatedTarget = targetIndex;
    final target = targetIndex.toDouble();
    final current = _controller.value;
    final maxIdx = math.max(0, widget.items.length - 1);
    final distance = target - current;

    // Ensure a juicy liquid bounce even when tapping or releasing right on Left (0) or Right (maxIdx)!
    double velocity = dragVelocity ?? 0.0;
    if (distance.abs() < 0.12 && velocity.abs() < 1.2) {
      if (targetIndex == 0) {
        velocity = -2.8; // Elastic bounce against left glass wall
      } else if (targetIndex == maxIdx) {
        velocity = 2.8; // Elastic bounce against right glass wall
      } else {
        velocity = distance >= 0 ? 2.2 : -2.2;
      }
    }

    _smoothedVelocity = 0.0;
    final simulation = SpringSimulation(
      _moveSpring,
      current,
      target,
      velocity,
      tolerance: _springTolerance,
    );
    _controller.animateWith(simulation);
    _swellDownWithBounce();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop();
    _smoothedVelocity = 0.0;
    HapticFeedback.selectionClick();
    _swellUp();
  }

  void _handleDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (itemWidth <= 0) return;
    final delta = details.primaryDelta ?? 0.0;
    final step = delta / itemWidth;
    final maxIdx = (widget.items.length - 1).toDouble();

    // Low-pass filter velocity so pill width NEVER stutters/jitters during drag!
    _smoothedVelocity = (_smoothedVelocity * 0.78 + (step * 8.0) * 0.22)
        .clamp(-1.2, 1.2)
        .toDouble();

    double next = _controller.value + step;
    // Soft rubber-band resistance when pulling past Left (0.0) or Right (maxIdx)
    if (next < 0.0) {
      next = _controller.value + step * 0.35;
      next = next.clamp(-0.28, 0.0).toDouble();
    } else if (next > maxIdx) {
      next = _controller.value + step * 0.35;
      next = next.clamp(maxIdx, maxIdx + 0.28).toDouble();
    }
    _controller.value = next;
  }

  void _handleDragEnd(DragEndDetails details, double itemWidth) {
    _isDragging = false;
    final maxIdx = widget.items.length - 1;
    final vx = itemWidth > 0
        ? (details.primaryVelocity ?? 0.0) / itemWidth
        : 0.0;
    int nextIndex = _controller.value.round().clamp(0, maxIdx);
    if (vx.abs() > 1.6) {
      nextIndex = (vx > 0 ? _controller.value.ceil() : _controller.value.floor())
          .clamp(0, maxIdx);
    }
    HapticFeedback.lightImpact();
    _animateToIndex(
      nextIndex,
      dragVelocity: vx.clamp(-5.5, 5.5).toDouble(),
    );
    if (nextIndex != widget.selectedIndex) {
      widget.onTabSelected(nextIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _lensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    return Padding(
      padding: widget.margin,
      child: RepaintBoundary(
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const padH = 5.0;
              final trackWidth = math.max(0.0, constraints.maxWidth - padH * 2);
              final itemWidth = count > 0 ? trackWidth / count : 0.0;

              return Listener(
                onPointerDown: (_) => _swellUp(),
                onPointerCancel: (_) {
                  if (!_isDragging) _swellDownWithBounce();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _handleDragStart,
                  onHorizontalDragUpdate: (d) =>
                      _handleDragUpdate(d, itemWidth),
                  onHorizontalDragEnd: (d) => _handleDragEnd(d, itemWidth),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Layer 1: Static Frosted GBox Glass Background
                      const Positioned.fill(
                        child: _StaticPillGlassBackdrop(borderRadius: 31),
                      ),

                      // Layer 2: GPU CustomPainter Water Droplet Pill (Zero widget rebuild!)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: padH,
                            vertical: 5,
                          ),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _WaterDropletPillPainter(
                                position: _controller,
                                lensSwell: _lensController,
                                itemCount: count,
                                baseHeight: 52,
                                getSmoothedVelocity: () => _smoothedVelocity,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Layer 3: Interactive Tab Items with iOS Spring Bounce
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: padH,
                          vertical: 5,
                        ),
                        child: Row(
                          children: List.generate(count, (idx) {
                            final item = widget.items[idx];
                            final isSelected = idx == widget.selectedIndex;
                            return Expanded(
                              child: BouncyTapWrapper(
                                pressedScale: 0.90,
                                onTap: () {},
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _animateToIndex(idx);
                                    widget.onTabSelected(idx);
                                  },
                                  child: SizedBox(
                                    height: 52,
                                    child: AnimatedScale(
                                      scale: isSelected ? 1.06 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOutBack,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconTheme.merge(
                                            data: IconThemeData(
                                              size: 20,
                                              color: isSelected
                                                  ? ClearTokColors.neonCyan
                                                  : Colors.white.withValues(
                                                      alpha: 0.55,
                                                    ),
                                            ),
                                            child: isSelected
                                                ? item.activeIcon
                                                : item.icon,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? ClearTokColors.neonCyan
                                                  : Colors.white.withValues(
                                                      alpha: 0.55,
                                                    ),
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
                    ],
                  ),
                ),
              );
            },
          ),
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

class GBoxSegmentedControl extends StatefulWidget {
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
  State<GBoxSegmentedControl> createState() => _GBoxSegmentedControlState();
}

class _GBoxSegmentedControlState extends State<GBoxSegmentedControl>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _lensController;
  double _smoothedVelocity = 0.0;
  bool _isDragging = false;
  int _lastAnimatedTarget = 0;

  static const _moveSpring = SpringDescription(
    mass: 1.0,
    stiffness: 290.0,
    damping: 19.5,
  );

  static const _swellSpring = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 17.5,
  );

  static const _springTolerance = Tolerance(distance: 0.002, velocity: 0.01);

  @override
  void initState() {
    super.initState();
    _lastAnimatedTarget = widget.selectedIndex;
    _controller = AnimationController.unbounded(
      value: widget.selectedIndex.toDouble(),
      vsync: this,
    );
    _lensController = AnimationController.unbounded(
      value: 0.0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant GBoxSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        !_isDragging &&
        widget.selectedIndex != _lastAnimatedTarget) {
      _animateToIndex(widget.selectedIndex);
    }
  }

  void _swellUp() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        _lensController.value,
        1.0,
        2.2,
        tolerance: _springTolerance,
      ),
    );
  }

  void _swellDownWithBounce() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        math.max(_lensController.value, 0.85),
        0.0,
        -2.6,
        tolerance: _springTolerance,
      ),
    );
  }

  void _animateToIndex(int targetIndex, {double? dragVelocity}) {
    _lastAnimatedTarget = targetIndex;
    final target = targetIndex.toDouble();
    final current = _controller.value;
    final maxIdx = math.max(0, widget.segments.length - 1);
    final distance = target - current;

    double velocity = dragVelocity ?? 0.0;
    if (distance.abs() < 0.12 && velocity.abs() < 1.2) {
      if (targetIndex == 0) {
        velocity = -2.6;
      } else if (targetIndex == maxIdx) {
        velocity = 2.6;
      } else {
        velocity = distance >= 0 ? 2.0 : -2.0;
      }
    }

    _smoothedVelocity = 0.0;
    final simulation = SpringSimulation(
      _moveSpring,
      current,
      target,
      velocity,
      tolerance: _springTolerance,
    );
    _controller.animateWith(simulation);
    _swellDownWithBounce();
  }

  @override
  void dispose() {
    _controller.dispose();
    _lensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.segments.length;
    return RepaintBoundary(
      child: SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const padH = 4.0;
            final trackWidth = math.max(0.0, constraints.maxWidth - padH * 2);
            final itemWidth = count > 0 ? trackWidth / count : 0.0;

            return Listener(
              onPointerDown: (_) => _swellUp(),
              onPointerCancel: (_) {
                if (!_isDragging) _swellDownWithBounce();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _isDragging = true;
                  _controller.stop();
                  _smoothedVelocity = 0.0;
                  HapticFeedback.selectionClick();
                  _swellUp();
                },
                onHorizontalDragUpdate: (d) {
                  if (itemWidth <= 0) return;
                  final step = (d.primaryDelta ?? 0.0) / itemWidth;
                  final maxIdx = (count - 1).toDouble();
                  _smoothedVelocity =
                      (_smoothedVelocity * 0.78 + (step * 8.0) * 0.22)
                          .clamp(-1.2, 1.2)
                          .toDouble();
                  double next = _controller.value + step;
                  if (next < 0.0) {
                    next = (_controller.value + step * 0.35)
                        .clamp(-0.26, 0.0)
                        .toDouble();
                  } else if (next > maxIdx) {
                    next = (_controller.value + step * 0.35)
                        .clamp(maxIdx, maxIdx + 0.26)
                        .toDouble();
                  }
                  _controller.value = next;
                },
                onHorizontalDragEnd: (d) {
                  _isDragging = false;
                  final maxIdx = count - 1;
                  final vx = itemWidth > 0
                      ? (d.primaryVelocity ?? 0.0) / itemWidth
                      : 0.0;
                  int nextIdx = _controller.value.round().clamp(0, maxIdx);
                  if (vx.abs() > 1.6) {
                    nextIdx = (vx > 0
                            ? _controller.value.ceil()
                            : _controller.value.floor())
                        .clamp(0, maxIdx);
                  }
                  HapticFeedback.lightImpact();
                  _animateToIndex(
                    nextIdx,
                    dragVelocity: vx.clamp(-5.0, 5.0).toDouble(),
                  );
                  if (nextIdx != widget.selectedIndex) {
                    widget.onSegmentSelected(nextIdx);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(
                      child: _StaticPillGlassBackdrop(
                        borderRadius: 24,
                        blur: false,
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(padH),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _WaterDropletPillPainter(
                              position: _controller,
                              lensSwell: _lensController,
                              itemCount: count,
                              baseHeight: 40,
                              getSmoothedVelocity: () => _smoothedVelocity,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(padH),
                      child: Row(
                        children: List.generate(count, (idx) {
                          final seg = widget.segments[idx];
                          final active = idx == widget.selectedIndex;
                          return Expanded(
                            child: BouncyTapWrapper(
                              pressedScale: 0.91,
                              onTap: () {},
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _animateToIndex(idx);
                                  widget.onSegmentSelected(idx);
                                },
                                child: SizedBox(
                                  height: 40,
                                  child: AnimatedScale(
                                    scale: active ? 1.04 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            seg.icon,
                                            size: 15,
                                            color: active
                                                ? ClearTokColors.neonCyan
                                                : Colors.white.withValues(
                                                    alpha: 0.55,
                                                  ),
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
                                                    : Colors.white.withValues(
                                                        alpha: 0.55,
                                                      ),
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
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

/// Cohesive Water-Glass Capsule Action Button (`Quét Repost`, `Hủy Repost`, etc.)
/// with tactile iOS spring bounce feedback.
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
    final radius = BorderRadius.circular(25);
    final accent = primary ? ClearTokColors.neonPink : ClearTokColors.neonCyan;

    return RepaintBoundary(
      child: BouncyTapWrapper(
        pressedScale: 0.93,
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1.0 : .50,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: primary
                      ? ClearTokColors.neonPink.withValues(alpha: .52)
                      : ClearTokColors.neonCyan.withValues(alpha: .38),
                  width: 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                  colors: primary
                      ? [
                          Colors.white.withValues(alpha: .20),
                          ClearTokColors.neonPink.withValues(alpha: .24),
                          const Color(0xFF2D1014).withValues(alpha: .78),
                        ]
                      : [
                          Colors.white.withValues(alpha: .18),
                          ClearTokColors.neonCyan.withValues(alpha: .10),
                          const Color(0xFF131B18).withValues(alpha: .82),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: primary ? .16 : .12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: radius,
                  splashColor: accent.withValues(alpha: .16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme.merge(
                          data: IconThemeData(
                            size: 18,
                            color: primary
                                ? Colors.white
                                : ClearTokColors.neonCyan,
                          ),
                          child: icon,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
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
        ),
      ),
    );
  }
}
