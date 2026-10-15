# 灯具遥控（LampSmart Pro 协议逆向迁移)

[![CI](https://github.com/katriyda/lampsmart-pro-remote/actions/workflows/ci.yml/badge.svg)](https://github.com/katriyda/lampsmart-pro-remote/actions/workflows/ci.yml)

按逆向出来的 BLE 广播协议控制灯具 / 风扇灯的**第三方 Android App**（Flutter 实现）。

原厂 App（`com.jingyuan.lamp`，Flutter + 自写 Java 插件 + 两个原生编码库）把控制命令编码成
13 个 16-bit Service UUID，用 **BLE Legacy 广播（ADV_IND）反复发送**；灯具只监听、不建连。
本项目把逆向结论完整迁移成一份可读、可测、可复现的 Dart 实现，UI 按原厂 App 的屏幕结构复刻
（图标全部现画，**不含原厂任何图片 / 字体 / 文案资源**）。

---

## ⚠️ 免责声明

- 本项目与 **景源 / Allink / LampSmart** 及其关联公司**没有任何隶属、合作或授权关系**；
  相关商标、产品名归其所有者所有。
- 本项目**仅供个人学习研究与控制自用设备**。使用前请确认你拥有该设备的合法使用权，
  并遵守所在地法律与设备厂商的服务条款。
- 仓库**不包含、也不会分发**原厂 APK 及其中的任何图片、字体、文案或其它资源；
  `docs/` 下只有逆向结论与自写的参考实现。
- 逆向出的协议没有任何实质安全保护（密钥完全由帧内 `seed` 决定），
  请勿用本项目干扰他人的设备。

---

## 为什么必须是 App

这不是「懒得做网页版」，而是**浏览器和 iOS 在物理上做不到**：

| 平台 | 能力 | 结论 |
|---|---|---|
| 浏览器（Web Bluetooth） | 只有 **central** 角色：能扫描、能连接、能读写 GATT | ❌ 协议要求发 **ADV_IND 广播**（peripheral / advertiser 角色），Web Bluetooth 至今没有广播 API（[web-bluetooth#484](https://github.com/WebBluetoothCG/web-bluetooth/issues/484) 仍未实现；[MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API) 也把 Web Bluetooth 定义为 central-only） |
| iOS（CoreBluetooth） | 可以广播，但 Apple 明确说明广播是 **best effort**，且应用层只能塞固定的 28 字节、AD 结构由系统决定 | ❌ 无法稳定发出一条 31 字节、内容自定的厂商帧 |
| Android | `BluetoothLeAdvertiser` + `AdvertiseData` 可以自定义 16-bit Service UUID 列表 | ✅ **唯一可行**，也是原厂 App 的做法 |

因此架构上只有「发送」这一件事需要 Android 平台通道，其余（协议编码、状态管理、全部 UI）
都是纯 Dart，可以在 `flutter test` 里逐字节验证。

---

## 逆向结论摘要

**指令帧固定 31 字节**，装在 13 个 16-bit Service UUID 里发出去：

| 字节 | 内容 |
|---|---|
| `b0..b4` | AD 结构模板 `02 01 02 1B 16`（Flags + Service Data 头，空中由系统协议栈重写） |
| `b5..b6` | 恒 `F0 08`（16-bit UUID `0x08F0`）——固件**唯一硬校验**的常量 |
| `b7` | 版本标志：V2 = `0x10`，V3 = `0x30`（线上 App 只走 V3） |
| `b8..b26` | 命令体（`b9..b26` 参与 XOR 混淆） |
| `b27..b28` | `seed`（决定 XOR 密钥与 CRC 初值） |
| `b29..b30` | CRC-16/CCITT，**对密文** `b7..b28` 计算，初值 `~seed` |

三重「安全」机制：

1. **XOR 混淆**：`b9..b26` 与内置 128 字节表 `XBOXES` 按位置异或，再异或 `seed & 0xFF`。
2. **CRC-16/CCITT**：`poly = 0x1021`、MSB-first、不反射、无最终异或，初值 `~seed`，在 XOR **之后**对密文计算。
3. **V3 AES 标签**：`b24..b25` = `AES-128-ECB(seed_lo ‖ seed_hi ‖ tx_count ‖ 13 字节常量, 明文 b8..b23)`
   的前 2 字节（为 0 时改写 `0xFFFF`）。密钥只差 `seed` 和 `tx_count`，等于无保护。

**13 个 UUID 的装载算法**：`b5..b30` 逐 2 字节小端解释成 u16 值，
写成 `0000xxxx-0000-1000-8000-00805f9b34fb`；因为 UUID 在空中也是小端，
这 13 个值回到空中正好逐字节还原成帧的 `b5..b30`。

完整字节表、指令表、编码顺序、XBOXES 常量见 [`docs/ble-protocol.md`](docs/ble-protocol.md)；
零依赖 Python 参考实现见 [`docs/reference-proto.py`](docs/reference-proto.py)。
Dart 实现（本 App 实际使用的）在 [`lib/protocol/`](lib/protocol/)。

---

## 功能迁移对照表（32 条 V3 指令）

这张表就是**迁移完整度的验收清单**：32 条指令每一条都有 UI 触达路径，
并且每条都有一条测试锁住 cmd 与扩展字节的映射。

证据等级：
- **[已实测]** —— 帧由 Unicorn 实际执行 APK 原生库得到输出，三方实现逐字节一致；
- **[有文案]** —— 原厂 APK 的中文字符串表里能找到对应文案；
- **[推断]** —— 原生库里存在这条指令，但原厂 App 从未调用、也没有文案（风扇 / 浴霸类）。

| # | 指令（JNI） | cmd | 证据 | 本 App 的 UI 入口 |
|---|---|---|---|---|
| 1 | `Binding` | `0x28` 绑定 / `0x45` 解绑 | [已实测] | 首页右上角「解除配对」（二次确认）· 设置页「配对 / 解除配对」 |
| 2 | `LampOnOff` | `0x10` 开 / `0x11` 关 | [已实测] | 设备弹窗 ON/OFF 药丸 · 「主灯」磁贴 · 房间开关（逐设备发） |
| 3 | `AidOnOff` | `0x12` 开 / `0x13` 关 | [已实测] | 「辅助灯」磁贴 |
| 4 | `Dimming` | `0x21` | [已实测] | 旋钮 / 亮度滑杆（带白光比例）· 色温页两条比例滑杆 |
| 5 | `DimmingNight` | `0x23` | [已实测] | 「夜灯」磁贴 |
| 6 | `TimingClose` | `0x41` | [已实测] | 「定时」磁贴 → 时/分/秒弹层（0 = 取消） |
| 7 | `RgbOnOff` | `0x1C` | [已实测] | 彩灯面板「彩灯」开关 · 设备弹窗「彩灯」磁贴 |
| 8 | `RgbAuto` | `0x1E` 开 / `0x1F` 关 | [已实测] | 彩灯面板「彩灯循环」开关 · 设备弹窗「循环」磁贴 |
| 9 | `RgbSwitch` | `0x22` | [已实测] | 彩灯面板色盘拖动 + 5 个预设色圆 |
| 10 | `AidRgbModeUp` | `0x1B`（`b21=0`） | [已实测] + [有文案] | 彩灯面板左滑切页 |
| 11 | `AidRgbModeDown` | `0x1B`（`b21=1`） | [已实测] + [有文案] | 彩灯面板右滑切页 |
| 12 | `AidBrigntness` | `0x2E` | [已实测] + [推断] | 亮度滑杆右侧图标切到「辅助灯」· 彩灯面板左旋钮 |
| 13 | `SceneSet` | `0x46` | [有文案] | 场景页长按槽位 →「保存当前状态到该场景」 |
| 14 | `SceneSwitch` | `0x47` | [有文案] | 场景页点按槽位 |
| 15 | `SceneReset` | `0x48` | [推断] | 场景页长按槽位 →「复位该场景」 |
| 16 | `SceneOn` | `0x10`（`b21=1`） | [推断] | 场景页长按槽位 →「启用场景」 |
| 17 | `GenericOnOff` | `0x6F` | [推断] | 设置页「通用开关」 |
| 18 | `FanMode` | `0x33` | [推断] | 风扇面板「常风 / 自然风 / 睡眠」 |
| 19 | `FanSpeed` | `0x31` | [推断] | 风扇面板档位滑杆 0..12 |
| 20 | `FanSwayOnOff` | `0x16` | [推断] | 风扇面板 / 设备弹窗「摆风」 |
| 21 | `WindDircOnOff` | `0x15` | [推断] | 「导风」磁贴 |
| 22 | `SwingOnOff` | `0xB0` | [推断] | 「摇头」磁贴 |
| 23 | `WarmOnOff` | `0x66` | [推断] | 风扇面板「更多指令」→ 暖风两参数 |
| 24 | `Ventilation` | `0x67` | [推断] | 「更多指令」→ 通风档位 |
| 25 | `DryOnOff` | `0x69` | [推断] | 「更多指令」→ 烘干 |
| 26 | `BathOnOff` | `0x68` | [推断] | 「更多指令」→ 浴霸 |
| 27 | `Temperature` | `0x52` | [推断] | 「更多指令」→ 温度两参数 |
| 28 | `AidSpeed` | `0xE4` | [推断] | 「更多指令」→ 辅助风速 |
| 29 | `AidPotUP` | `0x2F`（`b21=4`） | [推断] | 「更多指令」→ 档位 +1 |
| 30 | `AidPotDown` | `0x2F`（`b21=3`） | [推断] | 「更多指令」→ 档位 −1 |
| 31 | `AidPotAuto` | `0x2F`（`b21=1`） | [推断] | 「更多指令」→ 档位自动 |
| 32 | `AidPotEdit` | `0x2F`（`b21=2`） | [推断] | 「更多指令」→ 档位直接设定 |

> **风险提示**：第 18–32 条属于「原生库里有、原厂 App 从来没调用过」的一批
> （原厂界面文案里完全没有「风扇 / 浴霸 / 干衣 / 暖风 / 摆风 / 档位 / 温度」等字样）。
> 照发**未必有设备响应**，所以风扇面板顶部常驻一条「未在真机验证」的警示条。
> 如果真机确认无响应，删掉这 15 条不影响灯 / 彩灯 / 场景功能。
>
> 另外两处**语义未验证**的假设：`FanSpeed` 的档位与风量取同值（`b21 = b22 = 档位`，
> 0 视为关闭）；彩灯亮度复用了 `AidBrigntness`（协议里唯一可写的亮度指令）。

**全部 32 条指令在「原始指令」调试页里也都有一条通用出口**（选指令 + on + p4/p5/p6 → 发送）。

---

## 技术选型

| 方案 | 结论 |
|---|---|
| **Flutter 3.x（Dart）** | **采用。** 原厂 App 本身就是 Flutter；协议层是纯计算，可以用 `flutter test` 逐字节验证；旋钮 / 色盘用 `CustomPainter` 跨端；CI 一条命令出 APK。 |
| React Native / Expo | **否。** Expo 没有 BLE 广播能力，仍要自写 Android 原生模块；CI 还要额外装 Node + Android 工具链。 |
| Kotlin Multiplatform | **否。** 为百余行广播逻辑引入整套跨平台 Gradle 体系不划算，UI 还得全自写。 |

落到目录结构：

```
lib/protocol/   纯 Dart 协议层（xboxes / crc16 / aes128 / command / frame）
lib/transport/  发送通道：抽象接口 + Android 实现 + 非 Android 的明确报错
android/…/AdvertiserPlugin.kt   唯一需要写原生代码的地方（约 120 行）
lib/data/ lib/state/            本地分组与发送状态
lib/ui/                         按原厂屏幕结构复刻的界面
test/                           金向量对拍 + 算法 KAT + 映射断言 + 界面冒烟
tools/gen_vectors.py            测试夹具的唯一生成源（CI 用它卡住夹具漂移）
```

---

## 安装使用

1. 到 [Releases](https://github.com/katriyda/lampsmart-pro-remote/releases) 下载 `lampsmart-*-release.apk` 并安装。
   （APK 用 debug key 签名，适合自用；自行签名的步骤见下一节。）
2. 给 App 授予「附近的设备」权限（Android 12+ 需要 `BLUETOOTH_ADVERTISE`）。
3. **配对**：设备通电后 **5 秒内**点首页右上角或设置页的「配对」。
   灯具闪烁或鸣叫即表示配对成功（依据原厂文案）。
4. 在首页 `+` 里添加设备。**注意：房间与设备只是本地分组**——
   协议帧里没有寻址字段，灯具会响应任何合法帧，所以「关掉 A 房间」
   实际是给该房间里的每台设备各发一次 `lampOnOff(false)`。
5. 点设备卡片打开控制弹窗：旋钮 / 滑杆调亮度，磁贴切白光、黄光、夜灯、彩灯、定时、循环、辅助灯；
   彩灯与风扇设备会多出对应面板入口。

### 真机「不响应」时先调这三个值

帧里的 `var1`(u16) / `var2`(u32) / `var3`(u8) 在原 App 里传什么**没有解出来**，
固件侧也不校验（`is_ble_v3_pdu` 只看长度、`b5..b6` 和 CRC）。
本 App 默认全 0，并在**设置 → 高级参数**里做成可配置（十六进制输入）。
如果设备没反应，第一件事就是按你的设备型号试这几个值。

同理，**重发次数**（默认 3）与**单包时长**（默认 300 ms）也未解出，
在设置页可调（原厂的 `SendThread` 循环次数没能可靠解码）。

---

## 本地构建

```bash
mise install          # 按 mise.toml 装 Flutter 3.47.7
flutter pub get
flutter test          # 协议金向量 + 算法 KAT + 映射断言 + 界面冒烟，共 55 个用例
flutter analyze
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/app-release.apk`。
Release 默认用 debug key 签名；要换成自己的签名，参照
[`android/key.properties.example`](android/key.properties.example) 新建 `android/key.properties`
并在 `android/app/build.gradle.kts` 里配置（该文件已在 `.gitignore` 里）。

浏览器预览 UI（发不出帧，但界面可看）：

```bash
flutter build web
python -m http.server 8787 --directory build/web
```

---

## CI / 发布

- `.github/workflows/ci.yml`：push / PR / 手动触发。
  `dart format --set-exit-if-changed` → `flutter analyze --fatal-infos` →
  用 Python 参考实现重新生成测试夹具并 `git diff --exit-code`（**夹具漂移即失败**）→
  `flutter test` → `flutter build apk --debug` → 上传 artifact。
- `.github/workflows/release.yml`：推 `v*` 标签（或手动触发）→ 构建 release APK → 发到 GitHub Release。
- 两条流水线只用公开 runner，**不需要任何 secret**。

## 测试怎么保证协议是对的

- `tools/gen_vectors.py` 载入 `docs/reference-proto.py`，按报告 §6.1 的金向量入参
  （`var1=0x1234, var2=0x123456789ABCDEF0, var3=0x34, tx_count=0x42, seed=0x6BE9`）
  生成 32 条指令的密文，**并与报告表格里逐字抄下来的明文 / 密文两列比对**，
  对不上就直接报错退出；比对通过才写出 `test/gold_vectors.dart`。
- `test/gold_vectors_test.dart` 用 Dart 实现重算这 32 条，密文与明文都要逐字节相同，
  另加一条硬编码断言：开灯帧必须等于报告 §3.3 的
  `0201021b16f0083080ca68c56d1cad52615d1b02ce5b9c5e1129cfe96b3ce6`。
- `test/crypto_test.dart`：CRC-16/CCITT 标准校验值 `0x29B1` + FIPS-197 附录 C 的 AES-128 KAT。
- `test/frame_test.dart`：往返解析、13 个 UUID 与 `b5..b30` 的互推、四组负例（改 CRC / 长度 / UUID / 版本）。
- `test/lamp_controller_test.dart`：32 条指令的 cmd 与扩展字节映射逐条断言。
