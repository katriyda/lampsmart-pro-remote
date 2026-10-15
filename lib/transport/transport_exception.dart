/// 发送失败（系统拒绝广播、无蓝牙适配器、权限被拒等）。
class TransportException implements Exception {
  const TransportException(this.message, [this.code]);

  final String message;

  /// 平台层返回的错误码：Android 侧可能是 `onStartFailure` 的整型，
  /// 也可能是 MethodChannel 的字符串错误码。
  final Object? code;

  @override
  String toString() => code == null
      ? 'TransportException: $message'
      : 'TransportException($code): $message';
}
