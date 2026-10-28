import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;

import 'package:pure_live/app/app.dart' show RouteNames, SettingsSectionRoute, browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoWebsiteBoard;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CardGrid;

/// The station's views. The module's menu lists one entry per view, so each
/// opens on the one its entry names.
enum HongguoView {
  /// The live-action shelf under its selector panel.
  drama,

  /// The comic shelf under its selector panel.
  comic,

  /// The AI shelf under its selector panel.
  ai,

  /// The comic boards.
  rank,

  /// The newest arrivals, shelf by shelf.
  latest,

  /// The station's search.
  search;

  /// The shelf a browse view holds; null on the views that hold none.
  HongguoGenre? get genre => switch (this) {
    HongguoView.drama => HongguoGenre.shortPlay,
    HongguoView.comic => HongguoGenre.comicSeries,
    HongguoView.ai => HongguoGenre.aiSeries,
    _ => null,
  };

  /// The view's icon, on its empty state.
  DsIconData get icon => switch (this) {
    HongguoView.drama => DsIcons.clapperboard,
    HongguoView.comic => DsIcons.bookOpenText,
    HongguoView.ai => DsIcons.sparkles,
    HongguoView.rank => DsIcons.trophy,
    HongguoView.latest => DsIcons.rocket,
    HongguoView.search => DsIcons.search,
  };
}

/// The hongguo module's entry: the three shelves under their selector
/// panels, the comic boards, the newest arrivals, and the search — every
/// series a card that opens its episodes.
///
/// Everything the station shows comes from its companion service, so a
/// service that is not answering says so with a line to its settings rather
/// than an empty grid.
final class HongguoPage extends ConsumerStatefulWidget {
  /// The module's entry page, opening on [view].
  const HongguoPage({this.view = HongguoView.drama, super.key});

  /// The view the page opens on; the module's menu names it.
  final HongguoView view;

  @override
  ConsumerState<HongguoPage> createState() => _HongguoPageState();
}

final class _HongguoPageState extends ConsumerState<HongguoPage> {
  /// The view the page is showing.
  late HongguoView _view = widget.view;

  @override
  void didUpdateWidget(HongguoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the module's
    // entries, so a new entry has to move the page to its view.
    if (widget.view != _view) setState(() => _view = widget.view);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Expanded(
          child: switch (_view) {
            HongguoView.drama => const _BrowseView(genre: HongguoGenre.shortPlay),
            HongguoView.comic => const _BrowseView(genre: HongguoGenre.comicSeries),
            HongguoView.ai => const _BrowseView(genre: HongguoGenre.aiSeries),
            HongguoView.rank => const _RankView(),
            HongguoView.latest => const _LatestView(),
            HongguoView.search => const _SearchView(),
          },
        ),
      ],
    );
  }
}

/// The module's mark: the drama glyph in a tinted tile, the station's name,
/// and one line on what feeds it — the companion service.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    return Row(
      spacing: DsSpace.s12,
      children: [
        Container(
          width: theme.sizes.md,
          height: theme.sizes.md,
          decoration: DsBoxDecoration(
            color: colors.accentTint,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Center(child: DsIcon(DsIcons.drama, size: theme.sizes.iconMd, color: colors.accentText)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                t.hongguo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Text(
                t.hongguo.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The line the station says when its service did not answer, with the way
/// to its settings.
final class _ServiceHint extends StatelessWidget {
  const _ServiceHint();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, 0),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          DsIcon(DsIcons.cloudOff, size: theme.sizes.iconSm, color: colors.textMuted),
          Expanded(
            child: Text(
              t.hongguo.serverHint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
          DsButton(
            size: DsSize.sm,
            variant: DsButtonVariant.secondary,
            onPressed: () => unawaited(context.push(const SettingsSectionRoute(section: 'hongguo').location)),
            child: Text(t.hongguo.openSettings),
          ),
        ],
      ),
    );
  }
}

/// One shelf's browse view: the selector panel above the poster grid. A
/// changed chip resets the window; the grid's end raises it.
final class _BrowseView extends ConsumerWidget {
  /// The view for [genre].
  const _BrowseView({required this.genre});

  final HongguoGenre genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final feed = ref.watch(hongguoBrowseProvider.select((feeds) => feeds[genre.name]));
    final state =
        feed ??
        (
          items: const <HongguoSeries>[],
          cursor: null,
          loading: false,
          hasMore: true,
          error: null,
          selection: const <String, String>{},
          groups: const <HongguoFilterRow>[],
        );
    final controller = ref.read(hongguoBrowseProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open(genre));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in state.groups)
                HongguoFilterRowView(
                  row: row,
                  selection: state.selection,
                  onSelect: (id) => unawaited(controller.select(genre, row.type, id)),
                ),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) =>
                HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) =>
                HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: () => controller.loadMore(genre),
            error: state.error,
            onRetry: () => controller.retry(genre),
            onRefresh: () => controller.retry(genre),
            refreshError: state.error,
            emptyIcon: HongguoView.drama.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

/// The comic boards: the board chips above the ranked grid.
final class _RankView extends ConsumerWidget {
  const _RankView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(hongguoRankProvider);
    final controller = ref.read(hongguoRankProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open(state.board));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final board in HongguoWebsiteBoard.values)
                DsChip(
                  label: Text(_boardLabel(t, board)),
                  selected: state.board == board,
                  onChanged: (_) => unawaited(controller.open(board)),
                ),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) =>
                HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) =>
                HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            error: state.error,
            onRetry: controller.retry,
            onRefresh: controller.retry,
            refreshError: state.error,
            emptyIcon: HongguoView.rank.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

/// The newest arrivals: one shelf at a time, its feed walked by cursor —
/// the platform's freshest list, the seven-day window.
final class _LatestView extends ConsumerStatefulWidget {
  const _LatestView();

  @override
  ConsumerState<_LatestView> createState() => _LatestViewState();
}

final class _LatestViewState extends ConsumerState<_LatestView> {
  HongguoGenre _genre = HongguoGenre.shortPlay;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final feeds = ref.watch(hongguoLatestProvider);
    final state = feeds[_genre.name] ?? (items: const <HongguoSeries>[], cursor: null, loading: false, hasMore: true, error: null);
    final controller = ref.read(hongguoLatestProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.open(_genre));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              for (final genre in HongguoGenre.values)
                DsChip(
                  label: Text(genre.label(t)),
                  selected: _genre == genre,
                  onChanged: (_) => setState(() => _genre = genre),
                ),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) => HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) => HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: () => controller.loadMore(_genre),
            error: state.error,
            onRetry: () => controller.retry(_genre),
            onRefresh: () => controller.retry(_genre),
            refreshError: state.error,
            emptyIcon: HongguoView.latest.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

/// The station's search: the field above the grid; the grid's end continues
/// the query by the cursor the last page carried.
final class _SearchView extends ConsumerStatefulWidget {
  const _SearchView();

  @override
  ConsumerState<_SearchView> createState() => _SearchViewState();
}

final class _SearchViewState extends ConsumerState<_SearchView> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(hongguoSearchProvider);
    final controller = ref.read(hongguoSearchProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsTextField(
                  controller: _query,
                  semanticLabel: t.hongguo.searchHint,
                  onSubmitted: (value) => unawaited(controller.search(value)),
                ),
              ),
              DsButton(
                variant: DsButtonVariant.primary,
                onPressed: () => unawaited(controller.search(_query.text)),
                child: Text(t.hongguo.search),
              ),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) =>
                HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) =>
                HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: controller.loadMore,
            error: state.error,
            onRetry: controller.retry,
            onRefresh: controller.retry,
            refreshError: state.error,
            emptyIcon: HongguoView.search.icon,
            emptyTitle: state.query.isEmpty ? t.hongguo.searchIdleTitle : t.common.empty,
            emptyDescription: state.query.isEmpty ? t.hongguo.searchIdleDescription : t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

String _boardLabel(Translations t, HongguoWebsiteBoard board) => switch (board) {
  HongguoWebsiteBoard.all => t.hongguo.boardAll,
  HongguoWebsiteBoard.real => t.hongguo.boardReal,
  HongguoWebsiteBoard.comic => t.hongguo.boardComic,
  HongguoWebsiteBoard.ai => t.hongguo.boardAi,
};

void _open(BuildContext context, HongguoSeries series) {
  if (series.seriesId.isEmpty) return;
  unawaited(context.push(RouteNames.hongguoSeries.replaceFirst(':seriesId', series.seriesId)));
}
