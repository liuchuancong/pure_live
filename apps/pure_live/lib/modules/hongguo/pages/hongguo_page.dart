import 'dart:async' show Timer, unawaited;
import 'package:desen_ui/desen_ui.dart';
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
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CardGrid;

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
            HongguoView.home => const _HomeView(),
            HongguoView.find => const _FindView(),
            HongguoView.rank => const _RankView(),
            HongguoView.favorites => const _FavoritesView(),
            HongguoView.history => const _HistoryView(),
            HongguoView.reservations => const _ReservationsView(),
            HongguoView.account => const _AccountView(),
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

/// The 首页 feed: the cross-genre recommendations by default, one shelf's
/// own feed by chip; the grid's end walks the feed's session.
final class _HomeView extends ConsumerWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(hongguoHomeProvider);
    final controller = ref.read(hongguoHomeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open(null));
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
              DsChip(
                label: Text(t.hongguo.homeTabAll),
                selected: state.genre == null,
                onChanged: (_) => unawaited(controller.open(null)),
              ),
              DsChip(
                label: Text(t.hongguo.genreShortPlay),
                selected: state.genre == HongguoGenre.shortPlay,
                onChanged: (_) => unawaited(controller.open(HongguoGenre.shortPlay)),
              ),
              DsChip(
                label: Text(t.hongguo.genreComicSeries),
                selected: state.genre == HongguoGenre.comicSeries,
                onChanged: (_) => unawaited(controller.open(HongguoGenre.comicSeries)),
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
            hasMore: true,
            onLoadMore: controller.loadMore,
            error: state.error,
            onRetry: controller.retry,
            onRefresh: controller.retry,
            refreshError: state.error,
            emptyIcon: HongguoView.home.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.open(_genre));
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
              Wrap(
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
              for (final row in state.groups)
                HongguoFilterRowView(
                  row: row,
                  selection: state.selection,
                  onSelect: (id) => unawaited(controller.select(_genre, row.type, id)),
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
            emptyIcon: HongguoView.find.icon,
            emptyTitle: t.common.empty,
            emptyDescription: t.hongguo.noResultsDescription,
          ),
        ),
      ],
    );
  }
}

/// The boards: the board chips above the ranked grid.
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
            itemBuilder: (context, series) => HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) => HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: controller.loadMore,
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
          child: Wrap(
            spacing: DsSpace.s8,
            children: [
              DsChip(
                label: Text(t.hongguo.localTab),
                selected: !_account,
                onChanged: (_) => setState(() => _account = false),
              ),
              DsChip(
                label: Text(t.hongguo.accountTab),
                selected: _account,
                onChanged: (_) {
                  setState(() => _account = true);
                  if (ref.read(hongguoAccountProvider).signedIn && shelf.items.isEmpty && !shelf.loading) {
                    unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).refresh());
                  }
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
                onPressed: () => unawaited(
                  ref.read(hongguoAccountFavoritesProvider.notifier).setFavorite(series, add: false),
                ),
              ),
            ),
            _ => _SeriesList(
              rows: library.favorites,
              loading: false,
              error: null,
              emptyText: t.hongguo.favoritesLocalEmpty,
              trailingOf: (series) => _IconAction(
                icon: DsIcons.heartOff,
                semanticLabel: t.hongguo.favoriteToggleOff,
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final library = ref.watch(hongguoLibraryProvider);
    final account = ref.watch(hongguoAccountProvider);
    final cloud = ref.watch(hongguoAccountHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: Wrap(
            spacing: DsSpace.s8,
            children: [
              DsChip(
                label: Text(t.hongguo.localTab),
                selected: !_account,
                onChanged: (_) => setState(() => _account = false),
              ),
              DsChip(
                label: Text(t.hongguo.accountTab),
                selected: _account,
                onChanged: (_) {
                  setState(() => _account = true);
                  if (ref.read(hongguoAccountProvider).signedIn && cloud.items.isEmpty && !cloud.loading) {
                    unawaited(ref.read(hongguoAccountHistoryProvider.notifier).refresh());
                  }
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
                  row.series.copyWith(
                    hot: row.durationMs > 0 ? '${t.hongguo.resumeAt} ${_clock(row.positionMs)}' : '',
                  ),
              ],
              loading: cloud.loading,
              error: cloud.error,
              emptyText: t.hongguo.historyAccountEmpty,
            ),
            _ => _ProgressList(rows: library.history),
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
          child: Wrap(
            spacing: DsSpace.s8,
            children: [
              DsChip(
                label: Text(t.hongguo.reservationsOnline),
                selected: _online,
                onChanged: (_) => setState(() => _online = true),
              ),
              DsChip(
                label: Text(t.hongguo.reservationsUpcoming),
                selected: !_online,
                onChanged: (_) => setState(() => _online = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: !account.signedIn
              ? _SignInGate(message: t.hongguo.reservationsOff)
              : _SeriesList(
                  rows: [
                    for (final row in _online ? state.online : state.upcoming) row.series,
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
  const _AccountView();

  @override
  ConsumerState<_AccountView> createState() => _AccountViewState();
}

final class _AccountViewState extends ConsumerState<_AccountView> {
  Timer? _poll;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(hongguoAccountProvider).signedIn && ref.read(hongguoLoginSessionProvider).qr == null && !ref.read(hongguoLoginSessionProvider).polling) {
        unawaited(ref.read(hongguoLoginSessionProvider.notifier).load());
        _poll ??= Timer.periodic(const Duration(seconds: 2), (timer) async {
          final done = await ref.read(hongguoLoginSessionProvider.notifier).poll();
          if (done && mounted) {
            timer.cancel();
            _poll = null;
          }
        });
      }
      final held = ref.read(hongguoAccountProvider);
      if (held.credentials != null && held.profile == null && !held.loading) {
        unawaited(ref.read(hongguoAccountProvider.notifier).refreshProfile());
      }
    });
    if (account.signedIn) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s16,
          children: [
            Row(
              spacing: DsSpace.s12,
              children: [
                DsAvatar(initials: account.profile?.nickname ?? 'HG', toneIndex: 0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s3,
                    children: [
                      Text(
                        account.profile?.nickname ?? t.hongguo.title,
                        style: theme.typography.title.copyWith(color: colors.text),
                      ),
                      Text(
                        account.profile == null ? '' : '${t.hongguo.accountSignedInAs} · ${account.profile!.id}',
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            DsListSection(
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.refreshCw),
                  title: Text(t.hongguo.accountRefresh),
                  onPressed: () {
                    unawaited(ref.read(hongguoAccountProvider.notifier).refreshProfile());
                    unawaited(ref.read(hongguoAccountFavoritesProvider.notifier).refresh());
                    unawaited(ref.read(hongguoAccountHistoryProvider.notifier).refresh());
                    unawaited(ref.read(hongguoReservationsProvider.notifier).refresh());
                  },
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
            itemBuilder: (context, series) => HongguoSeriesCard(series: series, onOpen: () => _open(context, series)),
            listItemBuilder: (context, series) => HongguoSeriesRow(series: series, onOpen: () => _open(context, series)),
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
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.heart), title: Text(emptyText ?? t.common.empty)));
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

/// The local history's own rows: the stripe where playback stood.
final class _ProgressList extends ConsumerWidget {
  const _ProgressList({required this.rows});

  final List<HongguoWatchProgress> rows;

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
              : '${t.hongguo.episodeLabel(index: row.episodeIndex)} · ${_clock(row.positionMs)}',
        );
        return Column(
          spacing: DsSpace.s4,
          children: [
            HongguoSeriesRow(
              series: series,
              onOpen: () => _open(context, series),
              trailing: _IconAction(
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
      return const Center(child: SingleChildScrollView(padding: EdgeInsets.all(DsSpace.s24), child: _QrLoginCard()));
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

void _open(BuildContext context, HongguoSeries series) {
  if (series.seriesId.isEmpty) return;
  unawaited(context.push(RouteNames.hongguoSeries.replaceFirst(':seriesId', series.seriesId)));
}
