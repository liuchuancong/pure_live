import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// A dropdown select in the token model, controlled by [value] / [onChanged] —
/// Ant's `Select`. The closed field uses the select component token (and
/// re-skins with the input family); the popup is a token-styled card anchored
/// below it, with hover and selected item fills. This is the base for languages
/// that do not map a select to their own widget.
class TokenSelect<T> extends StatefulWidget {
  /// A select over [items].
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.enabled = true,
    super.key,
  });

  /// The selectable values.
  final List<T> items;

  /// Maps a value to its display label.
  final String Function(T item) itemLabel;

  /// Called with the chosen value.
  final ValueChanged<T>? onChanged;

  /// The currently selected value, if any.
  final T? value;

  /// Text shown when nothing is selected.
  final String? placeholder;

  /// Whether the select responds to input.
  final bool enabled;

  @override
  State<TokenSelect<T>> createState() => _TokenSelectState<T>();
}

class _TokenSelectState<T> extends State<TokenSelect<T>> {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _entry;
  bool _hovered = false;

  bool get _open => _entry != null;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _toggle() => _open ? _close() : _show();

  void _show() {
    if (!_interactive) {
      return;
    }
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 200;
    _entry = OverlayEntry(builder: (context) => _menu(width));
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

  void _choose(T item) {
    widget.onChanged?.call(item);
    _close();
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
          offset: Offset(0, theme.token.motion.lineWidth * 2),
          child: Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.xs),
            child: SizedBox(
              width: width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xxs),
                  decoration: BoxDecoration(
                    color: select.menuBackground,
                    borderRadius: BorderRadius.circular(select.borderRadius),
                    boxShadow: theme.token.motion.boxShadow,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in widget.items)
                          _Option(
                            label: widget.itemLabel(item),
                            selected: item == widget.value,
                            onTap: () => _choose(item),
                          ),
                      ],
                    ),
                  ),
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
    final theme = LiveTheme.of(context);
    final select = theme.select;
    final borderColor = _open
        ? select.focusBorder
        : _hovered
        ? select.hoverBorder
        : select.fieldBorder;
    final selected = widget.value;

    final field = CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            key: _fieldKey,
            constraints: BoxConstraints(minHeight: select.height),
            padding: EdgeInsets.symmetric(horizontal: select.paddingInline),
            decoration: BoxDecoration(
              color: select.fieldBackground,
              borderRadius: BorderRadius.circular(select.borderRadius),
              border: Border.all(color: borderColor, width: theme.token.motion.lineWidth),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected == null ? (widget.placeholder ?? '') : widget.itemLabel(selected),
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.body.copyWith(
                      color: selected == null ? theme.colors.textPlaceholder : theme.colors.text,
                    ),
                  ),
                ),
                SizedBox(width: theme.token.scale.sizes.xs),
                Icon(
                  _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: theme.text.body.fontSize! * 1.4,
                  color: theme.colors.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedOpacity(
      duration: theme.duration,
      opacity: widget.enabled ? 1 : theme.token.motion.opacityLoading,
      child: field,
    );
  }
}

/// The public dropdown: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` renders the select with the real library's
/// control (Material's [DropdownButton]) or the token base.
class LiveSelect<T> extends StatelessWidget {
  /// A select over [items].
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.placeholder,
    this.enabled = true,
    super.key,
  });

  /// The selectable values.
  final List<T> items;

  /// Maps a value to its display label.
  final String Function(T item) itemLabel;

  /// Called with the chosen value.
  final ValueChanged<T>? onChanged;

  /// The currently selected value, if any.
  final T? value;

  /// Text shown when nothing is selected.
  final String? placeholder;

  /// Whether the select responds to input.
  final bool enabled;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.select<T>(
    context,
    LanguageSelectSpec<T>(
      items: items,
      itemLabel: itemLabel,
      onChanged: onChanged,
      value: value,
      placeholder: placeholder,
      enabled: enabled,
    ),
  );
}

class _Option extends StatefulWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final select = theme.select;
    final background = widget.selected
        ? select.itemSelectedBackground
        : _hovered
        ? select.itemHoverBackground
        : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: select.itemHeight,
          padding: EdgeInsets.symmetric(horizontal: select.paddingInline),
          alignment: Alignment.centerLeft,
          color: background,
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: theme.text.body.copyWith(
              color: theme.colors.text,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
