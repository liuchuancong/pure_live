import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_panel.dart';

/// Builds the container's content: [labeled] is true where the groups need
/// their names; the panel keeps them on.
typedef PlayerMoreContent = Widget Function(BuildContext context, {required bool labeled});

/// Opens a player's more container on the component library's own panel
/// ([DsPanel] through [showDsPanel]): the library brings the chrome, the
/// header, the scroll and the escape, so no page hand-writes a second glass
/// box. The host brings its rows and segments ([PlayerMoreRow],
/// [PlayerMoreSeg]); the container is an index of the homes that have no bar,
/// not a second copy of the verbs the bars already carry.
Future<void> showPlayerMoreContainer(BuildContext context, {required PlayerMoreContent content}) {
  return showAppPanel<void>(
    context: context,
    builder: (context) => AppPanel(
      title: Text(context.t.common.more),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [content(context, labeled: true)],
      ),
    ),
  );
}

/// A group's name over its rows, quiet enough to read as a heading and not
/// another setting.
Widget playerMoreSectionLabel(BuildContext context, String label) {
  final colors = DsTheme.colorsOf(context);
  return Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s4, DsSpace.s8, DsSpace.s4, DsSpace.s4),
    child: Text(
      label,
      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted, fontWeight: FontWeight.w700),
    ),
  );
}

/// A settings row: the label, the current value, and the chevron that opens
/// where the value lives — or, where the verb is a choice between known
/// values ([trailing]), the choices themselves.
final class PlayerMoreRow extends StatelessWidget {
  /// The row for one setting or verb.
  const PlayerMoreRow({required this.label, required this.value, required this.onTap, this.trailing, super.key});

  final String label;

  /// The value's word before the chevron; null draws the chevron alone.
  final String? value;

  /// Runs the verb; null leaves the row inert.
  final VoidCallback? onTap;

  /// A control drawn at the row's end instead of the value-plus-chevron:
  /// the segment choices.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      onPressed: onTap,
      builder: (context, states, _) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s8),
        decoration: DsBoxDecoration(
          color: states.contains(WidgetState.hovered) ? colors.hover : null,
          borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
        ),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.text),
              ),
            ),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                ),
              DsIcon(DsIcons.chevronRight, size: 14, color: colors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// The segment chip strip: the known values in a row, the live one in the
/// accent ink. A stored value between segments — a slider's leftover —
/// lights none, until a chip is picked.
final class PlayerMoreSeg<T extends num> extends StatelessWidget {
  /// The strip for one choice.
  const PlayerMoreSeg({
    required this.values,
    required this.labels,
    required this.current,
    required this.onPick,
    super.key,
  });

  final List<T> values;

  final List<String> labels;

  /// The live value; a value outside [values] lights no chip.
  final T current;

  /// Runs when a chip is picked; the live chip does not press.
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Wrap(
      spacing: DsSpace.s4,
      runSpacing: DsSpace.s4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, value) in values.indexed)
          DsPressable(
            semanticLabel: labels[index],
            onPressed: value == current ? null : () => onPick(value),
            builder: (context, states, _) {
              final on = value == current;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s3),
                decoration: DsBoxDecoration(
                  // The reference's accSoft under the live segment.
                  color: on ? theme.selectedFill : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labels[index],
                  style: theme.typography.caption.copyWith(
                    color: on ? theme.onSelectedFill : colors.textMuted,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
