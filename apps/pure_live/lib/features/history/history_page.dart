import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/features/history/history_repository.dart';
import 'package:pure_live/l10n/translations.dart';

/// The live module's history: the watched rooms, newest watch first, as
/// full-width list cards; one row's x drops its record, the header's
/// button drops them all.
final class HistoryPage extends ConsumerWidget {
  /// The history page.
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    if (!history.ready) {
      return const _SkeletonList();
    }
    if (history.rooms.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.history),
          title: Text(context.t.history.emptyTitle),
          description: Text(context.t.history.emptyDescription),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s4),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton(
              onPressed: () => unawaited(ref.read(historyProvider.notifier).clear()),
              child: Text(context.t.history.clear),
            ),
          ),
        ),
        Expanded(
          child: MosaicGrid.builder(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
            columns: const MosaicColumns.count(1),
            rowGap: DsSpace.s8,
            itemCount: history.rooms.length,
            itemBuilder: (context, index) {
              final room = history.rooms[index];
              return _HistoryCard(
                room: room,
                onRemove: () => unawaited(ref.read(historyProvider.notifier).remove(room.ref.identityKey)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One watched room as a list card: the cover as a thumb, the title, the
/// streamer, and the record's remove button.
final class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.room, required this.onRemove});

  final LiveRoom room;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      onPressed: null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s8),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              SizedBox(
                width: theme.sizes.lg * 2,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s8)),
                    child: DsImage.network(room.content.coverUrl, semanticLabel: room.content.title),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(
                      room.anchor?.name ?? room.ref.roomId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              DsPressable(
                semanticLabel: context.t.history.remove,
                onPressed: onRemove,
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return DsIcon(
                    DsIcons.x,
                    size: theme.sizes.iconSm,
                    color: hovered ? colors.danger.fill : colors.textSubtle,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The list's opening placeholder.
final class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: const MosaicColumns.count(1),
      rowGap: DsSpace.s8,
      children: [for (var i = 0; i < 8; i++) const _HistoryCardSkeleton()],
    );
  }
}

/// One history card's placeholder.
final class _HistoryCardSkeleton extends StatelessWidget {
  const _HistoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s8),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsSkeleton.block(width: theme.sizes.lg * 2, height: theme.sizes.lg * 2 * 9 / 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [DsSkeleton(width: DsSpace.s32), DsSkeleton(width: DsSpace.s20)],
            ),
          ),
        ],
      ),
    );
  }
}
