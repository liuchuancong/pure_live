import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/app.dart' show RouteNames, browseLayoutProvider, browseSettingsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_account_state.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show hongguoHomeBannerProvider;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoWebsiteBoard;
import 'package:pure_live/modules/hongguo/widgets/hongguo_card_menu.dart' show HongguoCardMenu, hongguoSeriesOpenable;
import 'package:pure_live/modules/hongguo/widgets/hongguo_phone_sign_in.dart' show HongguoPhoneSignIn;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';
import 'package:pure_live/shared/shared.dart'
    show LiveWindow, NavigationItem, PagedCardGrid, avatarInitials, feedGutter;

/// The page's own left and right margin, asked rather than written again:
/// `LiveWindow.pageInset` is one number for the whole app (16 while the window
/// is compact, 20 above it), and this module's downloads page already reads it.
/// A page that keeps its own 20 puts two different left edges under one menu on
/// a phone, and pays a gutter the narrow window does not have to spare.
double _hongguoPageInset(BuildContext context) => LiveWindow.pageInset(MediaQuery.sizeOf(context).width);

/// The shelf bars' content tabs: one 44-tall row, aligned with the page's own
/// inset, without the bar's hairline cutting across the controls beside them.
const DsTabsStyle _kShelfTabsStyle = DsTabsStyle(height: 44, padding: EdgeInsets.zero, dividerColor: Color(0x00000000));

/// The local shelf's progress, keyed by series: the browse surfaces read it one
/// pass per build, so a hundred tiles do not each scan the history for
/// themselves — and every face of one list says the same thing about a title
/// this device has already opened.
Map<String, HongguoWatchProgress> _hongguoWatchedById(List<HongguoWatchProgress> history) => {
  for (final entry in history) entry.seriesId: entry,
};

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
    // The module's mark and name belong to the shell's head (its breadcrumb);
    // every view starts on its own tool line, the live module's shape.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            // The head line names the view; the view's own row keeps the live
            // module's top measure under it.
            padding: const EdgeInsets.only(top: DsSpace.s12),
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
      padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), 0),
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

  /// The genre's topics as the page last held them. A pick re-reads the shelf
  /// from its first page, and that read empties the feed's selector panel
  /// until the answer lands (`HongguoBrowseController._load`), so the bar's
  /// entry and the shelf's own name would otherwise go blind for the length
  /// of the pick — the entry disabling, the title falling back to the
  /// topic's numeric id.
  HongguoFilterRow? _topics;

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

  /// Switches the shelf: the topic goes back to the shelf's own selection,
  /// the batch walk starts over, and the new shelf's feeds go out.
  void _selectGenre(HongguoGenre? genre) {
    if (genre == _genre) return;
    setState(() {
      _genre = genre;
      _topics = null;
      _batch = 0;
    });
    _openFeeds();
  }

  /// The genre's topics, in a panel over the shelves: the pick goes straight
  /// to the shelf behind, as 找剧's selector panels do.
  void _openThemes(HongguoGenre genre, HongguoFilterRow row) {
    setState(() => _topics = row);
    unawaited(
      showDsPanel<void>(
        context: context,
        builder: (context) => _HomeThemePanel(genre: genre, row: row),
      ),
    );
  }

  /// Puts the head's picture on screen: where this device stopped when it
  /// stopped inside this title, its first episode otherwise. The shelf's card
  /// opens the series' page; the head's verb is the one the reference puts on
  /// its banner, so it has to reach the picture itself.
  void _playHero(HongguoSeries series, HongguoWatchProgress? seen) {
    final vid = seen?.episodeVid ?? '';
    final resume = seen != null && !seen.completed && seen.positionMs > 0 && vid.isNotEmpty
        ? seen.positionMs / 1000
        : null;
    unawaited(
      context.push(RouteNames.hongguoPlayerFor(series.seriesId, vid: vid.isEmpty ? null : vid, resumeSeconds: resume)),
    );
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
    // Where this device stands on each title the shelves below recommend: a
    // shelf's card has to say 已看完 / 看到第 N 集 rather than look untouched.
    final watchedById = _hongguoWatchedById(ref.watch(hongguoLibraryProvider.select((library) => library.history)));
    final themes = [
      for (final row in browse?.groups ?? const <HongguoFilterRow>[])
        if (row.type == 'category_dim_theme') row,
    ];
    // The topic on the shelf is the feed's own selection, not a copy the page
    // keeps: the chip wall this replaces reset its half on a genre switch
    // while the shelf behind stayed filtered by the pick it left behind.
    final themeRow = themes.isEmpty ? _topics : themes.first;
    final theme = browse?.selection['category_dim_theme'] ?? '';
    final hot = theme.isEmpty ? null : browse;
    // The page's first visual focus: the shelf's own first pick drawn at head
    // size, taken out of the row rather than shown a second time under it. One
    // title alone in the batch stays a card — a head over an empty row is not
    // a shelf.
    final batch = home.items.skip(_batch * _batchSize).toList();
    final hero = ref.watch(hongguoHomeBannerProvider) && batch.length > 1 ? batch.first : null;
    final forYou = (hero == null ? batch : batch.skip(1)).take(_batchSize).toList();
    final heroProgress = hero == null ? null : watchedById[hero.seriesId];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s20,
        children: [
          // The station's genre bar and the one condition this page carries.
          // The topics sit behind an entry, as 找剧 and 榜单 do theirs: a
          // genre's selector panel runs to twenty topics, and the wall of
          // chips they used to be pushed every shelf below the fold. Which one
          // is on gets said once — by the shelf it filters, whose name it
          // already is.
          SizedBox(
            height: 44,
            child: Builder(
              builder: (context) {
                final narrow = PageLayoutScope.isNarrow(context);
                final tabs = DsTabs<String>(
                  value: genre?.name ?? '',
                  onChanged: (name) => _selectGenre(name.isEmpty ? null : HongguoGenre.values.byName(name)),
                  style: _kShelfTabsStyle,
                  tabs: [
                    DsTab(value: '', label: Text(t.hongguo.homeTabAll)),
                    for (final value in HongguoGenre.values) DsTab(value: value.name, label: Text(value.label(t))),
                  ],
                );
                // A genre is the only shelf that carries topics; 推荐 has no
                // condition to set, so it gets no entry that cannot answer.
                final openTopics = genre == null || themeRow == null ? null : () => _openThemes(genre, themeRow);
                final filter = genre == null
                    ? null
                    : DsButton(
                        size: DsSize.sm,
                        variant: DsButtonVariant.secondary,
                        leading: const DsIcon(DsIcons.listFilter, size: 14),
                        onPressed: openTopics,
                        child: Text(t.hongguo.filter),
                      );
                // A narrow page keeps the genre bar alone and hands the one
                // condition to the shell's head line, as the live feeds do.
                if (narrow) publishPageHeadActions(context, ref, NavigationItem.hongguoHome, [?filter]);
                return Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(child: tabs),
                    if (!narrow) ?filter,
                  ],
                );
              },
            ),
          ),
          if (hero case final title?)
            HongguoFeedHero(
              series: title,
              eyebrow: t.hongguo.shelfForYou,
              watched: heroProgress,
              saved: ref.watch(hongguoLibraryProvider.select((library) => library.isFavorite(title.seriesId))),
              onOpen: () => _open(context, title),
              onPlay: () => _playHero(title, heroProgress),
              onSave: () {
                final added = ref.read(hongguoLibraryProvider.notifier).toggleFavorite(title);
                showDsToast(context: context, title: added ? t.hongguo.favoriteToggleOn : t.hongguo.favoriteToggleOff);
              },
            ),
          HongguoShelf(
            title: t.hongguo.shelfForYou,
            items: forYou,
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
            cardBuilder: (context, series) => HongguoCardMenu(
              series: series,
              onOpen: () => _open(context, series),
              child: HongguoSeriesCard(
                series: series,
                favoritable: true,
                watched: watchedById[series.seriesId],
                onOpen: () => _open(context, series),
              ),
            ),
          ),
          HongguoShelf(
            title: theme.isEmpty ? t.hongguo.shelfHot : _themeLabel(themeRow, theme),
            items: (theme.isEmpty ? heldRank.items : hot?.items ?? const <HongguoSeries>[]).take(_batchSize).toList(),
            loading: theme.isEmpty ? heldRank.loading : hot?.loading ?? true,
            error: theme.isEmpty ? heldRank.error : hot?.error,
            onRetry: theme.isEmpty
                ? () => unawaited(rankController.refresh(board))
                : () => unawaited(browseController.retry(genre!)),
            actions: [
              if (theme.isEmpty)
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
                onPressed: theme.isEmpty
                    ? () => unawaited(rankController.refresh(board))
                    : () => unawaited(browseController.retry(genre!)),
                child: Text(t.hongguo.refreshShelf),
              ),
            ],
            cardBuilder: (context, series) => HongguoCardMenu(
              series: series,
              onOpen: () => _open(context, series),
              child: HongguoSeriesCard(
                series: series,
                favoritable: true,
                watched: watchedById[series.seriesId],
                onOpen: () => _open(context, series),
              ),
            ),
          ),
          HongguoShelf(
            title: t.hongguo.shelfNew,
            items: latest?.items ?? const <HongguoSeries>[],
            loading: latest?.loading ?? true,
            error: latest?.error,
            onRetry: () => unawaited(latestController.retry(_latest)),
            // The shelf's own switches wrap under the title — three chips and
            // a button cannot share one header row down to the window's
            // 300 px floor. They name only the genre: this row's title is
            // already 新剧, and a shared suffix on every chip is text the eye
            // learns to skip.
            toolbar: [
              for (final value in HongguoGenre.values)
                DsChip(
                  label: Text(value.label(t)),
                  selected: _latest == value,
                  onChanged: (_) {
                    setState(() => _latest = value);
                    unawaited(latestController.open(value));
                  },
                ),
            ],
            actions: [
              DsButton(
                size: DsSize.sm,
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.refreshCw, size: 14),
                onPressed: () => unawaited(latestController.retry(_latest)),
                child: Text(t.hongguo.refreshShelf),
              ),
            ],
            cardBuilder: (context, series) => HongguoCardMenu(
              series: series,
              onOpen: () => _open(context, series),
              child: HongguoSeriesCard(
                series: series,
                favoritable: true,
                watched: watchedById[series.seriesId],
                onOpen: () => _open(context, series),
              ),
            ),
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

/// The home shelf's topics in the panel its bar opens: the one dimension that
/// names the shelf it filters, so its pick goes straight to the shelf behind
/// the panel and the row's own name says what is on.
final class _HomeThemePanel extends ConsumerWidget {
  const _HomeThemePanel({required this.genre, required this.row});

  /// The shelf these topics belong to.
  final HongguoGenre genre;

  /// The topic row the page is holding.
  final HongguoFilterRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(hongguoBrowseProvider.notifier);
    final selection =
        ref.watch(hongguoBrowseProvider.select((feeds) => feeds[genre.name]?.selection)) ?? const <String, String>{};
    return DsPanel(
      title: Text(t.hongguo.filterPanelTitle),
      footer: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: selection[row.type] == null ? null : () => unawaited(controller.select(genre, row.type, null)),
              child: Text(t.hongguo.filterReset),
            ),
          ),
          Expanded(
            child: DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.hongguo.filterDone)),
          ),
        ],
      ),
      child: HongguoFilterRowView(
        row: row,
        selection: selection,
        onSelect: (id) => unawaited(controller.select(genre, row.type, id)),
      ),
    );
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

  /// The conditions this shelf last answered with. A reload clears the feed's
  /// `groups` while it is in flight, and a page whose summary line goes quiet
  /// and whose entry greys out mid-read is describing a selection that is
  /// still in force as if it had gone.
  List<HongguoFilterRow> _held = const <HongguoFilterRow>[];

  /// Which shelf [`_held`] belongs to; a switch drops it, since the new
  /// shelf's conditions are not this one's.
  HongguoGenre? _heldGenre;

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
  Future<void> _openFilters(List<HongguoFilterRow> rows) => showDsPanel<void>(
    context: context,
    builder: (context) => _FindFilterPanel(genre: _genre, rows: rows),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final browse = ref.watch(browseSettingsProvider);
    final feed = ref.watch(hongguoBrowseProvider.select((feeds) => feeds[_genre.name]));
    final watchedById = _hongguoWatchedById(ref.watch(hongguoLibraryProvider.select((library) => library.history)));
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
    if (_heldGenre != _genre) {
      _heldGenre = _genre;
      _held = const <HongguoFilterRow>[];
    }
    if (state.groups.isNotEmpty) _held = state.groups;
    final groups = _held;
    final chosen = <String>[
      for (final row in groups)
        if (state.selection[row.type] case final id?)
          for (final option in row.items)
            if (option.id == id) option.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
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
                child: Builder(
                  builder: (context) {
                    final narrow = PageLayoutScope.isNarrow(context);
                    final tabs = DsTabs<HongguoGenre>(
                      value: _genre,
                      onChanged: (genre) {
                        if (genre == _genre) return;
                        setState(() => _genre = genre);
                        unawaited(controller.open(genre));
                      },
                      style: _kShelfTabsStyle,
                      tabs: [for (final genre in HongguoGenre.values) DsTab(value: genre, label: Text(genre.label(t)))],
                    );
                    final openFilters = groups.isEmpty ? null : () => unawaited(_openFilters(groups));
                    final filter = DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.listFilter, size: 14),
                      onPressed: openFilters,
                      child: Text(t.hongguo.filter),
                    );
                    // The shelf bar is the narrow page's one line: the
                    // conditions ride the shell's head, as the live feeds'.
                    if (narrow) publishPageHeadActions(context, ref, NavigationItem.hongguoFind, [filter]);
                    return Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(child: tabs),
                        if (!narrow) filter,
                      ],
                    );
                  },
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
          // The wall measures itself as a poster wall: the room feed's card
          // width would make one 0.62 tile the height of the pane it is drawn
          // in. The gutter the grid keeps is the window's, so the count of
          // posters is worked out of the width they are actually given.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = constraints.maxWidth - feedGutter(context).horizontal;
              return PagedCardGrid<HongguoSeries>(
                items: state.items,
                layout: ref.watch(browseLayoutProvider),
                cardExtent: hongguoPosterExtentForWidth(
                  content,
                  spacing: browse.crossSpacing,
                  ceiling: browse.gridColumns,
                ),
                crossSpacing: browse.crossSpacing,
                mainSpacing: browse.mainSpacing,
                aspectRatio: kHongguoSeriesTileAspect,
                listMainAxisExtent: kHongguoSeriesRowExtent,
                itemBuilder: (context, series) => HongguoCardMenu(
                  series: series,
                  onOpen: () => _open(context, series),
                  child: HongguoSeriesCard(
                    series: series,
                    favoritable: true,
                    watched: watchedById[series.seriesId],
                    onOpen: () => _open(context, series),
                  ),
                ),
                listItemBuilder: (context, series) => HongguoCardMenu(
                  series: series,
                  onOpen: () => _open(context, series),
                  child: HongguoSeriesRow(
                    series: series,
                    watched: watchedById[series.seriesId],
                    onOpen: () => _open(context, series),
                  ),
                ),
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
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The find page's conditions, in a panel over the posters: each choice goes
/// straight to the shelf's feed, so the grid behind thins as the viewer picks.
final class _FindFilterPanel extends ConsumerWidget {
  const _FindFilterPanel({required this.genre, required this.rows});

  /// The shelf whose selector panel the rows come from.
  final HongguoGenre genre;

  /// The conditions to offer: the page's own reading of them, so a panel
  /// opened while a reload is in flight is not an empty pane.
  final List<HongguoFilterRow> rows;

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
          for (final row in rows)
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

  /// The board's topics, in a panel over the rows: the board carries fifty of
  /// them at a time and a pick goes straight to the list behind.
  Future<void> _openTopics(HongguoWebsiteBoard board, List<HongguoRankTopic> topics) => showDsPanel<void>(
    context: context,
    builder: (context) =>
        _RankFilterPanel(topics: topics, topic: _topic, onSelect: (topic) => setState(() => _topic = topic ?? '')),
  );

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
    // Where this device left each title, so a hundred-place board reads as
    // 「which of these have I not opened」. One pass over the shelf's history
    // rather than a linear lookup per row.
    final watchedById = _hongguoWatchedById(ref.watch(hongguoLibraryProvider.select((library) => library.history)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (held.error != null && held.items.isEmpty) const _ServiceHint(),
        Padding(
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              // The boards' bar, the live module's measure; a board the page
              // has not read yet is opened on the pick, as the shelf bars do.
              SizedBox(
                height: 44,
                child: Builder(
                  builder: (context) {
                    final narrow = PageLayoutScope.isNarrow(context);
                    final tabs = DsTabs<HongguoWebsiteBoard>(
                      value: _board,
                      onChanged: (board) {
                        if (board == _board) return;
                        setState(() {
                          _board = board;
                          _topic = '';
                        });
                        unawaited(controller.open(board));
                      },
                      style: _kShelfTabsStyle,
                      tabs: [
                        for (final board in HongguoWebsiteBoard.values)
                          DsTab(value: board, label: Text(_boardLabel(t, board))),
                      ],
                    );
                    final openTopicsEntry = topics.isEmpty ? null : () => unawaited(_openTopics(_board, topics));
                    final reading = held.loading || held.renewing;
                    void readAgain() => unawaited(controller.refresh(_board));
                    final filter = DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.listFilter, size: 14),
                      onPressed: openTopicsEntry,
                      child: Text(t.hongguo.filter),
                    );
                    final refresh = DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: reading ? null : readAgain,
                      child: Text(reading ? t.hongguo.rankReading : t.hongguo.refresh),
                    );
                    // A narrow page keeps the boards' bar alone; the reload
                    // and the topic ride the shell's head, as the live feeds'.
                    if (narrow) {
                      publishPageHeadActions(context, ref, NavigationItem.hongguoRank, [refresh, filter]);
                    }
                    return Row(
                      spacing: DsSpace.s8,
                      children: [
                        Expanded(child: tabs),
                        if (!narrow) ...[filter, refresh],
                      ],
                    );
                  },
                ),
              ),
              // The one condition this board keeps, and how many of its hundred
              // rows it leaves — the row list itself starts right below it.
              Text(
                _topic.isEmpty
                    ? '${t.hongguo.rankTopicAll} · ${t.hongguo.rankSeriesCount(count: rows.length)}'
                    : '$_topic · ${t.hongguo.rankSeriesCount(count: rows.length)}',
                maxLines: 1,
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
                  padding: EdgeInsets.fromLTRB(
                    _hongguoPageInset(context),
                    DsSpace.s4,
                    _hongguoPageInset(context),
                    DsSpace.s24,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
                  itemBuilder: (context, index) {
                    final series = rows[index];
                    return HongguoCardMenu(
                      series: series,
                      onOpen: () => _open(context, series),
                      child: HongguoRankRow(
                        series: series,
                        position: index + 1,
                        watched: watchedById[series.seriesId],
                        onOpen: () => _open(context, series),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The board's topics, in the panel the board's own filter row opens: one
/// dimension, so its single choice goes straight to the board behind the
/// panel and the rows keep the place the board gave them.
final class _RankFilterPanel extends StatelessWidget {
  const _RankFilterPanel({required this.topics, required this.topic, required this.onSelect});

  /// The topics the whole board carries, most frequent first.
  final List<HongguoRankTopic> topics;

  /// The topic the board is thinned to; empty for the board whole.
  final String topic;

  /// Carries the chosen topic, or null for the board whole.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsPanel(
      title: Text(t.hongguo.rankFilterTitle),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(
            '${t.hongguo.rankSource} · ${t.hongguo.rankKeepsPlaces}',
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  onPressed: topic.isEmpty ? null : () => onSelect(null),
                  child: Text(t.hongguo.filterReset),
                ),
              ),
              Expanded(
                child: DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.hongguo.filterDone)),
              ),
            ],
          ),
        ],
      ),
      child: HongguoFilterRowView(
        row: HongguoFilterRow(
          type: 'topic',
          rowName: t.hongguo.rankFilterTitle,
          items: [
            for (final entry in topics) HongguoFilterOption(id: entry.topic, name: '${entry.topic} · ${entry.count}'),
          ],
        ),
        selection: topic.isEmpty ? const <String, String>{} : <String, String>{'topic': topic},
        onSelect: onSelect,
      ),
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
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
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
                  if (account && ref.read(hongguoAccountProvider).signedIn && shelf.items.isEmpty && !shelf.loading) {
                    unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).refresh());
                  }
                },
              ),
              if (!_account)
                Builder(
                  builder: (context) {
                    final narrow = PageLayoutScope.isNarrow(context);
                    final check = DsButton(
                      size: DsSize.sm,
                      variant: DsButtonVariant.secondary,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: library.favorites.isEmpty || library.checking
                          ? null
                          : () => unawaited(ref.read(hongguoLibraryProvider.notifier).checkUpdates(force: true)),
                      child: Text(t.hongguo.favoriteCheck),
                    );
                    // The shelf's one verb rides the shell's head on a narrow
                    // page, the live module's phone rule.
                    if (narrow) publishPageHeadActions(context, ref, NavigationItem.hongguoFavorites, [check]);
                    return Row(
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
                        if (!narrow) check,
                      ],
                    );
                  },
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
              // That line already reads 「共 80 集（+3）」; the count is said by
              // it, not again in front of it.
              withEpisodeCount: false,
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
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
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
                  if (account && ref.read(hongguoAccountProvider).signedIn && cloud.items.isEmpty && !cloud.loading) {
                    unawaited(ref.read(hongguoAccountHistoryProvider.notifier).refresh());
                  }
                },
              ),
              if (!_account)
                Builder(
                  builder: (context) {
                    final narrow = PageLayoutScope.isNarrow(context);
                    final actions = <Widget>[
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
                    ];
                    // The chips stay content (they thin the list); the shelf's
                    // verbs ride the shell's head on a narrow page.
                    if (narrow) publishPageHeadActions(context, ref, NavigationItem.hongguoHistory, actions);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s8,
                      children: [
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
                          ],
                        ),
                        if (!narrow && actions.isNotEmpty)
                          Wrap(spacing: DsSpace.s8, runSpacing: DsSpace.s8, children: actions),
                      ],
                    );
                  },
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
              emptyText: _watched == 0 ? null : t.common.empty,
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
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
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
                  openable: hongguoSeriesOpenable,
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
        padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s24),
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
                    initials: profile == null ? 'HG' : avatarInitials(profile.nickname),
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
  void initState() {
    super.initState();
    // A word handed from outside (the toolbar): taken once on arrival,
    // searched as though typed here. The listener catches a word handed
    // while the view is already showing.
    ref.listenManual(hongguoSearchHandoffProvider, (_, _) => _takeHandoff());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeHandoff());
  }

  /// Runs the handed word: the field reads it, the search answers it.
  void _takeHandoff() {
    final word = ref.read(hongguoSearchHandoffProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    _query.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    unawaited(ref.read(hongguoSearchProvider.notifier).search(word, genre: _genre));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final browse = ref.watch(browseSettingsProvider);
    final state = ref.watch(hongguoSearchProvider);
    final controller = ref.read(hongguoSearchProvider.notifier);
    final watchedById = _hongguoWatchedById(ref.watch(hongguoLibraryProvider.select((library) => library.history)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) const _ServiceHint(),
        Padding(
          padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              SizedBox(
                height: 44,
                child: DsTabs<HongguoGenre>(
                  value: _genre,
                  onChanged: (genre) {
                    if (genre == _genre) return;
                    setState(() => _genre = genre);
                    if (state.query.isNotEmpty) unawaited(controller.search(state.query, genre: genre));
                  },
                  style: _kShelfTabsStyle,
                  tabs: [for (final genre in HongguoGenre.values) DsTab(value: genre, label: Text(genre.label(t)))],
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
          // The hits are the same posters as the find wall, at the same
          // measure: one query seen through two pages cannot be two grids.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = constraints.maxWidth - feedGutter(context).horizontal;
              return PagedCardGrid<HongguoSeries>(
                items: state.items,
                layout: ref.watch(browseLayoutProvider),
                cardExtent: hongguoPosterExtentForWidth(
                  content,
                  spacing: browse.crossSpacing,
                  ceiling: browse.gridColumns,
                ),
                crossSpacing: browse.crossSpacing,
                mainSpacing: browse.mainSpacing,
                aspectRatio: kHongguoSeriesTileAspect,
                listMainAxisExtent: kHongguoSeriesRowExtent,
                itemBuilder: (context, series) => HongguoCardMenu(
                  series: series,
                  onOpen: () => _open(context, series),
                  child: HongguoSeriesCard(
                    series: series,
                    favoritable: true,
                    watched: watchedById[series.seriesId],
                    onOpen: () => _open(context, series),
                  ),
                ),
                listItemBuilder: (context, series) => HongguoCardMenu(
                  series: series,
                  onOpen: () => _open(context, series),
                  child: HongguoSeriesRow(
                    series: series,
                    watched: watchedById[series.seriesId],
                    onOpen: () => _open(context, series),
                  ),
                ),
                isLoading: state.loading,
                hasMore: state.hasMore,
                onLoadMore: controller.loadMore,
                error: state.error,
                onRetry: controller.retry,
                onRefresh: controller.retry,
                refreshError: state.error,
                emptyIcon: HongguoView.search.icon,
                emptyTitle: state.query.isEmpty ? t.hongguo.searchIdleTitle : t.common.empty,
                emptyDescription: state.query.isEmpty
                    ? t.hongguo.searchIdleDescription
                    : t.hongguo.noResultsDescription,
              );
            },
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
    this.withEpisodeCount = true,
  });

  final List<HongguoSeries> rows;
  final bool loading;
  final String? error;
  final String? emptyText;
  final Widget Function(HongguoSeries series)? trailingOf;
  final bool Function(HongguoSeries series)? openable;

  /// False where the rows' own figure line already names the episode total, so
  /// the listing line must not repeat it.
  final bool withEpisodeCount;

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
      padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
      itemBuilder: (context, index) {
        final series = rows[index];
        final canOpen = openable == null || openable!(series);
        return HongguoCardMenu(
          series: series,
          onOpen: canOpen ? () => _open(context, series) : null,
          child: HongguoSeriesRow(
            series: series,
            onOpen: canOpen ? () => _open(context, series) : null,
            trailing: trailingOf?.call(series),
            withEpisodeCount: withEpisodeCount,
          ),
        );
      },
    );
  }
}

/// The local history's own rows: the stripe where playback stood, and a
/// checkbox instead of the delete button while the shelf is being managed.
final class _ProgressList extends ConsumerWidget {
  const _ProgressList({
    required this.rows,
    this.managing = false,
    this.selected = const {},
    this.onToggle,
    this.emptyText,
  });

  final List<HongguoWatchProgress> rows;

  /// Whether the rows carry checkboxes for a batch removal.
  final bool managing;

  /// The rows ticked in that mode.
  final Set<String> selected;

  /// Flips one row's tick.
  final ValueChanged<String>? onToggle;

  /// What the empty shelf says; a shelf the filter emptied speaks for the
  /// filter, not for the whole history.
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    if (rows.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.history), title: Text(emptyText ?? t.hongguo.historyLocalEmpty)),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(_hongguoPageInset(context), DsSpace.s4, _hongguoPageInset(context), DsSpace.s24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpace.s8),
      itemBuilder: (context, index) {
        final row = rows[index];
        final series = HongguoSeries(
          seriesId: row.seriesId,
          title: row.title,
          cover: row.cover,
          episodeCount: row.episodeCount,
        );
        void remove() {
          ref.read(hongguoLibraryProvider.notifier).removeHistory(row.seriesId);
          showDsToast(context: context, title: t.hongguo.historyRemove);
        }

        return Column(
          spacing: DsSpace.s4,
          children: [
            HongguoCardMenu(
              series: series,
              onOpen: managing ? null : () => _open(context, series),
              items: [
                if (!managing)
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.hongguo.historyRemove),
                    destructive: true,
                    onPressed: remove,
                  ),
              ],
              child: HongguoSeriesRow(
                series: series,
                onOpen: managing ? null : () => _open(context, series),
                // The shelf's own row says where this device stands, in the
                // words every other face of the title uses, and the page adds
                // only the clock playback stood on.
                watched: row,
                note: row.completed ? null : _clock(row.positionMs),
                trailing: managing
                    ? DsCheckbox(
                        value: selected.contains(row.seriesId),
                        semanticLabel: row.title,
                        onChanged: (_) => onToggle?.call(row.seriesId),
                      )
                    : _IconAction(icon: DsIcons.trash2, semanticLabel: t.hongguo.historyRemove, onPressed: remove),
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
          final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
          return Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: lit ? DsTheme.colorsOf(context).hover : null,
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
