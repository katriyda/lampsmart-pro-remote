import 'package:flutter/material.dart';

import '../state/app_settings.dart';
import '../state/lamp_controller.dart';
import 'app_scope.dart';
import 'dialogs.dart';
import 'theme.dart';

/// 设置页：配对 / 高级参数 / 发送参数 / 权限 / 通用开关 / 免责声明。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _generic = false;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final AppSettings settings = scope.settings;
    final LampController controller = scope.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[settings, controller]),
        builder: (BuildContext context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '配对',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '设备通电后 5 秒内点「配对」；灯具闪烁或鸣叫即表示配对成功。'
                      '解除配对后其它手机才能重新配对。',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: controller.bind,
                            child: const Text('配对'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: danger,
                            ),
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
                            child: const Text('解除配对'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '高级参数',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '原 App 传什么没有解出来，固件也不校验。真机「不响应」时第一件事就是调这三个值。',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    HexField(
                      label: 'var1 (u16)',
                      value: settings.var1,
                      onChanged: settings.setVar1,
                    ),
                    const SizedBox(height: 8),
                    HexField(
                      label: 'var2 (u32)',
                      value: settings.var2,
                      onChanged: settings.setVar2,
                    ),
                    const SizedBox(height: 8),
                    HexField(
                      label: 'var3 (u8)',
                      value: settings.var3,
                      onChanged: settings.setVar3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'seed = 0x${settings.seed.toRadixString(16).toUpperCase().padLeft(4, '0')}（首启随机后固定）',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '发送参数',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const SizedBox(width: 64, child: Text('重发次数')),
                        Expanded(
                          child: Slider(
                            value: settings.repeats.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            activeColor: accent,
                            label: '${settings.repeats}',
                            onChanged: (double v) =>
                                settings.setRepeats(v.round()),
                          ),
                        ),
                        SizedBox(width: 28, child: Text('${settings.repeats}')),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        const SizedBox(width: 64, child: Text('单包时长')),
                        Expanded(
                          child: Slider(
                            value: settings.durationMs.toDouble(),
                            min: 100,
                            max: 1000,
                            divisions: 18,
                            activeColor: accent,
                            label: '${settings.durationMs}ms',
                            onChanged: (double v) =>
                                settings.setDurationMs((v / 50).round() * 50),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text('${settings.durationMs}ms'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.power_settings_new),
                title: const Text('通用开关 GenericOnOff'),
                subtitle: const Text('厂商留给其它功能的通用通道'),
                value: _generic,
                onChanged: (bool v) {
                  setState(() => _generic = v);
                  controller.setGeneric(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  controller.permissionGranted
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: controller.permissionGranted ? accent : danger,
                ),
                title: Text(
                  controller.permissionGranted ? '已授权广播权限' : '未授权广播权限',
                ),
                subtitle: Text(controller.platformLabel),
                trailing: controller.permissionGranted
                    ? null
                    : TextButton(
                        onPressed: controller.ensurePermission,
                        child: const Text('申请'),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('免责声明'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: '灯具遥控',
                  applicationLegalese:
                      '本项目与景源 / Allink / LampSmart 无任何隶属或授权关系，相关商标归其所有者所有。'
                      '仅供个人学习与自用设备控制，不含原厂 APK 及其任何图片 / 字体 / 文案资源的再分发。'
                      '使用者须遵守所在地法律与设备厂商条款。',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
