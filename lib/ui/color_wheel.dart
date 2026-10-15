import 'dart:math' as math;

import 'package:flutter/material.dart';

/// HSV 色盘：六扇形 `SweepGradient` + 白色圆心叠画，指示点跟随拖动。
class ColorWheel extends StatelessWidget {
  const ColorWheel({
    super.key,
    required this.size,
    required this.color,
    required this.onChanged,
    required this.onGestureStart,
    required this.onGestureEnd,
  });

  final double size;
  final Color color;
  final ValueChanged<Color> onChanged;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;

  @override
  Widget build(BuildContext context) {
    final double radius = size / 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (DragStartDetails details) {
        onGestureStart();
        onChanged(_colorAt(details.localPosition, radius));
      },
      onPanUpdate: (DragUpdateDetails details) =>
          onChanged(_colorAt(details.localPosition, radius)),
      onPanEnd: (DragEndDetails details) => onGestureEnd(),
      onPanCancel: onGestureEnd,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ColorWheelPainter(color: color)),
      ),
    );
  }

  static Color _colorAt(Offset local, double radius) {
    final Offset center = Offset(radius, radius);
    final Offset delta = local - center;
    final double distance = delta.distance.clamp(0.0, radius);
    final double hue =
        (math.atan2(delta.dy, delta.dx) + math.pi / 2) * 180 / math.pi;
    final double sat = (distance / radius).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1, (hue + 360) % 360, sat, 1).toColor();
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: <Color>[
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[Colors.white, Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );

    // 指示点：由颜色反推色相与饱和度。
    final HSVColor hsv = HSVColor.fromColor(color);
    final double hueRad = (hsv.hue - 90) * math.pi / 180;
    final double sat = hsv.saturation.clamp(0.0, 1.0);
    final Offset handle =
        center +
        Offset(math.cos(hueRad), math.sin(hueRad)) * (sat * radius * 0.96);
    canvas.drawCircle(handle, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      handle,
      6,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      handle,
      6,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ColorWheelPainter oldDelegate) =>
      oldDelegate.color != color;
}
