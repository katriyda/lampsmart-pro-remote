import 'dart:typed_data';

import 'frame_transport.dart';

/// 非 Android 平台：可以看界面，但发不出帧。
///
/// Web Bluetooth 只有 central（主机）能力，没有广播 / peripheral 模式；
/// iOS 也不允许 App 自行发 ADV_IND。
class UnsupportedTransport implements FrameTransport {
  const UnsupportedTransport();

  static const String unsupportedMessage =
      'BLE 广播仅 Android 可用（iOS / 桌面 / 浏览器无法发送 ADV_IND）';

  @override
  String get platformLabel => unsupportedMessage;

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> send(
    Uint8List frame, {
    required int repeats,
    required int durationMs,
  }) async {
    throw UnsupportedError(unsupportedMessage);
  }

  @override
  Future<void> stop() async {}
}
