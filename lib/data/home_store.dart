import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_models.dart';

/// 房间 / 设备的本地数据（`shared_preferences` 的 `rooms` 键）。
///
/// 首次启动写入默认数据：一个房间「客厅」+ 一个设备「灯具」。
class HomeStore extends ChangeNotifier {
  HomeStore(this._prefs);

  static const String storageKey = 'rooms';
  static const String roomIdDefault = 'room-default';
  static const String deviceIdDefault = 'device-default';

  final SharedPreferences _prefs;

  final List<Room> _rooms = <Room>[];
  int _counter = 0;

  List<Room> get rooms => List<Room>.unmodifiable(_rooms);

  int get deviceCount =>
      _rooms.fold(0, (int sum, Room r) => sum + r.devices.length);

  Room? get firstRoom => _rooms.isEmpty ? null : _rooms.first;

  Room? roomById(String? id) {
    if (id == null) {
      return null;
    }
    for (final Room r in _rooms) {
      if (r.id == id) {
        return r;
      }
    }
    return null;
  }

  Future<void> load() async {
    _rooms.clear();
    final String? raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      _rooms.add(
        Room(
          id: roomIdDefault,
          name: '客厅',
          devices: <Device>[
            Device(
              id: deviceIdDefault,
              name: '灯具',
              type: DeviceType.rgbFanLamp,
            ),
          ],
        ),
      );
      _counter = 0;
      _persist();
      return;
    }
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    for (final dynamic entry in decoded) {
      _rooms.add(Room.fromJson(entry as Map<String, dynamic>));
    }
    _counter = _rooms.length;
  }

  Room addRoom(String name) {
    final Room room = Room(id: _nextId('room'), name: name);
    _rooms.add(room);
    _persist();
    return room;
  }

  void renameRoom(Room room, String name) {
    room.name = name;
    _persist();
  }

  /// 删除房间；返回是否删掉了（最后一个房间不给删）。
  bool removeRoom(Room room) {
    if (_rooms.length <= 1 || !_rooms.remove(room)) {
      return false;
    }
    _persist();
    return true;
  }

  Device addDevice(Room room, String name, DeviceType type) {
    final Device device = Device(id: _nextId('device'), name: name, type: type);
    room.devices.add(device);
    _persist();
    return device;
  }

  void renameDevice(Device device, String name) {
    device.name = name;
    _persist();
  }

  void removeDevice(Room room, Device device) {
    if (room.devices.remove(device)) {
      _persist();
    }
  }

  String _nextId(String prefix) {
    _counter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  void _persist() {
    unawaited(_write());
    notifyListeners();
  }

  Future<void> _write() {
    return _prefs.setString(
      storageKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final Room r in _rooms) r.toJson(),
      ]),
    );
  }
}
