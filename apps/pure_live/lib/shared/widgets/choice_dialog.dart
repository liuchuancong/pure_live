import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';

/// Opens [options] as one radio group and returns the value confirmed, or
/// null when the viewer cancels. Nothing is applied while the dialog is
/// open: a row stages the choice, and Confirm is what answers. Escape, the
/// barrier and Cancel all answer null.
///
/// Every row is a full-width pressable list row, not just its radio mark:
/// the whole row selects, and the rows and the two actions are ordinary Tab
/// stops (and arrow-key destinations), so focus always reaches Cancel and
/// Confirm.
Future<T?> showChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required List<DsSelectOption<T>> options,
  required T? value,
  String? semanticLabel,
}) => showDsDialog<T>(
  context: context,
  builder: (context) =>
      _ChoiceDialog<T>(title: title, options: options, value: value, semanticLabel: semanticLabel ?? title),
);

final class _ChoiceDialog<T> extends StatefulWidget {
  const _ChoiceDialog({required this.title, required this.options, required this.value, required this.semanticLabel});

  final String title;
  final List<DsSelectOption<T>> options;
  final T? value;
  final String semanticLabel;

  @override
  State<_ChoiceDialog<T>> createState() => _ChoiceDialogState<T>();
}

final class _ChoiceDialogState<T> extends State<_ChoiceDialog<T>> {
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsDialog(
      title: Text(widget.title),
      description: DsListSection(
        children: [
          for (final option in widget.options)
            DsListRow(
              leading: _RadioMark(selected: _selected == option.value),
              title: option.leading == null
                  ? Text(option.label)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(dimension: 20, child: Center(child: option.leading)),
                        const SizedBox(width: DsSpace.s8),
                        Flexible(child: Text(option.label)),
                      ],
                    ),
              detail: option.detail == null ? null : Text(option.detail!),
              selected: _selected == option.value,
              autofocus: _selected == option.value,
              semanticLabel: option.label,
              onPressed: option.enabled
                  ? () {
                      if (_selected != option.value) setState(() => _selected = option.value);
                    }
                  : null,
            ),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
          child: Text(t.common.confirm),
        ),
      ],
    );
  }
}

/// The radio mark of a choice row: a circle that fills in when its row is
/// the staged choice, in the same ink as [DsRadio].
final class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // A strong selection fill carries the row's ink; the mark follows it so
    // the two never blend into one another.
    final strong = theme.fillsSelection;
    final fill = selected ? (strong ? theme.onSelectedFill : colors.accent) : colors.field;
    final border = selected ? (strong ? theme.onSelectedFill : colors.accentEdge) : colors.borderField;
    final dot = selected ? (strong ? theme.selectedFill : colors.onAccent) : null;
    return SizedBox.square(
      dimension: 18,
      child: AnimatedContainer(
        duration: theme.motion.toneDuration,
        curve: theme.motion.toneCurve,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border),
        ),
        child: dot == null
            ? null
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
      ),
    );
  }
}

/// A select-shaped trigger that opens [showChoiceDialog] instead of a menu.
/// Desktop keeps the platform's dropdown ([DsSelect]); a phone or tablet has
/// no pointer hover or wheel, so the same choice opens as a dialog with a
/// full-row list and the two actions.
final class AdaptiveChoiceField<T> extends ConsumerWidget {
  const AdaptiveChoiceField({
    required this.value,
    required this.options,
    required this.onChanged,
    this.title,
    this.placeholder,
    this.semanticLabel,
    super.key,
  });

  /// The value in force, or null for none.
  final T? value;

  /// What the field offers, top to bottom.
  final List<DsSelectOption<T>> options;

  /// Called with the value chosen. Null disables the field.
  final ValueChanged<T>? onChanged;

  /// The dialog's heading on touch; [semanticLabel] when omitted.
  final String? title;

  /// Shown while nothing is chosen.
  final String? placeholder;

  /// What this field chooses, for screen readers and the dialog heading.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(deviceProfileProvider).isDesktop) {
      return DsSelect<T>(
        value: value,
        onChanged: onChanged == null
            ? null
            : (picked) {
                if (picked != null) onChanged!(picked);
              },
        options: options,
        placeholder: placeholder,
        semanticLabel: semanticLabel,
      );
    }
    return _DialogChoiceField<T>(
      value: value,
      options: options,
      onChanged: onChanged,
      title: title,
      placeholder: placeholder,
      semanticLabel: semanticLabel,
    );
  }
}

/// The touch trigger: a select-shaped field that opens the dialog.
final class _DialogChoiceField<T> extends StatelessWidget {
  const _DialogChoiceField({
    required this.value,
    required this.options,
    required this.onChanged,
    this.title,
    this.placeholder,
    this.semanticLabel,
  });

  final T? value;
  final List<DsSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? title;
  final String? placeholder;
  final String? semanticLabel;

  DsSelectOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showChoiceDialog<T>(
      context: context,
      title: title ?? semanticLabel ?? placeholder ?? '',
      options: options,
      value: value,
      semanticLabel: semanticLabel,
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final selected = _selected;
    final label = selected?.label ?? placeholder ?? '';
    final semantic = semanticLabel == null ? label : '$semanticLabel: $label';
    return DsPressable(
      onPressed: onChanged == null ? null : () => unawaited(_open(context)),
      semanticLabel: semantic.isEmpty ? null : semantic,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        final focused = states.contains(WidgetState.focused);
        final height = theme.sizes.md;
        final disabled = states.contains(WidgetState.disabled);
        return AnimatedContainer(
          duration: theme.motion.toneDuration,
          curve: theme.motion.toneCurve,
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
          decoration: BoxDecoration(
            color: disabled ? colors.disabled : (hovered ? colors.controlHover : colors.field),
            borderRadius: theme.radii.controlCorners(null, height),
            border: Border.all(color: focused ? colors.focus : colors.borderField, width: focused ? 2 : 1),
          ),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: disabled ? colors.onDisabled : (selected == null ? colors.textSubtle : colors.text),
                  ),
                ),
              ),
              DsIcon(DsIcons.chevronDown, size: 16, color: disabled ? colors.onDisabled : colors.textMuted),
            ],
          ),
        );
      },
    );
  }
}
