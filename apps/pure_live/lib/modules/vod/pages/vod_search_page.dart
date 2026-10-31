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
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodSeasonCard, VodUserRow, VodVideoCard, kVodCardInfoExtent;
import 'package:pure_live/shared/shared.dart';

/// The kind's tab words, the reference's five search types.
String vodSearchKindLabel(Translations t, VodSearchKind kind) => switch (kind) {
  VodSearchKind.video => t.vod.searchKindVideo,
  VodSearchKind.bangumi => t.vod.searchKindBangumi,
  VodSearchKind.cinema => t.vod.searchKindCinema,
  VodSearchKind.user => t.vod.searchKindUser,
  VodSearchKind.liveRoom => t.vod.searchKindLiveRoom,
};

/// The station's search page: the field, the five result tabs, the video
/// tab's two filters, and the paged results — the reference's search screen.
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

  void _setOrder(String order) {
    if (order == _order) return;
    setState(() => _order = order);
    _rerun();
  }

  void _setDuration(int duration) {
    if (duration == _duration) return;
    setState(() => _duration = duration);
    _rerun();
  }

  void _rerun() {
    final query = ref.read(vodProvider).query;
    if (query.isEmpty) return;
    unawaited(ref.read(vodProvider.notifier).search(query, kind: _kind, order: _order, duration: _duration));
  }

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
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
          child: SizedBox(
            height: 40,
            child: DsTopNav<VodSearchKind>(
              value: _kind,
              onChanged: _selectKind,
              items: [
                for (final kind in VodSearchKind.values)
                  DsTopNavItem(value: kind, label: Text(vodSearchKindLabel(t, kind))),
              ],
            ),
          ),
        ),
        if (_kind.filterable)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              children: [
                SizedBox(
                  width: 150,
                  child: AdaptiveChoiceField<String>(
                    value: _order,
                    title: t.vod.sort,
                    semanticLabel: t.vod.sort,
                    onChanged: _setOrder,
                    options: [
                      DsSelectOption(value: 'totalrank', label: t.vod.sortTotalrank),
                      DsSelectOption(value: 'click', label: t.vod.sortClick),
                      DsSelectOption(value: 'pubdate', label: t.vod.sortPubdate),
                      DsSelectOption(value: 'dm', label: t.vod.sortDm),
                      DsSelectOption(value: 'stow', label: t.vod.sortStow),
                    ],
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: AdaptiveChoiceField<int>(
                    value: _duration,
                    title: t.vod.duration,
                    semanticLabel: t.vod.duration,
                    onChanged: _setDuration,
                    options: [
                      DsSelectOption(value: 0, label: t.vod.durationAny),
                      DsSelectOption(value: 1, label: t.vod.durationUnder10),
                      DsSelectOption(value: 2, label: t.vod.duration10to30),
                      DsSelectOption(value: 3, label: t.vod.duration30to60),
                      DsSelectOption(value: 4, label: t.vod.durationOver60),
                    ],
                  ),
                ),
              ],
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
          aspectRatio: 0.62,
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
