import 'dart:typed_data';

/// 帧发送通道：把一条 31 字节控制帧以 BLE Legacy 广播（ADV_IND）的形式发出去。
///
/// 协议是**单向广播**：灯具只监听、不建连，所以这里只有发送、没有连接与订阅。
abstract class FrameTransport {
  /// 界面展示用的通道名。
  String get platformLabel;

  /// 申请 / 查询发送广播所需的权限。返回是否已授权。
  Future<bool> ensurePermission();

  /// 发送一帧：[repeats] 次，每次持续 [durationMs] 毫秒。
  ///
  /// 失败时抛 [TransportException]。
  Future<void> send(
    Uint8List frame, {
    required int repeats,
    required int durationMs,
  });

  /// 立刻停止广播。
  Future<void> stop();
}
