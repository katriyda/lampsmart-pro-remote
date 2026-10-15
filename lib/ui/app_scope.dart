import 'package:flutter/widgets.dart';

import '../data/home_store.dart';
import '../state/app_settings.dart';
import '../state/lamp_controller.dart';

/// 把三个状态对象放进 widget 树，页面通过 `AppScope.of(context)` 取。
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.settings,
    required this.controller,
    required super.child,
  });

  final HomeStore store;
  final AppSettings settings;
  final LampController controller;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      store != oldWidget.store ||
      settings != oldWidget.settings ||
      controller != oldWidget.controller;
}
