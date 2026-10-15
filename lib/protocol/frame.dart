import 'dart:typed_data';

import 'aes128.dart';
import 'command.dart';
import 'crc16.dart';
import 'xboxes.dart';

/// 控制帧固定 31 字节。
const int frameLength = 31;

/// `b0..b6` 的 AD 结构模板：Flags + Service Data 头 + 16-bit UUID `0x08F0`。
/// 前 5 字节空中由系统协议栈重写，固件只校验 `b5..b6`（报告 §3.2）。
const List<int> baseHeader = <int>[0x02, 0x01, 0x02, 0x1B, 0x16, 0xF0, 0x08];

/// V3 版本标志（V2 = `0x10`，本 App 恒用 V3）。
const int v3VersionByte = 0x30;

/// 构造 31 字节 V3 控制帧。
///
/// 编码顺序即正确性（报告 附录 B），不能调换：
/// 1. 填 `b0..b23`（模板 / 版本 / 负载 / cmd / 扩展字节）；
/// 2. 对**混淆前**的 `b8..b23` 做 AES-128 加密，取前 2 字节写入 `b24..b25`
///    （为 0 时改写 `0xFFFF`）；
/// 3. 对 `b9..b26` 做 XOR 混淆；
/// 4. 写入 `b27..b28 = seed`；
/// 5. 对**密文** `b7..b28` 算 CRC-16，初值 `~seed`，小端写入 `b29..b30`。
///
/// [seed] 任意取值均可（原 App 首次启动随机取一个后固定不变，报告 §5.1），
/// [txCount] 是发送计数，参与 AES 密钥所以必须与写入 `b10` 的值一致。
Uint8List buildFrame(
  Command command, {
  required bool on,
  int var1 = 0,
  int var2 = 0,
  int var3 = 0,
  int p4 = 0,
  int p5 = 0,
  int p6 = 0,
  required int seed,
  required int txCount,
}) {
  final int s = seed & 0xFFFF;
  final Uint8List f = Uint8List(frameLength);

  f.setRange(0, 7, baseHeader);
  f[7] = v3VersionByte; // 版本
  f[8] = 0x80; // 固定
  f[9] = 0x00; // 固定（V3 struct[2] 恒 0 ⇒ XOR 子表恒用第 0 组）
  f[10] = txCount & 0xFF;
  f[11] = var1 & 0xFF;
  f[12] = (var1 >> 8) & 0xFF;
  f[13] = var2 & 0xFF;
  f[14] = (var2 >> 8) & 0xFF;
  f[15] = (var2 >> 16) & 0xFF;
  f[16] = (var2 >> 24) & 0xFF;
  f[17] = var3 & 0xFF;
  final int cmd = cmdOf(command, on: on);
  f[18] = cmd & 0xFF;
  f[19] = (cmd >> 8) & 0xFF;
  f.setRange(20, 24, extraOf(command, on: on, p4: p4, p5: p5, p6: p6));

  // 2. V3 AES-128 标签（必须在 XOR 之前算）
  final Uint8List key = Uint8List(16)
    ..[0] = s & 0xFF
    ..[1] = (s >> 8) & 0xFF
    ..[2] = f[10];
  key.setRange(3, 16, v3AesKeyTail);
  final Uint8List tagBlock = aes128EncryptBlock(
    key,
    Uint8List.fromList(f.sublist(8, 24)),
  );
  var tag = tagBlock[0] | (tagBlock[1] << 8);
  if (tag == 0) {
    tag = 0xFFFF;
  }
  f[24] = tag & 0xFF;
  f[25] = (tag >> 8) & 0xFF;

  // 3. XOR 混淆
  for (var i = 9; i <= 26; i++) {
    f[i] = (f[i] ^ xboxes[(s + i) & 0x1F] ^ (s & 0xFF)) & 0xFF;
  }

  // 4. seed
  f[27] = s & 0xFF;
  f[28] = (s >> 8) & 0xFF;

  // 5. 对密文算 CRC
  final int crc = crc16Ccitt(f.sublist(7, 29), init: (~s) & 0xFFFF);
  f[29] = crc & 0xFF;
  f[30] = (crc >> 8) & 0xFF;
  return f;
}

/// 把帧 `b5..b30`（26 字节）拆成 13 个 16-bit UUID —— App 就是这样塞进广播包的。
///
/// UUID 字符串按高字节在前书写，回到空中时逐字节还原成帧的 `b5..b30`（报告 §3.1）。
List<String> frameToUuids(Uint8List frame) {
  return <String>[
    for (var i = 5; i < 31; i += 2)
      '0000${_hex4(frame[i] | (frame[i + 1] << 8))}-0000-1000-8000-00805f9b34fb',
  ];
}

/// 逆向 XOR 混淆，返回明文帧（`b27..b30` 未加密，保持原值）。
///
/// [subkey] 选 32 字节子表，本 App 恒为 0。
Uint8List dexor(Uint8List frame, int seed, {int subkey = 0}) {
  final Uint8List f = Uint8List.fromList(frame);
  for (var i = 9; i <= 26; i++) {
    f[i] =
        (f[i] ^ xboxes[subkey * 32 + ((seed + i) & 0x1F)] ^ (seed & 0xFF)) &
        0xFF;
  }
  return f;
}

/// 校验长度 / 16-bit UUID / CRC（对应原生 `is_ble_v3_pdu`）。
/// 合法返回帧内 seed，否则返回 `null`。
int? verifyFrame(Uint8List f) {
  if (f.length != frameLength) {
    return null;
  }
  if (f[5] != 0xF0 || f[6] != 0x08) {
    return null;
  }
  final int seed = f[27] | (f[28] << 8);
  final int crc = crc16Ccitt(f.sublist(7, 29), init: (~seed) & 0xFFFF);
  return (f[29] | (f[30] << 8)) == crc ? seed : null;
}

/// 校验并解析控制帧；无效帧返回 `null`。键与 `docs/reference-proto.py`
/// 的 `parse_frame` 对齐（`txCount` 对应 `tx_count`，`plain` 为解密后的 31 字节）。
Map<String, dynamic>? parseFrame(Uint8List f) {
  final int? seed = verifyFrame(f);
  if (seed == null) {
    return null;
  }
  final Uint8List plain = dexor(f, seed);
  return <String, dynamic>{
    'version': plain[7] == 0x10
        ? 'V2'
        : plain[7] == 0x30
        ? 'V3'
        : plain[7],
    'txCount': plain[10],
    'var1': plain[11] | (plain[12] << 8),
    'var2':
        plain[13] | (plain[14] << 8) | (plain[15] << 16) | (plain[16] << 24),
    'var3': plain[17],
    'cmd': plain[18] | (plain[19] << 8),
    'extra': Uint8List.fromList(plain.sublist(20, 24)),
    'tag': plain[24] | (plain[25] << 8),
    'seed': seed,
    'crc': f[29] | (f[30] << 8),
    'plain': plain,
  };
}

/// 字节数组转小写十六进制串（UI 日志 / 调试页用）。
String bytesToHex(List<int> bytes) {
  final StringBuffer sb = StringBuffer();
  for (final int b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

String _hex4(int v) => v.toRadixString(16).padLeft(4, '0');
