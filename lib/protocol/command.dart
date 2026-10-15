import 'dart:typed_data';

/// 线上 App 实际使用的 **32 条 V3 指令**（V2 编码路径已删除，见报告 §2）。
///
/// [jni] 是报告 §6.1 表格里的 JNI 方法名，[label] 是其中文名
/// （灯类 12 条与场景类 5 条有 APK 文案证据，风扇/浴霸类 15 条为按符号直译的推断名）。
enum Command {
  binding('Binding', '配对 / 解除配对'),
  lampOnOff('LampOnOff', '主灯开关'),
  aidOnOff('AidOnOff', '辅助灯开关'),
  dimming('Dimming', '色温调节'),
  dimmingNight('DimmingNight', '夜灯模式'),
  rgbOnOff('RgbOnOff', '彩灯开关'),
  rgbAuto('RgbAuto', '彩灯循环'),
  rgbSwitch('RgbSwitch', '彩灯颜色设定'),
  fanMode('FanMode', '风扇模式'),
  fanSpeed('FanSpeed', '风扇档位 / 风量'),
  fanSwayOnOff('FanSwayOnOff', '风扇摆风'),
  windDirOnOff('WindDircOnOff', '导风板'),
  warmOnOff('WarmOnOff', '暖风 / 制热'),
  ventilation('Ventilation', '通风换气'),
  swingOnOff('SwingOnOff', '左右扫风'),
  dryOnOff('DryOnOff', '烘干 / 干衣'),
  bathOnOff('BathOnOff', '浴霸开关'),
  temperature('Temperature', '温度设定'),
  timingClose('TimingClose', '定时关闭'),
  genericOnOff('GenericOnOff', '通用开关'),
  sceneSet('SceneSet', '场景保存'),
  sceneSwitch('SceneSwitch', '场景切换'),
  sceneReset('SceneReset', '场景复位'),
  sceneOn('SceneOn', '启用场景'),
  aidBrightness('AidBrigntness', '辅助灯亮度'),
  aidSpeed('AidSpeed', '辅助风速档位'),
  aidPotUp('AidPotUP', '档位 +1'),
  aidPotDown('AidPotDown', '档位 −1'),
  aidPotAuto('AidPotAuto', '档位自动'),
  aidPotEdit('AidPotEdit', '档位直接设定'),
  rgbModeUp('AidRgbModeUp', '彩灯模式 下一个'),
  rgbModeDown('AidRgbModeDown', '彩灯模式 上一个');

  const Command(this.jni, this.label);

  /// 报告 §6.1 里的 JNI 方法名。
  final String jni;

  /// 中文名称。
  final String label;
}

/// 指令号（帧的 `b18..b19`，u16 LE）。
///
/// 四条开关类指令用 `on` 在两个 cmd 之间切换，其余是固定常量
/// （报告 §6.1「cmd 字节」列）。
int cmdOf(Command c, {required bool on}) {
  return switch (c) {
    Command.binding => on ? 0x28 : 0x45,
    Command.lampOnOff => on ? 0x10 : 0x11,
    Command.aidOnOff => on ? 0x12 : 0x13,
    Command.rgbAuto => on ? 0x1E : 0x1F,
    Command.dimming => 0x21,
    Command.dimmingNight => 0x23,
    Command.rgbOnOff => 0x1C,
    Command.rgbSwitch => 0x22,
    Command.fanMode => 0x33,
    Command.fanSpeed => 0x31,
    Command.fanSwayOnOff => 0x16,
    Command.windDirOnOff => 0x15,
    Command.warmOnOff => 0x66,
    Command.ventilation => 0x67,
    Command.swingOnOff => 0xB0,
    Command.dryOnOff => 0x69,
    Command.bathOnOff => 0x68,
    Command.temperature => 0x52,
    Command.timingClose => 0x41,
    Command.genericOnOff => 0x6F,
    Command.sceneSet => 0x46,
    Command.sceneSwitch => 0x47,
    Command.sceneReset => 0x48,
    Command.sceneOn => 0x10,
    Command.aidBrightness => 0x2E,
    Command.aidSpeed => 0xE4,
    Command.aidPotUp ||
    Command.aidPotDown ||
    Command.aidPotAuto ||
    Command.aidPotEdit => 0x2F,
    Command.rgbModeUp || Command.rgbModeDown => 0x1B,
  };
}

/// 扩展参数 `b20..b23`（4 字节）。
///
/// 全部取值来自报告 §6.1 的「扩展字段」列，与 `docs/reference-proto.py` 的
/// `_extra_bytes` 逐条一致；`z` 表示 `on`（1/0），未列出的字节恒 0。
Uint8List extraOf(
  Command c, {
  required bool on,
  int p4 = 0,
  int p5 = 0,
  int p6 = 0,
}) {
  final int z = on ? 1 : 0;
  final List<int> e = switch (c) {
    // b21 = z（cmd 固定，开关值写进扩展字节）
    Command.windDirOnOff ||
    Command.swingOnOff ||
    Command.dryOnOff ||
    Command.bathOnOff ||
    Command.genericOnOff => <int>[0, z, 0, 0],
    // b22 = p4, b23 = p5
    Command.dimming => <int>[0, 0, p4 & 0xFF, p5 & 0xFF],
    Command.rgbSwitch => <int>[0, p4 & 0xFF, p5 & 0xFF, p6 & 0xFF],
    Command.fanSpeed ||
    Command.warmOnOff ||
    Command.temperature => <int>[0, p4 & 0xFF, p5 & 0xFF, 0],
    // b21 = p4
    Command.rgbOnOff ||
    Command.fanSwayOnOff ||
    Command.fanMode ||
    Command.ventilation ||
    Command.sceneSet ||
    Command.sceneSwitch ||
    Command.sceneReset => <int>[0, p4 & 0xFF, 0, 0],
    // 秒数 / 档位数按 u16 小端拆到 b21、b22
    Command.timingClose => <int>[0, p4 & 0xFF, (p4 >> 8) & 0xFF, 0],
    Command.aidPotEdit => <int>[0, 2, p4 & 0xFF, (p4 >> 8) & 0xFF],
    // 固定值
    Command.aidBrightness => <int>[0, 3, p4 & 0xFF, 0],
    Command.aidSpeed => <int>[0, 0, p4 & 0xFF, 0],
    Command.aidPotUp => const <int>[0, 4, 0, 0],
    Command.aidPotDown => const <int>[0, 3, 0, 0],
    Command.aidPotAuto => const <int>[0, 1, 0, 0],
    Command.rgbModeUp => const <int>[0, 0, 0, 0],
    Command.rgbModeDown => const <int>[0, 1, 0, 0],
    Command.sceneOn => const <int>[0, 1, 0, 0],
    // 仅 cmd 随 on 变化，扩展字节恒 0
    Command.binding ||
    Command.dimmingNight ||
    Command.lampOnOff ||
    Command.aidOnOff ||
    Command.rgbAuto => const <int>[0, 0, 0, 0],
  };
  return Uint8List.fromList(e);
}
