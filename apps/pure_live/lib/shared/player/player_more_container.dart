import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart' show PlayerGlassCard;

/// The width where a player's more container docks as a panel; under it the
/// same content slides from the bottom as a sheet. The room's own measure.
const double kPlayerMorePanelBreakpoint = 720;

/// Builds the container's content: [labeled] is true in the sheet, where the
/// groups need their names, and false in the panel, where spacing reads them.
typedef PlayerMoreContent = Widget Function(BuildContext context, {required bool labeled});

/// Opens a player's more container at the page level: a right-docked glass
/// panel where the window has the room, a bottom glass sheet where it
/// doesn't — the same content in both, one entry (the picture's top-right ⋯)
/// and one barrier tap or Escape to close.
///
/// The shape the live room's more panel drew, lifted for every player: the
/// host brings its own rows and tiles ([PlayerMoreRow], [PlayerMoreTile],
/// [PlayerMoreSeg]) and the container carries the chrome — the glass, the
/// header, the grip, the escape — so no page draws a second one.
Future<void> showPlayerMoreContainer(BuildContext context, {required PlayerMoreContent content}) {
  final asPanel = MediaQuery.sizeOf(context).width >= kPlayerMorePanelBreakpoint;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t.common.more,
    barrierColor: const Color(0x40000000),
    pageBuilder: (context, _, _) => _PlayerMoreEscape(
      child: asPanel ? _PlayerMorePanel(content: content) : _PlayerMoreSheet(content: content),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: Offset(asPanel ? 1 : 0, asPanel ? 0 : 1), end: Offset.zero).animate(curve),
        child: child,
      );
    },
  );
}

/// Closes the container on Escape, wherever the focus sits inside it: a
/// keyboard viewer who opened the container from a shortcut expects the
/// keyboard to close it too. The autofocus keeps the shortcut live until a
/// tile takes the focus — and the shortcut still answers then, from the
/// tile's own place in this subtree.
final class _PlayerMoreEscape extends StatelessWidget {
  const _PlayerMoreEscape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// The right-docked panel: under the page's own bar, full height, rounded on
/// its start side only — its end edge is the window's. The header carries the
/// 更多 and the close ✕.
final class _PlayerMorePanel extends StatelessWidget {
  const _PlayerMorePanel({required this.content});

  final PlayerMoreContent content;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: EdgeInsetsDirectional.only(top: MediaQuery.paddingOf(context).top + 56),
        child: SizedBox(
          width: 372,
          child: PlayerGlassCard(
            borderRadius: BorderRadiusDirectional.horizontal(start: Radius.circular(theme.radii.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s6, DsSpace.s6, DsSpace.s6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t.common.more,
                          style: theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const _CloseButton(),
                    ],
                  ),
                ),
                Container(height: 1, color: colors.border),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsetsDirectional.only(bottom: MediaQuery.paddingOf(context).bottom + DsSpace.s12),
                    child: content(context, labeled: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet: the same content, the grip instead of a header, the
/// section labels on.
final class _PlayerMoreSheet extends StatelessWidget {
  const _PlayerMoreSheet({required this.content});

  final PlayerMoreContent content;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .76),
        child: SizedBox(
          width: double.infinity,
          child: PlayerGlassCard(
            topOnly: true,
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.only(bottom: MediaQuery.paddingOf(context).bottom + DsSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // A sheet reads its grip; a panel needs none — its edge is
                  // the seam.
                  Center(
                    child: Container(
                      margin: const EdgeInsetsDirectional.symmetric(vertical: DsSpace.s8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  content(context, labeled: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's close ✕: a quiet square that lights on hover.
final class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: context.t.common.close,
      onPressed: () => Navigator.of(context).pop(),
      builder: (context, states, _) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: DsBoxDecoration(
          color: states.contains(WidgetState.hovered) ? colors.hover : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DsIcon(DsIcons.close, size: 16, color: colors.textMuted),
      ),
    );
  }
}

/// A group's name: the sheet keeps its labels on, the panel lets the spacing
/// read them.
Widget playerMoreSectionLabel(BuildContext context, String label) {
  final colors = DsTheme.colorsOf(context);
  return Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s12, DsSpace.s12, DsSpace.s4),
    child: Text(
      label,
      style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted, fontWeight: FontWeight.w700),
    ),
  );
}

/// The tools grid's tile: a circle in the surface's own ink, a lit ring of
/// accent when the verb is on.
final class PlayerMoreTile extends StatelessWidget {
  /// The tile for one verb.
  const PlayerMoreTile({required this.icon, required this.label, required this.onTap, this.lit = false, super.key});

  final DsIconData icon;

  final String label;

  /// Runs the verb; null leaves the tile inert and grayed.
  final VoidCallback? onTap;

  /// Whether the verb is on — its ring and glyph read in the accent.
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final enabled = onTap != null;
    return DsPressable(
      onPressed: onTap,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hovered && enabled ? colors.hover : null,
                  border: Border.all(color: lit ? colors.accent : colors.border),
                ),
                child: DsIcon(
                  icon,
                  size: 18,
                  color: !enabled
                      ? colors.textMuted
                      : lit
                      ? colors.accent
                      : colors.text,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: enabled ? colors.text : colors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
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
