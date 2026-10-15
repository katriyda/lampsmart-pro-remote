import 'package:flutter/material.dart';

import '../data/device_models.dart';
import '../data/home_store.dart';
import '../state/lamp_controller.dart';
import 'app_scope.dart';
import 'device_sheet.dart';
import 'dialogs.dart';
import 'home_drawer.dart';
import 'theme.dart';

/// 智慧家庭：总控页 + 每个房间一页。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  LampController? _controller;
  String? _shownError;

  /// 每个房间上次发送的开关状态（协议不回读状态，纯本地镜像）。
  final Map<String, bool> _roomPower = <String, bool>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    if (_controller != scope.controller) {
      _controller = scope.controller;
      scope.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _tabs?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final String? error = _controller?.lastError;
    if (error == null || error == _shownError || !mounted) {
      return;
    }
    _shownError = error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    _controller?.clearError();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Room _targetRoom(HomeStore store) {
    final int index = _tabs?.index ?? 0;
    if (index == 0 || index - 1 >= store.rooms.length) {
      return store.rooms.first;
    }
    return store.rooms[index - 1];
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final HomeStore store = scope.store;
    final LampController controller = scope.controller;

    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, _) {
        final int tabCount = 1 + store.rooms.length;
        TabController? tabs = _tabs;
        if (tabs == null || tabs.length != tabCount) {
          final TabController? stale = tabs;
          if (stale != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => stale.dispose(),
            );
          }
          final int keep = (_tabs?.index ?? 0).clamp(0, tabCount - 1);
          tabs = TabController(
            length: tabCount,
            vsync: this,
            initialIndex: keep,
          )..addListener(_onTabChanged);
          _tabs = tabs;
        }

        final Room target = _targetRoom(store);

        return Scaffold(
          appBar: AppBar(
            title: const Text('智慧家庭'),
            actions: <Widget>[
              IconButton(
                tooltip: '解除配对',
                icon: const Icon(Icons.link_off),
                onPressed: () async {
                  final bool confirmed = await confirmDialog(
                    context,
                    title: '解除配对？',
                    message: '解除后其它手机才能重新配对',
                    confirmLabel: '解除配对',
                    destructive: true,
                  );
                  if (confirmed) {
                    await controller.unbind();
                  }
                },
              ),
            ],
          ),
          drawer: HomeDrawer(currentRoom: target),
          body: Column(
            children: <Widget>[
              TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: <Widget>[
                  const Tab(text: '总控'),
                  for (final Room room in store.rooms) Tab(text: room.name),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs,
                  children: <Widget>[
                    _AllRoomsView(
                      power: _roomPower,
                      onOpenRoom: (Room room) => _openRoom(store, room),
                      onToggleRoom: (Room room, bool on) =>
                          _toggleRoom(room, on),
                    ),
                    for (final Room room in store.rooms)
                      _RoomDevicesView(room: room, onOpenDevice: _openDevice),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            tooltip: '添加设备',
            onPressed: () => addDeviceSheet(context, room: target),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _openRoom(HomeStore store, Room room) {
    final int index = store.rooms.indexOf(room);
    if (index >= 0 && _tabs != null) {
      _tabs!.animateTo(index + 1);
    }
  }

  void _openDevice(Room room, Device device) {
    showDeviceSheet(context, room: room, device: device);
  }

  Future<void> _toggleRoom(Room room, bool on) async {
    _roomPower[room.id] = on;
    setState(() {});
    // 协议帧没有寻址字段：房间开关 = 逐个设备各发一帧 lampOnOff。
    for (int i = 0; i < room.devices.length; i++) {
      await _controller?.setPower(on);
    }
  }
}

/// 总控页：房间网格卡片。
class _AllRoomsView extends StatelessWidget {
  const _AllRoomsView({
    required this.power,
    required this.onOpenRoom,
    required this.onToggleRoom,
  });

  final Map<String, bool> power;
  final ValueChanged<Room> onOpenRoom;
  final void Function(Room room, bool on) onToggleRoom;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final List<Room> rooms = scope.store.rooms;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: rooms.length,
      itemBuilder: (BuildContext context, int index) {
        final Room room = rooms[index];
        return _RoomCard(
          room: room,
          power: power[room.id] ?? false,
          onOpen: () => onOpenRoom(room),
          onToggle: (bool on) => onToggleRoom(room, on),
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.power,
    required this.onOpen,
    required this.onToggle,
  });

  final Room room;
  final bool power;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                room.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${room.devices.length} 个设备',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final Device device in room.devices)
                    Tooltip(
                      message: device.name,
                      child: Icon(
                        switch (device.type) {
                          DeviceType.lamp => Icons.lightbulb_outline,
                          DeviceType.rgbLamp => Icons.palette_outlined,
                          DeviceType.fanLamp => Icons.toys_outlined,
                          DeviceType.rgbFanLamp => Icons.wb_twilight,
                          DeviceType.bathHeater => Icons.bathtub_outlined,
                        },
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '房间开关',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Switch(value: power, onChanged: onToggle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 房间页：设备列表。
class _RoomDevicesView extends StatelessWidget {
  const _RoomDevicesView({required this.room, required this.onOpenDevice});

  final Room room;
  final void Function(Room room, Device device) onOpenDevice;

  @override
  Widget build(BuildContext context) {
    if (room.devices.isEmpty) {
      return const Center(
        child: Text('这个房间还没有设备', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: room.devices.length,
      itemBuilder: (BuildContext context, int index) {
        final Device device = room.devices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(switch (device.type) {
              DeviceType.lamp => Icons.lightbulb_outline,
              DeviceType.rgbLamp => Icons.palette_outlined,
              DeviceType.fanLamp => Icons.toys_outlined,
              DeviceType.rgbFanLamp => Icons.wb_twilight,
              DeviceType.bathHeater => Icons.bathtub_outlined,
            }, color: accent),
            title: Text(device.name),
            subtitle: Text(device.type.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenDevice(room, device),
          ),
        );
      },
    );
  }
}
