import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

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
