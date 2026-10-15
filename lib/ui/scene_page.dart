import 'package:flutter/material.dart';

import '../data/device_models.dart';
import '../state/lamp_controller.dart';
import 'app_scope.dart';

/// 场景页：当前房间 4 个场景槽。
///
/// 点按 = `SceneSwitch`，长按 = 保存 / 复位 / 启用（依据原厂文案
/// 「已将当前房间所有灯状态保存为」「逆序切换」，报告 §6.3.2）。
class ScenePage extends StatelessWidget {
  const ScenePage({super.key, required this.room});

  final Room room;

  static const int slotCount = 4;

  @override
  Widget build(BuildContext context) {
    final LampController controller = AppScope.of(context).controller;
    return Scaffold(
      appBar: AppBar(title: Text('场景 · ${room.name}')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
        ),
        itemCount: slotCount,
        itemBuilder: (BuildContext context, int index) {
          final int slot = index + 1;
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => controller.setScene(slot),
              onLongPress: () => _showSlotMenu(context, controller, slot),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '场景 $slot',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '点按切换 · 长按更多',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSlotMenu(
    BuildContext context,
    LampController controller,
    int slot,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('场景 $slot', style: const TextStyle(fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('保存当前状态到该场景'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.saveScene(slot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('复位该场景'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.resetScene(slot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('启用场景（SceneOn）'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.applyScene();
              },
            ),
          ],
        ),
      ),
    );
  }
}
