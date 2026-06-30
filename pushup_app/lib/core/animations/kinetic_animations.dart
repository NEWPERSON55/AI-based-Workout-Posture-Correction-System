import 'dart:math';
import 'package:flutter/material.dart';

/// Fade + slide-up entrance animation using TweenAnimationBuilder.
/// No StatefulWidget needed.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offsetY = 30,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + delay,
      curve: curve,
      builder: (context, value, child) {
        // Clamp progress accounting for delay
        final delayFraction =
            delay.inMilliseconds / (duration + delay).inMilliseconds;
        final progress =
            ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Staggered animation for lists — each child fades+slides in
/// with an increasing delay.
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDuration;
  final Duration staggerDelay;
  final double offsetY;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const StaggeredList({
    super.key,
    required this.children,
    this.itemDuration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 80),
    this.offsetY = 24,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: List.generate(children.length, (i) {
        return FadeSlideIn(
          duration: itemDuration,
          delay: staggerDelay * i,
          offsetY: offsetY,
          child: children[i],
        );
      }),
    );
  }
}

/// Staggered Row variant for horizontal layouts.
class StaggeredRow extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDuration;
  final Duration staggerDelay;
  final MainAxisAlignment mainAxisAlignment;

  const StaggeredRow({
    super.key,
    required this.children,
    this.itemDuration = const Duration(milliseconds: 500),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: List.generate(children.length, (i) {
        return FadeSlideIn(
          duration: itemDuration,
          delay: staggerDelay * i,
          offsetY: 0,
          child: children[i],
        );
      }),
    );
  }
}

/// Scale-on-tap animation for interactive elements.
/// Uses TweenAnimationBuilder to avoid explicit controllers.
class ScaleOnTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleOnTapInner(
      onTap: onTap,
      scaleDown: scaleDown,
      child: child,
    );
  }
}

/// Inner widget that handles tap state via a minimal ValueNotifier approach.
class _ScaleOnTapInner extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const _ScaleOnTapInner({
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  @override
  State<_ScaleOnTapInner> createState() => _ScaleOnTapInnerState();
}

class _ScaleOnTapInnerState extends State<_ScaleOnTapInner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Pulsing glow effect that loops forever (for emphasis on key elements).
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxBlur;
  final Duration duration;

  const PulseGlow({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF8EFF71),
    this.maxBlur = 20,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blur = widget.maxBlur * (0.4 + 0.6 * _controller.value);
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.15 + 0.15 * _controller.value,
                ),
                blurRadius: blur,
                spreadRadius: blur * 0.2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated counter that tweens between old and new numeric values.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Text('$val', style: style);
      },
    );
  }
}

/// Animated progress bar that sweeps from 0 to target width.
class AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;
  final Duration duration;
  final bool showGlow;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 4,
    this.duration = const Duration(milliseconds: 1000),
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: val,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: showGlow
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated circular ring indicator that sweeps from 0 to target progress.
class AnimatedRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color? secondaryColor;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration duration;

  const AnimatedRing({
    super.key,
    required this.progress,
    required this.color,
    this.secondaryColor,
    this.size = 96,
    this.strokeWidth = 8,
    this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, ch) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _AnimatedRingPainter(
              val,
              color,
              secondaryColor,
              strokeWidth,
            ),
            child: ch,
          ),
        );
      },
      child: child != null ? Center(child: child) : null,
    );
  }
}

class _AnimatedRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color? secondaryColor;
  final double strokeWidth;

  _AnimatedRingPainter(
      this.progress, this.color, this.secondaryColor, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 2
        ..color = color.withValues(alpha: 0.1),
    );

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (secondaryColor != null) {
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [secondaryColor!, color],
      );
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = gradient.createShader(rect),
      );
    } else {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedRingPainter old) =>
      old.progress != progress;
}
