import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// The surface that holds a toolbar and a data table, drawn as one card:
/// the toolbar sits over a hairline, the table underneath is transparent
/// and keeps its own sticky header. The reference's resource panels.
final class IptvTablePanel extends StatelessWidget {
  /// A panel over [child], with [toolbar] above the rule.
  const IptvTablePanel({required this.toolbar, required this.child, this.fill = false, super.key});

  /// The filters, counts and actions above the rule.
  final Widget toolbar;

  /// The table (or whatever the panel holds).
  final Widget child;

  /// Whether [child] takes the panel's remaining height and scrolls inside
  /// it. False lets a short table sit at its natural height in a page that
  /// scrolls as a whole.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: DsBoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        shadows: theme.shadows.surface,
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8), child: toolbar),
          SizedBox(height: 1, child: ColoredBox(color: colors.border)),
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// The table style inside an [IptvTablePanel]: the panel already supplies
/// the fill, corners and shadow, so the table draws only its rules.
DsTableStyle iptvTableStyle(BuildContext context) {
  final colors = DsTheme.colorsOf(context);
  return DsTableStyle(
    background: const Color(0x00000000),
    shadows: const [],
    borderRadius: BorderRadius.zero,
    dividerColor: colors.border,
    rowHeight: 64,
    headerHeight: 36,
  );
}

/// "1,024" for a count in a summary or a table cell.
String iptvNumber(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// One icon action in a table row: a quiet square that shows its name on
/// hover and turns the danger tint for a destructive one. [busy] swaps the
/// glyph for a spinner and ignores presses.
final class IptvIconAction extends StatelessWidget {
  /// An action showing [icon], named [label].
  const IptvIconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.busy = false,
    this.color,
    super.key,
  });

  /// The glyph.
  final DsIconData icon;

  /// The tooltip and screen-reader name.
  final String label;

  /// Fired on press; null disables the action.
  final VoidCallback? onPressed;

  /// Draws the glyph in the danger tone.
  final bool destructive;

  /// Shows a spinner in the glyph's place, with presses ignored.
  final bool busy;

  /// A tone of its own (a favourited heart's accent); null follows the
  /// muted/danger rule.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final enabled = onPressed != null && !busy;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: enabled ? onPressed : null,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: hovered && enabled ? colors.hover : null,
              borderRadius: BorderRadius.circular(theme.radii.control(32)),
            ),
            child: busy
                ? DsSpinner(semanticLabel: label, style: const DsSpinnerStyle(size: 14))
                : DsIcon(
                    icon,
                    size: theme.sizes.iconSm,
                    color: !enabled
                        ? colors.textSubtle
                        : color ?? (destructive ? colors.danger.fill : colors.textMuted),
                  ),
          );
        },
      ),
    );
  }
}

/// Syncs every network playlist and guide, then says what the round did.
///
/// Shared by the channels and the sources surfaces: both offer the same
/// refresh, and both read the round's progress from the sources state.
Future<void> syncAllIptvSources(BuildContext context, WidgetRef ref) async {
  final report = await ref.read(iptvSourcesProvider.notifier).syncAll();
  if (!context.mounted) return;
  final t = context.t;
  if (report.total == 0) {
    showDsToast(context: context, title: t.iptv.syncAllNone, status: DsStatus.danger);
  } else if (report.failed == 0) {
    showDsToast(
      context: context,
      title: t.iptv.syncAllDone(count: report.total),
    );
  } else {
    showDsToast(
      context: context,
      title: t.iptv.syncAllPartial(failed: report.failed, count: report.total),
      status: DsStatus.danger,
    );
  }
}
