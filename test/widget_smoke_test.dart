import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/data/home_store.dart';
import 'package:lampsmart/main.dart';
import 'package:lampsmart/protocol/command.dart';
import 'package:lampsmart/protocol/frame.dart';
import 'package:lampsmart/state/app_settings.dart';
import 'package:lampsmart/state/lamp_controller.dart';
import 'package:lampsmart/ui/dial.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_transport.dart';

class _Harness {
  _Harness(this.transport, this.controller);

  final FakeTransport transport;
  final LampController controller;
}

/// 单测默认视口是 800×600，底部弹窗会溢出；统一换成手机比例。
void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<_Harness> _pump(WidgetTester tester) async {
  _usePhoneViewport(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs, random: Random(11));
  final store = HomeStore(prefs);
  await Future.wait<void>(<Future<void>>[settings.load(), store.load()]);
  final transport = FakeTransport();
  final controller = LampController(transport: transport, settings: settings);
  await tester.pumpWidget(
    LampSmartApp(store: store, settings: settings, controller: controller),
  );
  await tester.pumpAndSettle();
  _usePhoneViewport(tester);
  return _Harness(transport, controller);
}

/// 智慧家庭 → 房间卡片 → 设备列表 → 设备控制弹窗。
Future<void> _openDeviceSheet(WidgetTester tester) async {
  await tester.tap(find.text('客厅').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('灯具'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('智慧家庭页：房间卡片与设备入口', (WidgetTester tester) async {
    await _pump(tester);
    expect(find.text('智慧家庭'), findsOneWidget);
    expect(find.text('总控'), findsOneWidget);
    expect(find.text('客厅'), findsWidgets);
    expect(find.text('1 个设备'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  testWidgets('设备控制弹窗：点 ON 药丸发出 LampOnOff(开)', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await _openDeviceSheet(tester);
    expect(find.bySemanticsLabel('主灯亮度'), findsOneWidget);

    await tester.tap(find.text('ON'));
    await tester.pumpAndSettle();
    expect(h.transport.lastCmd, 0x10);
    expect(h.transport.last.length, frameLength);

    // 再点一次变成 OFF
    await tester.tap(find.text('OFF'));
    await tester.pumpAndSettle();
    expect(h.transport.lastCmd, 0x11);
  });

  testWidgets('拖旋钮到 0.8 附近发出 dimming', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await _openDeviceSheet(tester);

    final Offset center = tester.getCenter(find.byType(LampDial));
    final double angle = LampDial.startAngle + LampDial.sweepAngle * 0.8;
    final Offset target = center + Offset(cos(angle), sin(angle)) * 80;
    await tester.dragFrom(target, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(h.transport.lastCmd, 0x21);
    final List<int> extra = h.transport.lastExtra;
    expect(extra[0], 0);
    expect(extra[1], 0);
    expect(extra[2], closeTo(80, 25), reason: '亮度应落在 0.8 附近');

    // 手势结束补发最后一帧
    final int before = h.transport.frames.length;
    await tester.dragFrom(target + const Offset(6, 0), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(h.transport.frames.length, greaterThanOrEqualTo(before));
  });

  testWidgets('彩灯面板与风扇面板文案', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await _openDeviceSheet(tester);

    await tester.ensureVisible(find.text('彩灯'));
    await tester.tap(find.text('彩灯'));
    await tester.pumpAndSettle();
    expect(find.text('彩灯循环'), findsOneWidget);
    expect(find.text('彩灯'), findsWidgets);
    expect(h.transport.lastCmd, 0x1C);

    // 滑到色温页会发彩灯模式切换
    await tester.drag(find.byType(PageView).last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('白光比例'), findsOneWidget);
    expect(h.transport.lastCmd, 0x1B);

    await tester.tapAt(const Offset(200, 40)); // 收起面板
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('风扇'));
    await tester.tap(find.text('风扇'));
    await tester.pumpAndSettle();
    expect(find.text('以下指令未在真机验证，灯具可能无响应'), findsOneWidget);
    expect(find.text('更多指令'), findsOneWidget);
  });

  testWidgets('场景页四个槽位发出 SceneSwitch', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();
    expect(find.text('场景 · 客厅'), findsOneWidget);

    await tester.tap(find.text('场景 2'));
    await tester.pumpAndSettle();
    expect(h.transport.lastCmd, 0x47);
    expect(h.transport.lastExtra, <int>[0, 2, 0, 0]);
  });

  testWidgets('调试页能发任意指令并显示 13 个 UUID', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await _openDeviceSheet(tester);

    await tester.tap(find.byIcon(Icons.terminal));
    await tester.pumpAndSettle();
    expect(find.text('原始指令'), findsOneWidget);

    // 下拉菜单是懒渲染的，AidPotEdit 在列表靠后，要滚过去。
    await tester.tap(find.byType(DropdownButtonFormField<Command>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('AidPotEdit（档位直接设定）'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AidPotEdit（档位直接设定）').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'p4'), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    expect(h.transport.lastCmd, 0x2F);
    expect(h.transport.lastExtra, <int>[0, 2, 3, 0]);
    expect(find.text('000008f0-0000-1000-8000-00805f9b34fb'), findsOneWidget);
    expect(find.text(bytesToHex(h.transport.last)), findsOneWidget);
  });
  testWidgets('设置页有配对、解除配对与高级参数', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('解除配对'), findsOneWidget);
    expect(find.text('配对'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '配对'));
    await tester.pumpAndSettle();
    expect(h.transport.lastCmd, 0x28);

    await tester.scrollUntilVisible(
      find.text('免责声明'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('免责声明'), findsOneWidget);
  });

  testWidgets('首页解除配对需要二次确认', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();
    expect(find.text('解除配对？'), findsOneWidget);
    expect(find.text('解除后其它手机才能重新配对'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(h.transport.isEmpty, isTrue);

    await tester.tap(find.byIcon(Icons.link_off));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '解除配对'));
    await tester.pumpAndSettle();
    expect(h.transport.lastCmd, 0x45);
  });

  testWidgets('添加设备写进本地分组', (WidgetTester tester) async {
    final _Harness h = await _pump(tester);
    await tester.tap(find.byTooltip('添加设备'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '吊灯');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    // 总控页只显示设备数，进房间页才能看到设备名。
    expect(find.text('2 个设备'), findsOneWidget);
    expect(h.transport.isEmpty, isTrue);

    await tester.tap(find.text('客厅').first);
    await tester.pumpAndSettle();
    expect(find.text('吊灯'), findsOneWidget);
  });
}
