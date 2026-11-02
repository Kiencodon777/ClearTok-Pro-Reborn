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
            : Colors.white.withValues(alpha: .18),
        width: isSelected ? 1.1 : .8,
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
              width: .8,
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
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: gboxSquircleShape(borderRadius)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: borderShape,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      ClearTokColors.dockGlass.withValues(alpha: .62),
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
  const _StaticPillGlassBackdrop({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ClearTokColors.dockGlass.withValues(alpha: 0.55),
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    ClearTokColors.dockGlass.withValues(alpha: 0.55),
                    ClearTokColors.dockGlass.withValues(alpha: 0.68),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
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
    stiffness: 340.0,
    damping: 25.0,
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
    _dragVelocity = (step * 14.0).clamp(-1.5, 1.5);
    _controller.value = (_controller.value + step).clamp(0.0, maxIdx);
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
    _animateTo(nextIndex.toDouble(), velocity: vx.clamp(-6.0, 6.0));
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
                    // Layer 1: Static Frosted Liquid Glass Background (never rebuilds on animation)
                    const Positioned.fill(
                      child: _StaticPillGlassBackdrop(borderRadius: 31),
                    ),

                    // Layer 2: Dynamic Liquid Stretch Sliding Pill + Icons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: padH,
                        vertical: 5,
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final maxIdx = math.max(0, count - 1).toDouble();
                          final pos = _controller.value.clamp(0.0, maxIdx);
                          final travel = (_targetPos - _startPos).abs();
                          double flightStretch = 0.0;
                          if (!_isDragging && travel > 0.02) {
                            final t = ((pos - _startPos) /
                                    (_targetPos - _startPos))
                                .clamp(0.0, 1.0);
                            flightStretch =
                                math.sin(t * math.pi) *
                                (travel.clamp(0.5, 1.8) * 0.34);
                          }
                          final dragStretch = _isDragging
                              ? (_dragVelocity.abs() * 0.30).clamp(0.0, 0.36)
                              : 0.0;
                          final stretch = math.max(flightStretch, dragStretch);

                          final pillW = itemWidth * (1.0 + stretch);
                          final pillH = 52.0 * (1.0 - stretch * 0.08);
                          final centerX = (pos + 0.5) * itemWidth;
                          final left = (centerX - pillW / 2)
                              .clamp(0.0, math.max(0.0, trackWidth - pillW))
                              .toDouble();

                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned(
                                left: left,
                                width: pillW,
                                height: pillH,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        pillH / 2,
                                      ),
                                      border: Border.all(
                                        color: ClearTokColors.neonCyan
                                            .withValues(alpha: 0.42),
                                        width: 0.9,
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        stops: const [0.0, 0.55, 1.0],
                                        colors: [
                                          ClearTokColors.neonCyan.withValues(
                                            alpha: 0.18,
                                          ),
                                          ClearTokColors.neonPink.withValues(
                                            alpha: 0.22,
                                          ),
                                          ClearTokColors.neonCyan.withValues(
                                            alpha: 0.14,
                                          ),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ClearTokColors.neonPink
                                              .withValues(alpha: 0.24),
                                          blurRadius: 14,
                                          spreadRadius: 0.5,
                                        ),
                                        BoxShadow(
                                          color: ClearTokColors.neonCyan
                                              .withValues(alpha: 0.18),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: List.generate(count, (idx) {
                                  final item = widget.items[idx];
                                  final proximity = (1.0 - (pos - idx).abs())
                                      .clamp(0.0, 1.0)
                                      .toDouble();
                                  final isSelected = proximity > 0.55;
                                  final scale = 1.0 + (0.08 * proximity);
                                  final iconColor = Color.lerp(
                                    Colors.white.withValues(alpha: 0.50),
                                    ClearTokColors.neonCyan,
                                    proximity,
                                  )!;
                                  final textColor = Color.lerp(
                                    Colors.white.withValues(alpha: 0.50),
                                    Colors.white,
                                    proximity,
                                  )!;

                                  return Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        _animateTo(idx.toDouble());
                                        widget.onTabSelected(idx);
                                      },
                                      child: SizedBox(
                                        height: 52,
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              DecoratedBox(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: proximity > 0.35
                                                      ? [
                                                          BoxShadow(
                                                            color: ClearTokColors
                                                                .neonCyan
                                                                .withValues(
                                                                  alpha:
                                                                      0.32 *
                                                                      proximity,
                                                                ),
                                                            blurRadius: 10,
                                                          ),
                                                        ]
                                                      : const [],
                                                ),
                                                child: IconTheme.merge(
                                                  data: IconThemeData(
                                                    size: 20,
                                                    color: iconColor,
                                                  ),
                                                  child: isSelected
                                                      ? item.activeIcon
                                                      : item.icon,
                                                ),
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
                                                  color: textColor,
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
                            ],
                          );
                        },
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
  bool _isDragging = false;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
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
                _controller.value = (_controller.value + step).clamp(
                  0.0,
                  (count - 1).toDouble(),
                );
              },
              onHorizontalDragEnd: (d) {
                _isDragging = false;
                final nextIdx = _controller.value.round().clamp(0, count - 1);
                _animateTo(nextIdx.toDouble());
                if (nextIdx != widget.selectedIndex) {
                  widget.onSegmentSelected(nextIdx);
                }
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ClearTokColors.dockGlass.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(padH),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final maxIdx = math.max(0, count - 1).toDouble();
                      final pos = _controller.value.clamp(0.0, maxIdx);
                      final travel = (_targetPos - _startPos).abs();
                      double stretch = 0.0;
                      if (!_isDragging && travel > 0.02) {
                        final t = ((pos - _startPos) / (_targetPos - _startPos))
                            .clamp(0.0, 1.0);
                        stretch =
                            math.sin(t * math.pi) *
                            (travel.clamp(0.5, 1.6) * 0.28);
                      }
                      final pillW = itemWidth * (1.0 + stretch);
                      final pillH = 40.0 * (1.0 - stretch * 0.06);
                      final centerX = (pos + 0.5) * itemWidth;
                      final left = (centerX - pillW / 2)
                          .clamp(0.0, math.max(0.0, trackWidth - pillW))
                          .toDouble();

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Positioned(
                            left: left,
                            width: pillW,
                            height: pillH,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    pillH / 2,
                                  ),
                                  border: Border.all(
                                    color: ClearTokColors.neonCyan.withValues(
                                      alpha: 0.40,
                                    ),
                                    width: 0.8,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: const [0.0, 1.0],
                                    colors: [
                                      ClearTokColors.neonPink.withValues(
                                        alpha: 0.24,
                                      ),
                                      ClearTokColors.neonCyan.withValues(
                                        alpha: 0.16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(count, (idx) {
                              final seg = widget.segments[idx];
                              final proximity = (1.0 - (pos - idx).abs())
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                              final active = proximity > 0.55;
                              final scale = 1.0 + (0.05 * proximity);
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _animateTo(idx.toDouble());
                                    widget.onSegmentSelected(idx);
                                  },
                                  child: SizedBox(
                                    height: 40,
                                    child: Transform.scale(
                                      scale: scale,
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
                                              color: Color.lerp(
                                                Colors.white.withValues(
                                                  alpha: 0.50,
                                                ),
                                                ClearTokColors.neonCyan,
                                                proximity,
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
                                                  color: Color.lerp(
                                                    Colors.white.withValues(
                                                      alpha: 0.50,
                                                    ),
                                                    Colors.white,
                                                    proximity,
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
                              );
                            }),
                          ),
                        ],
                      );
                    },
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
