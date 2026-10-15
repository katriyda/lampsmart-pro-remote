import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发送参数（`shared_preferences` 持久化）。
///
/// `var1` / `var2` / `var3` 在原 App 里传什么没有解出来（报告 附录 C），
/// 固件侧也不校验，所以默认全 0 并做成可配置——真机「不响应」时第一件事就是调它们。
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs, {Random? random}) : _random = random ?? Random();

  static const String keySeed = 'seed';
  static const String keyTxCount = 'txCount';
  static const String keyRepeats = 'repeats';
  static const String keyDurationMs = 'durationMs';
  static const String keyVar1 = 'var1';
  static const String keyVar2 = 'var2';
  static const String keyVar3 = 'var3';

  /// V3 的 `tx_count` 初值（报告 §4.3：V3 从 `0x10` 起，8 位回绕）。
  static const int initialTxCount = 0x10;
  static const int defaultRepeats = 3;
  static const int defaultDurationMs = 300;

  final SharedPreferences _prefs;
  final Random _random;

  int _seed = 0;
  int _txCount = initialTxCount;
  int _repeats = defaultRepeats;
  int _durationMs = defaultDurationMs;
  int _var1 = 0;
  int _var2 = 0;
  int _var3 = 0;

  int get seed => _seed;
  int get repeats => _repeats;
  int get durationMs => _durationMs;
  int get var1 => _var1;
  int get var2 => _var2;
  int get var3 => _var3;

  Future<void> load() async {
    final int? storedSeed = _prefs.getInt(keySeed);
    if (storedSeed == null) {
      _seed = _random.nextInt(0x10000); // 首次启动随机取一个，之后固定不变
      unawaited(_prefs.setInt(keySeed, _seed));
    } else {
      _seed = storedSeed & 0xFFFF;
    }
    _txCount = (_prefs.getInt(keyTxCount) ?? initialTxCount) & 0xFF;
    _repeats = _prefs.getInt(keyRepeats) ?? defaultRepeats;
    _durationMs = _prefs.getInt(keyDurationMs) ?? defaultDurationMs;
    _var1 = _prefs.getInt(keyVar1) ?? 0;
    _var2 = _prefs.getInt(keyVar2) ?? 0;
    _var3 = _prefs.getInt(keyVar3) ?? 0;
    notifyListeners();
  }

  /// 取下一个发送计数并自增（每次发帧调用一次，保证帧内 `b10` 与 AES 密钥一致）。
  int consumeTxCount() {
    final int value = _txCount & 0xFF;
    _txCount = (_txCount + 1) & 0xFF;
    unawaited(_prefs.setInt(keyTxCount, _txCount));
    return value;
  }

  void setSeed(int value) {
    _seed = value & 0xFFFF;
    unawaited(_prefs.setInt(keySeed, _seed));
    notifyListeners();
  }

  void setRepeats(int value) {
    _repeats = value.clamp(1, 5);
    unawaited(_prefs.setInt(keyRepeats, _repeats));
    notifyListeners();
  }

  void setDurationMs(int value) {
    _durationMs = value;
    unawaited(_prefs.setInt(keyDurationMs, _durationMs));
    notifyListeners();
  }

  void setVar1(int value) {
    _var1 = value & 0xFFFF;
    unawaited(_prefs.setInt(keyVar1, _var1));
    notifyListeners();
  }

  void setVar2(int value) {
    _var2 = value & 0xFFFFFFFF;
    unawaited(_prefs.setInt(keyVar2, _var2));
    notifyListeners();
  }

  void setVar3(int value) {
    _var3 = value & 0xFF;
    unawaited(_prefs.setInt(keyVar3, _var3));
    notifyListeners();
  }
}
