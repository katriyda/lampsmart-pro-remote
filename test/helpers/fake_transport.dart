import 'dart:typed_data';

import 'package:lampsmart/protocol/frame.dart';
import 'package:lampsmart/transport/frame_transport.dart';
import 'package:lampsmart/transport/transport_exception.dart';

/// 记录收到的帧，供状态层与 widget 测试断言。
class FakeTransport implements FrameTransport {
  FakeTransport({this.granted = true});

  /// 记录每次 send 的完整帧。
  final List<Uint8List> frames = <Uint8List>[];

  /// send 时抛出的异常（模拟平台失败）。
  Exception? failure;

  bool granted;

  /// 每次 send 的参数。
  int? lastRepeats;
  int? lastDurationMs;

  @override
  String get platformLabel => 'FakeTransport';

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> send(
    Uint8List frame, {
    required int repeats,
    required int durationMs,
  }) async {
    lastRepeats = repeats;
    lastDurationMs = durationMs;
    frames.add(Uint8List.fromList(frame));
    final Exception? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> stop() async {}

  bool get isEmpty => frames.isEmpty;

  Uint8List get last => frames.last;

  String get lastHex => bytesToHex(last);

  /// 末帧解出的 cmd。
  int get lastCmd => parseFrame(last)!['cmd'] as int;

  /// 末帧解出的扩展字节 `b20..b23`。
  List<int> get lastExtra => (parseFrame(last)!['extra'] as Uint8List).toList();

  /// 末帧解出的版本。
  String get lastVersion => parseFrame(last)!['version'] as String;
}

/// 构造一个带指定 code 的发送失败（模拟 Android `onStartFailure`）。
TransportException advertiseFailure([int code = 3]) =>
    TransportException('系统未能启动 BLE 广播', code);
