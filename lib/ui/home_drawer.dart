import 'package:flutter/material.dart';

import '../data/device_models.dart';
import 'app_scope.dart';
import 'dialogs.dart';
import 'scene_page.dart';
import 'settings_page.dart';
import 'theme.dart';

/// 智慧家庭的侧边抽屉：房间管理 + 场景 / 设置 / 关于。
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key, required this.currentRoom});

  /// 当前选中的房间（总控页时为第一个房间）。
  final Room? currentRoom;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    return Drawer(
      backgroundColor: pageBgDeep,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: scope.store,
          builder: (BuildContext context, _) => ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(color: surfaceAlt),
                child: Text(
                  '灯具遥控',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_home_outlined),
                title: const Text('添加房间'),
                onTap: () {
                  Navigator.of(context).pop();
                  addRoomSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('重命名当前房间'),
                onTap: currentRoom == null
                    ? null
                    : () async {
                        final NavigatorState navigator = Navigator.of(context);
                        final String? name = await promptText(
                          context,
                          title: '重命名房间',
                          initialValue: currentRoom!.name,
                        );
                        navigator.pop();
                        if (name != null && name.isNotEmpty) {
                          scope.store.renameRoom(currentRoom!, name);
                        }
                      },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: danger),
                title: const Text('删除房间'),
                onTap: currentRoom == null
                    ? null
                    : () async {
                        final NavigatorState navigator = Navigator.of(context);
                        final bool confirmed = await confirmDialog(
                          context,
                          title: '删除「${currentRoom!.name}」？',
                          message: '房间和它的设备分组会一起删掉',
                          confirmLabel: '删除',
                          destructive: true,
                        );
                        navigator.pop();
                        if (confirmed) {
                          scope.store.removeRoom(currentRoom!);
                        }
                      },
              ),
              const Divider(color: faintLine),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('场景'),
                onTap: currentRoom == null
                    ? null
                    : () {
                        final Room room = currentRoom!;
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                ScenePage(room: room),
                          ),
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('设置'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                onTap: () {
                  Navigator.of(context).pop();
                  showAboutDialog(
                    context: context,
                    applicationName: '灯具遥控',
                    applicationLegalese:
                        '第三方开源项目，与景源 / Allink / LampSmart 无任何隶属或授权关系。'
                        '仅供个人学习与自用设备控制，请遵守所在地法律与设备厂商条款。',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
