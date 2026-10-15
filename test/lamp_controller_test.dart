import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/protocol/command.dart';
import 'package:lampsmart/protocol/frame.dart';
import 'package:lampsmart/state/app_settings.dart';
import 'package:lampsmart/state/lamp_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_transport.dart';

class _Harness {
  _Harness(this.transport, this.settings, this.controller);

  final FakeTransport transport;
  final AppSettings settings;
  final LampController controller;

  int get lastCmd => transport.lastCmd;
  List<int> get lastExtra => transport.lastExtra;
}

Future<_Harness> _harness() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs, random: Random(7));
  await settings.load();
  final transport = FakeTransport();
  return _Harness(
    transport,
    settings,
    LampController(transport: transport, settings: settings),
  );
}

void main() {
  group('灯类映射', () {
    test('亮度 60 + 白 100 / 黄 0 → dimming extra [0,0,60,0]', () async {
      final h = await _harness();
      await h.controller.setBrightness(60, whiteRatio: 100, yellowRatio: 0);
      expect(h.lastCmd, 0x21);
      expect(h.lastExtra, <int>[0, 0, 60, 0]);
    });

    test('亮度 60 + 白 50 / 黄 50 → dimming extra [0,0,30,30]', () async {
      final h = await _harness();
      await h.controller.setBrightness(60, whiteRatio: 50, yellowRatio: 50);
      expect(h.lastCmd, 0x21);
      expect(h.lastExtra, <int>[0, 0, 30, 30]);
    });

    test('色温页改比例仍发 dimming，并按亮度换算', () async {
      final h = await _harness();
      await h.controller.setColorTempRatio(30, 70, brightness: 100);
      expect(h.lastCmd, 0x21);
      expect(h.lastExtra, <int>[0, 0, 30, 70]);
    });

    test('setPower(true/false) → cmd 0x10 / 0x11', () async {
      final h = await _harness();
      await h.controller.setPower(true);
      expect(h.lastCmd, 0x10);
      await h.controller.setPower(false);
      expect(h.lastCmd, 0x11);
    });

    test('辅助灯 → cmd 0x12 / 0x13，辅助灯亮度 → cmd 0x2E', () async {
      final h = await _harness();
      await h.controller.setAuxPower(true);
      expect(h.lastCmd, 0x12);
      await h.controller.setAuxBrightness(40);
      expect(h.lastCmd, 0x2E);
      expect(h.lastExtra, <int>[0, 3, 40, 0]);
    });

    test('夜灯 → cmd 0x23', () async {
      final h = await _harness();
      await h.controller.setNightMode();
      expect(h.lastCmd, 0x23);
    });

    test('彩灯开关 / 循环 / 颜色 / 模式', () async {
      final h = await _harness();
      await h.controller.setRgbPower(true);
      expect(h.lastCmd, 0x1C);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
      await h.controller.setRgbPower(false);
      expect(h.lastExtra, <int>[0, 0, 0, 0]);

      await h.controller.setRgbAuto(true);
      expect(h.lastCmd, 0x1E);
      await h.controller.setRgbAuto(false);
      expect(h.lastCmd, 0x1F);

      await h.controller.setRgbColor(255, 0, 0);
      expect(h.lastCmd, 0x22);
      expect(h.lastExtra, <int>[0, 255, 0, 0]);

      await h.controller.cycleRgbMode(true);
      expect(h.lastCmd, 0x1B);
      expect(h.lastExtra, <int>[0, 0, 0, 0]);
      await h.controller.cycleRgbMode(false);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
    });

    test('定时 90 分钟 → timingClose 秒数 5400 = 0x1518', () async {
      final h = await _harness();
      await h.controller.setTimer(90 * 60);
      expect(h.lastCmd, 0x41);
      expect(h.lastExtra, <int>[0, 0x18, 0x15, 0]);
    });

    test('定时被夹在 0..65535 秒', () async {
      final h = await _harness();
      await h.controller.setTimer(70000);
      expect(h.lastExtra, <int>[0, 0xFF, 0xFF, 0]);
      await h.controller.setTimer(-5);
      expect(h.lastExtra, <int>[0, 0, 0, 0]);
    });
  });

  group('场景类映射', () {
    test(
      'saveScene(2) → 0x46，setScene(2) → 0x47，resetScene(2) → 0x48',
      () async {
        final h = await _harness();
        await h.controller.saveScene(2);
        expect(h.lastCmd, 0x46);
        expect(h.lastExtra, <int>[0, 2, 0, 0]);
        await h.controller.setScene(2);
        expect(h.lastCmd, 0x47);
        await h.controller.resetScene(2);
        expect(h.lastCmd, 0x48);
      },
    );

    test('applyScene() → cmd 0x10 + b21=1（与主灯开区分）', () async {
      final h = await _harness();
      await h.controller.applyScene();
      expect(h.lastCmd, 0x10);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
    });

    test('通用开关 → 0x6F', () async {
      final h = await _harness();
      await h.controller.setGeneric(true);
      expect(h.lastCmd, 0x6F);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
    });

    test('bind() / unbind() → 0x28 / 0x45', () async {
      final h = await _harness();
      await h.controller.bind();
      expect(h.lastCmd, 0x28);
      await h.controller.unbind();
      expect(h.lastCmd, 0x45);
    });
  });

  group('风扇 / 浴霸类映射', () {
    test('setFanGear(5) → 0x31 extra [0,5,5,0]', () async {
      final h = await _harness();
      await h.controller.setFanGear(5);
      expect(h.lastCmd, 0x31);
      expect(h.lastExtra, <int>[0, 5, 5, 0]);
    });

    test('setFanMode(2) → 0x33 extra [0,2,0,0]', () async {
      final h = await _harness();
      await h.controller.setFanMode(2);
      expect(h.lastCmd, 0x33);
      expect(h.lastExtra, <int>[0, 2, 0, 0]);
    });

    test('setFanSway(true) → 0x16，setWindDir → 0x15，setSwing → 0xB0', () async {
      final h = await _harness();
      await h.controller.setFanSway(true);
      expect(h.lastCmd, 0x16);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
      await h.controller.setWindDir(true);
      expect(h.lastCmd, 0x15);
      await h.controller.setSwing(true);
      expect(h.lastCmd, 0xB0);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
    });

    test('setFanPot(3) → 0x2F extra [0,2,3,0]', () async {
      final h = await _harness();
      await h.controller.setFanPot(3);
      expect(h.lastCmd, 0x2F);
      expect(h.lastExtra, <int>[0, 2, 3, 0]);
    });

    test('setFanPot(0x1234) → b22/b23 为低/高字节', () async {
      final h = await _harness();
      await h.controller.setFanPot(0x1234);
      expect(h.lastExtra, <int>[0, 2, 0x34, 0x12]);
    });

    test('档位 +1 / −1 / 自动 靠 b21 区分', () async {
      final h = await _harness();
      await h.controller.fanPotUp();
      expect(h.lastExtra, <int>[0, 4, 0, 0]);
      await h.controller.fanPotDown();
      expect(h.lastExtra, <int>[0, 3, 0, 0]);
      await h.controller.fanPotAuto();
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
      expect(h.lastCmd, 0x2F);
    });

    test('辅助风速 / 暖风 / 通风 / 温度', () async {
      final h = await _harness();
      await h.controller.setAuxSpeed(3);
      expect(h.lastCmd, 0xE4);
      expect(h.lastExtra, <int>[0, 0, 3, 0]);
      await h.controller.sendWarm(2, 5);
      expect(h.lastCmd, 0x66);
      expect(h.lastExtra, <int>[0, 2, 5, 0]);
      await h.controller.sendVentilation(1);
      expect(h.lastCmd, 0x67);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
      await h.controller.setTemperature(25, 1);
      expect(h.lastCmd, 0x52);
      expect(h.lastExtra, <int>[0, 25, 1, 0]);
    });

    test('烘干 / 浴霸', () async {
      final h = await _harness();
      await h.controller.setDry(true);
      expect(h.lastCmd, 0x69);
      expect(h.lastExtra, <int>[0, 1, 0, 0]);
      await h.controller.setBath(true);
      expect(h.lastCmd, 0x68);
    });
  });

  group('发送链路', () {
    test('sendRaw 走同一条路径，lastFrame 与 13 个 UUID 可用', () async {
      final h = await _harness();
      await h.controller.sendRaw(Command.aidPotEdit, p4: 3);
      expect(h.lastExtra, <int>[0, 2, 3, 0]);
      expect(h.controller.lastFrameUuids.length, 13);
      expect(
        h.controller.lastFrameUuids.first,
        '000008f0-0000-1000-8000-00805f9b34fb',
      );
      expect(h.controller.lastFrameInfo!['cmd'], 0x2F);
      expect(h.controller.log.first.label, contains('AidPotEdit'));
    });

    test('tx_count 每帧自增并写进帧里', () async {
      final h = await _harness();
      await h.controller.sendRaw(Command.lampOnOff, on: true);
      final int first = parseFrame(h.transport.last)!['txCount'] as int;
      await h.controller.sendRaw(Command.lampOnOff, on: true);
      final int second = parseFrame(h.transport.last)!['txCount'] as int;
      expect(second, (first + 1) & 0xFF);
    });

    test('重发次数与单包时长来自设置', () async {
      final h = await _harness();
      h.settings.setRepeats(5);
      h.settings.setDurationMs(500);
      await h.controller.setPower(true);
      expect(h.transport.lastRepeats, 5);
      expect(h.transport.lastDurationMs, 500);
    });

    test('失败记 lastError 并进日志，不抛', () async {
      final h = await _harness();
      h.transport.failure = advertiseFailure(3);
      await h.controller.setPower(true);
      expect(h.controller.lastError, contains('未能启动'));
      expect(h.controller.log.first.ok, isFalse);
      expect(h.controller.log.first.error, contains('未能启动'));
      h.controller.clearError();
      expect(h.controller.lastError, isNull);
    });

    test('节流：窗口内只发最后一帧，endGesture 补发', () async {
      final h = await _harness();
      await h.controller.setBrightness(10);
      await h.controller.setBrightness(20);
      await h.controller.setBrightness(30);
      expect(h.transport.frames.length, 1);
      await h.controller.endGesture();
      expect(h.transport.frames.length, 2);
      expect(h.transport.lastExtra, <int>[0, 0, 30, 0]);
    });
  });
}
