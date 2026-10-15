import 'package:flutter/material.dart';

import '../state/lamp_controller.dart';
import 'app_scope.dart';
import 'theme.dart';
import 'tiles.dart';

/// 风扇灯 / 浴霸面板：档位、模式、摆风类开关，以及厂商库里另外那批风扇指令。
///
/// 报告 §6.3.3：这 15 条指令在原厂 App 的文案里从未出现、也从没被调用过，
/// 所以面板顶部常驻一条未验证警示。
class FanPanel extends StatefulWidget {
  const FanPanel({super.key});

  @override
  State<FanPanel> createState() => _FanPanelState();
}

class _FanPanelState extends State<FanPanel> {
  static const List<String> _modeNames = <String>['常风', '自然风', '睡眠'];

  int _gear = 0;
  int _mode = 0;
  bool _sway = false;
  bool _windDir = false;
  bool _swing = false;
  bool _dry = false;
  bool _bath = false;

  final TextEditingController _auxSpeed = TextEditingController(text: '1');
  final TextEditingController _pot = TextEditingController(text: '1');
  final TextEditingController _warmA = TextEditingController(text: '1');
  final TextEditingController _warmB = TextEditingController(text: '0');
  final TextEditingController _vent = TextEditingController(text: '1');
  final TextEditingController _tempA = TextEditingController(text: '25');
  final TextEditingController _tempB = TextEditingController(text: '1');

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _auxSpeed,
      _pot,
      _warmA,
      _warmB,
      _vent,
      _tempA,
      _tempB,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final LampController controller = AppScope.of(context).controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
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
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tickActive,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '以下指令未在真机验证，灯具可能无响应',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF3A2A08),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('档位'),
                    Expanded(
                      child: Slider(
                        value: _gear.toDouble(),
                        max: 12,
                        divisions: 12,
                        activeColor: accent,
                        label: _gear == 0 ? '关' : '$_gear 档',
                        onChanged: (double v) {
                          final int gear = v.round();
                          setState(() => _gear = gear);
                          controller.setFanGear(gear);
                        },
                        onChangeEnd: (double v) => controller.endGesture(),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        _gear == 0 ? '关' : '$_gear 档',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Text('模式'),
                    const SizedBox(width: 12),
                    for (int i = 0; i < _modeNames.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_modeNames[i]),
                          selected: _mode == i,
                          onSelected: (_) {
                            setState(() => _mode = i);
                            controller.setFanMode(i);
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TileGrid(
                  children: <Widget>[
                    ModeTile(
                      icon: Icons.airline_seat_recline_normal,
                      label: '摆风',
                      selected: _sway,
                      onTap: () {
                        setState(() => _sway = !_sway);
                        controller.setFanSway(_sway);
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
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('更多指令'),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: <Widget>[
                    _sendRow(
                      '辅助风速',
                      _auxSpeed,
                      'AidSpeed',
                      onSend: () => controller.setAuxSpeed(_int(_auxSpeed)),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.fanPotUp,
                            child: const Text('档位 +1'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.fanPotDown,
                            child: const Text('档位 −1'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.fanPotAuto,
                            child: const Text('档位自动'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _sendRow(
                      '档位直接设定',
                      _pot,
                      'AidPotEdit',
                      onSend: () => controller.setFanPot(_int(_pot)),
                    ),
                    _sendRow(
                      '通风档位',
                      _vent,
                      'Ventilation',
                      onSend: () => controller.sendVentilation(_int(_vent)),
                    ),
                    _sendRow2(
                      '暖风',
                      _warmA,
                      _warmB,
                      'WarmOnOff',
                      () => controller.sendWarm(_int(_warmA), _int(_warmB)),
                    ),
                    _sendRow2(
                      '温度',
                      _tempA,
                      _tempB,
                      'Temperature',
                      () =>
                          controller.setTemperature(_int(_tempA), _int(_tempB)),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _switchTile('烘干', _dry, () {
                            setState(() => _dry = !_dry);
                            controller.setDry(_dry);
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _switchTile('浴霸', _bath, () {
                            setState(() => _bath = !_bath);
                            controller.setBath(_bath);
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String label, bool value, VoidCallback onChanged) {
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(label),
        value: value,
        onChanged: (bool v) => onChanged(),
      ),
    );
  }

  Widget _sendRow(
    String label,
    TextEditingController controller,
    String command, {
    required VoidCallback onSend,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSend,
            child: Text('发送 $command', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// 两参数指令（`WarmOnOff` / `Temperature`）共用的行：两个输入框 + 发送。
  Widget _sendRow2(
    String label,
    TextEditingController first,
    TextEditingController second,
    String command,
    VoidCallback onSend,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: TextField(
              controller: first,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: second,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          TextButton(
            onPressed: onSend,
            child: Text('发送 $command', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
