import 'package:flutter/material.dart';

import '../data/device_models.dart';
import 'app_scope.dart';
import 'theme.dart';

/// 二次确认对话框。破坏性操作走 [danger]。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: surfaceAlt,
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: destructive ? danger : accent),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 单行文本输入对话框（重命名用）。
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final TextEditingController controller = TextEditingController(
    text: initialValue,
  );
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: surfaceAlt,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '名称'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 添加设备底部弹层：名称 + 五种设备类型。
Future<void> addDeviceSheet(BuildContext context, {required Room room}) {
  final TextEditingController nameController = TextEditingController();
  DeviceType type = DeviceType.rgbFanLamp;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '添加设备到「${room.name}」',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '设备名称'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final DeviceType t in DeviceType.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: type == t,
                      onSelected: (_) => setSheetState(() => type = t),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final String name = nameController.text.trim();
                    AppScope.of(context).store.addDevice(
                      room,
                      name.isEmpty ? type.label : name,
                      type,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('添加'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 添加房间底部弹层。
Future<void> addRoomSheet(BuildContext context) {
  final TextEditingController nameController = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '添加房间',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '房间名称'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final String name = nameController.text.trim();
                AppScope.of(sheetContext).store
                    .addRoom(name.isEmpty ? '新房间' : name);
                Navigator.of(sheetContext).pop();
              },
              child: const Text('添加'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 十六进制输入框：非法输入不保存并红字提示（设置页的 var1/var2/var3）。
class HexField extends StatefulWidget {
  const HexField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final void Function(int value) onChanged;

  @override
  State<HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<HexField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.toRadixString(16).toUpperCase(),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final String text = raw.trim().replaceFirst(RegExp('^0[xX]'), '');
    if (text.isEmpty) {
      setState(() => _error = '不能为空');
      return;
    }
    final int? parsed = int.tryParse(text, radix: 16);
    if (parsed == null) {
      setState(() => _error = '非法十六进制');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _commit,
      onSubmitted: _commit,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _error,
        prefixText: '0x',
      ),
    );
  }
}
