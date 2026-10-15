import 'package:flutter/material.dart';

import '../state/lamp_controller.dart';

import 'app_scope.dart';
import 'color_temp_page.dart';
import 'color_wheel.dart';
import 'dial.dart';
import 'theme.dart';

/// 彩灯面板：左旋钮 + 右色盘，与色温页同在一个 `PageView` 里，
/// 左右滑动切页对应 `AidRgbModeUp` / `AidRgbModeDown`。
class RgbPanel extends StatefulWidget {
  const RgbPanel({super.key});

  @override
  State<RgbPanel> createState() => _RgbPanelState();
}

class _RgbPanelState extends State<RgbPanel> {
  /// 协议里唯一可写的亮度指令是 `AidBrigntness`（原厂文案亦称「辅助灯亮度」），
  /// 彩灯亮度复用它。
  double _brightness = 0.6;
  Color _color = const Color(0xFFFF0000);
  int _whiteRatio = 100;
  bool _rgbPower = true;
  bool _rgbAuto = false;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: faintLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: PageView(
              onPageChanged: (int index) {
                final bool forward = index > _page;
                setState(() => _page = index);
                controller.cycleRgbMode(forward);
              },
              children: <Widget>[
                _colorPage(controller),
                ColorTempPage(
                  whiteRatio: _whiteRatio,
                  yellowRatio: 100 - _whiteRatio,
                  brightness: (_brightness * 100).round(),
                  onWhiteChanged: (int v) {
                    setState(() => _whiteRatio = v);
                    controller.setColorTempRatio(
                      v,
                      100 - v,
                      brightness: (_brightness * 100).round(),
                    );
                  },
                  onYellowChanged: (int v) {
                    setState(() => _whiteRatio = 100 - v);
                    controller.setColorTempRatio(
                      100 - v,
                      v,
                      brightness: (_brightness * 100).round(),
                    );
                  },
                  onChangeEnd: controller.endGesture,
                ),
              ],
            ),
          ),
          _footer(controller),
        ],
      ),
    );
  }

  Widget _colorPage(LampController controller) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            LampDial(
              value: _brightness,
              size: 150,
              subtitle: '彩灯亮度',
              onChanged: (double v) {
                setState(() => _brightness = v);
                controller.setAuxBrightness((v * 100).round());
              },
              onGestureStart: () {},
              onGestureEnd: controller.endGesture,
            ),
            ColorWheel(
              size: 170,
              color: _color,
              onChanged: (Color c) {
                setState(() => _color = c);
                controller.setRgbColor(
                  (c.r * 255).round(),
                  (c.g * 255).round(),
                  (c.b * 255).round(),
                );
              },
              onGestureStart: () {},
              onGestureEnd: controller.endGesture,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _presets(controller),
        const SizedBox(height: 8),
        const Text(
          '左旋钮 = 彩灯亮度（复用 AidBrigntness 指令），色盘拖动 = 直接设定颜色；'
          '左右滑动切到色温页会发彩灯模式切换指令。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _presets(LampController controller) {
    const List<Color> colors = <Color>[
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFF00),
      Color(0xFFFF00FF),
    ];
    const List<String> names = <String>['红', '绿', '蓝', '黄', '紫'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < colors.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Tooltip(
              message: '将彩灯颜色调为${names[i]}色',
              child: GestureDetector(
                onTap: () {
                  setState(() => _color = colors[i]);
                  controller.setRgbColor(
                    (colors[i].r * 255).round(),
                    (colors[i].g * 255).round(),
                    (colors[i].b * 255).round(),
                  );
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(LampController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 2; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? accent : faintLine,
                  ),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('彩灯'),
            value: _rgbPower,
            onChanged: (bool v) {
              setState(() => _rgbPower = v);
              controller.setRgbPower(v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('彩灯循环'),
            value: _rgbAuto,
            onChanged: (bool v) {
              setState(() => _rgbAuto = v);
              controller.setRgbAuto(v);
            },
          ),
        ],
      ),
    );
  }
}
