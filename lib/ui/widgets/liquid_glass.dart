import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.1,
                  colors: [
                    ClearTokColors.pink.withValues(alpha: .18),
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
                  radius: 1.1,
                  colors: [
                    ClearTokColors.cyan.withValues(alpha: .14),
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
            width: isSelected ? 1.1 : .8,
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
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: isSelected
                        ? ClearTokColors.pink
                        : Colors.white.withValues(alpha: .20),
                    width: isSelected ? 1.1 : .8,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.38, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      ClearTokColors.dockGlass.withValues(alpha: .58),
                      ClearTokColors.dockGlass.withValues(alpha: .72),
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
        color: ClearTokColors.dockGlass.withValues(alpha: 0.52),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.14),
            ClearTokColors.dockGlass.withValues(alpha: 0.50),
            ClearTokColors.dockGlass.withValues(alpha: 0.68),
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
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: box,
          ),
        ),
      ),
    );
  }
}

/// Crystal-clear water droplet painter that runs directly on the GPU canvas
/// via `super(repaint: controller)` without rebuilding any Widget tree!
class _WaterDropletPillPainter extends CustomPainter {
  final Animation<double> position;
  final int itemCount;
  final double baseHeight;
  final double Function() getStartPos;
  final double Function() getTargetPos;
  final double Function() getDragVelocity;
  final bool Function() getIsDragging;

  _WaterDropletPillPainter({
    required this.position,
    required this.itemCount,
    required this.baseHeight,
    required this.getStartPos,
    required this.getTargetPos,
    required this.getDragVelocity,
    required this.getIsDragging,
  }) : super(repaint: position);

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0 || size.width <= 0) return;
    final itemWidth = size.width / itemCount;
    final maxIdx = math.max(0, itemCount - 1).toDouble();
    final pos = position.value.clamp(0.0, maxIdx).toDouble();
    final startPos = getStartPos();
    final targetPos = getTargetPos();
    final isDragging = getIsDragging();
    final travel = (targetPos - startPos).abs();

    double flightStretch = 0.0;
    if (!isDragging && travel > 0.02) {
      final t = ((pos - startPos) / (targetPos - startPos))
          .clamp(0.0, 1.0)
          .toDouble();
      flightStretch = math.sin(t * math.pi) * (travel.clamp(0.5, 1.8) * 0.36);
    }
    final dragStretch = isDragging
        ? (getDragVelocity().abs() * 0.32).clamp(0.0, 0.38).toDouble()
        : 0.0;
    final stretch = math.max(flightStretch, dragStretch);

    final pillW = itemWidth * (1.0 + stretch);
    final pillH = baseHeight * (1.0 - stretch * 0.09);
    final centerX = (pos + 0.5) * itemWidth;
    final left = (centerX - pillW / 2)
        .clamp(0.0, math.max(0.0, size.width - pillW))
        .toDouble();
    final top = (size.height - pillH) / 2;

    final rect = Rect.fromLTWH(left, top, pillW, pillH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(pillH / 2));

    // 1. Subtle caustic water shadow under the droplet
    final shadowPaint = Paint()
      ..color = ClearTokColors.neonCyan.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    // 2. Crystal-clear water droplet body (transparent center, refractive edges)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.26, 0.68, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.03),
          ClearTokColors.neonCyan.withValues(alpha: 0.14),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Top meniscus specular highlight (vầng sáng khúc xạ đỉnh giọt nước)
    final glossRect = Rect.fromLTWH(
      left + pillW * 0.10,
      top + 1.5,
      pillW * 0.80,
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
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(glossRect);
    canvas.drawRRect(glossRRect, glossPaint);

    // 4. Crisp water surface tension rim (viền căng bề mặt giọt nước)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.5, 1.0],
        colors: [
          Colors.white.withValues(alpha: 0.58),
          Colors.white.withValues(alpha: 0.18),
          ClearTokColors.neonCyan.withValues(alpha: 0.42),
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _startPos = 0.0;
  double _targetPos = 0.0;
  double _dragVelocity = 0.0;
  bool _isDragging = false;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 360.0,
    damping: 26.0,
  );

  @override
  void initState() {
    super.initState();
    _startPos = widget.selectedIndex.toDouble();
    _targetPos = _startPos;
    _controller = AnimationController.unbounded(
      value: _startPos,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant GBoxLiquidDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_isDragging) {
      _animateTo(widget.selectedIndex.toDouble());
    }
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    _startPos = _controller.value;
    _targetPos = target;
    _dragVelocity = 0.0;
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      velocity,
      tolerance: const Tolerance(distance: 0.002, velocity: 0.01),
    );
    _controller.animateWith(simulation);
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop();
    _startPos = _controller.value;
  }

  void _handleDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (itemWidth <= 0) return;
    final delta = details.primaryDelta ?? 0.0;
    final step = delta / itemWidth;
    final maxIdx = (widget.items.length - 1).toDouble();
    _dragVelocity = (step * 14.0).clamp(-1.5, 1.5).toDouble();
    _controller.value = (_controller.value + step).clamp(0.0, maxIdx).toDouble();
  }

  void _handleDragEnd(DragEndDetails details, double itemWidth) {
    _isDragging = false;
    final maxIdx = widget.items.length - 1;
    final vx = itemWidth > 0
        ? (details.primaryVelocity ?? 0.0) / itemWidth
        : 0.0;
    int nextIndex = _controller.value.round().clamp(0, maxIdx);
    if (vx.abs() > 1.8) {
      nextIndex = (vx > 0 ? _controller.value.ceil() : _controller.value.floor())
          .clamp(0, maxIdx);
    }
    _animateTo(nextIndex.toDouble(), velocity: vx.clamp(-6.0, 6.0).toDouble());
    if (nextIndex != widget.selectedIndex) {
      widget.onTabSelected(nextIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: (d) => _handleDragUpdate(d, itemWidth),
                onHorizontalDragEnd: (d) => _handleDragEnd(d, itemWidth),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Layer 1: Static Frosted Liquid Glass Background
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
                              itemCount: count,
                              baseHeight: 52,
                              getStartPos: () => _startPos,
                              getTargetPos: () => _targetPos,
                              getDragVelocity: () => _dragVelocity,
                              getIsDragging: () => _isDragging,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Layer 3: Interactive Tab Items
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _animateTo(idx.toDouble());
                                widget.onTabSelected(idx);
                              },
                              child: SizedBox(
                                height: 52,
                                child: AnimatedScale(
                                  scale: isSelected ? 1.07 : 1.0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                              ? Colors.white
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
                          );
                        }),
                      ),
                    ),
                  ],
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _startPos = 0.0;
  double _targetPos = 0.0;
  double _dragVelocity = 0.0;
  bool _isDragging = false;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 360.0,
    damping: 26.0,
  );

  @override
  void initState() {
    super.initState();
    _startPos = widget.selectedIndex.toDouble();
    _targetPos = _startPos;
    _controller = AnimationController.unbounded(
      value: _startPos,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant GBoxSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_isDragging) {
      _animateTo(widget.selectedIndex.toDouble());
    }
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    _startPos = _controller.value;
    _targetPos = target;
    _dragVelocity = 0.0;
    final simulation = SpringSimulation(
      _spring,
      _controller.value,
      target,
      velocity,
      tolerance: const Tolerance(distance: 0.002, velocity: 0.01),
    );
    _controller.animateWith(simulation);
  }

  @override
  void dispose() {
    _controller.dispose();
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

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _isDragging = true;
                _controller.stop();
                _startPos = _controller.value;
              },
              onHorizontalDragUpdate: (d) {
                if (itemWidth <= 0) return;
                final step = (d.primaryDelta ?? 0.0) / itemWidth;
                _dragVelocity = (step * 14.0).clamp(-1.5, 1.5).toDouble();
                _controller.value = (_controller.value + step)
                    .clamp(0.0, (count - 1).toDouble())
                    .toDouble();
              },
              onHorizontalDragEnd: (d) {
                _isDragging = false;
                final nextIdx = _controller.value.round().clamp(0, count - 1);
                _animateTo(nextIdx.toDouble());
                if (nextIdx != widget.selectedIndex) {
                  widget.onSegmentSelected(nextIdx);
                }
              },
              child: Stack(
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
                            itemCount: count,
                            baseHeight: 40,
                            getStartPos: () => _startPos,
                            getTargetPos: () => _targetPos,
                            getDragVelocity: () => _dragVelocity,
                            getIsDragging: () => _isDragging,
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _animateTo(idx.toDouble());
                              widget.onSegmentSelected(idx);
                            },
                            child: SizedBox(
                              height: 40,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                        );
                      }),
                    ),
                  ),
                ],
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
                width: .9,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 1.0],
                colors: primary
                    ? [
                        Colors.white.withValues(alpha: .22),
                        ClearTokColors.neonPink.withValues(alpha: .26),
                        const Color(0xFF3A0D1E).withValues(alpha: .65),
                      ]
                    : [
                        Colors.white.withValues(alpha: .20),
                        Colors.white.withValues(alpha: .06),
                        ClearTokColors.dockGlass.withValues(alpha: .68),
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
    );
  }
}
