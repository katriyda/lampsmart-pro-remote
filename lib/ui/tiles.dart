import 'package:flutter/material.dart';

import 'theme.dart';

/// 72×72 圆角 18 磁贴：图标 + 中文标签，选中态描 [accent]。
class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// 右下角的小控件（例如风扇面板里的开关）。
  final Widget? trailing;

  static const double size = 72;
  static const double radius = 18;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        icon,
                        size: 24,
                        color: selected ? accent : onSurface,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Positioned(right: 2, bottom: 2, child: trailing!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 磁贴宫格：每行 4 个（风扇类设备 12 个时自动折成 3 行）。
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // 每行放得下几个就放几个：8 项两行，风扇类 12 项三行。
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}
