import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvProgrammeSlot;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The module's one page head: the 44px line every IPTV page opens with —
/// the title, a muted description beside it, and the page's verbs at the
/// end. The reference's `head44` row. A page applies its own inset padding
/// around it and draws its own control lines under it; the row never folds
/// the verbs — the title and description give way first, so the verbs stay
/// visible to the width the module already supports — and a page whose verbs
/// ride the shell's head instead passes none.
final class IptvPageHead extends StatelessWidget {
  const IptvPageHead({required this.title, this.description, this.actions = const <Widget>[], super.key});

  /// The page's name, in the head's strong label.
  final String title;

  /// The muted facts beside the name — the counts, a search's tally. Null
  /// leaves the title alone on the line.
  final String? description;

  /// The page's verbs, laid out at the row's end.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      height: 44,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: theme.typography.labelStrong.copyWith(color: colors.text),
                  ),
                  if (description != null) ...[
                    TextSpan(
                      text: '  ·  ',
                      style: theme.typography.small.copyWith(color: colors.textSubtle),
                    ),
                    TextSpan(
                      text: description,
                      style: theme.typography.small.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The module's one way to draw a channel's mark: the playlist's own
/// `tvg-logo` picture where it names one, the module's tv glyph where it does
/// not. Never the channel's name — `DsAvatar`'s initials are 「up to two
/// letters」, so a name fed through them draws half a word in the very row that
/// writes the whole one beside it. Four surfaces used to copy this out at three
/// sizes with three fallbacks; the mark a list shows is the one thing every
/// channel row shares, so it is drawn in one place.
final class IptvChannelLogo extends StatelessWidget {
  /// The mark of [channel] at [size].
  const IptvChannelLogo({required this.channel, this.size = DsSize.sm, super.key});

  /// The channel whose logo is drawn.
  final IptvChannel channel;

  /// The kit's size; a row's mark and a page head's mark differ by [size],
  /// never by shape or by what stands in for a missing picture.
  final DsSize size;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    // The kit's own avatar diameters, so a mark folded here is exactly the size
    // the module's avatars were.
    final box = switch (size) {
      DsSize.xs => 24.0,
      DsSize.sm => 32.0,
      DsSize.md => 40.0,
      DsSize.lg => 48.0,
    };
    final mark = SizedBox(
      width: box,
      height: box,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.control, shape: BoxShape.circle),
        child: Center(
          child: DsIcon(DsIcons.tv, size: box * .55, color: colors.textMuted),
        ),
      ),
    );
    final logo = (channel.entry.tvgLogo ?? '').trim();
    if (logo.isEmpty) return mark;
    return ClipOval(
      child: DsImage(
        image: cachedImage(logo),
        width: box,
        height: box,
        fit: BoxFit.contain,
        semanticLabel: channel.entry.name,
        fallback: mark,
      ),
    );
  }
}

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
    final theme = DsTheme.of(context);
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
              child: toolbar,
            ),
            const DsDivider(),
            if (fill) Expanded(child: child) else child,
          ],
        ),
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

/// What is on the channel: the on-air programme with its progress, the next
/// one when nothing is on yet, and a quiet "no guide" line when there is no
/// schedule to read — three facts, drawn as three things.
///
/// The channel table's 正在播出 column and its stacked narrow form, and the
/// 最近观看 rows, all speak it: one guide, one wording for what it answers.
final class IptvNowCell extends StatelessWidget {
  /// The cell over [slot] — null while the library has not read it yet.
  const IptvNowCell({required this.slot, super.key});

  /// What is on and what comes after, as read at one instant.
  final IptvProgrammeSlot? slot;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final current = slot?.current;
    final next = slot?.next;
    if (current != null && current.title.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              DsBadge(label: Text(t.iptv.onAir), status: DsStatus.danger),
              Flexible(
                child: Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          // A programme whose length the guide does not know draws no bar:
          // an indeterminate sweep would read as "loading".
          if (slot?.progress case final progress?) DsProgressBar(value: progress, semanticLabel: t.iptv.onAir),
        ],
      );
    }
    if (next != null && next.title.isNotEmpty) {
      return Row(
        spacing: DsSpace.s6,
        children: [
          DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
          Flexible(
            child: Text(
              '${t.iptv.upNext} · ${next.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      );
    }
    return Text(
      t.iptv.noGuide,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(color: colors.textSubtle),
    );
  }
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
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: lit && enabled ? colors.hover : null,
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
