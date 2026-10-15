// 由 tools/gen_vectors.py 生成，请勿手改。
//
// 32 条 V3 指令的金向量：入参固定为 var1=0x1234, var2=0x123456789ABCDEF0,
// var3=0x34, tx_count=0x42, seed=0x6BE9（docs/ble-protocol.md §6.1）。
// 密文由 docs/reference-proto.py 生成，并与报告表格逐字节比对过；
// 明文直接抄自报告 §6.1 的「明文帧」列。
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:lampsmart/protocol/command.dart';

/// 一条金向量。
class GoldVector {
  const GoldVector({
    required this.jni,
    required this.command,
    required this.on,
    required this.p4,
    required this.p5,
    required this.p6,
    required this.cipherHex,
    required this.plainHex,
  });

  /// 报告 §6.1 的 JNI 方法名。
  final String jni;

  final Command command;
  final bool on;
  final int p4;
  final int p5;
  final int p6;

  /// 线上帧（31 字节密文）。
  final String cipherHex;

  /// 解密后的明文帧。
  final String plainHex;
}

const int goldVar1 = 0x1234;
const int goldVar2 = 0x9ABCDEF0;
const int goldVar3 = 0x34;
const int goldTxCount = 0x42;
const int goldSeed = 0x6BE9;

/// 报告 §6.1 的开灯帧（§3.3 / §4.1 也单独列了一遍）。
const String lampOnFrameHex =
    '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6';

final List<GoldVector> goldVectors = <GoldVector>[
  GoldVector(
    jni: 'Binding',
    command: Command.binding,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2302ce5b9c5ea753cfe96b9072',
    plainHex: '0201021b16f008308000423412f0debc9a34280000000000b32900e96b9072',
  ),
  GoldVector(
    jni: 'LampOnOff',
    command: Command.lampOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6',
    plainHex: '0201021b16f008308000423412f0debc9a34100000000000055300e96b3ce6',
  ),
  GoldVector(
    jni: 'AidOnOff',
    command: Command.aidOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1902ce5b9c5e9e99cfe96b77f0',
    plainHex: '0201021b16f008308000423412f0debc9a341200000000008ae300e96b77f0',
  ),
  GoldVector(
    jni: 'Dimming',
    command: Command.dimming,
    on: false,
    p4: 0x12,
    p5: 0x34,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2a02ce5b8e6a0209cfe96b4162',
    plainHex: '0201021b16f008308000423412f0debc9a34210000001234167300e96b4162',
  ),
  GoldVector(
    jni: 'DimmingNight',
    command: Command.dimmingNight,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2802ce5b9c5e2ae3cfe96b9f5a',
    plainHex: '0201021b16f008308000423412f0debc9a342300000000003e9900e96b9f5a',
  ),
  GoldVector(
    jni: 'RgbAuto',
    command: Command.rgbAuto,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1502ce5b9c5e074ccfe96b0e99',
    plainHex: '0201021b16f008308000423412f0debc9a341e0000000000133600e96b0e99',
  ),
  GoldVector(
    jni: 'RgbOnOff',
    command: Command.rgbOnOff,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1702ce499c5ece19cfe96b15d9',
    plainHex: '0201021b16f008308000423412f0debc9a341c0000120000da6300e96b15d9',
  ),
  GoldVector(
    jni: 'RgbSwitch',
    command: Command.rgbSwitch,
    on: false,
    p4: 0x12,
    p5: 0x34,
    p6: 0x56,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2902ce49a808704dcfe96b4a4e',
    plainHex: '0201021b16f008308000423412f0debc9a34220000123456643700e96b4a4e',
  ),
  GoldVector(
    jni: 'FanMode',
    command: Command.fanMode,
    on: false,
    p4: 0xAA,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d3802cef19c5e0935cfe96bcb71',
    plainHex: '0201021b16f008308000423412f0debc9a34330000aa00001d4f00e96bcb71',
  ),
  GoldVector(
    jni: 'FanSpeed',
    command: Command.fanSpeed,
    on: false,
    p4: 0xAA,
    p5: 0x1,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d3a02cef19d5e5e7dcfe96ba0f0',
    plainHex: '0201021b16f008308000423412f0debc9a34310000aa01004a0700e96ba0f0',
  ),
  GoldVector(
    jni: 'FanSwayOnOff',
    command: Command.fanSwayOnOff,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1d02ce499c5e1db3cfe96bc580',
    plainHex: '0201021b16f008308000423412f0debc9a3416000012000009c900e96bc580',
  ),
  GoldVector(
    jni: 'WindDircOnOff',
    command: Command.windDirOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1e02ce5a9c5e602fcfe96bafb8',
    plainHex: '0201021b16f008308000423412f0debc9a34150000010000745500e96bafb8',
  ),
  GoldVector(
    jni: 'WarmOnOff',
    command: Command.warmOnOff,
    on: false,
    p4: 0x12,
    p5: 0x34,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d6d02ce49a85e8376cfe96bdf45',
    plainHex: '0201021b16f008308000423412f0debc9a34660000123400970c00e96bdf45',
  ),
  GoldVector(
    jni: 'Ventilation',
    command: Command.ventilation,
    on: false,
    p4: 0xAA,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d6c02cef19c5e0c0fcfe96b7156',
    plainHex: '0201021b16f008308000423412f0debc9a34670000aa0000187500e96b7156',
  ),
  GoldVector(
    jni: 'SwingOnOff',
    command: Command.swingOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615dbb02ce5a9c5effeccfe96b7a79',
    plainHex: '0201021b16f008308000423412f0debc9a34b00000010000eb9600e96b7a79',
  ),
  GoldVector(
    jni: 'DryOnOff',
    command: Command.dryOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d6202ce5a9c5e720fcfe96b6387',
    plainHex: '0201021b16f008308000423412f0debc9a34690000010000667500e96b6387',
  ),
  GoldVector(
    jni: 'BathOnOff',
    command: Command.bathOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d6302ce5a9c5e5abdcfe96b0a49',
    plainHex: '0201021b16f008308000423412f0debc9a346800000100004ec700e96b0a49',
  ),
  GoldVector(
    jni: 'Temperature',
    command: Command.temperature,
    on: false,
    p4: 0xAA,
    p5: 0x1,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d5902cef19d5e2773cfe96b5571',
    plainHex: '0201021b16f008308000423412f0debc9a34520000aa0100330900e96b5571',
  ),
  GoldVector(
    jni: 'TimingClose',
    command: Command.timingClose,
    on: false,
    p4: 0x1234,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d4a02ce6f8e5e429ccfe96bc087',
    plainHex: '0201021b16f008308000423412f0debc9a3441000034120056e600e96bc087',
  ),
  GoldVector(
    jni: 'GenericOnOff',
    command: Command.genericOnOff,
    on: true,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d6402ce5a9c5ef27dcfe96b5afb',
    plainHex: '0201021b16f008308000423412f0debc9a346f0000010000e60700e96b5afb',
  ),
  GoldVector(
    jni: 'SceneSet',
    command: Command.sceneSet,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d4d02ce499c5ec891cfe96bbe5f',
    plainHex: '0201021b16f008308000423412f0debc9a34460000120000dceb00e96bbe5f',
  ),
  GoldVector(
    jni: 'SceneSwitch',
    command: Command.sceneSwitch,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d4c02ce499c5ef7b1cfe96baed9',
    plainHex: '0201021b16f008308000423412f0debc9a34470000120000e3cb00e96baed9',
  ),
  GoldVector(
    jni: 'SceneReset',
    command: Command.sceneReset,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d4302ce499c5e476ecfe96b4e00',
    plainHex: '0201021b16f008308000423412f0debc9a34480000120000531400e96b4e00',
  ),
  GoldVector(
    jni: 'SceneOn',
    command: Command.sceneOn,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1b02ce5a9c5e6d76cfe96b9796',
    plainHex: '0201021b16f008308000423412f0debc9a34100000010000790c00e96b9796',
  ),
  GoldVector(
    jni: 'AidBrigntness',
    command: Command.aidBrightness,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2502ce588e5ed10fcfe96b83f6',
    plainHex: '0201021b16f008308000423412f0debc9a342e0000031200c57500e96b83f6',
  ),
  GoldVector(
    jni: 'AidSpeed',
    command: Command.aidSpeed,
    on: false,
    p4: 0x12,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615def02ce5b8e5e62c5cfe96b57ea',
    plainHex: '0201021b16f008308000423412f0debc9a34e4000000120076bf00e96b57ea',
  ),
  GoldVector(
    jni: 'AidPotUP',
    command: Command.aidPotUp,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2402ce5f9c5edff4cfe96bb0f0',
    plainHex: '0201021b16f008308000423412f0debc9a342f0000040000cb8e00e96bb0f0',
  ),
  GoldVector(
    jni: 'AidPotDown',
    command: Command.aidPotDown,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2402ce589c5e1b06cfe96b33ff',
    plainHex: '0201021b16f008308000423412f0debc9a342f00000300000f7c00e96b33ff',
  ),
  GoldVector(
    jni: 'AidPotAuto',
    command: Command.aidPotAuto,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2402ce5a9c5e89f1cfe96bfcdc',
    plainHex: '0201021b16f008308000423412f0debc9a342f00000100009d8b00e96bfcdc',
  ),
  GoldVector(
    jni: 'AidPotEdit',
    command: Command.aidPotEdit,
    on: false,
    p4: 0x1234,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d2402ce59a84c6d89cfe96bba68',
    plainHex: '0201021b16f008308000423412f0debc9a342f000002341279f300e96bba68',
  ),
  GoldVector(
    jni: 'AidRgbModeUp',
    command: Command.rgbModeUp,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1002ce5b9c5e850ccfe96bcf18',
    plainHex: '0201021b16f008308000423412f0debc9a341b0000000000917600e96bcf18',
  ),
  GoldVector(
    jni: 'AidRgbModeDown',
    command: Command.rgbModeDown,
    on: false,
    p4: 0x0,
    p5: 0x0,
    p6: 0x0,
    cipherHex: '0201021b16f0083080ca68c56d1cad52615d1002ce5a9c5e1baacfe96bd17b',
    plainHex: '0201021b16f008308000423412f0debc9a341b00000100000fd000e96bd17b',
  ),
];
