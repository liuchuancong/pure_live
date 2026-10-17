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
import 'package:pure_uikit/src/styling/style/style.dart' show InteractionState, Style;
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';

/// The public dropdown: one widget, every theme and density. [build] switches
/// on `UiConfig.language` and constructs the language's own dropdown directly —
/// Material's [DropdownButton], iOS's pull-down menu anchored on a
/// `CupertinoButton`, macOS's `MacosPopupButton`, fluent_2's `FluentDropdown` —
/// so what the user sees is exactly what that library's own documentation
/// shows. Switching `UiConfig.language` re-skins every select.
class PureSelect<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = enabled ? onChanged : null;
    // Material's and macOS's pop-up buttons assert that the current value
    // matches exactly one item; a value the list does not carry is dropped to
    // null — the field shows its placeholder instead of pretending the value
    // is selected — and the menu keeps only choosable items (non-null, one of
    // each).
    final chosen = _chosenOrNull;

    return switch (theme.config.language) {
      PureDesignLanguage.material => DropdownButton<T>(
        value: chosen.value,
        hint: placeholder == null ? null : Text(placeholder!),
        isExpanded: true,
        items: [
          for (final item in chosen.items) DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
        ],
        // The menu can hand back a null selection; the contract has no such
        // case, so a null is dropped rather than reported.
        onChanged: select == null
            ? null
            : (value) {
                if (value != null) {
                  select(value);
                }
              },
      ),
      PureDesignLanguage.cupertino => _cupertino(theme, select),
      PureDesignLanguage.macos => macos.MacosPopupButton<T>(
        items: [
          for (final item in chosen.items) macos.MacosPopupMenuItem<T>(value: item, child: Text(itemLabel(item))),
        ],
        value: chosen.value,
        hint: placeholder == null ? null : Text(placeholder!),
        style: theme.text.body.copyWith(color: theme.colors.text),
        onChanged: select == null
            ? null
            : (value) {
                if (value != null) {
                  select(value);
                }
              },
      ),
      PureDesignLanguage.fluent => f2.FluentDropdown<T>(
        value: value,
        options: [for (final item in items) f2.FluentDropdownOption<T>(value: item, label: Text(itemLabel(item)))],
        onChanged: select,
        placeholder: placeholder == null ? null : Text(placeholder!),
      ),
      // The library's own dropdown, generic over the caller's value type. The
      // selection is lifted (`FSelectControl.lifted`): the value goes in and
      // the picked one comes out, so the caller keeps ownership. Items go
      // through `FSelect.rich` rather than the `items:` map constructor
      // because a map is keyed by the display label — two items the caller
      // labels the same would collapse into one. `expands` is deliberately not
      // asked for: the combination trips the fork's min/max-lines assertion (a
      // measured fact of forui 0.27.5). A null placeholder is left to the
      // library, which labels the empty field with its own localized hint.
      PureDesignLanguage.forui => forui.FSelect<T>.rich(
        format: itemLabel,
        control: forui.FSelectControl<T>.lifted(
          value: value,
          // The lifted control reports a deselection as null; the contract has
          // no such case, so a null is dropped rather than handed to the
          // caller as a value.
          onChange: (picked) {
            if (picked != null) {
              select?.call(picked);
            }
          },
        ),
        hint: placeholder,
        enabled: enabled && onChanged != null,
        children: [for (final item in items) forui.FSelectItem<T>(title: Text(itemLabel(item)), value: item)],
      ),
      // Hand-rolled glass-style composition: glass_morphism_plus carries no
      // select, and an overlay-anchored popup is not what a glass surface can
      // do without taking the caller's overlay — so the field is a frosted
      // [glass.GlassContainer] sheet and the option list opens as a second
      // frosted sheet *in flow*, under the field, capped and scrollable. The
      // list pushes the page rather than floating over it; it closes on a
      // choice or a second tap on the field.
      PureDesignLanguage.glass => _GlassSelect<T>(
        items: items,
        itemLabel: itemLabel,
        onChanged: select,
        value: value,
        placeholder: placeholder,
        enabled: enabled,
      ),
      // Hand-rolled neumorphic-style composition: the library carries no
      // dropdown, so the field is the library's own interactive plane
      // (`NeuContainer`, flat when shut and [neu.NeuShape.pressed] once open —
      // a recessed surface is how this style says "you are inside me") and the
      // option list a dish ([neu.NeuShape.concave]) of cells under it, the
      // chosen value pushed back out as a dome ([neu.NeuShape.convex]) with
      // the theme's accent on its label. The list opens inside the tree on
      // purpose: the caller reserves the room it takes, and it closes on a
      // choice or a second tap.
      PureDesignLanguage.neumorphic => _NeumorphicSelect<T>(
        items: items,
        itemLabel: itemLabel,
        onChanged: select,
        value: value,
        placeholder: placeholder,
        enabled: enabled,
      ),
      // The library's own typed select: every item becomes one `SelectOption`
      // whose label is this contract's `itemLabel`, and the chosen option's
      // value comes back unchanged. A null callback or `enabled: false`
      // disables the fork outright (`disabled: true` plus no `onChange`).
      PureDesignLanguage.wind => wind.WSelect<T>(
        value: value,
        options: [for (final item in items) wind.SelectOption<T>(value: item, label: itemLabel(item))],
        onChange: select,
        placeholder: placeholder ?? '',
        disabled: select == null,
      ),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different dropdown.
      PureDesignLanguage.material || PureDesignLanguage.yaru => DropdownButton<T>(
        value: chosen.value,
        hint: placeholder == null ? null : Text(placeholder!),
        isExpanded: true,
        items: [
          for (final item in chosen.items) DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
        ],
        onChanged: select == null
            ? null
            : (value) {
                if (value != null) {
                  select(value);
                }
              },
      ),
    };
  }

  /// [items] rewritten so the value-only-when-carried contract above holds:
  /// the values it can actually carry (non-null, one of each) and a current
  /// value that is either a member of that list or nothing at all.
  PureSelect<T> get _chosenOrNull {
    final carried = <T>[];
    for (final item in items) {
      if (item != null && !carried.contains(item)) {
        carried.add(item);
      }
    }
    return PureSelect<T>(
      items: carried,
      itemLabel: itemLabel,
      onChanged: onChanged,
      value: value != null && carried.contains(value) ? value : null,
      placeholder: placeholder,
      enabled: enabled,
    );
  }

  /// iOS's answer to "choose one of these" is a menu that opens *from* the
  /// control: the pull-down anchor of `CupertinoMenuAnchor`, the trigger a
  /// `CupertinoButton` carrying the current value (or the placeholder, which is
  /// how iOS marks an empty field) with the library's own chevron, and the
  /// choices below it with a checkmark on the selected one.
  Widget _cupertino(PureTheme theme, ValueChanged<T>? select) {
    final current = value;
    return cupertino.CupertinoMenuAnchor(
      enableSwipe: false,
      menuChildren: [
        for (final item in items)
          cupertino.CupertinoMenuItem(
            leading: item == value ? const Icon(cupertino.CupertinoIcons.checkmark, size: 13) : null,
            onPressed: select == null ? null : () => select(item),
            child: Text(itemLabel(item)),
          ),
      ],
      builder: (context, controller, child) => cupertino.CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xxs),
        onPressed: select == null ? null : controller.open,
        child: child ?? const SizedBox.shrink(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current == null ? placeholder ?? '' : itemLabel(current), overflow: TextOverflow.ellipsis),
          SizedBox(width: theme.token.scale.sizes.xxs),
          const Icon(cupertino.CupertinoIcons.chevron_down, size: 11),
        ],
      ),
    );
  }
}

/// The glass select: a hand-rolled glassmorphism composition (see the
/// [PureSelect] glass branch). The field is a frosted sheet; the option list is
/// a second frosted sheet in flow under it, capped and scrollable. Duplicate,
/// null or off-list values draw as rows rather than throwing — being composed,
/// there is nothing to guard.
class _GlassSelect<T> extends StatefulWidget {
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.value,
    required this.placeholder,
    required this.enabled,
  });

  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T>? onChanged;
  final T? value;
  final String? placeholder;
  final bool enabled;

  @override
  State<_GlassSelect<T>> createState() => _GlassSelectState<T>();
}

class _GlassSelectState<T> extends State<_GlassSelect<T>> {
  bool _open = false;

  void _choose(T item) {
    setState(() => _open = false);
    widget.onChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final interactive = widget.enabled && widget.onChanged != null;
    final radius = BorderRadius.circular(glassTheme.borderRadius);
    final selected = widget.value;
    final label = selected == null ? (widget.placeholder ?? '') : widget.itemLabel(selected);

    void toggle() {
      if (interactive) {
        setState(() => _open = !_open);
      }
    }

    final field = glass.GlassContainer(
      customBorderRadius: radius,
      child: PureBox(
        style: (state) => Style(
          borderRadius: radius,
          minHeight: theme.select.height,
          background: switch (state) {
            InteractionState.hovered ||
            InteractionState.pressed ||
            InteractionState.focused => glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
            _ => null,
          },
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        onTap: interactive ? toggle : null,
        enabled: widget.enabled,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.select.paddingInline),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.body.copyWith(
                    color: selected == null ? theme.colors.textPlaceholder : theme.colors.text,
                  ),
                ),
              ),
              SizedBox(width: theme.token.scale.sizes.xs),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: theme.text.body.fontSize! * 1.4,
                color: theme.colors.icon,
              ),
            ],
          ),
        ),
      ),
    );

    if (!_open) {
      return Semantics(button: true, expanded: _open, child: field);
    }
    return Semantics(
      button: true,
      expanded: _open,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          Padding(
            padding: EdgeInsets.only(top: theme.token.scale.sizes.xs),
            child: SizedBox(
              width: double.infinity,
              child: glass.GlassContainer(
                customBorderRadius: radius,
                padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xxs),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in widget.items)
                          PureBox(
                            style: (state) => Style(
                              background: switch (state) {
                                InteractionState.hovered || InteractionState.pressed => theme.select.itemHoverBackground,
                                _ when item == selected => theme.select.itemSelectedBackground,
                                _ => null,
                              },
                            ),
                            onTap: () => _choose(item),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.select.paddingInline,
                                vertical: theme.token.scale.sizes.xs,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.itemLabel(item),
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.text.body.copyWith(
                                        color: theme.colors.text,
                                        fontWeight: item == selected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (item == selected) ...[
                                    SizedBox(width: theme.token.scale.sizes.xs),
                                    Icon(Icons.check, size: theme.text.body.fontSize, color: theme.colors.primary),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The neumorphic select: a hand-rolled neumorphic composition (see the
/// [PureSelect] neumorphic branch). The field is `NeuContainer` flat when shut
/// and pressed once open; the option list is a concave dish of cells, the
/// chosen value domed out with the accent on its label.
class _NeumorphicSelect<T> extends StatefulWidget {
  const new({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.value,
    required this.placeholder,
    required this.enabled,
  });

  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T>? onChanged;
  final T? value;
  final String? placeholder;
  final bool enabled;

  @override
  State<_NeumorphicSelect<T>> createState() => _NeumorphicSelectState<T>();
}

class _NeumorphicSelectState<T> extends State<_NeumorphicSelect<T>> {
  bool _open = false;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  void _toggle() => setState(() => _open = !_open);

  void _choose(T item) {
    if (!_interactive) {
      return;
    }
    setState(() => _open = false);
    widget.onChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final radius = surface.borderRadius.resolve(Directionality.of(context));
    final inset = theme.token.scale.sizes.xs;
    final cellRadius = BorderRadius.circular(radius.topLeft.x <= inset ? 0.0 : radius.topLeft.x - inset);
    // The spec's value is matched by identity against the items, so an
    // off-list value reads as "nothing selected" rather than as a phantom row.
    final selected = widget.items.contains(widget.value) ? widget.value : null;
    final label = selected == null ? (widget.placeholder ?? '') : widget.itemLabel(selected);
    final tint = widget.enabled ? theme.colors.text : theme.colors.textDisabled;

    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _interactive ? _toggle : null,
      child: neu.NeuContainer(
        shape: _open ? neu.NeuShape.pressed : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: _open ? 2.0 : surface.depth,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text.body.copyWith(color: tint),
              ),
            ),
            Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: widget.enabled ? surface.accentColor : theme.colors.textDisabled,
              size: theme.text.body.fontSize,
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        if (_open) ...[
          SizedBox(height: inset),
          neu.NeuContainer(
            shape: neu.NeuShape.concave,
            borderRadius: radius,
            baseColor: surface.baseColor,
            depth: 2,
            padding: EdgeInsets.all(inset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.items)
                  _NeumorphicSelectOption(
                    text: widget.itemLabel(item),
                    selected: item == selected,
                    onTap: () => _choose(item),
                    radius: cellRadius,
                    surface: surface,
                    theme: theme,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One row of the neumorphic option list: flat, or domed out with the accent
/// label when it is the chosen value.
class _NeumorphicSelectOption extends StatelessWidget {
  const new({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final PureTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.text.body.copyWith(
            color: selected ? surface.accentColor : theme.colors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
