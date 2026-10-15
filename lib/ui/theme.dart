import 'package:flutter/material.dart';

/// 配色取自原厂 App 截图采样（`docs/` 之外的截图只用于取色，图标全部现画）。
const Color pageBg = Color(0xFF202737);
const Color pageBgDeep = Color(0xFF0E1118);
const Color surface = Color(0xFF474F62);
const Color surfaceAlt = Color(0xFF2F374A);
const Color accent = Color(0xFF26B798);
const Color tickActive = Color(0xFFF0A93B);
const Color onSurface = Colors.white;

/// 未激活刻度 / 分隔线用的半透明白。
const Color faintLine = Color(0x22FFFFFF);

/// 危险操作（解除配对）。
const Color danger = Color(0xFFE05B5B);

ThemeData buildDarkTheme() {
  final ColorScheme scheme = const ColorScheme.dark(
    primary: accent,
    secondary: accent,
    surface: surface,
    onSurface: onSurface,
    error: danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pageBg,
    canvasColor: pageBg,
    dividerColor: faintLine,
    appBarTheme: const AppBarTheme(
      backgroundColor: pageBg,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: Colors.white70,
      indicatorColor: accent,
      dividerColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: pageBgDeep,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surfaceAlt,
      contentTextStyle: TextStyle(color: onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: surface,
      thumbColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? accent : surface,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
  );
}
