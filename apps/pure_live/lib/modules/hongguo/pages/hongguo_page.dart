import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;

import 'package:pure_live/app/app.dart' show RouteNames, browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoWebsiteBoard;
import 'package:pure_live/modules/hongguo/widgets/hongguo_phone_sign_in.dart' show HongguoPhoneSignIn;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';
import 'package:pure_live/shared/shared.dart' show PagedCardGrid;

/// The station's views, the reference's top row plus the account surfaces:
/// the home feed, find-drama, the boards, the two shelves, the reservations,
/// the account and the search.
enum HongguoView {
  /// The official home feed: cross-genre by default, a shelf's own feed by
  /// chip.
  home,

  /// Find drama: the shelves under their live selector panels.
  find,

  /// The website's four boards.
  rank,

  /// The viewer's favorites: local and account.
  favorites,

  /// The watch history: local and account.
  history,

  /// The account's reservations: premiered and waiting.
  reservations,

  /// Sign-in and account management.
  account,

  /// The station's search.
  search;

  /// The view's icon, on its empty state.
  DsIconData get icon => switch (this) {
    HongguoView.home => DsIcons.home,
    HongguoView.find => DsIcons.clapperboard,
    HongguoView.rank => DsIcons.trophy,
    HongguoView.favorites => DsIcons.heart,
    HongguoView.history => DsIcons.history,
    HongguoView.reservations => DsIcons.calendarClock,
    HongguoView.account => DsIcons.circleUser,
    HongguoView.search => DsIcons.search,
  };
}

/// The hongguo module's entry: the reference's whole surface behind one
/// page — the home feed, the shelves, the boards, the viewer's own lists,
/// the account and the search.
final class HongguoPage extends ConsumerStatefulWidget {
  /// The module's entry page, opening on [view].
  const HongguoPage({this.view = HongguoView.home, super.key});

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
            HongguoView.home => _HomeView(onGo: (view) => setState(() => _view = view)),
            HongguoView.find => const _FindView(),
            HongguoView.rank => const _RankView(),
            HongguoView.favorites => const _FavoritesView(),
            HongguoView.history => const _HistoryView(),
            HongguoView.reservations => const _ReservationsView(),
            HongguoView.account => _AccountView(onGo: (view) => setState(() => _view = view)),
            HongguoView.search => const _SearchView(),
          },
        ),
      ],
    );
  }
}

/// The module's mark: the drama glyph in a tinted tile, the station's name,
/// and one line on what feeds it — the account's nickname once signed in.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final account = ref.watch(hongguoAccountProvider);
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
          child: Center(
            child: DsIcon(DsIcons.drama, size: theme.sizes.iconMd, color: colors.accentText),
          ),
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
                account.signedIn
                    ? '${t.hongguo.accountSignedInAs} · ${account.profile?.nickname ?? ''}'
                    : t.hongguo.tagline,
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

/// The line the station says when its endpoints did not answer.
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
        ],
      ),
    );
  }
}

/// The 首页: the station's own page shape — a row of recommendations you can
/// trade for another, the hot board, and the shelf's newest arrivals.
final class _HomeView extends ConsumerStatefulWidget {
  const _HomeView({required this.onGo});

  /// Moves the module's page to another view — the shelf's way to the whole
  /// board.
  final void Function(HongguoView view) onGo;

  @override
  ConsumerState<_HomeView> createState() => _HomeViewState();
}

final class _HomeViewState extends ConsumerState<_HomeView> {
  /// How many batches of the recommendation row the viewer has traded
  /// through; the row shows the batch it landed on.
  static const int _batchSize = 12;

  HongguoGenre? _genre;
  String _theme = '';
  HongguoGenre _latest = HongguoGenre.shortPlay;
  int _batch = 0;

  /// The board the genre's own shelf answers; 全部 takes the cross-type one.
  HongguoWebsiteBoard _boardFor(HongguoGenre? genre) => switch (genre) {
    null => HongguoWebsiteBoard.all,
    HongguoGenre.shortPlay => HongguoWebsiteBoard.real,
    HongguoGenre.comicSeries => HongguoWebsiteBoard.comic,
    HongguoGenre.aiSeries => HongguoWebsiteBoard.ai,
  };

  @override
  void initState() {
    super.initState();
    // The shelves are asked once per mount, and on an explicit genre change —
    // never from `build`, where every state write would ask again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openFeeds();
    });
  }

  /// Starts (or continues) every shelf the page shows under the current
  /// genre; each controller keeps what it already holds.
  void _openFeeds() {
    final genre = _genre;
    unawaited(ref.read(hongguoHomeProvider.notifier).open(genre));
    // `open` itself decides: read a board never held, renew quietly one
    // whose snapshot has gone stale, and leave a fresh one alone.
    unawaited(ref.read(hongguoRankProvider.notifier).open(_boardFor(genre)));
    unawaited(ref.read(hongguoLatestProvider.notifier).open(_latest));
    if (genre != null) unawaited(ref.read(hongguoBrowseProvider.notifier).open(genre));
  }

  /// Switches the shelf: the theme filter and the batch walk start over, and
  /// the new shelf's own feeds go out.
  void _selectGenre(HongguoGenre? genre) {
    if (genre == _genre) return;
    setState(() {
      _genre = genre;
      _theme = '';
      _batch = 0;
    });
    _openFeeds();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final genre = _genre;
    final home = ref.watch(hongguoHomeProvider);
    final homeController = ref.read(hongguoHomeProvider.notifier);
    final board = _boardFor(genre);
    final rank = ref.watch(hongguoRankProvider.select((boards) => boards[board.name]));
    final rankController = ref.read(hongguoRankProvider.notifier);
    final heldRank = rank ?? (items: const <HongguoSeries>[], readAt: 0, loading: false, renewing: false, error: null);
    final latest = ref.watch(hongguoLatestProvider.select((feeds) => feeds[_latest.name]));
    final latestController = ref.read(hongguoLatestProvider.notifier);
    final browse = ref.watch(hongguoBrowseProvider.select((feeds) => genre == null ? null : feeds[genre.name]));
    final browseController = ref.read(hongguoBrowseProvider.notifier);
    final themes = [
      for (final row in browse?.groups ?? const <HongguoFilterRow>[])
        if (row.type == 'category_dim_theme') row,
    ];
    final themeRow = themes.isEmpty ? null : themes.first;
    final hot = _theme.isEmpty ? null : browse;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s20,
        children: [
          // The station's genre bar, the live module's measure: one 44px
          // scrollable row instead of a wall of chips.
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
            child: SizedBox(
              height: 44,
              child: DsTopNav<String>(
                value: genre?.name ?? '',
                onChanged: (name) => _selectGenre(name.isEmpty ? null : HongguoGenre.values.byName(name)),
                items: [
                  DsTopNavItem(value: '', label: Text(t.hongguo.homeTabAll)),
                  for (final value in HongguoGenre.values) DsTopNavItem(value: value.name, label: Text(value.label(t))),
                ],
              ),
            ),
          ),
          if (themeRow != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s12,
              children: [
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(top: DsSpace.s6),
                    child: Text(
                      t.hongguo.shelfCategory,
                      style: DsTheme.of(context).typography.caption
                          .copyWith(color: DsTheme.colorsOf(context).textMuted),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      DsChip(
                        label: Text(t.hongguo.filterAll),
                        selected: _theme.isEmpty,
                        onChanged: (_) {
                          setState(() => _theme = '');
                          unawaited(browseController.select(genre!, 'category_dim_theme', null));
                        },
                      ),
                      for (final option in themeRow.items)
                        DsChip(
                          label: Text(option.name),
                          selected: _theme == option.id,
                          onChanged: (selected) {
                            final chosen = selected ? option.id : '';
                            setState(() => _theme = chosen);
                            unawaited(browseController.select(genre!, 'category_dim_theme', chosen));
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          HongguoShelf(
            title: t.hongguo.shelfForYou,
            items: home.items.skip(_batch * _batchSize).take(_batchSize).toList(),
            loading: home.loading && home.items.length <= _batch * _batchSize,
            error: home.error,
            onRetry: () => unawaited(homeController.retry()),
            actions: [
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.refreshCw, size: 14),
                onPressed: () {
                  setState(() => _batch++);
                  unawaited(homeController.loadMore());
                },
                child: Text(t.hongguo.shelfChangeBatch),
              ),
            ],
            cardBuilder: (context, series) =>
                HongguoSeriesCard(series: series, favoritable: true, onOpen: () => _open(context, series)),
          ),
          HongguoShelf(
            title: _theme.isEmpty ? t.hongguo.shelfHot : _themeLabel(themeRow, _theme),
            items: (_theme.isEmpty ? heldRank.items : hot?.items ?? const <HongguoSeries>[]).take(_batchSize).toList(),
            loading: _theme.isEmpty ? heldRank.loading : hot?.loading ?? true,
            error: _theme.isEmpty ? heldRank.error : hot?.error,
            onRetry: _theme.isEmpty
                ? () => unawaited(rankController.refresh(board))
                : () => unawaited(browseController.retry(genre!)),
            actions: [
              if (_theme.isEmpty)
                DsButton(
                  size: DsSize.sm,
                  variant: DsButtonVariant.secondary,
                  trailing: const DsIcon(DsIcons.chevronRight, size: 14),
                  onPressed: () => widget.onGo(HongguoView.rank),
                  child: Text(t.hongguo.openFullBoard),
                )
              else
                DsButton(
                  size: DsSize.sm,
                  variant: DsButtonVariant.secondary,
                  trailing: const DsIcon(DsIcons.chevronRight, size: 14),
                  onPressed: () => widget.onGo(HongguoView.find),
                  child: Text(t.hongguo.seeMore),
                ),
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.refreshCw, size: 14),
                onPressed: _theme.isEmpty
                    ? () => unawaited(rankController.refresh(board))
                    : () => unawaited(browseController.retry(genre!)),
                child: Text(t.hongguo.refreshShelf),
              ),
            ],
            cardBuilder: (context, series) =>
                HongguoSeriesCard(series: series, favoritable: true, onOpen: () => _open(context, series)),
          ),
          HongguoShelf(
            title: t.hongguo.shelfNew,
            items: latest?.items ?? const <HongguoSeries>[],
            loading: latest?.loading ?? true,
            actions: [
              for (final value in HongguoGenre.values)
                DsChip(
                  label: Text('${value.label(t)}${t.hongguo.newArrivals}'),
                  selected: _latest == value,
                  onChanged: (_) {
                    setState(() => _latest = value);
                    unawaited(latestController.open(value));
                  },
                ),
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.refreshCw, size: 14),
                onPressed: () => unawaited(latestController.retry(_latest)),
                child: Text(t.hongguo.refreshShelf),
              ),
            ],
            cardBuilder: (context, series) =>
                HongguoSeriesCard(series: series, favoritable: true, onOpen: () => _open(context, series)),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(HongguoFilterRow? row, String id) {
    if (row == null) return id;
    for (final option in row.items) {
      if (option.id == id) return option.name;
    }
    return id;
  }
}

/// 找剧: one shelf at a time under its live selector panel; a chip changes
/// the shelf, the panel follows the shelf's first page.
final class _FindView extends ConsumerStatefulWidget {
  const _FindView();

  @override
  ConsumerState<_FindView> createState() => _FindViewState();
}

final class _FindViewState extends ConsumerState<_FindView> {
  HongguoGenre _genre = HongguoGenre.shortPlay;

  @override
  void initState() {
    super.initState();
    // One ask per mount: `open` keeps what a rebuilt page would re-ask.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoBrowseProvider.notifier).open(_genre));
    });
  }

  /// The shelf's conditions live in a panel over the posters, as the app's
  /// other filtered lists do: the page keeps its room for the grid, and the
  /// grid thins as each condition arrives.
  Future<void> _openFilters() => showDsPanel<void>(
    context: context,
    builder: (context) => _FindFilterPanel(genre: _genre),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final feed = ref.watch(hongguoBrowseProvider.select((feeds) => feeds[_genre.name]));
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
    final chosen = <String>[
      for (final row in state.groups)
        if (state.selection[row.type] case final id?)
          for (final option in row.items)
            if (option.id == id) option.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              // The shelf bar, the live module's measure: the genres scroll
              // in one row and the conditions open beside them. A shelf the
              // page has not read yet is opened on the pick — the chips it
              // replaced left a new shelf an empty pane.
              SizedBox(
                height: 44,
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: DsTopNav<HongguoGenre>(
                        value: _genre,
                        onChanged: (genre) {
                          if (genre == _genre) return;
                          setState(() => _genre = genre);
                          unawaited(controller.open(genre));
                        },
                        items: [
                          for (final genre in HongguoGenre.values)
                            DsTopNavItem(value: genre, label: Text(genre.label(t))),
                        ],
                      ),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.listFilter, size: 14),
                      onPressed: state.groups.isEmpty ? null : () => unawaited(_openFilters()),
                      child: Text(t.hongguo.filter),
                    ),
                  ],
                ),
              ),
              Text(
                chosen.isEmpty ? t.hongguo.filterNone : chosen.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedCardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) =>
                HongguoSeriesCard(series: series, favoritable: true, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) =>
                HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: () => controller.loadMore(_genre),
            error: state.error,
            onRetry: () => controller.retry(_genre),
            onRefresh: () => controller.retry(_genre),
            refreshError: state.error,
            emptyIcon: HongguoView.find.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

/// The find page's conditions, in a panel over the posters: each choice goes
/// straight to the shelf's feed, so the grid behind thins as the viewer picks.
final class _FindFilterPanel extends ConsumerWidget {
  const _FindFilterPanel({required this.genre});

  /// The shelf whose selector panel the rows come from.
  final HongguoGenre genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final feed = ref.watch(hongguoBrowseProvider.select((feeds) => feeds[genre.name]));
    final controller = ref.read(hongguoBrowseProvider.notifier);
    final selection = feed?.selection ?? const <String, String>{};
    return DsPanel(
      title: Text(t.hongguo.filterPanelTitle),
      footer: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: selection.isEmpty ? null : () => unawaited(controller.clear(genre)),
              child: Text(t.hongguo.filterReset),
            ),
          ),
          Expanded(
            child: DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.hongguo.filterDone)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          for (final row in feed?.groups ?? const <HongguoFilterRow>[])
            HongguoFilterRowView(
              row: row,
              selection: selection,
              onSelect: (id) => unawaited(controller.select(genre, row.type, id)),
            ),
        ],
      ),
    );
  }
}

/// The boards: one whole board at a time, filtered by the topics its own
/// rows carry — the rows keep the place the board gave them.
final class _RankView extends ConsumerStatefulWidget {
  const _RankView();

  @override
  ConsumerState<_RankView> createState() => _RankViewState();
}

final class _RankViewState extends ConsumerState<_RankView> {
  HongguoWebsiteBoard _board = HongguoWebsiteBoard.all;
  String _topic = '';

  @override
  void initState() {
    super.initState();
    // A board is read once per mount; a stale snapshot renews itself inside
    // `open`, and a refusal waits for the refresh button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(hongguoRankProvider.notifier).open(_board));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(hongguoRankProvider.notifier);
    final feed = ref.watch(hongguoRankProvider.select((boards) => boards[_board.name]));
    final held = feed ?? (items: const <HongguoSeries>[], readAt: 0, loading: false, renewing: false, error: null);
    final topics = controller.topicsOf(_board);
    final rows = controller.rowsOf(_board, _topic);
    final figures = <String>[
      t.hongguo.rankSource,
      t.hongguo.rankSeriesCount(count: held.items.length),
      if (_topic.isNotEmpty) '$_topic ${t.hongguo.rankSeriesCount(count: rows.length)}（${t.hongguo.rankKeepsPlaces}）',
      if (held.renewing) t.hongguo.rankRenewing,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (held.error != null && held.items.isEmpty) const _ServiceHint(),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              // The boards' bar, the live module's measure; a board the page
              // has not read yet is opened on the pick, as the shelf bars do.
              SizedBox(
                height: 44,
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: DsTopNav<HongguoWebsiteBoard>(
                        value: _board,
                        onChanged: (board) {
                          if (board == _board) return;
                          setState(() {
                            _board = board;
                            _topic = '';
                          });
                          unawaited(controller.open(board));
                        },
                        items: [
                          for (final board in HongguoWebsiteBoard.values)
                            DsTopNavItem(value: board, label: Text(_boardLabel(t, board))),
                        ],
                      ),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: held.loading || held.renewing ? null : () => unawaited(controller.refresh(_board)),
                      child: Text(held.loading || held.renewing ? t.hongguo.rankReading : t.hongguo.refresh),
                    ),
                  ],
                ),
              ),
              if (topics.isNotEmpty)
                Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    DsChip(
                      label: Text('${t.hongguo.rankTopicAll} · ${held.items.length}'),
                      selected: _topic.isEmpty,
                      onChanged: (_) => setState(() => _topic = ''),
                    ),
                    for (final topic in topics)
                      DsChip(
                        label: Text('${topic.topic} · ${topic.count}'),
                        selected: _topic == topic.topic,
                        onChanged: (selected) => setState(() => _topic = selected ? topic.topic : ''),
                      ),
                  ],
                ),
              Text(
                figures.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          // The board reads as the station app's own ranking: a row per
          // title with its place, tags, blurb and heat, not a poster grid.
          child: rows.isEmpty
              ? (held.loading
                    ? const Center(child: DsSpinner())
                    : Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.trophy),
                          title: Text(held.error != null ? t.hongguo.loadFailed : t.common.empty),
                          description: Text(
                            held.error ?? (_topic.isEmpty ? t.hongguo.noResultsDescription : t.hongguo.rankEmptyTopic),
                          ),
                          actions: held.error == null
                              ? const []
                              : [
                                  DsButton(
                                    onPressed: () => unawaited(controller.refresh(_board)),
                                    child: Text(t.common.retry),
                                  ),
                                ],
                        ),
                      ))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
                  itemBuilder: (context, index) {
                    final series = rows[index];
                    return HongguoRankRow(series: series, position: index + 1, onOpen: () => _open(context, series));
                  },
                ),
        ),
      ],
    );
  }
}

/// The favorites: 本机 always there, 账户 behind the sign-in.
final class _FavoritesView extends ConsumerStatefulWidget {
  const _FavoritesView();

  @override
  ConsumerState<_FavoritesView> createState() => _FavoritesViewState();
}

final class _FavoritesViewState extends ConsumerState<_FavoritesView> {
  bool _account = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final library = ref.watch(hongguoLibraryProvider);
    final account = ref.watch(hongguoAccountProvider);
    final shelf = ref.watch(hongguoAccountFavoritesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              // 本机/账户, the areas page's segmented switch.
              DsSegmentedControl<bool>(
                segments: [
                  DsSegment(value: false, label: Text(t.hongguo.localTab)),
                  DsSegment(value: true, label: Text(t.hongguo.accountTab)),
                ],
                value: _account,
                onChanged: (account) {
                  setState(() => _account = account);
                  if (account &&
                      ref.read(hongguoAccountProvider).signedIn &&
                      shelf.items.isEmpty &&
                      !shelf.loading) {
                    unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).refresh());
                  }
                },
              ),
              if (!_account)
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Text(
                        _favoritesStatus(t, library),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsTheme.of(context).typography.caption
                            .copyWith(color: DsTheme.colorsOf(context).textMuted),
                      ),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: library.favorites.isEmpty || library.checking
                          ? null
                          : () => unawaited(ref.read(hongguoLibraryProvider.notifier).checkUpdates(force: true)),
                      child: Text(t.hongguo.favoriteCheck),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (true) {
            _ when _account && !account.signedIn => _SignInGate(message: t.hongguo.favoritesAccountOff),
            _ when _account => _SeriesList(
              rows: [for (final favorite in shelf.items) favorite.series],
              loading: shelf.loading,
              error: shelf.error,
              emptyText: t.hongguo.favoritesAccountEmpty,
              trailingOf: (series) => _IconAction(
                icon: DsIcons.heartOff,
                semanticLabel: t.hongguo.cloudFavoriteOff,
                onPressed: () =>
                    unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).setFavorite(series, add: false)),
              ),
            ),
            _ => _SeriesList(
              rows: [
                for (final series in library.favorites) series.copyWith(hot: hongguoFavoriteLine(t, library, series)),
              ],
              loading: false,
              error: null,
              emptyText: t.hongguo.favoritesLocalEmpty,
              trailingOf: (series) => _IconAction(
                icon: DsIcons.heartOff,
                semanticLabel: t.hongguo.unfavorite,
                onPressed: () {
                  ref.read(hongguoLibraryProvider.notifier).toggleFavorite(series);
                  showDsToast(context: context, title: t.hongguo.favoriteToggleOff);
                },
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// The watch history: 本机 rows carry the resume stripe, 账户 rows the
/// platform's own words.
final class _HistoryView extends ConsumerStatefulWidget {
  const _HistoryView();

  @override
  ConsumerState<_HistoryView> createState() => _HistoryViewState();
}

final class _HistoryViewState extends ConsumerState<_HistoryView> {
  bool _account = false;

  /// The local shelf's own filter: everything, what the viewer finished, and
  /// what is still running — the station's 全部 / 已看完 / 未看完 row.
  int _watched = 0;

  /// Whether the rows show checkboxes for a batch removal, and which rows
  /// are ticked — the reference's 管理本机记录.
  bool _managing = false;
  final Set<String> _selected = {};

  /// Empties this device's watch history after a confirmation; the reference
  ///'s 清空历史 asks before it forgets.
  Future<void> _clearHistory(Translations t) async {
    final confirmed = await showDsConfirm(
      context: context,
      title: t.hongguo.historyClear,
      description: t.hongguo.historyClearDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    ref.read(hongguoLibraryProvider.notifier).clearHistory();
    setState(() {
      _managing = false;
      _selected.clear();
    });
    showDsToast(context: context, title: t.hongguo.historyCleared);
  }

  /// Forgets every ticked row after a confirmation, then leaves the mode.
  Future<void> _removeSelected(Translations t) async {
    if (_selected.isEmpty) return;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.hongguo.historyManageDelete,
      description: t.hongguo.historyRemoveDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    ref.read(hongguoLibraryProvider.notifier).removeHistoryRows(_selected);
    setState(() {
      _managing = false;
      _selected.clear();
    });
  }

  void _leaveManaging() => setState(() {
    _managing = false;
    _selected.clear();
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final library = ref.watch(hongguoLibraryProvider);
    final account = ref.watch(hongguoAccountProvider);
    final cloud = ref.watch(hongguoAccountHistoryProvider);
    final rows = [
      for (final row in library.history)
        if (_watched == 0 || (_watched == 1) == row.completed) row,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              DsSegmentedControl<bool>(
                segments: [
                  DsSegment(value: false, label: Text(t.hongguo.localTab)),
                  DsSegment(value: true, label: Text(t.hongguo.accountTab)),
                ],
                value: _account,
                onChanged: (account) {
                  setState(() => _account = account);
                  if (account &&
                      ref.read(hongguoAccountProvider).signedIn &&
                      cloud.items.isEmpty &&
                      !cloud.loading) {
                    unawaited(ref.read(hongguoAccountHistoryProvider.notifier).refresh());
                  }
                },
              ),
              if (!_account)
                Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    DsChip(
                      label: Text(t.hongguo.filterAll),
                      selected: _watched == 0,
                      onChanged: (_) => setState(() => _watched = 0),
                    ),
                    DsChip(
                      label: Text(t.hongguo.historyFilterWatched),
                      selected: _watched == 1,
                      onChanged: (_) => setState(() => _watched = 1),
                    ),
                    DsChip(
                      label: Text(t.hongguo.historyFilterUnwatched),
                      selected: _watched == 2,
                      onChanged: (_) => setState(() => _watched = 2),
                    ),
                    if (library.history.isNotEmpty) ...[
                      if (_managing) ...[
                        DsButton(
                          size: DsSize.sm,
                          variant: DsButtonVariant.secondary,
                          leading: const DsIcon(DsIcons.trash2, size: 14),
                          onPressed: _selected.isEmpty ? null : () => unawaited(_removeSelected(t)),
                          child: Text(t.hongguo.historyManageDeleteCount(count: _selected.length)),
                        ),
                        DsButton(
                          size: DsSize.sm,
                          variant: DsButtonVariant.ghost,
                          onPressed: _leaveManaging,
                          child: Text(t.hongguo.historyManageDone),
                        ),
                      ] else ...[
                        DsButton(
                          size: DsSize.sm,
                          variant: DsButtonVariant.ghost,
                          leading: const DsIcon(DsIcons.listChecks, size: 14),
                          onPressed: () => setState(() => _managing = true),
                          child: Text(t.hongguo.historyManage),
                        ),
                        DsButton(
                          size: DsSize.sm,
                          variant: DsButtonVariant.ghost,
                          leading: const DsIcon(DsIcons.trash2, size: 14),
                          onPressed: () => unawaited(_clearHistory(t)),
                          child: Text(t.hongguo.historyClear),
                        ),
                      ],
                    ],
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (true) {
            _ when _account && !account.signedIn => _SignInGate(message: t.hongguo.historyAccountOff),
            _ when _account => _SeriesList(
              rows: [
                for (final row in cloud.items)
                  row.series.copyWith(hot: row.durationMs > 0 ? '${t.hongguo.resumeAt} ${_clock(row.positionMs)}' : ''),
              ],
              loading: cloud.loading,
              error: cloud.error,
              emptyText: t.hongguo.historyAccountEmpty,
            ),
            _ => _ProgressList(
              rows: rows,
              managing: _managing,
              selected: _selected,
              onToggle: (id) => setState(() {
                if (!_selected.remove(id)) _selected.add(id);
              }),
            ),
          },
        ),
      ],
    );
  }
}

/// The account's reservations, premiered and waiting, behind the sign-in.
final class _ReservationsView extends ConsumerStatefulWidget {
  const _ReservationsView();

  @override
  ConsumerState<_ReservationsView> createState() => _ReservationsViewState();
}

final class _ReservationsViewState extends ConsumerState<_ReservationsView> {
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final account = ref.watch(hongguoAccountProvider);
    final state = ref.watch(hongguoReservationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: DsSegmentedControl<bool>(
            segments: [
              DsSegment(value: true, label: Text(t.hongguo.reservationsOnline)),
              DsSegment(value: false, label: Text(t.hongguo.reservationsUpcoming)),
            ],
            value: _online,
            onChanged: (online) => setState(() => _online = online),
          ),
        ),
        Expanded(
          child: !account.signedIn
              ? _SignInGate(message: t.hongguo.reservationsOff)
              : _SeriesList(
                  rows: [
                    for (final row in _online ? state.online : state.upcoming)
                      // A waiting title speaks with its premiere date, as the
                      // station app prints it under the name.
                      row.series.copyWith(hot: row.series.hot.isNotEmpty ? row.series.hot : row.series.premiere),
                  ],
                  loading: state.loading,
                  error: state.error,
                  emptyText: _online ? t.hongguo.reservationsOnlineEmpty : t.hongguo.reservationsUpcomingEmpty,
                  openable: (series) => !series.seriesId.startsWith('reservation:'),
                ),
        ),
      ],
    );
  }
}

/// The account itself: the QR sign-in when signed out, the profile and the
/// levers when signed in.
final class _AccountView extends ConsumerStatefulWidget {
  const _AccountView({required this.onGo});

  /// Moves the module's page to one of the viewer's shelves.
  final void Function(HongguoView view) onGo;

  @override
  ConsumerState<_AccountView> createState() => _AccountViewState();
}

final class _AccountViewState extends ConsumerState<_AccountView> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // The sign-in card and the profile are asked once per visit: a refused
    // read keeps its words on screen until the viewer asks again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(hongguoAccountProvider).signedIn && !ref.read(hongguoLoginSessionProvider).polling) {
        unawaited(ref.read(hongguoLoginSessionProvider.notifier).load());
        _startPolling();
      }
      final held = ref.read(hongguoAccountProvider);
      if (held.credentials != null && held.profile == null && !held.loading && held.error == null) {
        unawaited(ref.read(hongguoAccountProvider.notifier).refreshProfile());
      }
    });
  }

  void _startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 2), (timer) async {
      final done = await ref.read(hongguoLoginSessionProvider.notifier).poll();
      if (done && mounted) {
        timer.cancel();
        _poll = null;
      }
    });
  }

  /// Whether the sign-in sheet shows the phone form rather than the QR code.
  bool _phone = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final account = ref.watch(hongguoAccountProvider);
    final session = ref.watch(hongguoLoginSessionProvider);
    if (account.signedIn) {
      final favorites = ref.watch(hongguoAccountFavoritesProvider);
      final cloud = ref.watch(hongguoAccountHistoryProvider);
      final reservations = ref.watch(hongguoReservationsProvider);
      final library = ref.watch(hongguoLibraryProvider);
      final profile = account.profile;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            DsCard(
              style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s16)),
              child: Row(
                spacing: DsSpace.s12,
                children: [
                  DsAvatar(
                    initials: profile?.nickname ?? 'HG',
                    size: DsSize.lg,
                    toneIndex: DsAvatar.toneFor(profile?.id ?? ''),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s3,
                      children: [
                        Text(
                          profile?.nickname ?? t.hongguo.accountSignedInAs,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                        Text(
                          profile == null ? t.hongguo.accountReading : '${t.hongguo.accountId}：${profile.id}',
                          style: theme.typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (profile != null)
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.ghost,
                      leading: const DsIcon(DsIcons.copy, size: 14),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: profile.id));
                        if (context.mounted) showDsToast(context: context, title: t.hongguo.copied);
                      },
                      child: Text(t.hongguo.copyAccountId),
                    ),
                ],
              ),
            ),
            // The app's own profile page leads with the viewer's shelves:
            // one tile each, holding the count and the way in.
            Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: _LibraryTile(
                    icon: DsIcons.heart,
                    label: t.hongguo.navFavorites,
                    count: favorites.items.isEmpty ? library.favorites.length : favorites.items.length,
                    onPressed: () => widget.onGo(HongguoView.favorites),
                  ),
                ),
                Expanded(
                  child: _LibraryTile(
                    icon: DsIcons.history,
                    label: t.hongguo.navHistory,
                    count: cloud.items.isEmpty ? library.history.length : cloud.items.length,
                    onPressed: () => widget.onGo(HongguoView.history),
                  ),
                ),
                Expanded(
                  child: _LibraryTile(
                    icon: DsIcons.calendarClock,
                    label: t.hongguo.navReservations,
                    count: reservations.online.length + reservations.upcoming.length,
                    onPressed: () => widget.onGo(HongguoView.reservations),
                  ),
                ),
              ],
            ),
            DsListSection(
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.heart),
                  title: Text(t.hongguo.accountFavoritesRefresh),
                  description: Text(_readCount(t, favorites.items.length, favorites.loading, favorites.error)),
                  onPressed: () => unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).refresh()),
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.history),
                  title: Text(t.hongguo.accountHistoryRefresh),
                  description: Text(_readCount(t, cloud.items.length, cloud.loading, cloud.error)),
                  onPressed: () => unawaited(ref.read(hongguoAccountHistoryProvider.notifier).refresh()),
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.calendarClock),
                  title: Text(t.hongguo.reservationsRefresh),
                  description: Text(
                    _readCount(
                      t,
                      reservations.online.length + reservations.upcoming.length,
                      reservations.loading,
                      reservations.error,
                    ),
                  ),
                  onPressed: () => unawaited(ref.read(hongguoReservationsProvider.notifier).refresh()),
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.logOut),
                  title: Text(t.hongguo.accountSignOut),
                  description: Text(t.hongguo.accountSignOutDesc),
                  onPressed: () => unawaited(ref.read(hongguoAccountProvider.notifier).signOut()),
                ),
              ],
            ),
            if (account.error != null)
              Text(account.error!, style: theme.typography.caption.copyWith(color: colors.danger.text)),
          ],
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Text(t.hongguo.accountSignInTitle, style: theme.typography.title.copyWith(color: colors.text)),
            Text(
              t.hongguo.accountSignInDesc,
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(color: colors.textMuted),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: DsSpace.s8,
              children: [
                DsChip(
                  label: Text(t.hongguo.accountQrToggle),
                  selected: !_phone,
                  onChanged: (_) {
                    setState(() => _phone = false);
                    // Coming back to the code: a session that never got one
                    // (or lost it) asks again here, not on every rebuild.
                    if (ref.read(hongguoLoginSessionProvider).qr == null) {
                      unawaited(ref.read(hongguoLoginSessionProvider.notifier).load());
                      _startPolling();
                    }
                  },
                ),
                DsChip(
                  label: Text(t.hongguo.accountPhoneToggle),
                  selected: _phone,
                  onChanged: (_) => setState(() => _phone = true),
                ),
              ],
            ),
            if (_phone)
              const HongguoPhoneSignIn()
            else ...[
              if (session.qr != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  child: Image(image: MemoryImage(session.qr!.image), width: 240, height: 240, fit: BoxFit.contain),
                )
              else if (session.error != null)
                Padding(
                  padding: const EdgeInsets.all(DsSpace.s12),
                  child: Text(session.error!, style: theme.typography.caption.copyWith(color: colors.danger.text)),
                )
              else
                const SizedBox(height: 240, child: Center(child: DsSpinner())),
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () {
                  unawaited(ref.read(hongguoLoginSessionProvider.notifier).load());
                },
                child: Text(t.hongguo.accountQrRefresh),
              ),
            ],
          ],
        ),
      ),
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

  /// The shelf the query is asked of: the app's own search answers one
  /// shelf at a time, so comics need asking as comics.
  HongguoGenre _genre = HongguoGenre.shortPlay;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              SizedBox(
                height: 44,
                child: DsTopNav<HongguoGenre>(
                  value: _genre,
                  onChanged: (genre) {
                    if (genre == _genre) return;
                    setState(() => _genre = genre);
                    if (state.query.isNotEmpty) unawaited(controller.search(state.query, genre: genre));
                  },
                  items: [
                    for (final genre in HongguoGenre.values) DsTopNavItem(value: genre, label: Text(genre.label(t))),
                  ],
                ),
              ),
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsTextField(
                      controller: _query,
                      semanticLabel: t.hongguo.searchHint,
                      onChanged: controller.suggest,
                      onSubmitted: (value) => unawaited(controller.search(value, genre: _genre)),
                    ),
                  ),
                  DsButton(
                    variant: DsButtonVariant.primary,
                    onPressed: () => unawaited(controller.search(_query.text, genre: _genre)),
                    child: Text(t.hongguo.search),
                  ),
                ],
              ),
              if (state.suggestions.isNotEmpty)
                Wrap(
                  spacing: DsSpace.s8,
                  runSpacing: DsSpace.s8,
                  children: [
                    for (final word in state.suggestions)
                      DsChip(
                        label: Text(word),
                        selected: false,
                        onChanged: (_) {
                          _query.text = word;
                          unawaited(controller.search(word, genre: state.genre));
                        },
                      ),
                  ],
                )
              else if (state.suggestionError != null)
                Text(
                  '${t.hongguo.suggestOff} · ${state.suggestionError}',
                  style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
                ),
              if (state.query.isEmpty && state.history.isNotEmpty)
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: DsSpace.s8,
                        runSpacing: DsSpace.s8,
                        children: [
                          for (final word in state.history)
                            DsChip(
                              label: Text(word),
                              selected: false,
                              onChanged: (_) {
                                _query.text = word;
                                unawaited(controller.search(word, genre: state.genre));
                              },
                            ),
                        ],
                      ),
                    ),
                    DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.ghost,
                      onPressed: controller.clearHistory,
                      child: Text(t.hongguo.searchHistoryClear),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: PagedCardGrid<HongguoSeries>(
            items: state.items,
            layout: ref.watch(browseLayoutProvider),
            aspectRatio: 0.62,
            listMainAxisExtent: 124,
            itemBuilder: (context, series) =>
                HongguoSeriesCard(series: series, favoritable: true, onOpen: () => _open(context, series)),
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

/// A plain list of series rows, one trailing action each.
final class _SeriesList extends StatelessWidget {
  const _SeriesList({
    required this.rows,
    required this.loading,
    required this.error,
    this.emptyText,
    this.trailingOf,
    this.openable,
  });

  final List<HongguoSeries> rows;
  final bool loading;
  final String? error;
  final String? emptyText;
  final Widget Function(HongguoSeries series)? trailingOf;
  final bool Function(HongguoSeries series)? openable;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (error != null && rows.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.hongguo.loadFailed),
          description: Text(error!),
        ),
      );
    }
    if (loading && rows.isEmpty) {
      return const Center(child: DsSpinner());
    }
    if (rows.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.heart), title: Text(emptyText ?? t.common.empty)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
      itemBuilder: (context, index) {
        final series = rows[index];
        final canOpen = openable == null || openable!(series);
        return HongguoSeriesRow(
          series: series,
          onOpen: canOpen ? () => _open(context, series) : null,
          trailing: trailingOf?.call(series),
        );
      },
    );
  }
}

/// The local history's own rows: the stripe where playback stood, and a
/// checkbox instead of the delete button while the shelf is being managed.
final class _ProgressList extends ConsumerWidget {
  const _ProgressList({required this.rows, this.managing = false, this.selected = const {}, this.onToggle});

  final List<HongguoWatchProgress> rows;

  /// Whether the rows carry checkboxes for a batch removal.
  final bool managing;

  /// The rows ticked in that mode.
  final Set<String> selected;

  /// Flips one row's tick.
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    if (rows.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.history), title: Text(t.hongguo.historyLocalEmpty)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
      itemBuilder: (context, index) {
        final row = rows[index];
        final series = HongguoSeries(
          seriesId: row.seriesId,
          title: row.title,
          cover: row.cover,
          episodeCount: row.episodeCount,
          hot: row.completed
              ? t.hongguo.watchedBadge
              : '${row.episodeCount > 0 ? t.hongguo.historyEpisodeProgress(index: row.episodeIndex, total: row.episodeCount) : t.hongguo.episodeLabel(index: row.episodeIndex)} · ${_clock(row.positionMs)}',
        );
        return Column(
          spacing: DsSpace.s4,
          children: [
            HongguoSeriesRow(
              series: series,
              onOpen: managing ? null : () => _open(context, series),
              trailing: managing
                  ? DsCheckbox(
                      value: selected.contains(row.seriesId),
                      semanticLabel: t.hongguo.episodeLabel(index: row.episodeIndex),
                      onChanged: (_) => onToggle?.call(row.seriesId),
                    )
                  : _IconAction(
                      icon: DsIcons.trash2,
                      semanticLabel: t.hongguo.historyRemove,
                      onPressed: () {
                        ref.read(hongguoLibraryProvider.notifier).removeHistory(row.seriesId);
                        showDsToast(context: context, title: t.hongguo.historyRemove);
                      },
                    ),
            ),
            if (!row.completed) HongguoProgressStripe(fraction: row.fraction),
          ],
        );
      },
    );
  }
}

/// The sign-in gate an account tab shows when no login is held; its action
/// opens the QR flow in a dialog.
final class _SignInGate extends ConsumerStatefulWidget {
  const _SignInGate({required this.message});

  final String message;

  @override
  ConsumerState<_SignInGate> createState() => _SignInGateState();
}

final class _SignInGateState extends ConsumerState<_SignInGate> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (_showQr) {
      return const Center(
        child: SingleChildScrollView(padding: EdgeInsets.all(DsSpace.s24), child: _QrLoginCard()),
      );
    }
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.circleUser),
        title: Text(t.hongguo.accountSignInTitle),
        description: Text(widget.message),
        actions: [
          DsButton(
            variant: DsButtonVariant.primary,
            onPressed: () => setState(() => _showQr = true),
            child: Text(t.hongguo.accountSignInTitle),
          ),
        ],
      ),
    );
  }
}

/// The QR card the account view and the gates share: the code, its status
/// line, and the poll that settles it.
final class _QrLoginCard extends ConsumerStatefulWidget {
  const _QrLoginCard();

  @override
  ConsumerState<_QrLoginCard> createState() => _QrLoginCardState();
}

final class _QrLoginCardState extends ConsumerState<_QrLoginCard> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(hongguoLoginSessionProvider).qr == null) {
        unawaited(ref.read(hongguoLoginSessionProvider.notifier).load());
      }
      _poll = Timer.periodic(const Duration(seconds: 2), (timer) async {
        final done = await ref.read(hongguoLoginSessionProvider.notifier).poll();
        if (done && mounted) {
          timer.cancel();
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final session = ref.watch(hongguoLoginSessionProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        if (session.qr != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.card),
              child: Image(image: MemoryImage(session.qr!.image), width: 220, height: 220, fit: BoxFit.contain),
            ),
          )
        else
          const Center(child: DsSpinner(style: DsSpinnerStyle(size: 48))),
        if (session.error != null)
          Text(session.error!, style: theme.typography.caption.copyWith(color: colors.danger.text)),
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => unawaited(ref.read(hongguoLoginSessionProvider.notifier).load()),
          child: Text(context.t.hongguo.accountQrRefresh),
        ),
      ],
    );
  }
}

/// One shelf's count on the account page: the glyph, how much it holds and
/// its name, the way into the shelf — the station app's own profile tiles.
final class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.icon, required this.label, required this.count, required this.onPressed});

  final DsIconData icon;
  final String label;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsCard(
      onPressed: onPressed,
      semanticLabel: label,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          DsIcon(icon, size: theme.sizes.iconMd, color: colors.accentText),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Text('$count', style: theme.typography.numeric(theme.typography.title.copyWith(color: colors.text))),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small icon action on a row's end.
final class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.semanticLabel, this.onPressed});

  final DsIconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsTooltip(
      message: semanticLabel,
      child: DsPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: hovered ? DsTheme.colorsOf(context).hover : null,
              borderRadius: BorderRadius.circular(theme.radii.control(36)),
            ),
            child: DsIcon(icon, size: 18, color: DsTheme.colorsOf(context).textMuted),
          );
        },
      ),
    );
  }
}

String _boardLabel(Translations t, HongguoWebsiteBoard board) => switch (board) {
  HongguoWebsiteBoard.all => t.hongguo.boardAll,
  HongguoWebsiteBoard.real => t.hongguo.boardReal,
  HongguoWebsiteBoard.comic => t.hongguo.boardComic,
  HongguoWebsiteBoard.ai => t.hongguo.boardAi,
};

String _clock(int milliseconds) {
  final total = milliseconds ~/ 1000;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  final hours = minutes ~/ 60;
  if (hours > 0) {
    return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// What one account shelf says about itself: the read in flight, the count
/// it holds, or the reason it holds nothing.
String _readCount(Translations t, int count, bool loading, String? error) {
  if (loading) return t.hongguo.accountReading;
  if (count == 0) return error ?? t.hongguo.accountNotRead;
  return t.hongguo.accountReadCount(count: count);
}

/// What the local shelf says about its last walk over the favorites.
String _favoritesStatus(Translations t, HongguoLibraryState library) {
  if (library.checking) {
    return t.hongguo.favoriteChecking(done: library.checksDone, total: library.checksTotal);
  }
  if (library.favorites.isEmpty) return t.hongguo.favoriteNoFavorites;
  if (library.checksTotal > 0) {
    final walked = t.hongguo.favoriteChecked(done: library.checksDone, total: library.checksTotal);
    if (library.checkFailures == 0) return walked;
    final some = t.hongguo.favoriteCheckedSome(
      done: library.checksDone,
      total: library.checksTotal,
      failures: library.checkFailures,
    );
    return library.checkError == null ? some : '$some · ${library.checkError}';
  }
  final grown = library.updates.values.where((update) => update.added > 0).length;
  return grown == 0 ? t.hongguo.favoriteRecentCheck : t.hongguo.favoriteBadge(count: grown);
}

void _open(BuildContext context, HongguoSeries series) {
  if (series.seriesId.isEmpty) return;
  unawaited(context.push(RouteNames.hongguoSeries.replaceFirst(':seriesId', series.seriesId)));
}
