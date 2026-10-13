import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/root/live_config_provider.dart';

/// One menu action.
class LiveMenuItem {
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

/// A dropdown menu anchored to its [child]; tapping the child opens a token
/// styled list of [items] — Ant's `Dropdown`. Reuses the select popup surface so
/// it re-skins with the rest of the UI.
class LiveMenu extends StatefulWidget {
  /// A menu over [items], anchored to [child].
  const new({required this.items, required this.child, this.enabled = true, super.key});

  /// The actions.
  final List<LiveMenuItem> items;

  /// The trigger widget.
  final Widget child;

  /// Whether the trigger responds.
  final bool enabled;

  @override
  State<LiveMenu> createState() => _LiveMenuState();
}

class _LiveMenuState extends State<LiveMenu> {
  final LayerLink _link = LayerLink();
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _entry;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _show();

  void _show() {
    if (!widget.enabled) {
      return;
    }
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 180;
    _entry = OverlayEntry(builder: (_) => _menu(width));
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

  Widget _menu(double width) {
    final theme = LiveTheme.of(context);
    final select = theme.select;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close, child: const SizedBox.expand()),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 4),
          child: SizedBox(
            width: width < 180 ? 180 : width,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xxs),
              decoration: BoxDecoration(
                color: select.menuBackground,
                borderRadius: BorderRadius.circular(select.borderRadius),
                boxShadow: theme.token.motion.boxShadow,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in widget.items)
                      _MenuRow(
                        item: item,
                        onSelect: () {
                          _close();
                          item.onTap?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(key: _anchorKey, behavior: HitTestBehavior.opaque, onTap: _toggle, child: widget.child),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const new({required this.item, required this.onSelect});

  final LiveMenuItem item;
  final VoidCallback onSelect;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final enabled = widget.item.enabled && widget.item.onTap != null;
    final color = widget.item.danger
        ? theme.colors.error
        : enabled
        ? theme.colors.text
        : theme.colors.textDisabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onSelect : null,
        child: Container(
          height: theme.select.itemHeight,
          color: _hovered && enabled ? theme.select.itemHoverBackground : null,
          padding: EdgeInsets.symmetric(horizontal: theme.select.paddingInline),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (widget.item.icon case final icon?) ...[
                Icon(icon, size: theme.text.body.fontSize, color: color),
                SizedBox(width: theme.token.scale.sizes.sm),
              ],
              Expanded(
                child: Text(widget.item.label, style: theme.text.body.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
