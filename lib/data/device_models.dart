/// 设备类型，决定这个设备显示哪些面板。
///
/// 只是本地分组标签：**协议帧里没有寻址字段**，灯具会响应任何合法帧
/// （报告 §0、§7），所以这里的类型不影响发出去的字节。
enum DeviceType {
  lamp('灯具', hasRgb: false, hasFan: false),
  rgbLamp('彩灯', hasRgb: true, hasFan: false),
  fanLamp('风扇灯', hasRgb: false, hasFan: true),
  rgbFanLamp('彩灯风扇灯', hasRgb: true, hasFan: true),
  bathHeater('浴霸', hasRgb: false, hasFan: true);

  const DeviceType(this.label, {required this.hasRgb, required this.hasFan});

  final String label;

  /// 是否显示彩灯面板 / 彩灯相关指令。
  final bool hasRgb;

  /// 是否显示风扇面板 / 风扇相关指令。
  final bool hasFan;
}

/// 一台设备。
class Device {
  Device({required this.id, required this.name, required this.type});

  final String id;
  String name;
  DeviceType type;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'type': type.name,
  };
  static Device fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名',
    type: DeviceType.values.firstWhere(
      (DeviceType t) => t.name == json['type'],
      orElse: () => DeviceType.lamp,
    ),
  );
}

/// 一个房间（纯本地分组）。
class Room {
  Room({required this.id, required this.name, List<Device>? devices})
    : devices = devices ?? <Device>[];

  final String id;
  String name;
  final List<Device> devices;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'devices': devices.map((Device d) => d.toJson()).toList(),
  };

  static Room fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名房间',
    devices: <Device>[
      for (final dynamic d
          in (json['devices'] as List<dynamic>? ?? <dynamic>[]))
        Device.fromJson(d as Map<String, dynamic>),
    ],
  );
}
