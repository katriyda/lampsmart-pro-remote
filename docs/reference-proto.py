#!/usr/bin/env python3
"""LampSmart Pro (com.jingyuan.lamp) BLE 控制协议 —— 纯 Python 参考实现。

    >>> import lampsmart_proto as lp
    >>> lp.encode_v3('LampOnOff', seed=0x6BE9, tx_count=0x42, var1=0x1234,
    ...              var2=0x123456789ABCDEF0, var3=0x34, on=True).hex()
    '0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6'

帧长 31 字节: 前 5 字节是 AD 结构模板, b9..b26 用 XBOXES 表 XOR 混淆,
末尾 4 字节是 seed 与 CRC16。完整说明见 lampsmartpro-ble-protocol.md。
零依赖 (AES-128 为内置实现)。
"""
import struct

__all__ = ['XBOXES', 'V3_AES_KEY_TAIL', 'V2_COMMANDS', 'V3_COMMANDS', 'FRAME_LEN',
           'crc16_ccitt', 'aes128_encrypt_block', 'build_frame', 'encode_v2',
           'encode_v3', 'dexor', 'verify_frame', 'parse_frame', 'as_uuids']

# ---------------------------------------------------------------- 加密常量

#: 4 组各 32 字节的 XOR 子密钥 (libencode.so/.rodata)。本 App 恒用第 0 组。
XBOXES = bytes.fromhex(
    'b7fd9326363ff7cc34a5e5f171d83115'
    '04c723c31896059a071280e2eb27b275'
    'd0efaafb434d338545f9027f503c9fa8'
    '51a3408f929d38f5bcb6da2110fff3d2'
    'e0323a0a4906245cc2d3ac629195e479'
    'e7c8376d8dd54ea96c56f4ea657aae08'
    'e1f8981169d98e949b1e87e9ce5528df'
    '8ca1890dbfe6426841992d0fb054bb16')

#: V3 AES-128 密钥的后 13 字节; 前 3 字节为 seed_lo, seed_hi, tx_count
V3_AES_KEY_TAIL = bytes.fromhex('0dbfe6426841992d0fb054bb16')

FRAME_LEN = 31
XOR_RANGE = range(9, 27)          # 参与 XOR 的字节区间 [9, 26]
CRC_RANGE = slice(7, 29)          # 参与 CRC 的字节区间 [7, 28]
_BASE_HEADER = bytes([0x02, 0x01, 0x02, 0x1B, 0x16, 0xF0, 0x08])


# ---------------------------------------------------------------- AES-128

def _xtime(a):
    a <<= 1
    return (a ^ 0x1B) & 0xFF if a & 0x100 else a


def _gmul(a, b):
    r = 0
    while b:
        if b & 1:
            r ^= a
        a = _xtime(a)
        b >>= 1
    return r


def _make_sbox():
    """标准 AES S 盒 = GF(2^8) 求逆 + 仿射变换, 现场计算以免抄错常量。"""
    inv = [0] * 256
    for a in range(1, 256):
        for b in range(1, 256):
            if _gmul(a, b) == 1:
                inv[a] = b
                break
    sbox = bytearray(256)
    for a in range(256):
        c = inv[a]
        s = c
        for i in range(1, 5):                      # c ^ rotl(c,1..4) ^ 0x63
            s ^= ((c << i) | (c >> (8 - i))) & 0xFF
        sbox[a] = s ^ 0x63
    return bytes(sbox)


_SBOX = _make_sbox()


def _expand_key(key):
    """AES-128 密钥扩展 -> 11 个 16 字节轮密钥。"""
    if len(key) != 16:
        raise ValueError('AES-128 key must be 16 bytes')
    words = [list(key[i:i + 4]) for i in range(0, 16, 4)]
    rcon = 1
    for i in range(4, 44):
        if i % 4 == 0:
            t = words[i - 1][1:] + words[i - 1][:1]   # RotWord
            t = [_SBOX[b] for b in t]                   # SubWord
            t[0] ^= rcon                                 # Rcon
            rcon = _xtime(rcon)
        else:
            t = words[i - 1]
        words.append([a ^ b for a, b in zip(words[i - 4], t)])
    return [bytes(b for w in words[r * 4:r * 4 + 4] for b in w) for r in range(11)]


def aes128_encrypt_block(key, block):
    """AES-128 单块加密 (协议只需要加密方向)。"""
    if len(block) != 16:
        raise ValueError('AES block must be 16 bytes')
    rk = _expand_key(key)
    s = bytearray(x ^ k for x, k in zip(block, rk[0]))
    for rnd in range(1, 11):
        s = bytearray(_SBOX[b] for b in s)                                  # SubBytes
        s = bytearray(s[(i + 4 * (i % 4)) % 16] for i in range(16))          # ShiftRows
        if rnd != 10:                                                       # MixColumns
            t = bytearray(16)
            for c in range(4):
                a = s[4 * c:4 * c + 4]
                t[4 * c + 0] = _xtime(a[0]) ^ _xtime(a[1]) ^ a[1] ^ a[2] ^ a[3]
                t[4 * c + 1] = a[0] ^ _xtime(a[1]) ^ _xtime(a[2]) ^ a[2] ^ a[3]
                t[4 * c + 2] = a[0] ^ a[1] ^ _xtime(a[2]) ^ _xtime(a[3]) ^ a[3]
                t[4 * c + 3] = _xtime(a[0]) ^ a[0] ^ a[1] ^ a[2] ^ _xtime(a[3])
            s = t
        s = bytearray(x ^ k for x, k in zip(s, rk[rnd]))                    # AddRoundKey
    return bytes(s)


# ---------------------------------------------------------------- CRC16

def crc16_ccitt(data, init=0xFFFF):
    """MSB-first CRC-16/CCITT: poly 0x1021, 不反射, 无最终异或。"""
    crc = init & 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


_ONOFF = {'LampOnOff': 0x11, 'AidOnOff': 0x13, 'RgbAuto': 0x1F}
#: 名字 -> (cmd 常量, [扩展字段写入规则]); 规则形如 'b22=p4&0xff'
_EXTRA = {
    'WindDircOnOff': (0x15, ['b21=z']), 'SwingOnOff': (0xB0, ['b21=z']),
    'DryOnOff': (0x69, ['b21=z']), 'BathOnOff': (0x68, ['b21=z']),
    'GenericOnOff': (0x6F, ['b21=z']),
    'Dimming': (0x21, ['b21=0', 'b22=p4', 'b23=p5']),
    'DimmingNight': (0x23, []),
    'RgbSwitch': (0x22, ['b21=p4', 'b22=p5', 'b23=p6']),
    'FanMode': (0x33, ['b21=p4']), 'FanSpeed': (0x31, ['b21=p4', 'b22=p5']),
    'WarmOnOff': (0x66, ['b21=p4', 'b22=p5']),
    'Ventilation': (0x67, ['b21=p4']), 'Temperature': (0x52, ['b21=p4', 'b22=p5']),
    'TimingClose': (0x41, ['b21=p4&0xff', 'b22=p4>>8']),
    'SceneSet': (0x46, ['b21=p4']), 'SceneSwitch': (0x47, ['b21=p4']),
    'SceneReset': (0x48, ['b21=p4']), 'SceneOn': (0x10, ['b21=1']),
    'RgbOnOff': (0x1C, ['b20=0', 'b21=p4']),
    'FanSwayOnOff': (0x16, ['b20=0', 'b21=p4']),
}
#: V3 在 V2 基础上追加的 Aid* 系列
V3_ONLY = {
    'AidBrigntness': (0x2E, ['b21=3', 'b22=p4']),
    'AidSpeed': (0xE4, ['b22=p4']),
    'AidPotUP': (0x2F, ['b21=4']), 'AidPotDown': (0x2F, ['b21=3']),
    'AidPotAuto': (0x2F, ['b21=1']),
    'AidPotEdit': (0x2F, ['b21=2', 'b22=p4&0xff', 'b23=p4>>8']),
    'AidRgbModeUp': (0x1B, ['b21=0']), 'AidRgbModeDown': (0x1B, ['b21=1']),
}
V2_COMMANDS = ('Binding',) + tuple(_ONOFF) + tuple(_EXTRA)
V3_COMMANDS = V2_COMMANDS + tuple(V3_ONLY)


def _extra_bytes(name, p):
    out = bytearray(4)
    spec = _EXTRA.get(name) or V3_ONLY.get(name) or (0, [])
    for item in spec[1]:
        off, _, expr = item.partition('=')
        idx = int(off[1:]) - 20
        if expr == 'z':
            val = 1 if p.get('on') else 0
        elif expr[0] == 'p' and expr[1].isdigit():
            val = p.get(f'p{expr[1]}', 0) & 0xFFFF
            if '>>8' in expr:
                val >>= 8
        else:
            val = int(expr, 0)
        out[idx] = val & 0xFF
    return bytes(out)


def _cmd_of(name, p):
    if name == 'Binding':
        return (0x45 - 0x1D * (1 if p.get('on') else 0)) & 0xFFFF
    if name in _ONOFF:
        return (_ONOFF[name] - (1 if p.get('on') else 0)) & 0xFFFF
    return (_EXTRA.get(name) or V3_ONLY[name])[0]


# ---------------------------------------------------------------- 组帧

def build_frame(name, version=3, var1=0, var2=0, var3=0, seed=0, tx_count=0, **p):
    """构造 31 字节控制帧。

    version:   2 或 3, V3 为本 App 实际使用的版本
    seed:      16 位种子, 决定 XOR 密钥与 CRC 初值并原样写进帧尾, 任意值均可
    tx_count:  发送计数, App 每次发送后自增 (V2 从 0 起, V3 从 0x10 起)
    关键字:    var1/var2/var3 为三个通用负载; p4/p5/p6 为额外负载; on=True 表示开/绑定
    """
    if version not in (2, 3):
        raise ValueError('version must be 2 or 3')
    if name not in (V2_COMMANDS if version == 2 else V3_COMMANDS):
        raise KeyError(f'unknown command {name!r}')
    seed &= 0xFFFF
    f = bytearray(FRAME_LEN)
    f[0:7] = _BASE_HEADER
    f[7] = 0x10 if version == 2 else 0x30     # 版本标志
    f[8] = 0x80                                # 固定
    f[9] = 0x00                                # 固定
    f[10] = tx_count & 0xFF
    f[11:13] = struct.pack('<H', var1 & 0xFFFF)
    f[13:17] = struct.pack('<I', var2 & 0xFFFFFFFF)
    f[17] = var3 & 0xFF
    f[18:20] = struct.pack('<H', _cmd_of(name, p))
    f[20:24] = _extra_bytes(name, p)

    if version == 3:                          # AES-128 标签, 在 XOR 之前写入
        key = bytes([seed & 0xFF, seed >> 8, f[10]]) + V3_AES_KEY_TAIL
        tag = struct.unpack('<H', aes128_encrypt_block(key, bytes(f[8:24]))[:2])[0] or 0xFFFF
        f[24:26] = struct.pack('<H', tag)

    for i in XOR_RANGE:
        f[i] ^= XBOXES[(seed + i) & 0x1F] ^ (seed & 0xFF)
    f[27:29] = struct.pack('<H', seed)
    f[29:31] = struct.pack('<H', crc16_ccitt(bytes(f[CRC_RANGE]), (~seed) & 0xFFFF))
    return bytes(f)


def encode_v3(name, seed=0, tx_count=0, **p):
    return build_frame(name, 3, seed=seed, tx_count=tx_count, **p)


def encode_v2(name, seed=0, tx_count=0, **p):
    return build_frame(name, 2, seed=seed, tx_count=tx_count, **p)


# ---------------------------------------------------------------- 解帧

def dexor(frame, seed, subkey=0):
    """逆向 XOR 混淆, 返回明文帧 (b27..b30 未加密, 保持原值)。"""
    f = bytearray(frame)
    for i in XOR_RANGE:
        f[i] ^= XBOXES[subkey * 32 + ((seed + i) & 0x1F)] ^ (seed & 0xFF)
    return bytes(f)


def verify_frame(frame):
    """校验长度 / 16-bit UUID / CRC, 对应原生 is_ble_v3_pdu; 返回 seed 或 None。"""
    if len(frame) != FRAME_LEN or frame[5:7] != b'\xf0\x08':
        return None
    seed = struct.unpack('<H', frame[27:29])[0]
    crc = struct.pack('<H', crc16_ccitt(frame[CRC_RANGE], (~seed) & 0xFFFF))
    return seed if frame[29:31] == crc else None


def parse_frame(frame):
    """校验并解析控制帧, 返回 dict; 无效帧抛 ValueError。"""
    seed = verify_frame(frame)
    if seed is None:
        raise ValueError('not a LampSmart control frame')
    plain = dexor(frame, seed)
    return {
        'version': {0x10: 'V2', 0x30: 'V3'}.get(plain[7], plain[7]),
        'tx_count': plain[10],
        'var1': struct.unpack('<H', plain[11:13])[0],
        'var2': struct.unpack('<I', plain[13:17])[0],
        'var3': plain[17],
        'cmd': struct.unpack('<H', plain[18:20])[0],
        'extra': plain[20:24],
        'tag': struct.unpack('<H', plain[24:26])[0],
        'seed': seed,
        'crc': struct.unpack('<H', frame[29:31])[0],
        'plain': plain,
    }


def as_uuids(frame):
    """把帧 b5..b30 转成 13 个 16-bit UUID 字符串 —— App 就是这样塞进广播包的。"""
    return ['0000%04x-0000-1000-8000-00805f9b34fb' % struct.unpack_from('<H', frame, i)[0]
            for i in range(5, 31, 2)]
