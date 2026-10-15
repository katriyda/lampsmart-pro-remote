import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/home_store.dart';
import 'state/app_settings.dart';
import 'state/lamp_controller.dart';
import 'transport/create_transport.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppSettings settings = AppSettings(prefs);
  final HomeStore store = HomeStore(prefs);
  await Future.wait<void>(<Future<void>>[settings.load(), store.load()]);

  final LampController controller = LampController(
    transport: createTransport(),
    settings: settings,
  );

  runApp(
    LampSmartApp(store: store, settings: settings, controller: controller),
  );

  // 权限申请放在首帧之后，避免弹出对话框时界面还没起来。
  unawaited(controller.ensurePermission());
}

class LampSmartApp extends StatelessWidget {
  const LampSmartApp({
    super.key,
    required this.store,
    required this.settings,
    required this.controller,
  });

  final HomeStore store;
  final AppSettings settings;
  final LampController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      settings: settings,
      controller: controller,
      child: MaterialApp(
        title: '灯具遥控',
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}
