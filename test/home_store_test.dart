import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lampsmart/data/device_models.dart';
import 'package:lampsmart/data/home_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HomeStore> _loaded() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final store = HomeStore(prefs);
  await store.load();
  return store;
}

Future<List<dynamic>> _persisted(SharedPreferences prefs) async {
  return jsonDecode(prefs.getString(HomeStore.storageKey)!) as List<dynamic>;
}

void main() {
  test('首次启动写入默认数据：客厅 + 灯具', () async {
    final store = await _loaded();
    expect(store.rooms.length, 1);
    expect(store.rooms.first.name, '客厅');
    expect(store.rooms.first.devices.length, 1);
    expect(store.rooms.first.devices.first.name, '灯具');
    expect(store.deviceCount, 1);
    // 已经写进存储，第二次 load 读到的是同一份
    final again = HomeStore((await SharedPreferences.getInstance()));
    await again.load();
    expect(again.rooms.first.name, '客厅');
    expect(again.rooms.first.devices.single.type, DeviceType.rgbFanLamp);
  });

  test('增删改后 JSON 往返一致', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = HomeStore(prefs);
    await store.load();

    final room = store.addRoom('卧室');
    store.addDevice(room, '吊灯', DeviceType.fanLamp);
    store.addDevice(room, '灯带', DeviceType.rgbLamp);
    store.renameRoom(room, '次卧');
    store.renameDevice(room.devices.first, '主吊灯');
    await Future<void>.delayed(Duration.zero);

    final reloaded = HomeStore(prefs);
    await reloaded.load();
    expect(reloaded.rooms.map((Room r) => r.name), <String>['客厅', '次卧']);
    final Room second = reloaded.rooms[1];
    expect(second.devices.map((Device d) => d.name), <String>['主吊灯', '灯带']);
    expect(second.devices.map((Device d) => d.type), <DeviceType>[
      DeviceType.fanLamp,
      DeviceType.rgbLamp,
    ]);

    // 设备增删
    store.removeDevice(room, room.devices.last);
    await Future<void>.delayed(Duration.zero);
    final afterDeviceDelete = HomeStore(prefs);
    await afterDeviceDelete.load();
    expect(afterDeviceDelete.rooms[1].devices.length, 1);

    // 房间删除（最后一个房间保留）
    store.removeRoom(room);
    await Future<void>.delayed(Duration.zero);
    expect(store.removeRoom(store.rooms.last), isFalse);
    final afterRoomDelete = HomeStore(prefs);
    await afterRoomDelete.load();
    expect(afterRoomDelete.rooms.length, 1);
    expect(afterRoomDelete.rooms.first.name, '客厅');
  });

  test('删除按钮会通知监听者', () async {
    final store = await _loaded();
    var notified = 0;
    store.addListener(() => notified++);
    store.renameRoom(store.rooms.first, '起居室');
    expect(notified, 1);
    await _persisted(await SharedPreferences.getInstance());
    expect(store.rooms.first.name, '起居室');
  });

  test('损坏的存储内容不会崩（缺字段回落到 lamp）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      HomeStore.storageKey: '[{"id":"r1","name":"房","devices":[{"id":"d1"}]}]',
    });
    final store = HomeStore(await SharedPreferences.getInstance());
    await store.load();
    expect(store.rooms.single.name, '房');
    expect(store.rooms.single.devices.single.type, DeviceType.lamp);
  });
}
