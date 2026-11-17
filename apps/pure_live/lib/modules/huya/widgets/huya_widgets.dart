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

/// The widest a video card gets on the station's pages: denser than the
/// shared browse ceiling, because the station's cards are a 16:9 cover over
/// one title line — at the shared 340 a wide window shows six enormous
/// frames where the station's own home shows eight modest ones.
const double kHuyaVideoCardWidth = 260;

/// The narrowest that card may get before the row takes a column back
/// rather than thinning the covers into slivers.
const double kHuyaVideoCardMinWidth = 200;

/// The card extent the station's grids give themselves over [content]
/// pixels, or null where the shared measure should answer: a window too
/// narrow for two cards is the phone's, whose own column count speaks.
/// The viewer's own column count may only densify this wall — it raises the
/// station's count when it asks for more — never fatten it: a low count on
/// a wide window is exactly the fat-cover wall this station's measure
/// exists to answer, so the station's cap always governs.
double? huyaVideoCardExtent(double content, BrowseSettings browse) {
  if (content < kBrowseCardMinWidth * 2 + browse.crossSpacing) return null;
  double width(int columns) => (content - browse.crossSpacing * (columns - 1)) / columns;
  var columns = math.max(1, ((content + browse.crossSpacing) / (kHuyaVideoCardWidth + browse.crossSpacing)).ceil());
  if (columns > 1 && width(columns) < kHuyaVideoCardMinWidth) columns--;
  return columnExtentForWidth(
    content,
    pinnedColumnsForWidth(
      content,
      spacing: browse.crossSpacing,
      pinned: browse.gridColumns,
      base: columns,
      minWidth: kHuyaVideoCardMinWidth,
    ),
    browse.crossSpacing,
  );
}

/// The module's one in-place state pane: the spinner a first read waits
/// under, or the failure with its way back in. Every surface the grid does
/// not own — a strip that has not arrived, an uploader's page — shows its
/// wait and its failure through this, so the wording and the retry stay one
/// shape module-wide.
final class HuyaLoadPanes extends StatelessWidget {
  /// The pane for [loading] or [error]; [error] wins.
  const HuyaLoadPanes({required this.loading, required this.onRetry, this.error, this.icon = DsIcons.film, super.key});

  /// Whether the first read is in flight.
  final bool loading;

  /// The failure's message, when there is one.
  final String? error;

  /// Reads again after a failure.
  final VoidCallback onRetry;

  /// The pane's glyph, the surface's own.
  final DsIconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (error case final message?) {
      return Center(
        child: DsEmptyState(
          icon: DsIcon(icon),
          title: Text(t.huya.errorTitle),
          description: Text(message),
          actions: [DsButton(variant: DsButtonVariant.secondary, onPressed: onRetry, child: Text(t.common.retry))],
        ),
      );
    }
    return const Center(child: DsSpinner());
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // The station's own measure, over the content the page really has;
        // the shared answer stands where the viewer's cap or a phone speaks.
        final content = constraints.maxWidth - feedGutter(context).horizontal;
        return PagedCardGrid<HuyaCard>(
          scrollController: scrollController,
          items: cards,
          layout: ref.watch(browseLayoutProvider),
          cardExtent: huyaVideoCardExtent(content, browse),
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
          itemBuilder: (context, card) => VodVideoCard(
            video: card.video,
            rank: card.rank == 0 ? null : card.rank,
            onOpen: () => onOpen(card.video.id),
          ),
        );
      },
    );
  }
}
