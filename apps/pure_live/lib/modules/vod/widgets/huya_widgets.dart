import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoCard, VodVideoRow, kVodCardInfoExtent;
import 'package:pure_live/shared/shared.dart';

/// One card in a Huya grid, with the stand it holds on a board.
typedef HuyaCard = ({VodVideo video, int rank});

/// One shelf of the station's home: its name with the way to the whole
/// listing beside it, and as many cards as a single row holds — the same
/// measure the browse grid takes, so a shelf never invents a card shape.
final class HuyaShelf extends ConsumerWidget {
  /// The shelf for [shelf].
  const HuyaShelf({required this.shelf, required this.onOpen, this.onMore, super.key});

  /// The shelf's videos and its channel.
  final HuyaVideoShelf shelf;

  /// Opens one video.
  final ValueChanged<String> onOpen;

  /// Walks into the shelf's channel; null leaves the way out.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final browse = ref.watch(browseSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        Semantics(
          header: true,
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  shelf.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                ),
              ),
              if (onMore != null)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: onMore,
                  child: Text(t.vod.huyaMore),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
            if (content <= 0) return const SizedBox.shrink();
            final spacing = browse.crossSpacing;
            final columns = math.max(
              1,
              cappedColumnsForWidth(
                content,
                spacing: spacing,
                ceiling: browse.gridColumns,
                minWidth: kBrowseCardMinWidth,
              ),
            );
            final width = columnExtentForWidth(content, columns, spacing) - .01;
            final height = width * 9 / 16 + kVodCardInfoExtent;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final video in shelf.videos.take(columns))
                  SizedBox(
                    width: width,
                    height: height,
                    child: VodVideoCard(video: video.asVideo(), onOpen: () => onOpen(video.id)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One page of the station's videos as the shared card grid: the viewer's
/// own card/list layout and spacing, the board's stand over the cover when
/// [ranked], and the grid's own skeletons, footer and empty state.
final class HuyaVideoGrid extends ConsumerWidget {
  /// The grid over [videos].
  const HuyaVideoGrid({
    required this.videos,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onOpen,
    this.scrollController,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.emptyTitle,
    this.emptyDescription,
    this.ranked = false,
    super.key,
  });

  /// The rows the source has answered so far.
  final List<HuyaVideo> videos;

  /// Whether a page is in flight.
  final bool loading;

  /// Whether the source may still have more.
  final bool hasMore;

  /// Asks for the next page.
  final Future<void> Function() onLoadMore;

  /// Opens one video by its station id.
  final ValueChanged<String> onOpen;

  /// The grid's scroll controller, when the page keeps one.
  final ScrollController? scrollController;

  /// The failure to show in place of rows.
  final String? error;

  /// Reads again after a failure.
  final VoidCallback? onRetry;

  /// Reloads the whole page.
  final Future<void> Function()? onRefresh;

  /// What an empty page says under its title.
  final String? emptyTitle;

  /// What an empty page says under its title.
  final String? emptyDescription;

  /// Whether the cards wear their 1-based stand on the board.
  final bool ranked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(browseSettingsProvider);
    final cards = <HuyaCard>[
      for (final (index, video) in videos.indexed) (video: video.asVideo(), rank: ranked ? index + 1 : 0),
    ];
    return PagedCardGrid<HuyaCard>(
      scrollController: scrollController,
      items: cards,
      layout: ref.watch(browseLayoutProvider),
      listMainAxisExtent: 104,
      listItemBuilder: (context, card) => VodVideoRow(video: card.video, onOpen: () => onOpen(card.video.id)),
      infoExtent: kVodCardInfoExtent,
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      isLoading: loading,
      hasMore: hasMore,
      onLoadMore: onLoadMore,
      error: error,
      onRetry: onRetry,
      onRefresh: onRefresh,
      refreshError: error,
      emptyIcon: DsIcons.film,
      emptyTitle: emptyTitle ?? t.common.empty,
      emptyDescription: emptyDescription,
      itemBuilder: (context, card) =>
          VodVideoCard(video: card.video, rank: card.rank == 0 ? null : card.rank, onOpen: () => onOpen(card.video.id)),
    );
  }
}
