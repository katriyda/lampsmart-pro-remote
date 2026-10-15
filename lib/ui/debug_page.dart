import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../protocol/command.dart';
import '../protocol/frame.dart';
import '../state/lamp_controller.dart';
import 'app_scope.dart';
import 'theme.dart';

/// 原始指令发送器 + 帧日志：全部 32 条指令在这里都有一条触达路径。
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  static const int logShown = 20;

  Command _command = Command.lampOnOff;
  bool _on = true;
  final TextEditingController _p4 = TextEditingController(text: '0');
  final TextEditingController _p5 = TextEditingController(text: '0');
  final TextEditingController _p6 = TextEditingController(text: '0');

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _p4,
      _p5,
      _p6,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final LampController controller = AppScope.of(context).controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('原始指令'),
        actions: <Widget>[
          IconButton(
            tooltip: '复制当前帧',
            onPressed: controller.lastFrame == null
                ? null
                : () => Clipboard.setData(
                    ClipboardData(text: bytesToHex(controller.lastFrame!)),
                  ),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<Command>(
              initialValue: _command,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '指令'),
              items: <DropdownMenuItem<Command>>[
                for (final Command c in Command.values)
                  DropdownMenuItem<Command>(
                    value: c,
                    child: Text(
                      '${c.jni}（${c.label}）',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (Command? c) =>
                  setState(() => _command = c ?? _command),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('on（开 / 绑定）'),
              value: _on,
              onChanged: (bool v) => setState(() => _on = v),
            ),
            Row(
              children: <Widget>[
                Expanded(child: _numberField('p4', _p4)),
                const SizedBox(width: 8),
                Expanded(child: _numberField('p5', _p5)),
                const SizedBox(width: 8),
                Expanded(child: _numberField('p6', _p6)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => controller.sendRaw(
                _command,
                on: _on,
                p4: _int(_p4),
                p5: _int(_p5),
                p6: _int(_p6),
              ),
              child: const Text('发送'),
            ),
            const SizedBox(height: 16),
            _frameCard(controller),
            const SizedBox(height: 12),
            _logCard(controller),
          ],
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _frameCard(LampController controller) {
    final String hex = controller.lastFrame == null
        ? '（还没发过）'
        : bytesToHex(controller.lastFrame!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '最近一帧',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              hex,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (controller.lastFrame != null)
              Text(
                '${controller.lastFrame!.length} 字节',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            const Divider(color: faintLine),
            const Text('13 个 16-bit UUID', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            for (final String uuid in controller.lastFrameUuids)
              Text(
                uuid,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(LampController controller) {
    final List<FrameLogEntry> log = controller.log.take(logShown).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '帧日志（最近 $logShown 条 / 共 ${controller.log.length} 条，上限 50）',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (log.isEmpty)
              const Text(
                '（还没有发送记录）',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              )
            else
              for (final FrameLogEntry entry in log)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${entry.time.toIso8601String().substring(11, 19)}  ${entry.label}'
                        '${entry.ok ? '' : '  ✗ ${entry.error}'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: entry.ok ? Colors.white70 : danger,
                        ),
                      ),
                      Text(
                        entry.hex,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
