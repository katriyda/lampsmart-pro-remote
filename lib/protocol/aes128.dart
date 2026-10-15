import 'dart:typed_data';

/// AES-128 单块**加密**（协议只需要这一个方向）。
///
/// S 盒在首次使用时由 GF(2^8) 求逆 + 仿射变换现场生成，不抄常量表
/// （与 `docs/reference-proto.py` 的 `_make_sbox` 同构）。
/// KAT（FIPS-197 附录 C.1）：
/// `aes128EncryptBlock(000102…0f, 00112233445566778899aabbccddeeff)`
/// `== 69c4e0d86a7b0430d8cdb78070b4c55a`。
final Uint8List _sbox = _buildSbox();

Uint8List aes128EncryptBlock(Uint8List key, Uint8List block) {
  if (key.length != 16) {
    throw ArgumentError.value(
      key.length,
      'key.length',
      'AES-128 key must be 16 bytes',
    );
  }
  if (block.length != 16) {
    throw ArgumentError.value(
      block.length,
      'block.length',
      'AES block must be 16 bytes',
    );
  }

  final List<Uint8List> roundKeys = _expandKey(key);
  final s = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    s[i] = block[i] ^ roundKeys[0][i];
  }
  final t = Uint8List(16);
  for (var round = 1; round <= 10; round++) {
    // SubBytes
    for (var i = 0; i < 16; i++) {
      s[i] = _sbox[s[i]];
    }
    // ShiftRows（行内循环左移）
    for (var i = 0; i < 16; i++) {
      t[i] = s[(i + 4 * (i % 4)) % 16];
    }
    s.setRange(0, 16, t);
    if (round != 10) {
      // MixColumns
      for (var c = 0; c < 4; c++) {
        final a0 = s[4 * c];
        final a1 = s[4 * c + 1];
        final a2 = s[4 * c + 2];
        final a3 = s[4 * c + 3];
        t[4 * c] = _xtime(a0) ^ _xtime(a1) ^ a1 ^ a2 ^ a3;
        t[4 * c + 1] = a0 ^ _xtime(a1) ^ _xtime(a2) ^ a2 ^ a3;
        t[4 * c + 2] = a0 ^ a1 ^ _xtime(a2) ^ _xtime(a3) ^ a3;
        t[4 * c + 3] = _xtime(a0) ^ a0 ^ a1 ^ a2 ^ _xtime(a3);
      }
      s.setRange(0, 16, t);
    }
    // AddRoundKey
    for (var i = 0; i < 16; i++) {
      s[i] ^= roundKeys[round][i];
    }
  }
  return s;
}

int _xtime(int a) {
  final int x = (a & 0xFF) << 1;
  return (x & 0x100) != 0 ? (x ^ 0x1B) & 0xFF : x & 0xFF;
}

int _gmul(int a, int b) {
  var r = 0;
  var x = a & 0xFF;
  var y = b;
  while (y != 0) {
    if ((y & 1) != 0) {
      r ^= x;
    }
    x = _xtime(x);
    y >>= 1;
  }
  return r;
}

Uint8List _buildSbox() {
  final inv = Uint8List(256);
  for (var a = 1; a < 256; a++) {
    for (var b = 1; b < 256; b++) {
      if (_gmul(a, b) == 1) {
        inv[a] = b;
        break;
      }
    }
  }
  final sbox = Uint8List(256);
  for (var a = 0; a < 256; a++) {
    final c = inv[a];
    var s = c;
    for (var i = 1; i < 5; i++) {
      s ^= ((c << i) | (c >> (8 - i))) & 0xFF;
    }
    sbox[a] = s ^ 0x63;
  }
  return sbox;
}

List<Uint8List> _expandKey(Uint8List key) {
  final words = <Uint8List>[];
  for (var i = 0; i < 4; i++) {
    words.add(Uint8List.fromList(key.sublist(i * 4, i * 4 + 4)));
  }
  var rcon = 1;
  for (var i = 4; i < 44; i++) {
    Uint8List t;
    if (i % 4 == 0) {
      final prev = words[i - 1];
      t = Uint8List.fromList(<int>[
        _sbox[prev[1]],
        _sbox[prev[2]],
        _sbox[prev[3]],
        _sbox[prev[0]],
      ]);
      t[0] ^= rcon;
      rcon = _xtime(rcon);
    } else {
      t = words[i - 1];
    }
    final prev4 = words[i - 4];
    final word = Uint8List(4);
    for (var k = 0; k < 4; k++) {
      word[k] = prev4[k] ^ t[k];
    }
    words.add(word);
  }
  return <Uint8List>[
    for (var r = 0; r < 11; r++)
      Uint8List.fromList(<int>[
        ...words[r * 4],
        ...words[r * 4 + 1],
        ...words[r * 4 + 2],
        ...words[r * 4 + 3],
      ]),
  ];
}
