import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/shared.dart';

/// A setting row with its control in the row on a wide pane, and under the
/// label on a narrow one — desen_ui's form rhythm without copying a
/// desktop layout onto a phone. Shared by the app-wide sections and the
/// module-specific panes (IPTV, the Bilibili station), so every settings
/// surface answers a narrow window the same way.
final class SettingsConfigRow extends StatelessWidget {
  /// A row for [title] with [control] at its end.
  const SettingsConfigRow({
    required this.title,
    required this.control,
    this.description,
    this.leading,
    this.detail,
    this.controlWidth = 200,
    super.key,
  });

  /// The row's name.
  final String title;

  /// One line under the name.
  final String? description;

  /// A leading glyph.
  final Widget? leading;

  /// A value printed before the control, e.g. "250 px".
  final Widget? detail;

  /// The control itself.
  final Widget control;

  /// The control's width in the wide layout.
  ///
  /// Ignored for a control that carries its own size, e.g. a switch: it gets
  /// its natural track and sits at the end of this width.
  final double controlWidth;

  /// Whether [control] brings its own size, so the row must not stretch it.
  /// A stretched switch reads as a progress bar, not a toggle.
  bool get _controlIsIntrinsic => control is DsSwitch || control is DsCheckbox;

  /// The control in a slot of [controlWidth] that it is allowed to shrink
  /// inside of.
  Widget _slot({required AlignmentGeometry alignment}) {
    final sized = _controlIsIntrinsic ? Align(alignment: alignment, child: control) : control;
    return SizedBox(width: controlWidth, child: sized);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final row = DsListRow(
          leading: leading,
          title: Text(title),
          description: description == null ? null : Text(description!),
          detail: detail,
          trailing: wide ? _slot(alignment: Alignment.centerRight) : null,
        );
        if (wide) return row;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
              child: _slot(alignment: Alignment.centerLeft),
            ),
          ],
        );
      },
    );
  }
}

/// A setting row whose value follows the shell: desktop keeps the select's
/// dropdown, and touch opens a full-row radio dialog whose Confirm applies
/// the choice. The dialog's rows and actions are ordinary focus stops, so a
/// keyboard or remote can leave the options for Cancel and Confirm.
final class SettingsChoiceRow<T> extends ConsumerWidget {
  const SettingsChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leading,
    this.description,
    this.placeholder,
    this.semanticLabel,
    this.controlWidth = 220,
    super.key,
  });

  /// The row's name, and the dialog's heading.
  final String title;

  /// One line under the name.
  final String? description;

  /// A leading glyph.
  final Widget? leading;

  /// The value in force, or null for none.
  final T? value;

  /// What the dialog offers, top to bottom.
  final List<DsSelectOption<T>> options;

  /// Called with the value confirmed in the dialog; null disables the row.
  final ValueChanged<T>? onChanged;

  /// Shown at the end while nothing is chosen.
  final String? placeholder;

  /// What the row chooses, for screen readers; the title when omitted.
  final String? semanticLabel;

  /// The dropdown's width on desktop.
  final double controlWidth;

  DsSelectOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showChoiceDialog<T>(
      context: context,
      title: title,
      options: options,
      value: value,
      semanticLabel: semanticLabel ?? title,
    );
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(deviceProfileProvider).isDesktop) {
      return SettingsConfigRow(
        leading: leading,
        title: title,
        description: description,
        controlWidth: controlWidth,
        control: DsSelect<T>(
          value: value,
          onChanged: onChanged == null
              ? null
              : (picked) {
                  if (picked != null) onChanged!(picked);
                },
          options: options,
          placeholder: placeholder,
          semanticLabel: semanticLabel,
        ),
      );
    }
    final selected = _selected;
    final detail = selected?.label ?? placeholder;
    return DsListRow(
      leading: leading,
      title: Text(title),
      description: description == null ? null : Text(description!),
      detail: detail == null ? null : Text(detail),
      showChevron: onChanged != null,
      onPressed: onChanged == null ? null : () => unawaited(_open(context)),
      semanticLabel: semanticLabel,
    );
  }
}
