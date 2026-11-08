import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard, RoomCardMenu;
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodSeasonCard, VodUserRow, VodVideoCard, VodVideoRow, kVodCardInfoExtent, kVodSeasonTileAspect;
import 'package:pure_live/shared/shared.dart';

/// The kind's tab words, the reference's five search types.
String vodSearchKindLabel(Translations t, VodSearchKind kind) => switch (kind) {
  VodSearchKind.video => t.vod.searchKindVideo,
  VodSearchKind.bangumi => t.vod.searchKindBangumi,
  VodSearchKind.cinema => t.vod.searchKindCinema,
  VodSearchKind.user => t.vod.searchKindUser,
  VodSearchKind.liveRoom => t.vod.searchKindLiveRoom,
};

/// The archive tab's sorts, in the station's own order.
const List<String> kVodSearchSorts = ['totalrank', 'click', 'pubdate', 'dm', 'stow'];

/// The archive tab's length bands, the station's own zero for any length.
const List<int> kVodSearchDurations = [0, 1, 2, 3, 4];

/// One sort id's words.
String vodSearchSortLabel(Translations t, String sort) => switch (sort) {
  'click' => t.vod.sortClick,
  'pubdate' => t.vod.sortPubdate,
  'dm' => t.vod.sortDm,
  'stow' => t.vod.sortStow,
  _ => t.vod.sortTotalrank,
};

/// One length band's words.
String vodSearchDurationLabel(Translations t, int duration) => switch (duration) {
  1 => t.vod.durationUnder10,
  2 => t.vod.duration10to30,
  3 => t.vod.duration30to60,
  4 => t.vod.durationOver60,
  _ => t.vod.durationAny,
};

/// The station's search page: two head rows over the results — the
/// reference's search screen. The first row is the field, its search verb
/// and the archive tab's condition entry (the panel behind it carries the
/// sort and the length); the second is the five result kinds with the
/// conditions' caption at its end. The results share the browse feeds' grid,
/// so the viewer's spacing, the card/list layout, the wide pager and the
/// narrow append all work here as they do on the feeds.
final class VodSearchPage extends ConsumerStatefulWidget {
  /// The search page.
  const VodSearchPage({super.key});

  @override
  ConsumerState<VodSearchPage> createState() => _VodSearchPageState();
}

final class _VodSearchPageState extends ConsumerState<VodSearchPage> {
  final TextEditingController _search = TextEditingController();
  VodSearchKind _kind = VodSearchKind.video;
  String _order = 'totalrank';
  int _duration = 0;

  @override
  void initState() {
    super.initState();
    // A word handed from outside (the toolbar): taken once on arrival,
    // searched as though typed here. The listener catches a word handed
    // while the page is already showing.
    ref.listenManual(vodPendingSearchProvider, (_, _) => _takePending());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePending());
  }

  /// Runs the handed word: the field reads it, the search answers it.
  void _takePending() {
    final word = ref.read(vodPendingSearchProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    _search.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    _run();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _run() {
    unawaited(ref.read(vodProvider.notifier).search(_search.text, kind: _kind, order: _order, duration: _duration));
  }

  void _selectKind(VodSearchKind kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    // The same words, the other result kind: a committed query is re-asked.
    unawaited(ref.read(vodProvider.notifier).search(_search.text, kind: kind, order: _order, duration: _duration));
  }

  /// Asks the station the query on the screen again, with the conditions the
  /// page carries now; the toolbar's reload runs the same path.
  Future<void> _rerun() async {
    final query = ref.read(vodProvider).query;
    if (query.isEmpty) return;
    await ref.read(vodProvider.notifier).search(query, kind: _kind, order: _order, duration: _duration);
  }

  /// Whether the two conditions stand away from their defaults: the entry
  /// then wears the accent, the way the reference marks a filtered search.
  bool get _filtered => _order != kVodSearchSorts.first || _duration != 0;

  /// The two conditions in the panel the field row's entry opens: the picks
  /// wait in the panel until the panel confirms them, so walking the five
  /// sorts is one search rather than five.
  Future<void> _openFilters() => showDsPanel<void>(
    context: context,
    builder: (context) => _SearchFilterPanel(
      order: _order,
      duration: _duration,
      onApply: (order, duration) {
        setState(() {
          _order = order;
          _duration = duration;
        });
        unawaited(_rerun());
      },
    ),
  );

  void _openVideo(VodVideo video) {
    final bvid = video.bvid ?? video.id;
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  void _openSeason(VodSeason season) => unawaited(context.push('/vod/season/${season.seasonId}'));

  void _openRoom(VodLiveRoom room) {
    unawaited(openRoom(context, platform: 'bilibili', roomId: '${room.roomId}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final vod = ref.watch(vodProvider);
    final settings = ref.watch(browseSettingsProvider);
    final layout = ref.watch(browseLayoutProvider);
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // Only the archive tab takes the station's two conditions; the other
    // kinds answer with what they are.
    final filterable = _kind.filterable;
    final searched = vod.query.isNotEmpty;
    final narrow = PageLayoutScope.isNarrow(context);
    // The conditions the results stand under, the reference's caption at the
    // kinds row's end; the archive tab alone has them.
    final conditions = '${vodSearchSortLabel(t, _order)} · ${vodSearchDurationLabel(t, _duration)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The head's first row: the field, the search verb beside it on a
        // window that holds one (a narrow page submits from the keyboard),
        // and the archive tab's condition entry in the accent once a
        // condition stands away from its default.
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: DsSearchField(
                  controller: _search,
                  autofocus: true,
                  placeholder: t.vod.searchHint,
                  onSubmitted: (_) => _run(),
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: DsSpace.s8),
                DsButton(variant: DsButtonVariant.ghost, size: DsSize.sm, onPressed: _run, child: Text(t.vod.search)),
              ],
              if (filterable) ...[
                const SizedBox(width: DsSpace.s8),
                DsButton.icon(
                  variant: _filtered ? DsButtonVariant.tinted : DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.vod.searchFilterTitle,
                  onPressed: () => unawaited(_openFilters()),
                  icon: const DsIcon(DsIcons.listFilter, size: 16),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
          // The head's second row, the same 44 as the three browse pages:
          // the result kinds at its start, and on a wide window the
          // conditions the results stand under at its end — a narrow page
          // keeps the kinds alone. The toolbar's reload rides at its end
          // while a query is on the screen, and on a narrow page publishes
          // itself to the shell's head line.
          child: VodFeedToolbar(
            owner: NavigationItem.vodSearch,
            tabs: Row(
              children: [
                Expanded(
                  child: DsTabs<VodSearchKind>(
                    value: _kind,
                    onChanged: _selectKind,
                    style: kVodFeedTabsStyle,
                    tabs: [
                      for (final kind in VodSearchKind.values)
                        DsTab(value: kind, label: Text(vodSearchKindLabel(t, kind))),
                    ],
                  ),
                ),
                if (searched && filterable && !narrow) ...[
                  const SizedBox(width: DsSpace.s8),
                  Flexible(
                    child: Text(
                      conditions,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
            showLayout: false,
            onRefresh: searched ? _rerun : null,
          ),
        ),
        Expanded(
          child: _SearchResults(
            state: vod,
            controller: ref.read(vodProvider.notifier),
            settings: settings,
            layout: layout,
            onRefresh: _rerun,
            onVideo: _openVideo,
            onSeason: _openSeason,
            onRoom: _openRoom,
          ),
        ),
      ],
    );
  }
}

/// The archive tab's conditions in one panel over the results: the sort and
/// the length, each as its own chip row — the head-entry shape the boards and
/// the plaza use. The picks stay in the panel until [onApply] asks the station
/// once, so walking the five sorts is one search rather than five.
final class _SearchFilterPanel extends StatefulWidget {
  const _SearchFilterPanel({required this.order, required this.duration, required this.onApply});

  /// The sort the results are under.
  final String order;

  /// The length band the results are under.
  final int duration;

  /// Runs the search the picks describe.
  final void Function(String order, int duration) onApply;

  @override
  State<_SearchFilterPanel> createState() => _SearchFilterPanelState();
}

final class _SearchFilterPanelState extends State<_SearchFilterPanel> {
  late String _order = widget.order;
  late int _duration = widget.duration;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);

    Widget row(String label, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s6,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
          Wrap(spacing: DsSpace.s8, runSpacing: DsSpace.s8, children: chips),
        ],
      ),
    );

    return DsPanel(
      title: Text(t.vod.searchFilterTitle),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DsButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onApply(_order, _duration);
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(t.vod.sort, [
            for (final sort in kVodSearchSorts)
              DsChip(
                label: Text(vodSearchSortLabel(t, sort)),
                selected: sort == _order,
                onChanged: (on) {
                  if (!on) return;
                  setState(() => _order = sort);
                },
              ),
          ]),
          row(t.vod.duration, [
            for (final duration in kVodSearchDurations)
              DsChip(
                label: Text(vodSearchDurationLabel(t, duration)),
                selected: duration == _duration,
                onChanged: (on) {
                  if (!on) return;
                  setState(() => _duration = duration);
                },
              ),
          ]),
        ],
      ),
    );
  }
}

/// Every kind's results over the one shared feed: the browse grid's cards, or
/// its row cards under the viewer's list layout, with the paging, the pull
/// and the empty and failure states the grid owns.
final class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.controller,
    required this.settings,
    required this.layout,
    required this.onRefresh,
    required this.onVideo,
    required this.onSeason,
    required this.onRoom,
  });

  final VodState state;
  final VodController controller;
  final BrowseSettings settings;

  /// The viewer's card/row layout; the video hits take it, the kinds without
  /// a second form keep their own.
  final CardLayout layout;

  /// Loads the first page again (the pull gesture).
  final Future<void> Function() onRefresh;

  final ValueChanged<VodVideo> onVideo;
  final ValueChanged<VodSeason> onSeason;
  final ValueChanged<VodLiveRoom> onRoom;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (state.query.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.search),
          title: Text(t.vod.idleTitle),
          description: Text(t.vod.idleDescription),
        ),
      );
    }
    void retry() => unawaited(controller.retry());
    switch (state.kind) {
      case VodSearchKind.video:
        return PagedCardGrid<VodVideo>(
          items: state.videos,
          layout: layout,
          // The row card is a cover beside two text lines, the same fixed
          // height the browse feeds' list layout holds it at.
          listMainAxisExtent: 104,
          listItemBuilder: (context, video) => VodVideoRow(video: video, onOpen: () => onVideo(video)),
          infoExtent: kVodCardInfoExtent,
          crossSpacing: settings.crossSpacing,
          mainSpacing: settings.mainSpacing,
          isLoading: state.loading,
          hasMore: state.hasMore,
          onLoadMore: controller.loadMore,
          error: state.error?.message,
          onRetry: retry,
          onRefresh: onRefresh,
          refreshError: state.error?.message,
          emptyIcon: DsIcons.searchX,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onVideo(video), preview: true),
        );
      case VodSearchKind.bangumi:
      case VodSearchKind.cinema:
        // The poster wall has no row form, so the layout choice does not
        // reach this kind; the viewer's spacing and the paging still do.
        return PagedCardGrid<VodSeason>(
          items: state.seasons,
          aspectRatio: kVodSeasonTileAspect,
          crossSpacing: settings.crossSpacing,
          mainSpacing: settings.mainSpacing,
          isLoading: state.loading,
          hasMore: state.hasMore,
          onLoadMore: controller.loadMore,
          error: state.error?.message,
          onRetry: retry,
          onRefresh: onRefresh,
          refreshError: state.error?.message,
          emptyIcon: DsIcons.clapperboard,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, season) => VodSeasonCard(season: season, onOpen: () => onSeason(season), preview: true),
        );
      case VodSearchKind.user:
        // A user hit is a display row — the station offers no space page to
        // open — so this kind stays the list however the feeds are laid out.
        return PagedCardGrid<VodUser>(
          items: state.users,
          layout: CardLayout.list,
          listMainAxisExtent: 104,
          listItemBuilder: (context, user) => VodUserRow(user: user),
          crossSpacing: settings.crossSpacing,
          mainSpacing: settings.mainSpacing,
          isLoading: state.loading,
          hasMore: state.hasMore,
          onLoadMore: controller.loadMore,
          error: state.error?.message,
          onRetry: retry,
          onRefresh: onRefresh,
          refreshError: state.error?.message,
          emptyIcon: DsIcons.user,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, user) => VodUserRow(user: user),
        );
      case VodSearchKind.liveRoom:
        return PagedCardGrid<VodLiveRoom>(
          items: state.rooms,
          crossSpacing: settings.crossSpacing,
          mainSpacing: settings.mainSpacing,
          isLoading: state.loading,
          hasMore: state.hasMore,
          onLoadMore: controller.loadMore,
          error: state.error?.message,
          onRetry: retry,
          onRefresh: onRefresh,
          refreshError: state.error?.message,
          emptyIcon: DsIcons.radio,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, room) {
            final live = _liveRoomOf(room);
            return RoomCardMenu(
              room: live,
              onOpen: () => onRoom(room),
              child: RoomCard(room: live, onOpen: () => onRoom(room), livePreview: true),
            );
          },
        );
    }
  }
}

/// One live-room hit as the shared card's room: the station answers a search
/// with the same room the live feeds show, minus the fields a search hit does
/// not carry.
LiveRoom _liveRoomOf(VodLiveRoom room) => LiveRoom.normalized(
  platform: SiteIds.bilibili,
  roomId: '${room.roomId}',
  content: RoomContent.of(title: room.title, coverUrl: room.coverUrl ?? ''),
  anchor: LiveAnchor.of(name: room.anchor ?? '', avatarUrl: room.avatar),
  audience: RoomAudience.of(onlineViewers: room.online),
  broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
);
