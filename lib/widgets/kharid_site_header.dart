import "package:flutter/material.dart";

import "app_logo.dart";

/// Сарлавҳаи умум монанди веб‑фронт: фони сафед, лого дар марказ, бе сояи AppBar.
/// Дар саҳифаҳои дохилӣ (`canPop`): [назад | чап], [лого | марказ], [уведомления + меню | рост].
/// Дар реша: [меню | чап], [лого | марказ], [`trailing` | рост].
class KharidSiteHeader extends StatelessWidget implements PreferredSizeWidget {
  const KharidSiteHeader({
    super.key,
    required this.onMenuPressed,
    this.logoHeight = 34,
    this.toolbarHeight = 54,
    this.trailing,
    this.subtitle,
    this.showBackWhenCanPop = true,
    this.onNotificationPressed,
  });

  final VoidCallback onMenuPressed;

  /// Баландии лого дар марказ (монанди макет ~26 px).
  final double logoHeight;
  final double toolbarHeight;

  /// Тугмаҳо аз рости дар саҳифаҳои реша (ҷустҷӯ, огоҳӣ).
  final Widget? trailing;

  /// Сатри дополнительный зери сутун (масалан унвони саҳифа).
  final Widget? subtitle;

  /// Агар `Navigator.canPop` бошад, тартиби дохилӣ: назад чап, меню рост.
  final bool showBackWhenCanPop;

  /// Зангӯли push / уведомления. Агар `null` бошад, паём нишон дода мешавад.
  final VoidCallback? onNotificationPressed;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight + (subtitle != null ? 42 : 0));

  static Color backgroundFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF061433) : Colors.white;
  }

  bool _isInternalPage(BuildContext context) => showBackWhenCanPop && Navigator.canPop(context);

  void _onNotificationTap(BuildContext context) {
    if (onNotificationPressed != null) {
      onNotificationPressed!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Уведомления: раздел в разработке")),
    );
  }

  Widget _menuButton(BuildContext context, Color iconColor) {
    return IconButton(
      onPressed: onMenuPressed,
      iconSize: 26,
      padding: const EdgeInsets.only(left: 8, right: 8),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: "Меню",
      icon: Icon(Icons.menu_rounded, color: iconColor),
    );
  }

  Widget _backButton(BuildContext context, Color iconColor) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.only(left: 8, right: 10),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: "Назад",
      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: iconColor),
      onPressed: () => Navigator.maybePop(context),
    );
  }

  Widget _notificationButton(BuildContext context, Color iconColor) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
      tooltip: "Уведомления",
      icon: Icon(Icons.notifications_none_rounded, size: 24, color: iconColor),
      onPressed: () => _onNotificationTap(context),
    );
  }

  Widget? _rightSideRoot(BuildContext context) {
    if (trailing != null) return trailing;
    return null;
  }

  Widget _rightSideInternal(BuildContext context, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?trailing,
        _notificationButton(context, iconColor),
        _menuButton(context, iconColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundFor(context);
    final iconColor = theme.colorScheme.onSurface;
    final internal = _isInternalPage(context);

    return Material(
      color: bg,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: toolbarHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: internal ? _backButton(context, iconColor) : _menuButton(context, iconColor),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AppLogo(height: logoHeight),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: internal
                      ? Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: _rightSideInternal(context, iconColor),
                        )
                      : (_rightSideRoot(context) ?? const SizedBox(width: 52)),
                ),
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DefaultTextStyle(
                style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontSize: (theme.textTheme.titleMedium?.fontSize ?? 18) - 1,
                  height: 1.2,
                ),
                textAlign: TextAlign.start,
                child: subtitle!,
              ),
            ),
        ],
      ),
    );
  }
}
