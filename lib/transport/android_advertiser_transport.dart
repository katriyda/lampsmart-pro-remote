import 'package:flutter/services.dart';

import '../protocol/frame.dart';
import 'frame_transport.dart';
import 'transport_exception.dart';

/// Android 实现：`MethodChannel('dev.katriyda.lampsmart/adv')`
/// 把 13 个 16-bit UUID 交给 `AdvertiserPlugin.kt` 塞进 `AdvertiseData`。
class AndroidAdvertiserTransport implements FrameTransport {
  static const MethodChannel channel = MethodChannel(
    'dev.katriyda.lampsmart/adv',
  );

  @override
  String get platformLabel => 'Android BLE 广播';

  @override
  Future<bool> ensurePermission() async {
    final Map<String, bool>? result = await channel
        .invokeMapMethod<String, bool>('ensurePermission');
    return result?['granted'] ?? false;
  }

  @override
  Future<void> send(
    Uint8List frame, {
    required int repeats,
    required int durationMs,
  }) async {
    final List<String> uuids = frameToUuids(frame);
    try {
      for (var i = 0; i < repeats; i++) {
        final bool? started = await channel.invokeMethod<bool>(
          'advertise',
          <String, Object>{'uuids': uuids, 'durationMs': durationMs},
        );
        if (started != true) {
          throw const TransportException('系统未能启动 BLE 广播（适配器不可用或被其它应用占用）');
        }
        await Future<void>.delayed(Duration(milliseconds: durationMs));
      }
    } on PlatformException catch (e) {
      throw TransportException(e.message ?? 'BLE 广播失败', e.code);
    } finally {
      await _stopQuietly();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      throw TransportException(e.message ?? '停止广播失败', e.code);
    }
  }

  Future<void> _stopQuietly() async {
    try {
      await channel.invokeMethod<void>('stop');
    } on PlatformException {
      // 停止失败不影响已经发出去的结果，忽略。
    }
  }
}
