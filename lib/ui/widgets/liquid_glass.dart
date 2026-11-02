import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class ClearTokColors {
  static const background = Color(0xFF07080C);
  static const surface = Color(0xFF161926);
  static const pink = Color(0xFFFE2C55);
  static const cyan = Color(0xFF25F4EE);
  static const neonCyan = Color(0xFF00F2FE);
  static const neonPink = Color(0xFFFF2A54);
  static const dockGlass = Color(0xFF141824);
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
      backgroundColor: ClearTokColors.surface.withValues(alpha: .85),
      selectedColor: ClearTokColors.pink.withValues(alpha: .22),
      side: const BorderSide(color: ClearTokColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: ClearTokTokens.caption,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClearTokColors.surface.withValues(alpha: .85),
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
                  center: Alignment.topRight,
                  radius: 1.15,
                  colors: [
                    ClearTokColors.pink.withValues(alpha: .20),
                    const Color(0xFF6C1D5F).withValues(alpha: .08),
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
                  center: Alignment.bottomLeft,
                  radius: 1.15,
                  colors: [
                    ClearTokColors.cyan.withValues(alpha: .16),
                    const Color(0xFF143552).withValues(alpha: .08),
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
                ? ClearTokColors.pink
                : Colors.white.withValues(alpha: .14),
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
                color: Colors.black.withValues(alpha: .30),
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
                        ? ClearTokColors.pink
                        : Colors.white.withValues(alpha: .20),
                    width: isSelected ? 1.2 : .8,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.38, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      ClearTokColors.dockGlass.withValues(alpha: .60),
                      ClearTokColors.dockGlass.withValues(alpha: .76),
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
        color: ClearTokColors.dockGlass.withValues(alpha: 0.62),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.85,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.13),
            const Color(0xFF171A24).withValues(alpha: 0.66),
            const Color(0xFF0E1017).withValues(alpha: 0.82),
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
              color: Colors.black.withValues(alpha: 0.42),
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

/// Authentic GBox Crystal-Clear Water-Droplet Painter.
/// - 100% transparent crystal water body (NEVER turns solid green!)
/// - When moving/pressed (`lensSwell > 0`), the droplet magnifies LARGER than
///   the dock height (`pillH` expands past `size.height` by up to +10px!)
///   just like GBox's protruding water lens!
class _WaterDropletPillPainter extends CustomPainter {
  final Animation<double> position;
  final Animation<double> lensSwell;
  final int itemCount;
  final double baseHeight;
  final double maxExpandedHeight;
  final double Function() getSmoothedVelocity;

  _WaterDropletPillPainter({
    required this.position,
    required this.lensSwell,
    required this.itemCount,
    required this.baseHeight,
    required this.maxExpandedHeight,
    required this.getSmoothedVelocity,
  }) : super(repaint: Listenable.merge([position, lensSwell]));

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0 || size.width <= 0) return;
    final itemWidth = size.width / itemCount;
    final maxIdx = math.max(0, itemCount - 1).toDouble();

    final rawPos = position.value;
    final swell = lensSwell.value.clamp(0.0, 1.45).toDouble();
    final vel = getSmoothedVelocity().abs().clamp(0.0, 1.5).toDouble();

    // Elastic edge overshoot at Left (< 0) and Right (> maxIdx)
    double edgeOvershoot = 0.0;
    double displayPos = rawPos;
    if (rawPos < 0.0) {
      edgeOvershoot = (-rawPos).clamp(0.0, 0.45).toDouble();
      displayPos = -edgeOvershoot * 0.36;
    } else if (rawPos > maxIdx) {
      edgeOvershoot = (rawPos - maxIdx).clamp(0.0, 0.45).toDouble();
      displayPos = maxIdx + edgeOvershoot * 0.36;
    }

    // Active optical energy (0.0 at rest -> 1.0 when touched/sliding/bouncing)
    final opticalEnergy = (swell * 0.90 + vel * 0.65 + edgeOvershoot * 1.4)
        .clamp(0.0, 1.0)
        .toDouble();

    // GBox magnifying water droplet expansion:
    // When active, the pill swells wider AND taller than the dock itself!
    final widthStretch =
        (swell * 0.16) + (vel * 0.18) - (edgeOvershoot * 0.18);
    final pillW = (itemWidth * (1.0 + widthStretch))
        .clamp(itemWidth * 0.80, size.width * 0.94)
        .toDouble();

    final targetExpandedH =
        lerpDouble(baseHeight, maxExpandedHeight, opticalEnergy)! +
        (edgeOvershoot * 6.0);
    final pillH = targetExpandedH
        .clamp(baseHeight * 0.88, maxExpandedHeight + 4.0)
        .toDouble();

    final centerX = (displayPos + 0.5) * itemWidth;
    const minLeft = -6.0;
    final maxLeft = math.max(minLeft, size.width - pillW + 6.0);
    final left = (centerX - pillW / 2).clamp(minLeft, maxLeft).toDouble();
    final top = (size.height - pillH) / 2;

    final rect = Rect.fromLTWH(left, top, pillW, pillH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(pillH / 2));

    // 1. Deep optical drop shadow under the protruding water lens
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(
        alpha: lerpDouble(0.22, 0.48, opticalEnergy)!,
      )
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        lerpDouble(4.0, 12.0, opticalEnergy)!,
      );
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), shadowPaint);

    // 2. 100% Crystal-Clear Water Droplet Body (Transparent center like real water!)
    // At rest: subtle smoked capsule. In motion: ultra-clear transparent glass lens!
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.25, 0.65, 1.0],
        colors: [
          Colors.white.withValues(
            alpha: lerpDouble(0.14, 0.26, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.06, 0.02, opticalEnergy)!,
          ),
          Colors.black.withValues(
            alpha: lerpDouble(0.22, 0.04, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.05, 0.16, opticalEnergy)!,
          ),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Top Water Meniscus Specular Highlight (Vòm khúc xạ ánh sáng trắng trong suốt)
    final glossRect = Rect.fromLTWH(
      left + pillW * 0.08,
      top + 1.5,
      pillW * 0.84,
      pillH * 0.36,
    );
    final glossRRect = RRect.fromRectAndRadius(
      glossRect,
      Radius.circular(pillH * 0.20),
    );
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(
            alpha: lerpDouble(0.18, 0.46, opticalEnergy)!,
          ),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(glossRect);
    canvas.drawRRect(glossRRect, glossPaint);

    // 4. Bottom Inner Caustic Water Reflection Arc
    if (opticalEnergy > 0.05) {
      final bottomArcRect = Rect.fromLTWH(
        left + pillW * 0.14,
        top + pillH * 0.72,
        pillW * 0.72,
        pillH * 0.24,
      );
      final bottomArcRRect = RRect.fromRectAndRadius(
        bottomArcRect,
        Radius.circular(pillH * 0.14),
      );
      final bottomArcPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24 * opticalEnergy),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(bottomArcRect);
      canvas.drawRRect(bottomArcRRect, bottomArcPaint);
    }

    // 5. Crisp Pure-Crystal Surface Tension Rim (Viền nước trong suốt như GBox)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(0.95, 1.55, opticalEnergy)!
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.35, 0.70, 1.0],
        colors: [
          Colors.white.withValues(
            alpha: lerpDouble(0.38, 0.88, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.12, 0.32, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.10, 0.28, opticalEnergy)!,
          ),
          Colors.white.withValues(
            alpha: lerpDouble(0.22, 0.72, opticalEnergy)!,
          ),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.5), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropletPillPainter oldDelegate) =>
      oldDelegate.itemCount != itemCount ||
      oldDelegate.baseHeight != baseHeight ||
      oldDelegate.maxExpandedHeight != maxExpandedHeight;
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
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<GBoxLiquidDock> createState() => _GBoxLiquidDockState();
}

class _GBoxLiquidDockState extends State<GBoxLiquidDock>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _lensController;
  late final AnimationController _dockRecoilController;
  double _smoothedVelocity = 0.0;
  bool _isDragging = false;
  int _lastAnimatedTarget = 0;

  static const _moveSpring = SpringDescription(
    mass: 1.0,
    stiffness: 290.0,
    damping: 19.0,
  );

  static const _swellSpring = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 17.0,
  );

  // Coupled dock recoil spring: makes the whole dock sway & bounce left-right with the droplet!
  static const _dockRecoilSpring = SpringDescription(
    mass: 1.0,
    stiffness: 260.0,
    damping: 13.5,
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
    _dockRecoilController = AnimationController.unbounded(
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
        2.4,
        tolerance: _springTolerance,
      ),
    );
  }

  void _swellDownWithBounce() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        math.max(_lensController.value, 0.90),
        0.0,
        -2.8,
        tolerance: _springTolerance,
      ),
    );
  }

  void _triggerDockRecoil(double directionImpulse) {
    _dockRecoilController.animateWith(
      SpringSimulation(
        _dockRecoilSpring,
        _dockRecoilController.value,
        0.0,
        directionImpulse.clamp(-4.5, 4.5).toDouble(),
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

    double velocity = dragVelocity ?? 0.0;
    double dockImpulse = distance * 2.2 + velocity * 0.45;
    if (distance.abs() < 0.12 && velocity.abs() < 1.2) {
      if (targetIndex == 0) {
        velocity = -2.8;
        dockImpulse = -3.2;
      } else if (targetIndex == maxIdx) {
        velocity = 2.8;
        dockImpulse = 3.2;
      } else {
        velocity = distance >= 0 ? 2.2 : -2.2;
        dockImpulse = distance >= 0 ? 2.4 : -2.4;
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
    _triggerDockRecoil(dockImpulse);
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop();
    _dockRecoilController.stop();
    _smoothedVelocity = 0.0;
    HapticFeedback.selectionClick();
    _swellUp();
  }

  void _handleDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (itemWidth <= 0) return;
    final delta = details.primaryDelta ?? 0.0;
    final step = delta / itemWidth;
    final maxIdx = (widget.items.length - 1).toDouble();

    _smoothedVelocity = (_smoothedVelocity * 0.78 + (step * 8.0) * 0.22)
        .clamp(-1.2, 1.2)
        .toDouble();

    double next = _controller.value + step;
    if (next < 0.0) {
      next = (_controller.value + step * 0.35).clamp(-0.28, 0.0).toDouble();
    } else if (next > maxIdx) {
      next = (_controller.value + step * 0.35)
          .clamp(maxIdx, maxIdx + 0.28)
          .toDouble();
    }
    _controller.value = next;

    // Coupled horizontal sway & elastic stretch of the entire dock while dragging!
    final nextRecoil = (_dockRecoilController.value * 0.82 + step * 1.35)
        .clamp(-0.65, 0.65)
        .toDouble();
    _dockRecoilController.value = nextRecoil;
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
    _dockRecoilController.dispose();
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
                  if (!_isDragging) {
                    _swellDownWithBounce();
                    _triggerDockRecoil(0.0);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _handleDragStart,
                  onHorizontalDragUpdate: (d) =>
                      _handleDragUpdate(d, itemWidth),
                  onHorizontalDragEnd: (d) => _handleDragEnd(d, itemWidth),
                  child: AnimatedBuilder(
                    animation: _dockRecoilController,
                    builder: (context, dockChild) {
                      final recoil = _dockRecoilController.value
                          .clamp(-0.85, 0.85)
                          .toDouble();
                      final dx = recoil * 9.0;
                      final scaleX = 1.0 + recoil.abs() * 0.032;
                      final scaleY = 1.0 - recoil.abs() * 0.018;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.scale(
                          scaleX: scaleX,
                          scaleY: scaleY,
                          child: dockChild,
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Layer 1: Static Frosted GBox Glass Background
                        const Positioned.fill(
                          child: _StaticPillGlassBackdrop(borderRadius: 31),
                        ),

                        // Layer 2: GPU CustomPainter Crystal Water Droplet Pill
                        // Expands up to 70px (protruding outside the 62px dock like GBox!)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: padH,
                            ),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _WaterDropletPillPainter(
                                  position: _controller,
                                  lensSwell: _lensController,
                                  itemCount: count,
                                  baseHeight: 50,
                                  maxExpandedHeight: 70,
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
                                                size: 19,
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
                                                fontSize: 10.0,
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
  late final AnimationController _barRecoilController;
  double _smoothedVelocity = 0.0;
  bool _isDragging = false;
  int _lastAnimatedTarget = 0;

  static const _moveSpring = SpringDescription(
    mass: 1.0,
    stiffness: 290.0,
    damping: 19.0,
  );

  static const _swellSpring = SpringDescription(
    mass: 1.0,
    stiffness: 340.0,
    damping: 17.0,
  );

  static const _barRecoilSpring = SpringDescription(
    mass: 1.0,
    stiffness: 270.0,
    damping: 14.0,
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
    _barRecoilController = AnimationController.unbounded(
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
        2.4,
        tolerance: _springTolerance,
      ),
    );
  }

  void _swellDownWithBounce() {
    _lensController.animateWith(
      SpringSimulation(
        _swellSpring,
        math.max(_lensController.value, 0.90),
        0.0,
        -2.8,
        tolerance: _springTolerance,
      ),
    );
  }

  void _triggerBarRecoil(double impulse) {
    _barRecoilController.animateWith(
      SpringSimulation(
        _barRecoilSpring,
        _barRecoilController.value,
        0.0,
        impulse.clamp(-4.0, 4.0).toDouble(),
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
    double barImpulse = distance * 2.0 + velocity * 0.4;
    if (distance.abs() < 0.12 && velocity.abs() < 1.2) {
      if (targetIndex == 0) {
        velocity = -2.6;
        barImpulse = -2.8;
      } else if (targetIndex == maxIdx) {
        velocity = 2.6;
        barImpulse = 2.8;
      } else {
        velocity = distance >= 0 ? 2.0 : -2.0;
        barImpulse = distance >= 0 ? 2.2 : -2.2;
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
    _triggerBarRecoil(barImpulse);
  }

  @override
  void dispose() {
    _controller.dispose();
    _lensController.dispose();
    _barRecoilController.dispose();
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
                if (!_isDragging) {
                  _swellDownWithBounce();
                  _triggerBarRecoil(0.0);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _isDragging = true;
                  _controller.stop();
                  _barRecoilController.stop();
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
                  _barRecoilController.value =
                      (_barRecoilController.value * 0.82 + step * 1.2)
                          .clamp(-0.55, 0.55)
                          .toDouble();
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
                child: AnimatedBuilder(
                  animation: _barRecoilController,
                  builder: (context, barChild) {
                    final recoil = _barRecoilController.value
                        .clamp(-0.75, 0.75)
                        .toDouble();
                    return Transform.translate(
                      offset: Offset(recoil * 6.5, 0),
                      child: Transform.scale(
                        scaleX: 1.0 + recoil.abs() * 0.025,
                        scaleY: 1.0 - recoil.abs() * 0.014,
                        child: barChild,
                      ),
                    );
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
                          padding: const EdgeInsets.symmetric(horizontal: padH),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _WaterDropletPillPainter(
                                position: _controller,
                                lensSwell: _lensController,
                                itemCount: count,
                                baseHeight: 40,
                                maxExpandedHeight: 54,
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                      ? ClearTokColors.neonPink.withValues(alpha: .55)
                      : Colors.white.withValues(alpha: .28),
                  width: 0.95,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                  colors: primary
                      ? [
                          Colors.white.withValues(alpha: .22),
                          ClearTokColors.neonPink.withValues(alpha: .26),
                          const Color(0xFF3A0D1E).withValues(alpha: .68),
                        ]
                      : [
                          Colors.white.withValues(alpha: .20),
                          Colors.white.withValues(alpha: .06),
                          ClearTokColors.dockGlass.withValues(alpha: .72),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: primary ? .18 : .10),
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
