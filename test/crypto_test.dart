import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/protocol/aes128.dart';
import 'package:lampsmart/protocol/crc16.dart';
import 'package:lampsmart/protocol/frame.dart';

Uint8List _hex(String s) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < s.length; i += 2) {
    bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('CRC-16/CCITT', () {
    test('标准校验值 "123456789" = 0x29B1', () {
      expect(crc16Ccitt(ascii.encode('123456789')), 0x29B1);
    });

    test('初值参与计算（与 Python 参考实现同值）', () {
      expect(crc16Ccitt(ascii.encode('123456789'), init: 0x0000), 0x31C3);
      expect(crc16Ccitt(const <int>[], init: 0xFFFF), 0xFFFF);
    });

    test('报告 §5.2 的帧 CRC：对密文 b7..b28、初值 ~seed', () {
      final frame = _hex(
        '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6',
      );
      final seed = frame[27] | (frame[28] << 8);
      final crc = crc16Ccitt(frame.sublist(7, 29), init: (~seed) & 0xFFFF);
      expect(crc, 0xE63C);
      expect(frame[29] | (frame[30] << 8), 0xE63C);
    });
  });

  group('AES-128', () {
    test('FIPS-197 附录 C.1', () {
      final result = aes128EncryptBlock(
        _hex('000102030405060708090a0b0c0d0e0f'),
        _hex('00112233445566778899aabbccddeeff'),
      );
      expect(bytesToHex(result), '69c4e0d86a7b0430d8cdb78070b4c55a');
    });

    test('FIPS-197 附录 C.2（可变密钥轮）', () {
      final result = aes128EncryptBlock(
        _hex('2b7e151628aed2a6abf7158809cf4f3c'),
        _hex('3243f6a8885a308d313198a2e0370734'),
      );
      expect(bytesToHex(result), '3925841d02dc09fbdc118597196a0b32');
    });

    test('只收 16 字节密钥与 16 字节明文块', () {
      expect(
        () => aes128EncryptBlock(_hex('00' * 17), _hex('00' * 16)),
        throwsArgumentError,
      );
      expect(
        () => aes128EncryptBlock(_hex('00' * 16), _hex('00' * 17)),
        throwsArgumentError,
      );
    });
  });
}
