import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/shared.dart';

/// A setting row with its control at the row's end; on a narrow pane a wide
/// control (a slider, a field, a picker) drops under the label, while a
/// switch or checkbox — small enough to fit beside any label — stays in the
/// row. Shared by the app-wide sections and the module-specific panes (IPTV,
/// the Bilibili station), so every settings surface answers a narrow window
/// the same way.
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

  /// The narrowest row a slider still shares with its label. Below it the
  /// slider drops under the label instead of squeezing both to a sliver.
  static const double _sliderInlineMinWidth = 300;

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
        final wide = constraints.maxWidth >= LiveWindow.sheet;
        // A slider is narrow enough to sit at the row's end on any pane that
        // can still spare its share of the line — the danmaku page stacks
        // some twenty of them, and a slider under every label made that
        // column read twice as tall as it is wide. Under this width there is
        // no honest room for both, so it drops below the label.
        final narrowSlider = !wide && control is DsSlider && constraints.maxWidth >= _sliderInlineMinWidth;
        // A switch or checkbox is small enough to keep at the row's end at
        // any width; only a control that needs a slot of its own drops to
        // the line below the label.
        final inRow = wide || _controlIsIntrinsic || narrowSlider;
        final row = DsListRow(
          leading: leading,
          title: Text(title),
          description: description == null ? null : Text(description!),
          detail: detail,
          trailing: inRow
              ? wide
                    ? _slot(alignment: Alignment.centerRight)
                    : narrowSlider
                    ? SizedBox(width: math.min(controlWidth, constraints.maxWidth * 0.42), child: control)
                    : Align(alignment: Alignment.centerRight, child: control)
              : null,
        );
        if (inRow) return row;
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

/// A muted paragraph inside a settings card: the explanation a row cannot
/// carry, or the caveat that would make its description too long. Every page
/// uses this so notes share one measure, one tone and one distance from the
/// row above them.
final class SettingsHint extends StatelessWidget {
  /// The note's [text]; [style] overrides the muted caption for a warning.
  const SettingsHint(this.text, {this.style, super.key});

  /// What the note says.
  final String text;

  /// Overrides the muted caption; used for a danger-toned caveat.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
      child: Text(text, style: style ?? theme.typography.caption.copyWith(color: colors.textMuted)),
    );
  }
}

/// A row for a short choice — two or three options whose labels fit side by
/// side — drawn as one segmented control: the current value stays visible,
/// and changing it is one tap rather than a dialog. A wider pane keeps the
/// control on the row's end; a phone puts it under the label at full width.
final class SettingsSegmentedRow<T> extends StatelessWidget {
  /// A row choosing [value] among [options].
  const SettingsSegmentedRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leading,
    this.description,
    this.detail,
    this.controlWidth = 240,
    super.key,
  });

  /// The row's name.
  final String title;

  /// One line under the name.
  final String? description;

  /// A leading glyph.
  final Widget? leading;

  /// A value printed before the control, e.g. the "custom" badge.
  final Widget? detail;

  /// The value in force; a value no option names selects none.
  final T value;

  /// The labels and their values, in reading order.
  final List<({T value, String label})> options;

  /// Called with the picked value; null disables the control.
  final ValueChanged<T>? onChanged;

  /// The control's width on a wide pane.
  final double controlWidth;

  @override
  Widget build(BuildContext context) {
    final control = DsSegmentedControl<T>(
      value: value,
      onChanged: onChanged,
      semanticLabel: title,
      segments: [for (final option in options) DsSegment(value: option.value, label: Text(option.label))],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= LiveWindow.sheet) {
          return SettingsConfigRow(
            leading: leading,
            title: title,
            description: description,
            detail: detail,
            controlWidth: controlWidth,
            control: control,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsListRow(
              leading: leading,
              title: Text(title),
              description: description == null ? null : Text(description!),
              detail: detail,
            ),
            Padding(padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12), child: control),
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
