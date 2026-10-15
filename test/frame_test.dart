import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/protocol/aes128.dart';
import 'package:lampsmart/protocol/command.dart';
import 'package:lampsmart/protocol/frame.dart';
import 'package:lampsmart/protocol/xboxes.dart';

Uint8List _build({
  Command command = Command.dimming,
  bool on = true,
  int var1 = 0xABCD,
  int var2 = 0x89ABCDEF,
  int var3 = 0x77,
  int p4 = 0,
  int p5 = 0,
  int p6 = 0,
  int seed = 0x1357,
  int txCount = 0x20,
}) {
  return buildFrame(
    command,
    on: on,
    var1: var1,
    var2: var2,
    var3: var3,
    p4: p4,
    p5: p5,
    p6: p6,
    seed: seed,
    txCount: txCount,
  );
}

void main() {
  test('解析结果与入参一致（往返）', () {
    final frame = _build(
      command: Command.rgbSwitch,
      p4: 11,
      p5: 22,
      p6: 33,
      var1: 0x1234,
      var2: 0x9ABCDEF0,
      var3: 0x34,
      seed: 0x6BE9,
      txCount: 0x42,
    );
    final info = parseFrame(frame)!;
    expect(info['version'], 'V3');
    expect(info['cmd'], 0x22);
    expect(info['seed'], 0x6BE9);
    expect(info['txCount'], 0x42);
    expect(info['var1'], 0x1234);
    expect(info['var2'], 0x9ABCDEF0);
    expect(info['var3'], 0x34);
    expect(info['extra'], <int>[0, 11, 22, 33]);
  });

  test('边界：var2 截断到 u32，seed / txCount 取低位', () {
    final frame = buildFrame(
      Command.lampOnOff,
      on: true,
      var2: 0x123456789ABCDEF0,
      seed: 0x1FFFF, // & 0xFFFF
      txCount: 0x1AA, // & 0xFF
    );
    final info = parseFrame(frame)!;
    expect(info['var2'], 0x9ABCDEF0);
    expect(info['seed'], 0xFFFF);
    expect(info['txCount'], 0xAA);
  });

  test('frameToUuids：13 个、首项 0x08F0、小端拼回等于 b5..b30', () {
    final frame = _build();
    final uuids = frameToUuids(frame);
    expect(uuids.length, 13);
    expect(uuids.first, '000008f0-0000-1000-8000-00805f9b34fb');
    final Uint8List rebuilt = Uint8List(26);
    for (var i = 0; i < uuids.length; i++) {
      final int value = int.parse(uuids[i].substring(4, 8), radix: 16);
      rebuilt[2 * i] = value & 0xFF;
      rebuilt[2 * i + 1] = (value >> 8) & 0xFF;
    }
    expect(rebuilt, frame.sublist(5));
  });

  test('verifyFrame：合法帧返回 seed，四组负例全部判否', () {
    expect(verifyFrame(_build()), 0x1357);

    final brokenCrc = _build()..[29] ^= 0xFF;
    expect(verifyFrame(brokenCrc), isNull, reason: '改 CRC');

    final brokenLength = Uint8List.fromList(_build().sublist(0, 30));
    expect(verifyFrame(brokenLength), isNull, reason: '改长度');

    final brokenUuid = _build()..[5] = 0x00;
    expect(verifyFrame(brokenUuid), isNull, reason: '改 b5..b6');

    final brokenVersion = _build()..[7] ^= 0x20;
    expect(verifyFrame(brokenVersion), isNull, reason: '改 b7 会破坏 CRC');
  });

  test('b24..b25 = AES(seed‖tx_count‖尾, 混淆前 b8..b23) 的前两字节', () {
    final frame = _build(command: Command.warmOnOff, p4: 7, p5: 9);
    final plain = dexor(frame, 0x1357);
    final key = Uint8List(16)
      ..[0] = 0x57
      ..[1] = 0x13
      ..[2] = 0x20;
    key.setRange(3, 16, v3AesKeyTail);
    final block = aes128EncryptBlock(
      key,
      Uint8List.fromList(plain.sublist(8, 24)),
    );
    // 标签本身也参与 XOR，所以比的是解密后的 b24..b25。
    expect(plain[24] | (plain[25] << 8), block[0] | (block[1] << 8));
  });

  test('cmd 号冲突：LampOnOff(开) 与 SceneOn 同为 0x10，靠 b21 区分', () {
    final lampOn = parseFrame(_build(command: Command.lampOnOff, on: true))!;
    final sceneOn = parseFrame(_build(command: Command.sceneOn))!;
    expect(lampOn['cmd'], 0x10);
    expect(sceneOn['cmd'], 0x10);
    expect(lampOn['extra'], <int>[0, 0, 0, 0]);
    expect(sceneOn['extra'], <int>[0, 1, 0, 0]);
  });
}
