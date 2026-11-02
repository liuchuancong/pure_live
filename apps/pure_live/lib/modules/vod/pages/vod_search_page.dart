import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard, RoomCardMenu;
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedAction, VodFeedToolbar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart'
    show VodSeasonCard, VodUserRow, VodVideoCard, kVodCardInfoExtent, kVodSeasonTileAspect;
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

/// The station's search page: the field, the five result tabs, and the paged
/// results — the reference's search screen. The archive tab's two conditions
/// live behind one head entry, so the results start under the head instead of
/// under a standing filter row.
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
    _search.value = TextEditingValue(text: word, selection: TextSelection.collapsed(offset: word.length));
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
  /// page carries now; the head's reload runs the same path.
  Future<void> _rerun() async {
    final query = ref.read(vodProvider).query;
    if (query.isEmpty) return;
    await ref.read(vodProvider.notifier).search(query, kind: _kind, order: _order, duration: _duration);
  }

  /// The two conditions in the panel the head's entry opens: the picks wait
  /// in the panel until the panel confirms them, so walking the five sorts is
  /// one search rather than five.
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
    final controller = ref.read(vodProvider.notifier);
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // Only the archive tab takes the station's two conditions; the other
    // kinds answer with what they are.
    final filterable = _kind.filterable;
    final searched = vod.query.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          child: DsSearchField(
            controller: _search,
            autofocus: true,
            placeholder: t.vod.searchHint,
            onSubmitted: (_) => _run(),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, searched && filterable ? DsSpace.s4 : DsSpace.s8),
          // The station's feed head, the same 44 as the three browse pages:
          // the result kinds at its start, the condition entry and the reload
          // at its end — and on a narrow window one more icon for both.
          child: VodFeedToolbar(
            tabs: DsTopNav<VodSearchKind>(
              value: _kind,
              onChanged: _selectKind,
              items: [
                for (final kind in VodSearchKind.values)
                  DsTopNavItem(value: kind, label: Text(vodSearchKindLabel(t, kind))),
              ],
            ),
            showLayout: false,
            actions: [
              if (filterable)
                VodFeedAction(
                  icon: DsIcons.listFilter,
                  label: t.vod.searchFilterTitle,
                  onPressed: () => unawaited(_openFilters()),
                ),
            ],
            onRefresh: searched ? _rerun : null,
          ),
        ),
        if (searched && filterable)
          // The two conditions the results are under, in one line the grid
          // does not have to pay for.
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: Text(
              '${vodSearchSortLabel(t, _order)} · ${vodSearchDurationLabel(t, _duration)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        Expanded(
          child: _SearchResults(
            state: vod,
            controller: controller,
            settings: ref.watch(browseSettingsProvider),
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

final class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.controller,
    required this.settings,
    required this.onVideo,
    required this.onSeason,
    required this.onRoom,
  });

  final VodState state;
  final VodController controller;
  final BrowseSettings settings;
  final ValueChanged<VodVideo> onVideo;
  final ValueChanged<VodSeason> onSeason;
  final ValueChanged<VodLiveRoom> onRoom;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
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
          infoExtent: kVodCardInfoExtent,
          crossSpacing: settings.crossSpacing,
          mainSpacing: settings.mainSpacing,
          isLoading: state.loading,
          hasMore: state.hasMore,
          onLoadMore: controller.loadMore,
          error: state.error?.message,
          onRetry: retry,
          emptyIcon: DsIcons.searchX,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onVideo(video)),
        );
      case VodSearchKind.bangumi:
      case VodSearchKind.cinema:
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
          emptyIcon: DsIcons.clapperboard,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, season) => VodSeasonCard(season: season, onOpen: () => onSeason(season)),
        );
      case VodSearchKind.user:
        if (state.error != null && state.users.isEmpty) {
          return _Failed(message: state.error!.message, onRetry: retry);
        }
        if (state.loading && state.users.isEmpty) return const Center(child: DsSpinner());
        if (state.users.isEmpty) return const _NoResults();
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
          itemCount: state.users.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s4),
          itemBuilder: (context, index) {
            if (index == state.users.length) return _MoreFooter(state: state, onMore: controller.loadMore);
            return VodUserRow(user: state.users[index]);
          },
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
          emptyIcon: DsIcons.radio,
          emptyTitle: t.vod.noResultsTitle,
          emptyDescription: t.vod.noResultsDescription,
          itemBuilder: (context, room) {
            final live = _liveRoomOf(room);
            return RoomCardMenu(
              room: live,
              onOpen: () => onRoom(room),
              child: RoomCard(room: live, onOpen: () => onRoom(room)),
            );
          },
        );
    }
  }
}

final class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.searchX),
        title: Text(t.vod.noResultsTitle),
        description: Text(t.vod.noResultsDescription),
      ),
    );
  }
}

final class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(t.vod.loadFailed),
        description: Text(message),
        actions: [DsButton(onPressed: onRetry, child: Text(t.vod.retry))],
      ),
    );
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

/// The list's footer: the next page's button while one is left.
final class _MoreFooter extends StatelessWidget {
  const _MoreFooter({required this.state, required this.onMore});

  final VodState state;
  final Future<void> Function() onMore;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (!state.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
      child: Center(
        child: state.loading
            ? const DsSpinner()
            : DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(onMore()),
                child: Text(t.vod.loadMore),
              ),
      ),
    );
  }
}
