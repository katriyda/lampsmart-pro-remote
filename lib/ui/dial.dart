import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 旋钮：270° 扫角（从 135° 顺时针到 45°），61 根刻度。
///
/// 拖动时把触点相对圆心的极角映射到 0..1（底部 90° 是死区，值被夹到两端）。
class LampDial extends StatelessWidget {
  const LampDial({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onGestureStart,
    required this.onGestureEnd,
    required this.subtitle,
    this.size = 240,
    this.warmth = 0,
  });

  /// 0..1。
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onGestureStart;
  final VoidCallback onGestureEnd;

  /// 中心大字下方的小字。
  final String subtitle;

  final double size;

  /// 色温：0 = 纯白光，1 = 全黄光（影响内盘渐变）。
  final double warmth;

  /// 起始角（画布坐标系里 y 向下，所以 135° 落在左下）。
  static const double startAngle = 3 * math.pi / 4;

  /// 扫角 270°。
  static const double sweepAngle = 3 * math.pi / 2;

  static const int tickCount = 61;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (DragStartDetails details) {
        onGestureStart();
        onChanged(_valueFor(details.localPosition, size));
      },
      onPanUpdate: (DragUpdateDetails details) {
        onChanged(_valueFor(details.localPosition, size));
      },
      onPanEnd: (DragEndDetails details) => onGestureEnd(),
      onPanCancel: onGestureEnd,
      child: Semantics(
        label: subtitle,
        value: '${(value * 100).round()}%',
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DialPainter(
              value: value.clamp(0.0, 1.0),
              subtitle: subtitle,
              warmth: warmth.clamp(0.0, 1.0),
            ),
          ),
        ),
      ),
    );
  }

  static double _valueFor(Offset local, double size) {
    final Offset center = Offset(size / 2, size / 2);
    final Offset delta = local - center;
    if (delta.distance < 1) {
      return 0;
    }
    double angle = math.atan2(delta.dy, delta.dx);
    if (angle < 0) {
      angle += 2 * math.pi;
    }
    double delta2 = (angle - startAngle) % (2 * math.pi);
    if (delta2 < 0) {
      delta2 += 2 * math.pi;
    }
    return (delta2 / sweepAngle).clamp(0.0, 1.0);
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.value,
    required this.subtitle,
    required this.warmth,
  });

  final double value;
  final String subtitle;
  final double warmth;

  static const Color _inactive = Color(0x22FFFFFF);
  static const Color _coreCenter = Color(0xFFFFFDF6);
  static const Color _coreWarm = Color(0xFFFFD08A);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 8;

    canvas.drawCircle(center, radius, Paint()..color = surfaceAlt);

    final double activeTicks = value * (LampDial.tickCount - 1);
    final Paint tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    for (var i = 0; i < LampDial.tickCount; i++) {
      final double angle =
          LampDial.startAngle +
          LampDial.sweepAngle * (i / (LampDial.tickCount - 1));
      final bool active = i <= activeTicks;
      tickPaint.color = active ? tickActive : _inactive;
      final double inner = radius * 0.86;
      final double outer = radius * (active ? 0.97 : 0.95);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    // 当前值指针
    final double pointerAngle =
        LampDial.startAngle + LampDial.sweepAngle * value;
    _paintPointer(canvas, center, radius, pointerAngle);

    // 内盘
    final double coreRadius = radius * 0.62;
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _coreCenter,
            Color.lerp(_coreCenter, _coreWarm, warmth)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );

    _paintText(canvas, center, coreRadius);
  }

  void _paintPointer(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    final Offset dir = Offset(math.cos(angle), math.sin(angle));
    final Offset tip = center + dir * (radius * 0.99);
    final Offset side = Offset(-dir.dy, dir.dx);
    final Offset base = center + dir * (radius * 0.80);
    final Path path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + side.dx * 7, base.dy + side.dy * 7)
      ..lineTo(base.dx - side.dx * 7, base.dy - side.dy * 7)
      ..close();
    canvas.drawPath(path, Paint()..color = tickActive);
  }

  void _paintText(Canvas canvas, Offset center, double coreRadius) {
    final TextPainter valuePainter = TextPainter(
      text: TextSpan(
        text: '${(value * 100).round()}%',
        style: const TextStyle(
          color: Color(0xFF3A3020),
          fontSize: 34,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valuePainter.paint(
      canvas,
      center - Offset(valuePainter.width / 2, valuePainter.height / 2 + 8),
    );

    final TextPainter subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: const TextStyle(color: Color(0xCC4A4030), fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subtitlePainter.paint(
      canvas,
      center -
          Offset(
            subtitlePainter.width / 2,
            coreRadius - 14 - subtitlePainter.height / 2,
          ),
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.subtitle != subtitle ||
      oldDelegate.warmth != warmth;
}
