#!/usr/bin/env python3
"""生成 test/gold_vectors.dart —— 32 条 V3 指令的测试夹具（唯一生成源）。

金向量入参固定为报告 §6.1 表格那一组：
    var1=0x1234, var2=0x123456789ABCDEF0, var3=0x34, tx_count=0x42, seed=0x6BE9

做法：用 docs/reference-proto.py 生成密文 / 明文，并与报告 §6.1 表格里
**逐字抄下来的**明文、密文两列比对；只要有一条对不上就直接报错退出，
所以夹具永远等于「报告表格 + Python 参考实现」两者。

用法（在仓库根目录）：
    python tools/gen_vectors.py && flutter test test/gold_vectors_test.dart
"""
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFERENCE = os.path.join(ROOT, 'docs', 'reference-proto.py')
OUTPUT = os.path.join(ROOT, 'test', 'gold_vectors.dart')

VAR1 = 0x1234
VAR2 = 0x123456789ABCDEF0
VAR3 = 0x34
TX_COUNT = 0x42
SEED = 0x6BE9

# (Python 方法名, Dart 枚举名, 入参, 报告 §6.1 明文帧, 报告 §6.1 线上帧)
VECTORS = [
    ('Binding', 'binding', {'on': True},
     '0201021b16f008308000423412f0debc9a34280000000000b32900e96b9072',
     '0201021b16f0083080ca68c56d1cad52615d2302ce5b9c5ea753cfe96b9072'),
    ('LampOnOff', 'lampOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a34100000000000055300e96b3ce6',
     '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6'),
    ('AidOnOff', 'aidOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a341200000000008ae300e96b77f0',
     '0201021b16f0083080ca68c56d1cad52615d1902ce5b9c5e9e99cfe96b77f0'),
    ('Dimming', 'dimming', {'p4': 0x12, 'p5': 0x34},
     '0201021b16f008308000423412f0debc9a34210000001234167300e96b4162',
     '0201021b16f0083080ca68c56d1cad52615d2a02ce5b8e6a0209cfe96b4162'),
    ('DimmingNight', 'dimmingNight', {},
     '0201021b16f008308000423412f0debc9a342300000000003e9900e96b9f5a',
     '0201021b16f0083080ca68c56d1cad52615d2802ce5b9c5e2ae3cfe96b9f5a'),
    ('RgbAuto', 'rgbAuto', {'on': True},
     '0201021b16f008308000423412f0debc9a341e0000000000133600e96b0e99',
     '0201021b16f0083080ca68c56d1cad52615d1502ce5b9c5e074ccfe96b0e99'),
    ('RgbOnOff', 'rgbOnOff', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a341c0000120000da6300e96b15d9',
     '0201021b16f0083080ca68c56d1cad52615d1702ce499c5ece19cfe96b15d9'),
    ('RgbSwitch', 'rgbSwitch', {'p4': 0x12, 'p5': 0x34, 'p6': 0x56},
     '0201021b16f008308000423412f0debc9a34220000123456643700e96b4a4e',
     '0201021b16f0083080ca68c56d1cad52615d2902ce49a808704dcfe96b4a4e'),
    ('FanMode', 'fanMode', {'p4': 0xAA},
     '0201021b16f008308000423412f0debc9a34330000aa00001d4f00e96bcb71',
     '0201021b16f0083080ca68c56d1cad52615d3802cef19c5e0935cfe96bcb71'),
    ('FanSpeed', 'fanSpeed', {'p4': 0xAA, 'p5': 0x01},
     '0201021b16f008308000423412f0debc9a34310000aa01004a0700e96ba0f0',
     '0201021b16f0083080ca68c56d1cad52615d3a02cef19d5e5e7dcfe96ba0f0'),
    ('FanSwayOnOff', 'fanSwayOnOff', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a3416000012000009c900e96bc580',
     '0201021b16f0083080ca68c56d1cad52615d1d02ce499c5e1db3cfe96bc580'),
    ('WindDircOnOff', 'windDirOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a34150000010000745500e96bafb8',
     '0201021b16f0083080ca68c56d1cad52615d1e02ce5a9c5e602fcfe96bafb8'),
    ('WarmOnOff', 'warmOnOff', {'p4': 0x12, 'p5': 0x34},
     '0201021b16f008308000423412f0debc9a34660000123400970c00e96bdf45',
     '0201021b16f0083080ca68c56d1cad52615d6d02ce49a85e8376cfe96bdf45'),
    ('Ventilation', 'ventilation', {'p4': 0xAA},
     '0201021b16f008308000423412f0debc9a34670000aa0000187500e96b7156',
     '0201021b16f0083080ca68c56d1cad52615d6c02cef19c5e0c0fcfe96b7156'),
    ('SwingOnOff', 'swingOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a34b00000010000eb9600e96b7a79',
     '0201021b16f0083080ca68c56d1cad52615dbb02ce5a9c5effeccfe96b7a79'),
    ('DryOnOff', 'dryOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a34690000010000667500e96b6387',
     '0201021b16f0083080ca68c56d1cad52615d6202ce5a9c5e720fcfe96b6387'),
    ('BathOnOff', 'bathOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a346800000100004ec700e96b0a49',
     '0201021b16f0083080ca68c56d1cad52615d6302ce5a9c5e5abdcfe96b0a49'),
    ('Temperature', 'temperature', {'p4': 0xAA, 'p5': 0x01},
     '0201021b16f008308000423412f0debc9a34520000aa0100330900e96b5571',
     '0201021b16f0083080ca68c56d1cad52615d5902cef19d5e2773cfe96b5571'),
    ('TimingClose', 'timingClose', {'p4': 0x1234},
     '0201021b16f008308000423412f0debc9a3441000034120056e600e96bc087',
     '0201021b16f0083080ca68c56d1cad52615d4a02ce6f8e5e429ccfe96bc087'),
    ('GenericOnOff', 'genericOnOff', {'on': True},
     '0201021b16f008308000423412f0debc9a346f0000010000e60700e96b5afb',
     '0201021b16f0083080ca68c56d1cad52615d6402ce5a9c5ef27dcfe96b5afb'),
    ('SceneSet', 'sceneSet', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a34460000120000dceb00e96bbe5f',
     '0201021b16f0083080ca68c56d1cad52615d4d02ce499c5ec891cfe96bbe5f'),
    ('SceneSwitch', 'sceneSwitch', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a34470000120000e3cb00e96baed9',
     '0201021b16f0083080ca68c56d1cad52615d4c02ce499c5ef7b1cfe96baed9'),
    ('SceneReset', 'sceneReset', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a34480000120000531400e96b4e00',
     '0201021b16f0083080ca68c56d1cad52615d4302ce499c5e476ecfe96b4e00'),
    ('SceneOn', 'sceneOn', {},
     '0201021b16f008308000423412f0debc9a34100000010000790c00e96b9796',
     '0201021b16f0083080ca68c56d1cad52615d1b02ce5a9c5e6d76cfe96b9796'),
    ('AidBrigntness', 'aidBrightness', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a342e0000031200c57500e96b83f6',
     '0201021b16f0083080ca68c56d1cad52615d2502ce588e5ed10fcfe96b83f6'),
    ('AidSpeed', 'aidSpeed', {'p4': 0x12},
     '0201021b16f008308000423412f0debc9a34e4000000120076bf00e96b57ea',
     '0201021b16f0083080ca68c56d1cad52615def02ce5b8e5e62c5cfe96b57ea'),
    ('AidPotUP', 'aidPotUp', {},
     '0201021b16f008308000423412f0debc9a342f0000040000cb8e00e96bb0f0',
     '0201021b16f0083080ca68c56d1cad52615d2402ce5f9c5edff4cfe96bb0f0'),
    ('AidPotDown', 'aidPotDown', {},
     '0201021b16f008308000423412f0debc9a342f00000300000f7c00e96b33ff',
     '0201021b16f0083080ca68c56d1cad52615d2402ce589c5e1b06cfe96b33ff'),
    ('AidPotAuto', 'aidPotAuto', {},
     '0201021b16f008308000423412f0debc9a342f00000100009d8b00e96bfcdc',
     '0201021b16f0083080ca68c56d1cad52615d2402ce5a9c5e89f1cfe96bfcdc'),
    ('AidPotEdit', 'aidPotEdit', {'p4': 0x1234},
     '0201021b16f008308000423412f0debc9a342f000002341279f300e96bba68',
     '0201021b16f0083080ca68c56d1cad52615d2402ce59a84c6d89cfe96bba68'),
    ('AidRgbModeUp', 'rgbModeUp', {},
     '0201021b16f008308000423412f0debc9a341b0000000000917600e96bcf18',
     '0201021b16f0083080ca68c56d1cad52615d1002ce5b9c5e850ccfe96bcf18'),
    ('AidRgbModeDown', 'rgbModeDown', {},
     '0201021b16f008308000423412f0debc9a341b00000100000fd000e96bd17b',
     '0201021b16f0083080ca68c56d1cad52615d1002ce5a9c5e1baacfe96bd17b'),
]


def load_reference():
    spec = importlib.util.spec_from_file_location('reference_proto', REFERENCE)
    if spec is None or spec.loader is None:
        raise SystemExit('cannot load %s' % REFERENCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    proto = load_reference()
    entries = []
    for name, dart_name, params, report_plain, report_cipher in VECTORS:
        frame = proto.build_frame(
            name, 3, var1=VAR1, var2=VAR2, var3=VAR3, seed=SEED, tx_count=TX_COUNT, **params)
        cipher = frame.hex()
        if cipher != report_cipher:
            raise SystemExit('%s: 参考实现与报告 §6.1 线上帧不一致\n  生成 %s\n  报告 %s'
                             % (name, cipher, report_cipher))
        parsed = proto.parse_frame(frame)
        plain = parsed['plain'].hex()
        if plain != report_plain:
            raise SystemExit('%s: 解密帧与报告 §6.1 明文帧不一致\n  生成 %s\n  报告 %s'
                             % (name, plain, report_plain))
        entries.append((dart_name, name, params, cipher, report_plain))

    lines = [
        '// 由 tools/gen_vectors.py 生成，请勿手改。',
        '//',
        '// 32 条 V3 指令的金向量：入参固定为 var1=0x1234, var2=0x123456789ABCDEF0,',
        '// var3=0x34, tx_count=0x42, seed=0x6BE9（docs/ble-protocol.md §6.1）。',
        '// 密文由 docs/reference-proto.py 生成，并与报告表格逐字节比对过；',
        '// 明文直接抄自报告 §6.1 的「明文帧」列。',
        '//',
        '// ignore_for_file: lines_longer_than_80_chars',
        '',
        "import 'package:lampsmart/protocol/command.dart';",
        '',
        '/// 一条金向量。',
        'class GoldVector {',
        '  const GoldVector({',
        '    required this.jni,',
        '    required this.command,',
        '    required this.on,',
        '    required this.p4,',
        '    required this.p5,',
        '    required this.p6,',
        '    required this.cipherHex,',
        '    required this.plainHex,',
        '  });',
        '',
        '  /// 报告 §6.1 的 JNI 方法名。',
        '  final String jni;',
        '',
        '  final Command command;',
        '  final bool on;',
        '  final int p4;',
        '  final int p5;',
        '  final int p6;',
        '',
        '  /// 线上帧（31 字节密文）。',
        '  final String cipherHex;',
        '',
        '  /// 解密后的明文帧。',
        '  final String plainHex;',
        '}',
        '',
        'const int goldVar1 = 0x1234;',
        'const int goldVar2 = 0x9ABCDEF0;',
        'const int goldVar3 = 0x34;',
        'const int goldTxCount = 0x42;',
        'const int goldSeed = 0x6BE9;',
        '',
        '/// 报告 §6.1 的开灯帧（§3.3 / §4.1 也单独列了一遍）。',
        "const String lampOnFrameHex = '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6';",
        '',
        'final List<GoldVector> goldVectors = <GoldVector>[',
    ]
    for dart_name, name, params, cipher, plain in entries:
        lines.append('  GoldVector(')
        lines.append('    jni: %r,' % name)
        lines.append('    command: Command.%s,' % dart_name)
        lines.append('    on: %s,' % ('true' if params.get('on') else 'false'))
        lines.append('    p4: 0x%X,' % params.get('p4', 0))
        lines.append('    p5: 0x%X,' % params.get('p5', 0))
        lines.append('    p6: 0x%X,' % params.get('p6', 0))
        lines.append('    cipherHex:')
        lines.append("        '%s'," % cipher)
        lines.append('    plainHex:')
        lines.append("        '%s'," % plain)
        lines.append('  ),')
    lines.append('];')
    lines.append('')

    with open(OUTPUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('\n'.join(lines))
    print('wrote %s (%d vectors)' % (OUTPUT, len(entries)))


if __name__ == '__main__':
    sys.exit(main())