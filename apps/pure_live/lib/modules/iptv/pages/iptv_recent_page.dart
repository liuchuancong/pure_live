import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart';
import 'package:pure_live/shared/shared.dart' show cachedImage;

/// The IPTV module's 最近观看: the channels the player has opened, newest
/// first. The record is this module's own — it follows the library's channel
/// ids, so a re-import keeps the entries attached to the same channels.
final class IptvRecentPage extends ConsumerWidget {
  /// The module's history page.
  const IptvRecentPage({super.key});

  void _open(BuildContext context, IptvChannel channel) {
    unawaited(context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel));
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.recentClearTitle,
      description: t.iptv.recentClearDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(iptvRecentProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final recent = ref.watch(iptvRecentProvider);
    final library = ref.watch(iptvLibraryProvider).value;
    final channels = {for (final channel in library?.channels ?? const <IptvChannel>[]) channel.id: channel};
    final rows = [
      for (final entry in recent)
        if (channels[entry.channelId] case final channel?) (entry: entry, channel: channel),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      t.iptv.recentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                    Text(
                      t.iptv.recentCount(count: rows.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty)
                DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.iptv.recentClear,
                  onPressed: () => unawaited(_clear(context, ref)),
                  icon: const DsIcon(DsIcons.trash2, size: 16),
                ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? DsEmptyState(
                  icon: const DsIcon(DsIcons.history),
                  title: Text(t.iptv.recentEmptyTitle),
                  description: Text(t.iptv.recentEmptyDescription),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s4, DsSpace.s16, DsSpace.s24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final (:entry, :channel) = rows[index];
                    final logo = (channel.entry.tvgLogo ?? '').trim();
                    final group = iptvGroupKeyOf(channel);
                    final watched = t.iptv.recentWatched(time: recentTimeLabel(entry.watchedAt));
                    return DsListRow(
                      leading: DsAvatar(
                        initials: channel.entry.name,
                        image: logo.isEmpty ? null : cachedImage(logo),
                        size: DsSize.sm,
                        toneIndex: DsAvatar.toneFor(channel.id),
                        semanticLabel: channel.entry.name,
                      ),
                      title: Text(
                        channel.entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(color: colors.text),
                      ),
                      description: Text(
                        group.isEmpty ? watched : '$group · $watched',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textSubtle),
                      ),
                      trailing: DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.iptv.recentRemove,
                        onPressed: () => unawaited(ref.read(iptvRecentProvider.notifier).remove(channel.id)),
                        icon: const DsIcon(DsIcons.x, size: 16),
                      ),
                      onPressed: () => _open(context, channel),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A history record's moment, "MM-DD HH:mm".
String recentTimeLabel(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}
