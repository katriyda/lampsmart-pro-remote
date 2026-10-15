import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/protocol/command.dart';
import 'package:lampsmart/protocol/frame.dart';

import 'gold_vectors.dart';

void main() {
  test('32 条 V3 指令的金向量密文与明文逐字节一致', () {
    expect(goldVectors.length, 32);
    for (final GoldVector v in goldVectors) {
      final frame = buildFrame(
        v.command,
        on: v.on,
        var1: goldVar1,
        var2: goldVar2,
        var3: goldVar3,
        p4: v.p4,
        p5: v.p5,
        p6: v.p6,
        seed: goldSeed,
        txCount: goldTxCount,
      );
      expect(bytesToHex(frame), v.cipherHex, reason: '${v.jni} 线上帧不一致');
      expect(
        bytesToHex(dexor(frame, goldSeed)),
        v.plainHex,
        reason: '${v.jni} 明文帧不一致',
      );
    }
  });

  test('金向量覆盖全部 32 条指令且每条只出现一次', () {
    expect(
      goldVectors.map((GoldVector v) => v.command).toSet(),
      Command.values.toSet(),
    );
  });

  test('开灯帧等于报告 §3.3 / §4.1 的硬编码值', () {
    final frame = buildFrame(
      Command.lampOnOff,
      on: true,
      var1: 0x1234,
      var2: 0x123456789ABCDEF0,
      var3: 0x34,
      seed: 0x6BE9,
      txCount: 0x42,
    );
    expect(bytesToHex(frame), lampOnFrameHex);
    expect(
      bytesToHex(frame),
      '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6',
    );
  });

  test('frameToUuids 还原报告 §3.3 列出的 13 个 UUID', () {
    final frame = buildFrame(
      Command.lampOnOff,
      on: true,
      var1: 0x1234,
      var2: 0x123456789ABCDEF0,
      var3: 0x34,
      seed: 0x6BE9,
      txCount: 0x42,
    );
    expect(frameToUuids(frame), <String>[
      '000008f0-0000-1000-8000-00805f9b34fb',
      '00008030-0000-1000-8000-00805f9b34fb',
      '000068ca-0000-1000-8000-00805f9b34fb',
      '00006dc5-0000-1000-8000-00805f9b34fb',
      '0000ad1c-0000-1000-8000-00805f9b34fb',
      '00006152-0000-1000-8000-00805f9b34fb',
      '00001b5d-0000-1000-8000-00805f9b34fb',
      '0000ce02-0000-1000-8000-00805f9b34fb',
      '00009c5b-0000-1000-8000-00805f9b34fb',
      '0000115e-0000-1000-8000-00805f9b34fb',
      '0000cf29-0000-1000-8000-00805f9b34fb',
      '00006be9-0000-1000-8000-00805f9b34fb',
      '0000e63c-0000-1000-8000-00805f9b34fb',
    ]);
  });
}
