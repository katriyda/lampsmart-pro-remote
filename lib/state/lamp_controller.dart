import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/command.dart';
import '../protocol/frame.dart';
import '../transport/frame_transport.dart';
import '../transport/transport_exception.dart';
import 'app_settings.dart';

/// 一条发送记录。
class FrameLogEntry {
  FrameLogEntry({
    required this.time,
    required this.label,
    required this.hex,
    required this.ok,
    this.error,
  });

  final DateTime time;
  final String label;
  final String hex;
  final bool ok;
  final String? error;
}

/// 状态 → 指令的唯一入口：每个动作对应**恰好一条**指令。
///
/// 全量 32 条指令的映射都在这里（README 的迁移对照表即本类的公开方法表），
/// 协议帧本身由 `lib/protocol/` 生成，这里只负责节流、日志与错误上报。
class LampController extends ChangeNotifier {
  LampController({required this.transport, required this.settings});

  /// 拖动类指令的节流窗口。
  static const Duration throttleWindow = Duration(milliseconds: 200);

  /// 帧日志上限。
  static const int logLimit = 50;

  /// 发送通道。
  final FrameTransport transport;

  /// 发送参数（seed / 计数 / 重发次数）。
  final AppSettings settings;

  final List<FrameLogEntry> _log = <FrameLogEntry>[];

  /// 最近一帧（可能是发送失败的）。
  Uint8List? lastFrame;

  /// 最近一次失败原因；成功发送后清空。
  String? lastError;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  List<FrameLogEntry> get log => List<FrameLogEntry>.unmodifiable(_log);

  /// 最近一帧拆出的 13 个 UUID。
  List<String> get lastFrameUuids =>
      lastFrame == null ? const <String>[] : frameToUuids(lastFrame!);

  /// 最近一帧的解帧结果。
  Map<String, dynamic>? get lastFrameInfo =>
      lastFrame == null ? null : parseFrame(lastFrame!);

  Future<bool> ensurePermission() async {
    _permissionGranted = await transport.ensurePermission();
    notifyListeners();
    return _permissionGranted;
  }

  // ------------------------------------------------------------ 灯类指令

  /// 发送通道名（界面展示用）。
  String get platformLabel => transport.platformLabel;

  /// 主灯开关（`LampOnOff`）。
  Future<void> setPower(bool on) => _send(Command.lampOnOff, on: on);

  /// 辅助灯开关（`AidOnOff`）。
  Future<void> setAuxPower(bool on) => _send(Command.aidOnOff, on: on);

  /// 色温调节（`Dimming`）：一次设定白光 / 黄光两路的实际亮度值。
  ///
  /// `white = brightness * whiteRatio / 100`，黄光同理（报告 §6.3.1 第 4 条）。
  Future<void> setBrightness(
    int brightness, {
    int whiteRatio = 100,
    int yellowRatio = 0,
  }) {
    final int white = (brightness * whiteRatio / 100).round().clamp(0, 255);
    final int yellow = (brightness * yellowRatio / 100).round().clamp(0, 255);
    return _throttled(
      () => _send(Command.dimming, on: true, p4: white, p5: yellow),
    );
  }

  /// 色温页：调整白光 / 黄光比例（互不牵连），仍发 `Dimming`。
  Future<void> setColorTempRatio(
    int whiteRatio,
    int yellowRatio, {
    required int brightness,
  }) {
    final int white = (brightness * whiteRatio / 100).round().clamp(0, 255);
    final int yellow = (brightness * yellowRatio / 100).round().clamp(0, 255);
    return _throttled(
      () => _send(Command.dimming, on: true, p4: white, p5: yellow),
    );
  }

  /// 夜灯模式（`DimmingNight`）。
  Future<void> setNightMode() => _send(Command.dimmingNight, on: true);

  /// 辅助灯亮度（`AidBrigntness`）。
  Future<void> setAuxBrightness(int value) => _throttled(
    () => _send(Command.aidBrightness, on: true, p4: value.clamp(0, 255)),
  );

  /// 彩灯开关（`RgbOnOff`，`p4` 是开关值）。
  Future<void> setRgbPower(bool on) =>
      _send(Command.rgbOnOff, on: on, p4: on ? 1 : 0);

  /// 彩灯循环（`RgbAuto`）。
  Future<void> setRgbAuto(bool on) => _send(Command.rgbAuto, on: on);

  /// 彩灯颜色（`RgbSwitch`，三通道值）。
  Future<void> setRgbColor(int r, int g, int b) =>
      _throttled(() => _send(Command.rgbSwitch, on: true, p4: r, p5: g, p6: b));

  /// 彩灯模式切换（`AidRgbModeUp` / `AidRgbModeDown`）。
  Future<void> cycleRgbMode(bool forward) =>
      _send(forward ? Command.rgbModeUp : Command.rgbModeDown, on: true);

  /// 定时关闭（`TimingClose`，秒数 0..65535，0 = 取消）。
  Future<void> setTimer(int seconds) =>
      _send(Command.timingClose, on: true, p4: seconds.clamp(0, 0xFFFF));

  // ------------------------------------------------------------ 场景类指令

  Future<void> setScene(int index) =>
      _send(Command.sceneSwitch, on: true, p4: index);
  Future<void> saveScene(int index) =>
      _send(Command.sceneSet, on: true, p4: index);
  Future<void> resetScene(int index) =>
      _send(Command.sceneReset, on: true, p4: index);
  Future<void> applyScene() => _send(Command.sceneOn, on: true);

  /// 通用开关（`GenericOnOff`）。
  Future<void> setGeneric(bool on) => _send(Command.genericOnOff, on: on);

  /// 配对 / 解除配对（`Binding`）。
  Future<void> bind() => _send(Command.binding, on: true);
  Future<void> unbind() => _send(Command.binding, on: false);

  // ------------------------------------------------------------ 风扇 / 浴霸类

  /// 风扇档位与风量（`FanSpeed`）；0 = 关（基于 `FanSpeed` 语义的最合理假设）。
  Future<void> setFanGear(int gear) {
    final int g = gear.clamp(0, 0xFF);
    return _throttled(() => _send(Command.fanSpeed, on: true, p4: g, p5: g));
  }

  /// 风扇模式（`FanMode`）。
  Future<void> setFanMode(int mode) =>
      _send(Command.fanMode, on: true, p4: mode);

  /// 风扇摆风（`FanSwayOnOff`）。
  Future<void> setFanSway(bool on) =>
      _send(Command.fanSwayOnOff, on: on, p4: on ? 1 : 0);

  /// 导风板（`WindDircOnOff`）。
  Future<void> setWindDir(bool on) => _send(Command.windDirOnOff, on: on);

  /// 左右扫风（`SwingOnOff`）。
  Future<void> setSwing(bool on) => _send(Command.swingOnOff, on: on);

  /// 暖风 / 制热（`WarmOnOff`）。
  Future<void> sendWarm(int p4, int p5) =>
      _send(Command.warmOnOff, on: true, p4: p4, p5: p5);

  /// 通风换气（`Ventilation`）。
  Future<void> sendVentilation(int gear) =>
      _send(Command.ventilation, on: true, p4: gear);

  /// 烘干（`DryOnOff`）。
  Future<void> setDry(bool on) => _send(Command.dryOnOff, on: on);

  /// 浴霸（`BathOnOff`）。
  Future<void> setBath(bool on) => _send(Command.bathOnOff, on: on);

  /// 温度设定（`Temperature`）。
  Future<void> setTemperature(int p4, int p5) =>
      _send(Command.temperature, on: true, p4: p4, p5: p5);

  /// 辅助风路档位（`AidSpeed`）。
  Future<void> setAuxSpeed(int gear) =>
      _send(Command.aidSpeed, on: true, p4: gear);

  Future<void> fanPotUp() => _send(Command.aidPotUp, on: true);
  Future<void> fanPotDown() => _send(Command.aidPotDown, on: true);
  Future<void> fanPotAuto() => _send(Command.aidPotAuto, on: true);

  /// 档位直接设定（`AidPotEdit`）。
  Future<void> setFanPot(int gear) =>
      _send(Command.aidPotEdit, on: true, p4: gear);

  // ------------------------------------------------------------ 调试出口

  /// 原始指令发送器用的通用出口。
  Future<void> sendRaw(
    Command command, {
    bool on = false,
    int p4 = 0,
    int p5 = 0,
    int p6 = 0,
  }) => _send(command, on: on, p4: p4, p5: p5, p6: p6);

  /// 手势结束：把节流窗口内攒下的最后一帧发出去。
  Future<void> endGesture() {
    _lastThrottledAt = null;
    final Future<void> Function()? pending = _pendingThrottled;
    _pendingThrottled = null;
    return pending == null ? Future<void>.value() : pending();
  }

  // ------------------------------------------------------------ 内部

  DateTime? _lastThrottledAt;
  Future<void> Function()? _pendingThrottled;
  Future<void> _tail = Future<void>.value();

  /// 拖动类指令：窗口内只记下最新的一帧，窗口外立即发送。
  Future<void> _throttled(Future<void> Function() action) {
    _pendingThrottled = action;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastThrottledAt;
    if (last != null && now.difference(last) < throttleWindow) {
      return Future<void>.value();
    }
    _lastThrottledAt = now;
    final Future<void> Function()? pending = _pendingThrottled;
    _pendingThrottled = null;
    return pending!();
  }

  Future<void> _send(
    Command command, {
    required bool on,
    int p4 = 0,
    int p5 = 0,
    int p6 = 0,
  }) {
    // 帧同步构造：tx_count 严格递增，也不会与上一帧的发送重叠。
    final Uint8List frame = buildFrame(
      command,
      on: on,
      var1: settings.var1,
      var2: settings.var2,
      var3: settings.var3,
      p4: p4,
      p5: p5,
      p6: p6,
      seed: settings.seed,
      txCount: settings.consumeTxCount(),
    );
    lastFrame = frame;
    _tail = _tail.then((_) => _transmit(command, frame));
    return _tail;
  }

  Future<void> _transmit(Command command, Uint8List frame) async {
    final String label = '${command.jni}（${command.label}）';
    final String hex = bytesToHex(frame);
    try {
      await transport.send(
        frame,
        repeats: settings.repeats,
        durationMs: settings.durationMs,
      );
      lastError = null;
      _append(
        FrameLogEntry(time: DateTime.now(), label: label, hex: hex, ok: true),
      );
    } on UnsupportedError catch (e) {
      lastError = e.message?.toString() ?? '当前平台不支持 BLE 广播';
      _append(
        FrameLogEntry(
          time: DateTime.now(),
          label: label,
          hex: hex,
          ok: false,
          error: lastError,
        ),
      );
    } on TransportException catch (e) {
      lastError = e.message;
      _append(
        FrameLogEntry(
          time: DateTime.now(),
          label: label,
          hex: hex,
          ok: false,
          error: e.message,
        ),
      );
    }
    notifyListeners();
  }

  void _append(FrameLogEntry entry) {
    _log.insert(0, entry);
    if (_log.length > logLimit) {
      _log.removeRange(logLimit, _log.length);
    }
  }

  void clearError() {
    if (lastError == null) {
      return;
    }
    lastError = null;
    notifyListeners();
  }
}
