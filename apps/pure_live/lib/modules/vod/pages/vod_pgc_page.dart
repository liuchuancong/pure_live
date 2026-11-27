import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_library.dart' show VodSeasonProgress, vodSeasonProgressProvider;
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodSeasonCard, kVodSeasonTileAspect, vodPosterExtentForWidth;
import 'package:pure_live/shared/shared.dart';

/// The cinema's six catalogues with the platform's own names — Bilibili's
/// season types, in the reference's tab order.
String vodPgcLabel(Translations t, int type) => switch (type) {
  1 => t.vod.pgcAnime,
  2 => t.vod.pgcMovie,
  3 => t.vod.pgcDocumentary,
  4 => t.vod.pgcGuochuang,
  5 => t.vod.pgcTv,
  7 => t.vod.pgcVariety,
  _ => '$type',
};

/// The station's 影视 page: the reference's PGC entry — one catalogue at a
/// time, its seasons in a poster grid that pages in by cursor.
final class VodPgcPage extends ConsumerStatefulWidget {
  /// The cinema page, opening on [type] (Bilibili's season type).
  const VodPgcPage({this.type = 1, super.key});

  /// The catalogue the page opens on.
  final int type;

  @override
  ConsumerState<VodPgcPage> createState() => _VodPgcPageState();
}

final class _VodPgcPageState extends ConsumerState<VodPgcPage> {
  late int _type = widget.type;
  final Map<int, ScrollController> _scrolls = {};

  @override
  void initState() {
    super.initState();
    _ensure(_type);
  }

  @override
  void didUpdateWidget(VodPgcPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != _type) _select(widget.type);
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(int type) => _scrolls.putIfAbsent(type, ScrollController.new);

  void _ensure(int type) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodPgcProvider.notifier).open(type));
    });
  }

  void _select(int type) {
    if (type == _type) return;
    setState(() => _type = type);
    _ensure(type);
  }

  void _openSeason(VodSeason season) {
    unawaited(context.push('/vod/season/${season.seasonId}'));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vodClientProvider, (_, _) => _ensure(_type));
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    // The one series the viewer last left unfinished: a single card above the
    // wall, the door back to the episode the season page remembers. Finished
    // series drop out on their own — the checkpoint says so.
    final resume = ref.watch(vodSeasonProgressProvider).where((entry) => !entry.completed).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The cinema grid is posters alone — one form, so no layout switch
          // beside its tabs, only the reload the other feeds offer.
          child: VodFeedToolbar(
            owner: NavigationItem.vodPgc,
            tabs: DsTabs<int>(
              value: _type,
              onChanged: _select,
              style: kVodFeedTabsStyle,
              tabs: [for (final type in kVodPgcTypes) DsTab(value: type, label: Text(vodPgcLabel(t, type)))],
            ),
            showLayout: false,
            onRefresh: () => ref.read(vodPgcProvider.notifier).refresh(_type),
          ),
        ),
        if (resume != null)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: _SeasonResumeCard(entry: resume),
          ),
        Expanded(
          child: _PgcFeedView(type: _type, scrollController: _scrollOf(_type), onOpen: _openSeason),
        ),
      ],
    );
  }
}

/// One catalogue's cursor feed as the poster wall, its spacing the viewer's
/// browse settings say — posters are the wall's one form, so the grid never
/// grows a list shape and the measure stays the season tile's own.
final class _PgcFeedView extends ConsumerWidget {
  const _PgcFeedView({required this.type, required this.scrollController, required this.onOpen});

  final int type;
  final ScrollController scrollController;
  final ValueChanged<VodSeason> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(browseSettingsProvider);
    final feed =
        ref.watch(vodPgcProvider.select((feeds) => feeds[type])) ??
        (seasons: const <VodSeason>[], cursor: 0, hasMore: true, loading: true, loaded: false, error: null);
    final controller = ref.read(vodPgcProvider.notifier);
    // The wall's own measure: the width the page's inset leaves, spent on
    // the poster shelf's narrow tiles instead of the browse feed's landscape
    // ceiling — the viewer's column pin still raises the count.
    final width = MediaQuery.sizeOf(context).width;
    final content = width - LiveWindow.pageInset(width) * 2;
    // The toolbar's word narrows the shelf's loaded seasons in place.
    final filter = ref.watch(inlineFilterProvider(NavigationItem.vodPgc));
    final seasons = [
      for (final season in feed.seasons)
        if (inlineFilterKeeps(filter, [season.title, season.subtitle])) season,
    ];
    final grid = PagedCardGrid<VodSeason>(
      key: ValueKey(type),
      scrollController: scrollController,
      items: seasons,
      cardExtent: vodPosterExtentForWidth(content, spacing: browse.crossSpacing, pinned: browse.gridColumns),
      aspectRatio: kVodSeasonTileAspect,
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      isLoading: feed.loading,
      hasMore: feed.hasMore,
      onLoadMore: () => controller.loadMore(type),
      error: feed.error?.message,
      onRetry: () => controller.retry(type),
      onRefresh: () => controller.refresh(type),
      refreshError: feed.error?.message,
      emptyIcon: DsIcons.clapperboard,
      emptyTitle: t.common.empty,
      emptyDescription: t.vod.pgcEmptyDescription,
      itemBuilder: (context, season) => VodSeasonCard(season: season, onOpen: () => onOpen(season), preview: true),
    );
    if (filter == null) return grid;
    return Column(
      children: [
        InlineFilterBar(
          word: filter,
          onClear: () => ref.read(inlineFilterProvider(NavigationItem.vodPgc).notifier).clear(),
        ),
        Expanded(child: grid),
      ],
    );
  }
}

/// The continue card: the series' poster, its name, where the ladder
/// stopped and the way back in. One row, the card a wall page allows
/// itself — gone once the series is finished or the store is cleared.
final class _SeasonResumeCard extends ConsumerWidget {
  const _SeasonResumeCard({required this.entry});

  final VodSeasonProgress entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final fallback = CoverFallback(title: entry.title, padding: const EdgeInsets.all(DsSpace.s4));
    final cover = entry.cover;
    return DsPressable(
      semanticLabel: t.vod.continueWatching,
      onPressed: () => unawaited(context.push('/vod/season/${entry.seasonId}')),
      builder: (context, states, _) => Container(
        padding: const EdgeInsets.all(DsSpace.s8),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered) ? colors.hover : colors.surface,
          borderRadius: BorderRadius.circular(theme.radii.card),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.card),
              child: cover == null || cover.isEmpty
                  ? fallback
                  : DsImage(
                      image: cachedImage(cover, policy: ImageCachePolicies.videoCover),
                      width: 44,
                      height: 58,
                      semanticLabel: entry.title,
                      fallback: fallback,
                    ),
            ),
            const SizedBox(width: DsSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.vod.continueWatching, style: theme.typography.overline.copyWith(color: colors.textMuted)),
                  const SizedBox(height: DsSpace.s4),
                  Text(entry.title, style: theme.typography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (entry.total != null) ...[
                    const SizedBox(height: DsSpace.s4),
                    Text(
                      t.vod.seasonEpisodeProgress(index: entry.episodeIndex + 1, total: entry.total!),
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            DsIcon(DsIcons.chevronRight, size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
