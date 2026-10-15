import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// 亮度滑杆行：左侧说明按钮 + 圆角轨道 + 手柄，右侧切换「主灯 / 辅助灯」目标。
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onToggleTarget,
    required this.auxiliary,
    required this.onHelp,
  });

  /// 0..1。
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;
  final VoidCallback onToggleTarget;

  /// 滑杆当前作用在辅助灯上。
  final bool auxiliary;

  /// 点左侧说明按钮。
  final VoidCallback onHelp;

  static const double trackHeight = 12;
  static const double handleRadius = 14;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: '这一项控制什么',
          onPressed: onHelp,
          icon: const Icon(Icons.info_outline),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (DragStartDetails details) =>
                    onChanged(_valueFor(details.localPosition.dx, width)),
                onHorizontalDragUpdate: (DragUpdateDetails details) =>
                    onChanged(_valueFor(details.localPosition.dx, width)),
                onHorizontalDragEnd: (DragEndDetails details) => onChangeEnd(),
                onHorizontalDragCancel: onChangeEnd,
                child: CustomPaint(
                  size: Size(width, 48),
                  painter: _SliderPainter(value.clamp(0.0, 1.0)),
                ),
              );
            },
          ),
        ),
        IconButton(
          tooltip: auxiliary ? '当前：辅助灯亮度' : '当前：主灯亮度',
          onPressed: onToggleTarget,
          icon: Icon(
            auxiliary ? Icons.brightness_4 : Icons.brightness_4_outlined,
            color: auxiliary ? tickActive : null,
          ),
        ),
      ],
    );
  }

  static double _valueFor(double dx, double width) {
    final double usable = math.max(1.0, width - handleRadius * 2);
    return ((dx - handleRadius) / usable).clamp(0.0, 1.0);
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double left = ValueSlider.handleRadius;
    final double right = size.width - ValueSlider.handleRadius;
    final double usable = math.max(1.0, right - left);
    final RRect track = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        0,
        centerY - ValueSlider.trackHeight / 2,
        size.width,
        centerY + ValueSlider.trackHeight / 2,
      ),
      const Radius.circular(ValueSlider.trackHeight / 2),
    );
    canvas.drawRRect(track, Paint()..color = surface);

    final double filled = left + usable * value;
    if (filled > left) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            centerY - ValueSlider.trackHeight / 2,
            filled,
            centerY + ValueSlider.trackHeight / 2,
          ),
          const Radius.circular(ValueSlider.trackHeight / 2),
        ),
        Paint()..color = accent,
      );
    }

    final Offset handle = Offset(filled, centerY);
    canvas.drawCircle(
      handle,
      ValueSlider.handleRadius,
      Paint()..color = Colors.white,
    );
    final Paint stripe = Paint()
      ..color = const Color(0x553A3F4A)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final double dx in <double>[-4, 0, 4]) {
      canvas.drawLine(handle + Offset(dx, -6), handle + Offset(dx, 6), stripe);
    }
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) => oldDelegate.value != value;
}
