import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The public dropdown: one widget, every theme and density. The widget's
/// `build` switches on `UiConfig.language` and constructs the language's own
/// dropdown directly —
/// Material's [DropdownButton], iOS's pull-down menu anchored on a
/// `CupertinoButton`, macOS's `MacosPopupButton`, fluent_2's `FluentDropdown` —
/// so what the user sees is exactly what that library's own documentation
/// shows. Switching `UiConfig.language` re-skins every select.
class PureSelect<T> extends cupertino.StatefulWidget {
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
  cupertino.State<PureSelect<T>> createState() => _PureSelectState<T>();
}

class _PureSelectState<T> extends cupertino.State<PureSelect<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = widget.enabled ? widget.onChanged : null;
    // Material's and macOS's pop-up buttons assert that the current value
    // matches exactly one item; a value the list does not carry is dropped to
    // null — the field shows its placeholder instead of pretending the value
    // is selected — and the menu keeps only choosable items (non-null, one of
    // each).
    final chosen = _chosenOrNull;

    return switch (theme.config.language) {
      PureDesignLanguage.material => DropdownButton<T>(
        value: chosen.value,
        hint: widget.placeholder == null ? null : Text(widget.placeholder!),
        isExpanded: true,
        items: [for (final item in chosen.items) DropdownMenuItem<T>(value: item, child: Text(widget.itemLabel(item)))],
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
          for (final item in chosen.items)
            macos.MacosPopupMenuItem<T>(value: item, child: Text(widget.itemLabel(item))),
        ],
        value: chosen.value,
        hint: widget.placeholder == null ? null : Text(widget.placeholder!),
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
        value: widget.value,
        options: [
          for (final item in widget.items) f2.FluentDropdownOption<T>(value: item, label: Text(widget.itemLabel(item))),
        ],
        onChanged: select,
        placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
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
        format: widget.itemLabel,
        control: forui.FSelectControl<T>.lifted(
          value: widget.value,
          // The lifted control reports a deselection as null; the contract has
          // no such case, so a null is dropped rather than handed to the
          // caller as a value.
          onChange: (picked) {
            if (picked != null) {
              select?.call(picked);
            }
          },
        ),
        hint: widget.placeholder,
        enabled: widget.enabled && widget.onChanged != null,
        children: [
          for (final item in widget.items) forui.FSelectItem<T>(title: Text(widget.itemLabel(item)), value: item),
        ],
      ),
      // glass_morphism_plus ships no select. Use Flutter's official Material
      // dropdown instead of a hand-built frosted option list.
      PureDesignLanguage.glass => _materialDropdown(chosen, select),
      // The neumorphic library ships no dropdown. Use the official Material
      // dropdown.
      PureDesignLanguage.neumorphic => _materialDropdown(chosen, select),
      // The library's own typed select: every item becomes one `SelectOption`
      // whose label is this contract's `itemLabel`, and the chosen option's
      // value comes back unchanged. A null callback or `enabled: false`
      // disables the fork outright (`disabled: true` plus no `onChange`).
      PureDesignLanguage.wind => wind.WSelect<T>(
        value: widget.value,
        options: [for (final item in widget.items) wind.SelectOption<T>(value: item, label: widget.itemLabel(item))],
        onChange: select,
        placeholder: widget.placeholder ?? '',
        disabled: select == null,
      ),
      // Yaru ships no combobox — the library has no drop-down at all, so the
      // official Material control is the fallback.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialDropdown(chosen, select),
    };
  }

  /// The official Material dropdown, shared by the languages whose libraries
  /// ship no select.
  Widget _materialDropdown(PureSelect<T> chosen, ValueChanged<T>? select) {
    return DropdownButton<T>(
      value: chosen.value,
      hint: widget.placeholder == null ? null : Text(widget.placeholder!),
      isExpanded: true,
      items: [for (final item in chosen.items) DropdownMenuItem<T>(value: item, child: Text(widget.itemLabel(item)))],
      onChanged: select == null
          ? null
          : (value) {
              if (value != null) {
                select(value);
              }
            },
    );
  }

  /// The widget's items rewritten so the value-only-when-carried contract
  /// above holds: the values it can actually carry (non-null, one of each) and
  /// a current value that is either a member of that list or nothing at all.
  PureSelect<T> get _chosenOrNull {
    final carried = <T>[];
    for (final item in widget.items) {
      if (item != null && !carried.contains(item)) {
        carried.add(item);
      }
    }
    return PureSelect<T>(
      items: carried,
      itemLabel: widget.itemLabel,
      onChanged: widget.onChanged,
      value: widget.value != null && carried.contains(widget.value) ? widget.value : null,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
    );
  }

  /// iOS's answer to "choose one of these" is a menu that opens *from* the
  /// control: the pull-down anchor of `CupertinoMenuAnchor`, the trigger a
  /// `CupertinoButton` carrying the current value (or the placeholder, which is
  /// how iOS marks an empty field) with the library's own chevron, and the
  /// choices below it with a checkmark on the selected one.
  Widget _cupertino(PureTheme theme, ValueChanged<T>? select) {
    final current = widget.value;
    return cupertino.CupertinoMenuAnchor(
      enableSwipe: false,
      menuChildren: [
        for (final item in widget.items)
          cupertino.CupertinoMenuItem(
            leading: item == widget.value ? const Icon(cupertino.CupertinoIcons.checkmark, size: 13) : null,
            onPressed: select == null ? null : () => select(item),
            child: Text(widget.itemLabel(item)),
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
          Text(current == null ? widget.placeholder ?? '' : widget.itemLabel(current), overflow: TextOverflow.ellipsis),
          SizedBox(width: theme.token.scale.sizes.xxs),
          const Icon(cupertino.CupertinoIcons.chevron_down, size: 11),
        ],
      ),
    );
  }
}
