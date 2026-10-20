import 'package:flutter/material.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// A pill that names one thing on a feed and offers something to do with it:
/// a filter that selects, a source that deletes.
///
/// The Material `Chip` family is printed on a Material sheet, and the app's own
/// hosts lay down none — a `ChoiceChip` under a Fluent host throws before it
/// paints and takes its strip down with it. So the pill is the toolkit's
/// generic styled group, dressed from the theme's tokens, with the dispatched
/// `PureIconButton` for the delete affordance; every language draws it in its
/// own fills and corner rather than borrowing Material's.
final class FeedChip extends StatelessWidget {
  /// A pill labelled [label].
  const new({required this.label, this.selected = false, this.onTap, this.onDeleted, this.deleteTooltip, super.key});

  /// The pill's text.
  final String label;

  /// Whether this pill is the one chosen.
  final bool selected;

  /// What a tap does; null renders the pill as a caption with no press state.
  final VoidCallback? onTap;

  /// What the trailing cross does; null leaves it off.
  final VoidCallback? onDeleted;

  /// The hint on the delete affordance; the shared "删除" when unset, so a
  /// caller cannot leave the cross unnamed.
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return PureBox(
      onTap: onTap,
      enabled: onTap != null,
      style: (state) => Style(
        background: switch ((selected, state)) {
          (true, _) => theme.colors.primary,
          // A caption-only pill has no press feedback to promise.
          (false, InteractionState.hovered) => onTap == null ? null : theme.colors.fillQuaternary,
          (false, InteractionState.pressed) => onTap == null ? null : theme.colors.fillTertiary,
          (false, _) => theme.colors.fillQuaternary,
        },
        foreground: selected ? theme.colors.onPrimary : theme.colors.text,
        padding: EdgeInsets.fromLTRB(10, 4, onDeleted == null ? 10 : 6, 4),
        minHeight: 28,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderColor: theme.colors.border,
        borderWidth: 1,
        alignment: Alignment.center,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.text.caption),
          if (onDeleted case final delete?) ...[
            const SizedBox(width: 2),
            PureIconButton(
              icon: Icons.close,
              tooltip: deleteTooltip ?? context.t.common.delete,
              size: ControlSize.sm,
              onPressed: delete,
            ),
          ],
        ],
      ),
    );
  }
}
