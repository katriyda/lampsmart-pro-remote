import 'package:flutter/material.dart';

import '../data/device_models.dart';
import '../state/lamp_controller.dart';
import 'app_scope.dart';
import 'debug_page.dart';
import 'dial.dart';
import 'fan_panel.dart';
import 'rgb_panel.dart';
import 'theme.dart';
import 'tiles.dart';
import 'value_slider.dart';

/// 打开设备控制弹窗。
Future<void> showDeviceSheet(
  BuildContext context, {
  required Room room,
  required Device device,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) =>
        _DeviceSheet(room: room, device: device),
  );
}

class _DeviceSheet extends StatefulWidget {
  const _DeviceSheet({required this.room, required this.device});

  final Room room;
  final Device device;

  @override
  State<_DeviceSheet> createState() => _DeviceSheetState();
}

class _DeviceSheetState extends State<_DeviceSheet> {
  double _brightness = 0.6;
  int _whiteRatio = 100;
  bool _power = false;
  bool _auxPower = false;
  bool _rgbAuto = false;
  bool _fanSway = false;
  bool _windDir = false;
  bool _swing = false;
  bool _auxTarget = false;

  int get _brightnessValue => (_brightness * 100).round().clamp(0, 255);

  void _applyBrightness(double value) {
    setState(() => _brightness = value.clamp(0.0, 1.0));
    final controller = AppScope.of(context).controller;
    if (_auxTarget) {
      controller.setAuxBrightness(_brightnessValue);
    } else {
      controller.setBrightness(
        _brightnessValue,
        whiteRatio: _whiteRatio,
        yellowRatio: 100 - _whiteRatio,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LampController controller = AppScope.of(context).controller;
    final Device device = widget.device;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${widget.room.name} · ${device.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LampDial(
                          value: _brightness,
                          subtitle: _auxTarget ? '辅助灯亮度' : '主灯亮度',
                          warmth: (100 - _whiteRatio) / 100,
                          onChanged: _applyBrightness,
                          onGestureStart: () {},
                          onGestureEnd: controller.endGesture,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueSlider(
                    value: _brightness,
                    auxiliary: _auxTarget,
                    onChanged: _applyBrightness,
                    onChangeEnd: controller.endGesture,
                    onToggleTarget: () =>
                        setState(() => _auxTarget = !_auxTarget),
                    onHelp: () => _showHelp(
                      '亮度滑杆',
                      '拖动或旋转上面的旋钮都能调亮度，数值范围 0..255。'
                          '右侧图标切换滑杆作用对象：主灯亮度发 Dimming 指令（带白光 / 黄光比例），'
                          '辅助灯亮度发 AidBrigntness 指令。\n\n手势结束时会补发最后一帧。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TileGrid(children: _buildTiles(device, controller)),
                ],
              ),
            ),
          ),
          _bottomBar(controller),
        ],
      ),
    );
  }

  List<Widget> _buildTiles(Device device, LampController controller) {
    final List<Widget> tiles = <Widget>[
      ModeTile(
        icon: Icons.light_mode,
        label: '白光',
        selected: _whiteRatio == 100 && _brightness >= 0.99,
        onTap: () {
          setState(() {
            _brightness = 1;
            _whiteRatio = 100;
          });
          controller.setBrightness(100, whiteRatio: 100, yellowRatio: 0);
          controller.endGesture();
        },
      ),
      ModeTile(
        icon: Icons.wb_sunny_outlined,
        label: '黄光',
        selected: _whiteRatio == 0 && _brightness >= 0.99,
        onTap: () {
          setState(() {
            _brightness = 1;
            _whiteRatio = 0;
          });
          controller.setBrightness(100, whiteRatio: 0, yellowRatio: 100);
          controller.endGesture();
        },
      ),
      ModeTile(
        icon: Icons.nightlight_round,
        label: '夜灯',
        onTap: controller.setNightMode,
      ),
      if (device.type.hasRgb)
        ModeTile(
          icon: Icons.palette_outlined,
          label: '彩灯',
          onTap: () async {
            await controller.setRgbPower(true);
            if (!mounted) {
              return;
            }
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext sheetContext) => const RgbPanel(),
            );
          },
        ),
      ModeTile(
        icon: Icons.lightbulb_outline,
        label: '主灯',
        selected: _power,
        onTap: () {
          setState(() => _power = !_power);
          controller.setPower(_power);
        },
      ),
      ModeTile(
        icon: Icons.timer_outlined,
        label: '定时',
        onTap: () => _timerSheet(controller),
      ),
      if (device.type.hasRgb)
        ModeTile(
          icon: Icons.autorenew,
          label: '循环',
          selected: _rgbAuto,
          onTap: () {
            setState(() => _rgbAuto = !_rgbAuto);
            controller.setRgbAuto(_rgbAuto);
          },
        ),
      ModeTile(
        icon: Icons.lightbulb,
        label: '辅助灯',
        selected: _auxPower,
        onTap: () {
          setState(() => _auxPower = !_auxPower);
          controller.setAuxPower(_auxPower);
        },
      ),
      if (device.type.hasFan) ...<Widget>[
        ModeTile(
          icon: Icons.toys_outlined,
          label: '风扇',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext sheetContext) => const FanPanel(),
          ),
        ),
        ModeTile(
          icon: Icons.airline_seat_recline_normal,
          label: '摆风',
          selected: _fanSway,
          onTap: () {
            setState(() => _fanSway = !_fanSway);
            controller.setFanSway(_fanSway);
          },
        ),
        ModeTile(
          icon: Icons.vertical_align_center,
          label: '导风',
          selected: _windDir,
          onTap: () {
            setState(() => _windDir = !_windDir);
            controller.setWindDir(_windDir);
          },
        ),
        ModeTile(
          icon: Icons.swap_horiz,
          label: '摇头',
          selected: _swing,
          onTap: () {
            setState(() => _swing = !_swing);
            controller.setSwing(_swing);
          },
        ),
      ],
    ];
    return tiles;
  }

  Widget _bottomBar(LampController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _power ? surface : accent,
                foregroundColor: _power
                    ? Colors.white
                    : const Color(0xFF06302A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                setState(() => _power = !_power);
                controller.setPower(_power);
              },
              child: Text(
                _power ? 'OFF' : 'ON',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: '原始指令调试',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const DebugPage(),
              ),
            ),
            icon: const Icon(Icons.terminal),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: surfaceAlt,
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _timerSheet(LampController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          _TimerSheet(onConfirm: (int seconds) => controller.setTimer(seconds)),
    );
  }
}

class _TimerSheet extends StatefulWidget {
  const _TimerSheet({required this.onConfirm});

  final ValueChanged<int> onConfirm;

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;

  @override
  Widget build(BuildContext context) {
    final int total = _hours * 3600 + _minutes * 60 + _seconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '定时关闭',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '到点后自动关灯；发送 0 秒即取消定时。',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _picker(
                  '时',
                  _hours,
                  0,
                  23,
                  (int v) => setState(() => _hours = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _picker(
                  '分',
                  _minutes,
                  0,
                  59,
                  (int v) => setState(() => _minutes = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _picker(
                  '秒',
                  _seconds,
                  0,
                  59,
                  (int v) => setState(() => _seconds = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onConfirm(0);
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消定时'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: total == 0
                      ? null
                      : () {
                          widget.onConfirm(total);
                          Navigator.of(context).pop();
                        },
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _picker(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<int>>[
        for (int v = min; v <= max; v++)
          DropdownMenuItem<int>(
            value: v,
            child: Text(v.toString().padLeft(2, '0')),
          ),
      ],
      onChanged: (int? v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }
}
