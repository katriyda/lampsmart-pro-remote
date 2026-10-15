import 'package:flutter/material.dart';

import 'theme.dart';

/// 色温页：白光比例 / 黄光比例两条独立滑杆（0..100，互不牵连）。
///
/// 任一变化都发 `Dimming`，比例乘以当前亮度得到两路的实际亮度值。
class ColorTempPage extends StatelessWidget {
  const ColorTempPage({
    super.key,
    required this.whiteRatio,
    required this.yellowRatio,
    required this.brightness,
    required this.onWhiteChanged,
    required this.onYellowChanged,
    required this.onChangeEnd,
  });

  final int whiteRatio;
  final int yellowRatio;

  /// 当前亮度 0..100。
  final int brightness;

  final ValueChanged<int> onWhiteChanged;
  final ValueChanged<int> onYellowChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: <Widget>[
        Text(
          '白光 $whiteRatio% · 黄光 $yellowRatio%',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '按亮度 $brightness% 换算后发送 Dimming',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _ratioRow('白光比例', whiteRatio, (int v) => onWhiteChanged(v)),
        const SizedBox(height: 8),
        _ratioRow('黄光比例', yellowRatio, (int v) => onYellowChanged(v)),
        const SizedBox(height: 16),
        const Text(
          '协议只有 Dimming 一条两路色温指令：b22 = 白光实际亮度、b23 = 黄光实际亮度，'
          '这里两条滑杆只改比例，实际亮度 = 比例 × 亮度。',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _ratioRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            max: 100,
            divisions: 100,
            activeColor: accent,
            label: '$value%',
            onChanged: (double v) => onChanged(v.round()),
            onChangeEnd: (double v) => onChangeEnd(),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
