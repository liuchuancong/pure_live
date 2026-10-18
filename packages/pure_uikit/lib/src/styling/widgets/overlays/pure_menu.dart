import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// One menu action.
class PureMenuItem {
  /// A menu item; give [onTap] to make it actionable.
  const new({required this.id, required this.label, this.icon, this.danger = false, this.enabled = true, this.onTap});

  /// The stable id.
  final String id;

  /// The visible label.
  final String label;

  /// An optional leading icon.
  final IconData? icon;

  /// Whether to draw the label in the error colour (a destructive action).
  final bool danger;

  /// Whether the item responds to taps.
  final bool enabled;

  /// Called when the item is chosen (after the menu closes).
  final VoidCallback? onTap;
}

/// A dropdown menu anchored to its [child], built from the active language's
/// own menu widget where it has one.
///
/// macOS, glass and neumorphic ship no anchored popup menu in their libraries,
/// so Flutter's official Material `MenuAnchor` is the shared fallback.
class PureMenu extends StatelessWidget {
  /// A menu over [items], anchored to [child].
  const new({required this.items, required this.child, this.enabled = true, super.key});

  /// The actions.
  final List<PureMenuItem> items;

  /// The trigger widget.
  final Widget child;

  /// Whether the trigger responds.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.macos ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.neumorphic => _materialMenu(theme),
      PureDesignLanguage.cupertino => _cupertinoMenu(theme),
      PureDesignLanguage.fluent => _fluentMenu(theme),
      PureDesignLanguage.forui => _foruiMenu(),
      PureDesignLanguage.wind => _windMenu(),
    };
  }

  /// Whether an item responds at all: switched off, or given no callback.
  bool _itemEnabled(PureMenuItem item) => item.enabled && item.onTap != null;

  /// The tap-to-toggle trigger the anchor libraries wrap.
  Widget _trigger(VoidCallback? onTap) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);

  /// The official Material menu.
  Widget _materialMenu(PureTheme theme) {
    return MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, child) =>
          _trigger(enabled ? () => controller.isOpen ? controller.close() : controller.open() : null),
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            onPressed: _itemEnabled(item) ? item.onTap : null,
            leadingIcon: item.icon == null ? null : Icon(item.icon),
            child: Text(item.label, style: item.danger ? TextStyle(color: theme.colors.error) : null),
          ),
      ],
    );
  }

  /// The official Cupertino pull-down.
  Widget _cupertinoMenu(PureTheme theme) {
    return cupertino.CupertinoMenuAnchor(
      consumeOutsideTaps: true,
      builder: (context, controller, child) =>
          _trigger(enabled ? () => controller.isOpen ? controller.close() : controller.open() : null),
      menuChildren: [
        for (final item in items)
          cupertino.CupertinoMenuItem(
            onPressed: _itemEnabled(item) ? item.onTap : null,
            isDestructiveAction: item.danger,
            leading: item.icon == null ? null : Icon(item.icon),
            child: Text(item.label),
          ),
      ],
    );
  }

  /// The library's own Fluent menu.
  Widget _fluentMenu(PureTheme theme) {
    return f2.FluentMenu(
      items: [
        for (final item in items)
          f2.FluentMenuItem(
            label: Text(item.label, style: item.danger ? TextStyle(color: theme.colors.error) : null),
            icon: item.icon == null ? null : Icon(item.icon),
            enabled: _itemEnabled(item),
            onPressed: _itemEnabled(item) ? item.onTap : null,
          ),
      ],
      builder: (context, toggle) => _trigger(enabled ? toggle : null),
    );
  }

  /// The library's own ForUI popover menu.
  Widget _foruiMenu() {
    return forui.FPopoverMenu(
      menu: [
        forui.FItemGroup(
          children: [
            for (final item in items)
              forui.FItem(
                title: Text(item.label),
                prefix: item.icon == null ? null : Icon(item.icon),
                variant: item.danger ? forui.FItemVariant.destructive : forui.FItemVariant.primary,
                enabled: _itemEnabled(item),
                onPress: _itemEnabled(item) ? item.onTap : null,
              ),
          ],
        ),
      ],
      builder: (context, controller, child) => _trigger(enabled ? controller.toggle : null),
    );
  }

  /// The fork's own anchored popover menu.
  Widget _windMenu() {
    return wind.WPopover(
      disabled: !enabled,
      className: 'rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-1',
      triggerBuilder: (context, isOpen, isHovering) => child,
      contentBuilder: (context, close) => wind.WDiv(
        className: 'flex flex-col gap-1',
        children: [
          for (final item in items)
            wind.WAnchor(
              onTap: _itemEnabled(item)
                  ? () {
                      close();
                      item.onTap?.call();
                    }
                  : null,
              isDisabled: !_itemEnabled(item),
              child: wind.WDiv(
                className: item.danger
                    ? 'flex flex-row items-center gap-2 rounded-md px-3 py-1.5 text-sm text-red-600 dark:text-red-400'
                          ' hover:bg-red-50 dark:hover:bg-red-950'
                    : 'flex flex-row items-center gap-2 rounded-md px-3 py-1.5 text-sm text-gray-900 dark:text-gray-100'
                          ' hover:bg-gray-100 dark:hover:bg-gray-700',
                children: [
                  if (item.icon case final IconData glyph) wind.WIcon(glyph, className: 'text-sm'),
                  wind.WText(item.label, className: 'text-sm shrink'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
