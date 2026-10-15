import 'package:flutter/foundation.dart';

import 'android_advertiser_transport.dart';
import 'frame_transport.dart';
import 'unsupported_transport.dart';

/// 按运行平台挑选发送通道。
///
/// 用 `package:flutter/foundation.dart` 的 [defaultTargetPlatform] 而不是
/// `dart:io` 的 `Platform`——后者在 `flutter build web` 时根本不存在。
FrameTransport createTransport() {
  return defaultTargetPlatform == TargetPlatform.android
      ? AndroidAdvertiserTransport()
      : const UnsupportedTransport();
}
