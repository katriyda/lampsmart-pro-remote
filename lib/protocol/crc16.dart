/// CRC-16/CCITT：`poly = 0x1021`、MSB-first、不反射、无最终异或。
///
/// 与 `docs/reference-proto.py` 的 `crc16_ccitt` **逐行同构**（位循环而非查表），
/// 便于和 Python 参考实现对拍。标准校验值：
/// `crc16Ccitt(ascii('123456789')) == 0x29B1`。
int crc16Ccitt(List<int> data, {int init = 0xFFFF}) {
  var crc = init & 0xFFFF;
  for (final byte in data) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xFFFF
          : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}
