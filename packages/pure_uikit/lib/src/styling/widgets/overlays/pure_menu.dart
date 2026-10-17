import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';

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

/// A dropdown menu anchored to its [child]; tapping the child opens a list of
/// [items] — Ant's `Dropdown`.
///
/// The menu under each language is that language's own anchored menu,
/// constructed directly: `MenuAnchor` + `MenuItemButton` under material, yaru
/// riding it (Yaru is Material carrying Ubuntu's tokens),
/// `CupertinoMenuAnchor` + `CupertinoMenuItem` under cupertino, `FluentMenu`
/// under fluent, `FPopoverMenu` under forui and `WPopover` under wind — so
/// what the user sees is exactly what that library's own documentation shows,
/// and the library owns the positioning, the dismissal and (under fluent) the
/// keyboard model. Switching `UiConfig.language` re-skins every menu.
///
/// macos_ui, glass_morphism_plus and flutter_neumorphic_ui_kit ship no
/// anchored menu widget, so those three panels are hand-rolled into the shared
/// anchored overlay below in each language's own idiom — a `MacosOverlayFilter`
/// pulldown sheet, a frosted `GlassContainer`, a concave `NeuContainer` dish —
/// with the trigger, the scrim and the follower staying the core's.
class PureMenu extends StatefulWidget {
  /// A menu over [items], anchored to [child].
  const new({required this.items, required this.child, this.enabled = true, super.key});

  /// The actions.
  final List<PureMenuItem> items;

  /// The trigger widget.
  final Widget child;

  /// Whether the trigger responds.
  final bool enabled;

  @override
  State<PureMenu> createState() => _PureMenuState();
}

class _PureMenuState extends State<PureMenu> {
  final LayerLink _link = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _entry;

  /// The hand-rolled panel the shared overlay opens, for the languages whose
  /// libraries ship no anchored menu ([_anchored] stores it, [_show] reads it).
  Widget Function()? _panelBuilder;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _show();

  void _show() {
    if (!widget.enabled || _panelBuilder == null) {
      return;
    }
    final theme = PureTheme.of(context);
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 180;
    _entry = OverlayEntry(builder: (_) => _menu(theme, width));
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      // Yaru opens menus with the Material `MenuAnchor` — that is what Yaru
      // itself is; its character comes from the host theme.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialMenu(theme),
      PureDesignLanguage.cupertino => _cupertinoMenu(theme),
      PureDesignLanguage.macos => _anchored(_macosPanel),
      PureDesignLanguage.fluent => _fluentMenu(theme),
      PureDesignLanguage.forui => _foruiMenu(),
      PureDesignLanguage.glass => _anchored(_glassPanel),
      PureDesignLanguage.neumorphic => _anchored(_neumorphicPanel),
      PureDesignLanguage.wind => _windMenu(),
    };
  }

  /// Whether an item responds at all: switched off, or given no callback.
  bool _itemEnabled(PureMenuItem item) => item.enabled && item.onTap != null;

  /// The tap-to-toggle trigger the anchor libraries wrap.
  Widget _trigger(VoidCallback? onTap) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: widget.child);

  /// The trigger for the languages whose panel is hand-rolled into the shared
  /// overlay: it records which panel to open, then anchors the follower.
  Widget _anchored(Widget Function() panel) {
    _panelBuilder = panel;
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(key: _anchorKey, behavior: HitTestBehavior.opaque, onTap: _toggle, child: widget.child),
    );
  }

  /// The shared anchored overlay the hand-rolled panels open into: the scrim
  /// row (an outside tap closes) and the follower under the trigger. The panel
  /// itself is the language's — see [PureMenu].
  Widget _menu(PureTheme theme, double width) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close, child: const SizedBox.expand()),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          offset: Offset(0, theme.token.scale.sizes.xxs),
          child: SizedBox(
            width: width < 180 ? 180 : width,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: _panelBuilder!()),
            ),
          ),
        ),
      ],
    );
  }

  /// The Material menu: the library's own `MenuAnchor` pull-down, opened from
  /// the trigger and dismissed by an outside tap (`consumeOutsideTap`, the
  /// library's answer to the shared popup's scrim row). A `danger` item keeps
  /// its semantics the only way a `MenuItemButton` can: the label carries the
  /// colour.
  Widget _materialMenu(PureTheme theme) {
    return MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, child) => _trigger(
        widget.enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
      menuChildren: [
        for (final item in widget.items)
          MenuItemButton(
            onPressed: _itemEnabled(item) ? item.onTap : null,
            leadingIcon: item.icon == null ? null : Icon(item.icon),
            child: Text(item.label, style: item.danger ? TextStyle(color: theme.colors.error) : null),
          ),
      ],
    );
  }

  /// The Cupertino menu: the library's own pull-down — iOS's answer to "choose
  /// one of these" is a menu that opens *from* the control — with `danger`
  /// mapped to the library's own destructive action, which tints the whole
  /// row.
  Widget _cupertinoMenu(PureTheme theme) {
    return cupertino.CupertinoMenuAnchor(
      consumeOutsideTaps: true,
      builder: (context, controller, child) => _trigger(
        widget.enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
      menuChildren: [
        for (final item in widget.items)
          cupertino.CupertinoMenuItem(
            onPressed: _itemEnabled(item) ? item.onTap : null,
            isDestructiveAction: item.danger,
            leading: item.icon == null ? null : Icon(item.icon),
            child: Text(item.label),
          ),
      ],
    );
  }

  /// The Fluent menu: the library's own `FluentMenu` — rows with their hover
  /// and keyboard model, opened from the trigger it hangs off. [PureMenuItem]
  /// has no Fluent-native danger row, so the label carries the colour.
  Widget _fluentMenu(PureTheme theme) {
    return f2.FluentMenu(
      items: [
        for (final item in widget.items)
          f2.FluentMenuItem(
            label: Text(item.label, style: item.danger ? TextStyle(color: theme.colors.error) : null),
            icon: item.icon == null ? null : Icon(item.icon),
            enabled: _itemEnabled(item),
            onPressed: _itemEnabled(item) ? item.onTap : null,
          ),
      ],
      builder: (context, toggle) => _trigger(widget.enabled ? toggle : null),
    );
  }

  /// The ForUI menu: the library's own `FPopoverMenu` — an `FItemGroup` of
  /// `FItem`s opened from the trigger, hidden on an outside tap. `danger` maps
  /// to the library's own destructive variant, which tints the whole row.
  Widget _foruiMenu() {
    return forui.FPopoverMenu(
      menu: [
        forui.FItemGroup(
          children: [
            for (final item in widget.items)
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
      builder: (context, controller, child) => _trigger(widget.enabled ? controller.toggle : null),
    );
  }

  /// The Wind menu: the library's own `WPopover` — the anchored overlay the
  /// fork ships (there is no menu widget above it) — with rows composed from
  /// `WAnchor` + `WDiv` in the fork's utility classes; a `danger` row carries
  /// the fork's own red utility. The panel chrome rides the popover's own
  /// `className`, and the fork sizes the sheet to the trigger itself.
  Widget _windMenu() {
    return wind.WPopover(
      disabled: !widget.enabled,
      className: 'rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 p-1',
      triggerBuilder: (context, isOpen, isHovering) => widget.child,
      contentBuilder: (context, close) => wind.WDiv(
        className: 'flex flex-col gap-1',
        children: [
          for (final item in widget.items)
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

  /// Hand-rolled because macos_ui ships no anchored popup-menu widget: the
  /// panel recreates the library's own pulldown surface — a
  /// `MacosOverlayFilter` vibrancy sheet over the pulldown colour, rows
  /// hover-highlighted with the pulldown theme's highlight, exactly as the
  /// library's own `_MacosPulldownMenu` paints them.
  Widget _macosPanel() {
    final pulldown = macos.MacosPulldownButtonTheme.of(context);
    final typography = macos.MacosTheme.of(context).typography;
    return macos.MacosOverlayFilter(
      color: pulldown.pulldownColor?.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in widget.items)
              _MacosMenuRow(
                item: item,
                highlight: pulldown.highlightColor ?? macos.MacosColors.controlAccentColor,
                textStyle: typography.body,
                onSelect: () {
                  _close();
                  item.onTap?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Hand-rolled because the library ships no menu widget: a frosted
  /// `GlassContainer` sheet over the trigger, rows hover-lit the way this
  /// language's own select list is.
  Widget _glassPanel() {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    return glass.GlassContainer(
      customBorderRadius: BorderRadius.circular(glassTheme.borderRadius),
      padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xxs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in widget.items)
            PureBox(
              style: (state) => Style(
                background: switch (state) {
                  InteractionState.hovered ||
                  InteractionState.pressed when _itemEnabled(item) => theme.select.itemHoverBackground,
                  _ => null,
                },
              ),
              onTap: _itemEnabled(item)
                  ? () {
                      _close();
                      item.onTap?.call();
                    }
                  : null,
              enabled: _itemEnabled(item),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.select.paddingInline,
                  vertical: theme.token.scale.sizes.xs,
                ),
                child: Row(
                  children: [
                    if (item.icon case final IconData glyph) ...[
                      Icon(glyph, size: theme.text.body.fontSize, color: theme.colors.icon),
                      SizedBox(width: theme.token.scale.sizes.sm),
                    ],
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.body.copyWith(
                          color: item.danger
                              ? theme.colors.error
                              : _itemEnabled(item)
                              ? theme.colors.text
                              : theme.colors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hand-rolled because the library ships no menu widget: a concave
  /// (`neu.NeuShape.concave`) dish of cells under the trigger, each cell
  /// rising ([neu.NeuShape.convex]) under the pointer — the reading this
  /// language's own select list uses.
  Widget _neumorphicPanel() {
    final theme = PureTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    return neu.NeuContainer(
      shape: neu.NeuShape.concave,
      borderRadius: surface.borderRadius,
      baseColor: surface.baseColor,
      depth: 2,
      padding: EdgeInsets.all(theme.token.scale.sizes.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in widget.items)
            _NeumorphicMenuRow(
              item: item,
              surface: surface,
              onSelect: () {
                _close();
                item.onTap?.call();
              },
            ),
        ],
      ),
    );
  }
}

/// One row of the hand-rolled macOS menu: hover-lit like the library's own
/// pulldown item button.
class _MacosMenuRow extends StatefulWidget {
  const new({required this.item, required this.highlight, required this.textStyle, required this.onSelect});

  final PureMenuItem item;
  final Color highlight;
  final TextStyle textStyle;
  final VoidCallback onSelect;

  @override
  State<_MacosMenuRow> createState() => _MacosMenuRowState();
}

class _MacosMenuRowState extends State<_MacosMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final enabled = item.enabled && item.onTap != null;
    final lit = _hovered && enabled;
    final disabled = macos.MacosDynamicColor.resolve(macos.MacosColors.disabledControlTextColor, context);
    final color = !enabled
        ? disabled
        : item.danger
        ? macos.MacosDynamicColor.resolve(macos.MacosColors.systemRedColor, context)
        : lit
        ? macos.MacosColors.white
        : widget.textStyle.color;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.basic : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onSelect : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: lit ? widget.highlight : null,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Row(
            children: [
              if (item.icon case final IconData glyph) ...[
                Icon(glyph, size: 13, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.textStyle.copyWith(color: color, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the hand-rolled Neumorphic menu: a cell that rises under the
/// pointer.
class _NeumorphicMenuRow extends StatefulWidget {
  const new({required this.item, required this.surface, required this.onSelect});

  final PureMenuItem item;
  final neu.NeuThemeData surface;
  final VoidCallback onSelect;

  @override
  State<_NeumorphicMenuRow> createState() => _NeumorphicMenuRowState();
}

class _NeumorphicMenuRowState extends State<_NeumorphicMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final surface = widget.surface;
    final item = widget.item;
    final enabled = item.enabled && item.onTap != null;
    final lit = _hovered && enabled;
    final color = !enabled
        ? theme.colors.textDisabled
        : item.danger
        ? theme.colors.error
        : theme.colors.text;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onSelect : null,
        child: neu.NeuContainer(
          shape: lit ? neu.NeuShape.convex : neu.NeuShape.flat,
          borderRadius: surface.borderRadius,
          baseColor: surface.baseColor,
          depth: lit ? surface.depth : 0.0,
          distance: lit ? surface.distance : 0.0,
          padding: EdgeInsets.symmetric(
            horizontal: theme.token.scale.sizes.md,
            vertical: theme.token.scale.sizes.sm,
          ),
          child: Row(
            children: [
              if (item.icon case final IconData glyph) ...[
                Icon(glyph, size: theme.text.body.fontSize, color: color),
                SizedBox(width: theme.token.scale.sizes.sm),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.body.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
