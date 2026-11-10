import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart' show publishPageHeadActions;
import 'package:pure_live/layouts/page_layout_scope.dart' show PageLayoutScope;
import 'package:pure_live/modules/huya/controller/huya_video.dart';
import 'package:pure_live/modules/huya/widgets/huya_widgets.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDateText;
import 'package:pure_live/shared/shared.dart';

/// The station's three surfaces: its home shelves, the channel listings and
/// the ranking boards.
enum HuyaView {
  /// The home's shelves.
  home,

  /// The channel directory.
  channels,

  /// The boards.
  rank;

  /// The menu entry that opens this view: the rail's row the page stands in
  /// for, and the owner the shell shows this page's verbs under.
  NavigationItem get entry => switch (this) {
    HuyaView.home => NavigationItem.huyaHome,
    HuyaView.channels => NavigationItem.huyaChannels,
    HuyaView.rank => NavigationItem.huyaRank,
  };
}

/// The station's own page: its shelves, its channel listings and its boards,
/// with the shell's search field answering over whichever is on screen.
///
/// Every view wears the app's one page head — the title, the facts beside
/// it and the view's verbs at the end — and a narrow page hands the verbs to
/// the shell's head under the entry that opened it, the live module's rule.
final class HuyaVideoPage extends ConsumerStatefulWidget {
  /// The station's page, opening on [view].
  const HuyaVideoPage({this.view = HuyaView.home, super.key});

  /// The view the page opens on.
  final HuyaView view;

  @override
  ConsumerState<HuyaVideoPage> createState() => _HuyaVideoPageState();
}

final class _HuyaVideoPageState extends ConsumerState<HuyaVideoPage> {
  late HuyaView _view = widget.view;
  final Map<HuyaView, ScrollController> _scrolls = {};

  @override
  void didUpdateWidget(HuyaVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the rail moves between the module's
    // entries, so a new entry moves the page to its view.
    if (widget.view != _view) setState(() => _view = widget.view);
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(HuyaView view) => _scrolls.putIfAbsent(view, ScrollController.new);

  void _openVideo(String id) {
    if (id.isEmpty) return;
    unawaited(context.push('/huya/$id'));
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      HuyaView.home => _HomeView(
        entry: HuyaView.home.entry,
        scrollController: _scrollOf(HuyaView.home),
        onOpen: _openVideo,
      ),
      HuyaView.channels => _ChannelsView(
        entry: HuyaView.channels.entry,
        scrollController: _scrollOf(HuyaView.channels),
        onOpen: _openVideo,
      ),
      HuyaView.rank => _RankView(
        entry: HuyaView.rank.entry,
        scrollController: _scrollOf(HuyaView.rank),
        onOpen: _openVideo,
      ),
    };
  }
}

/// The head row a view wears: the title, the facts beside it and the verbs
/// at the end — a narrow page publishes the verbs to the shell's head and
/// answers with nothing, the live module's rule.
Widget _viewHead(
  BuildContext context,
  WidgetRef ref, {
  required NavigationItem entry,
  required String title,
  required List<Widget> actions,
  String? description,
}) {
  if (PageLayoutScope.isNarrow(context)) {
    publishPageHeadActions(context, ref, entry, actions);
    return const SizedBox.shrink();
  }
  final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
  return Padding(
    padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
    child: ModulePageHead(title: title, description: description, actions: actions),
  );
}

/// The station's home: a 专区 bar over one card feed — the module's 热门,
/// read the way the live module reads its popular page. 推荐 is the
/// station's recommended videos merged with its shelves; a 专区 narrows the
/// feed to that shelf, and that shelf's own listing pages on from the same
/// walk the channel directory caches, so the feed keeps growing instead of
/// stopping at the home answer.
final class _HomeView extends ConsumerStatefulWidget {
  const _HomeView({required this.entry, required this.scrollController, required this.onOpen});

  final NavigationItem entry;
  final ScrollController scrollController;
  final ValueChanged<String> onOpen;

  @override
  ConsumerState<_HomeView> createState() => _HomeViewState();
}

final class _HomeViewState extends ConsumerState<_HomeView> {
  /// The selected 专区's index; null is 推荐, the whole home feed.
  int? _shelf;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(huyaVideoHomeProvider);
    final controller = ref.read(huyaVideoHomeProvider.notifier);
    final batch = ref.watch(huyaBatchProvider);
    final batchController = ref.read(huyaBatchProvider.notifier);
    final browse = ref.watch(huyaBrowseProvider);
    final browseController = ref.read(huyaBrowseProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(controller.open());
      // The chosen shelf's listing primes with the browse walk, so the feed's
      // load-more answers from the first reached row.
      if (_request case final request?) {
        unawaited(browseController.openListing(request));
      }
    });
    final home = state.home;
    final shelves = home?.shelves ?? const <HuyaVideoShelf>[];
    final selected = (_shelf != null && _shelf! >= 0 && _shelf! < shelves.length) ? _shelf : null;
    final shelf = selected == null ? null : shelves[selected];
    final request = shelf == null || shelf.channelId.isEmpty
        ? null
        : HuyaListRequest(channelId: shelf.channelId, setId: shelf.setId, order: HuyaVideoOrder.hot);
    _request = request;
    final (:videos, :hasMore, :onLoadMore) = _feedOf(
      home: home,
      shelf: shelf,
      request: request,
      batch: batch,
      browse: browse,
      browseController: browseController,
    );

    final refresh = DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.common.refresh,
      onPressed: () => unawaited(controller.refresh()),
      icon: const DsIcon(DsIcons.refreshCw, size: 16),
    );
    final actions = <Widget>[
      // 换一批 belongs to a 专区 with a channel: 推荐 has none to draw a
      // batch from.
      if (shelf != null && shelf.channelId.isNotEmpty)
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: batch.loading
              ? null
              : () => unawaited(batchController.exchange(channelId: shelf.channelId, setId: shelf.setId)),
          leading: const DsIcon(DsIcons.refreshCw, size: 16),
          child: Text(t.huya.exchange),
        ),
      refresh,
    ];
    final description = shelf == null
        ? (videos.isEmpty ? null : t.huya.headVideos(count: videos.length))
        : '${shelf.title} · ${t.huya.headVideos(count: videos.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _viewHead(context, ref, entry: widget.entry, title: t.huya.home, description: description, actions: actions),
        if (shelves.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
              DsSpace.s4,
              LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
              DsSpace.s8,
            ),
            child: SizedBox(
              height: 44,
              child: DsTopNav<int>(
                value: selected ?? -1,
                items: [
                  DsTopNavItem(value: -1, label: Text(t.huya.recommend)),
                  for (final (index, item) in shelves.indexed) DsTopNavItem(value: index, label: Text(item.title)),
                ],
                onChanged: (value) => setState(() => _shelf = value < 0 ? null : value),
              ),
            ),
          ),
        Expanded(
          child: HuyaVideoGrid(
            scrollController: widget.scrollController,
            videos: videos,
            loading:
                state.loading ||
                (home == null && state.error == null) ||
                (batch.loading && videos.isEmpty) ||
                (request != null && browse.listingFor(request).loading && videos.isEmpty),
            hasMore: hasMore,
            onLoadMore: onLoadMore,
            onOpen: widget.onOpen,
            error: state.error?.message,
            onRetry: () => unawaited(controller.refresh()),
            onRefresh: controller.refresh,
            emptyTitle: t.huya.homeEmpty,
          ),
        ),
      ],
    );
  }

  /// The chosen shelf's listing request, kept for the post-frame prime.
  HuyaListRequest? _request;

  /// What the feed shows for the shelf on screen: the 推荐 merge, a walked
  /// listing, a fresh 换一批 batch, or the home answer's own rows until the
  /// listing lands — with the walk the grid may go on with.
  ({List<HuyaVideo> videos, bool hasMore, Future<void> Function() onLoadMore}) _feedOf({
    required HuyaVideoHome? home,
    required HuyaVideoShelf? shelf,
    required HuyaListRequest? request,
    required HuyaBatchState batch,
    required HuyaBrowseState browse,
    required HuyaBrowseController browseController,
  }) {
    Future<void> idle() async {}
    if (shelf == null) {
      final seen = <String>{};
      return (
        videos: <HuyaVideo>[
          if (home != null)
            for (final video in [...home.recommended, for (final item in home.shelves) ...item.videos])
              if (seen.add(video.id)) video,
        ],
        hasMore: false,
        onLoadMore: idle,
      );
    }
    if (request case final listing?) {
      final walked = browse.listingFor(listing);
      if (batch.channelId == shelf.channelId && batch.videos.isNotEmpty) {
        // 换一批 swapped the feed for one fresh page: a single-batch answer
        // has no walk behind it.
        return (videos: batch.videos, hasMore: false, onLoadMore: idle);
      }
      if (walked.videos.isNotEmpty) {
        return (
          videos: walked.videos,
          hasMore: walked.hasMore,
          onLoadMore: () => browseController.loadListing(listing),
        );
      }
      // The home answer's own rows stand in until the listing lands.
      return (videos: shelf.videos, hasMore: true, onLoadMore: () => browseController.openListing(listing));
    }
    return (videos: shelf.videos, hasMore: false, onLoadMore: idle);
  }
}

/// The station's listings: the group strip, the group's own channels and the
/// order, over the paged card grid.
final class _ChannelsView extends ConsumerWidget {
  const _ChannelsView({required this.entry, required this.scrollController, required this.onOpen});

  final NavigationItem entry;
  final ScrollController scrollController;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    final state = ref.watch(huyaBrowseProvider);
    final controller = ref.read(huyaBrowseProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.groups.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _viewHead(context, ref, entry: entry, title: t.huya.channels, actions: const []),
          Expanded(
            child: HuyaLoadPanes(
              loading: state.groupsLoading,
              error: state.error?.message,
              onRetry: () => unawaited(controller.open()),
            ),
          ),
        ],
      );
    }
    final group = state.groups.where((group) => group.setId == state.groupId).firstOrNull ?? state.groups.first;
    final channel = group.channels.where((item) => item.id == state.channelId).firstOrNull;
    final list = state.current;
    final facts = [
      group.title,
      if (channel != null && channel.id != 'all') channel.name,
      huyaOrderLabel(t, state.order),
    ].join(' · ');
    final refresh = DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.common.refresh,
      onPressed: () => unawaited(controller.refresh()),
      icon: const DsIcon(DsIcons.refreshCw, size: 16),
    );
    final order = DsSegmentedControl<HuyaVideoOrder>(
      value: state.order,
      semanticLabel: t.huya.sort,
      segments: [
        for (final order in HuyaVideoOrder.values) DsSegment(value: order, label: Text(huyaOrderLabel(t, order))),
      ],
      onChanged: (order) => unawaited(controller.selectOrder(order)),
    );
    final channelStrip = SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: group.channels.length,
        separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
        itemBuilder: (context, index) {
          final channel = group.channels[index];
          final selected = channel.id == state.channelId && (channel.id != 'all' || state.setId == group.setId);
          return DsChip(
            label: Text(channel.name),
            selected: selected,
            onChanged: (on) {
              if (on) unawaited(controller.selectChannel(group, channel));
            },
          );
        },
      ),
    );
    // One toolbar line while the window pays for it — the channels narrowing
    // and the order beside it; under the toolbar width the two stack, the
    // live module's own rule.
    final toolbar = LiveWindow.stacksToolbar(width)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              channelStrip,
              Align(alignment: AlignmentDirectional.centerEnd, child: order),
            ],
          )
        : Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(child: channelStrip),
              order,
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _viewHead(
          context,
          ref,
          entry: entry,
          title: t.huya.channels,
          description: '$facts · ${t.huya.headVideos(count: list.videos.length)}',
          actions: [refresh],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, 0),
          child: DsTopNav<int>(
            value: group.setId,
            items: [for (final item in state.groups) DsTopNavItem(value: item.setId, label: Text(item.title))],
            onChanged: (setId) {
              final next = state.groups.where((item) => item.setId == setId).firstOrNull;
              if (next != null) unawaited(controller.selectGroup(next));
            },
          ),
        ),
        Padding(padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0), child: toolbar),
        Expanded(
          child: HuyaVideoGrid(
            scrollController: scrollController,
            videos: list.videos,
            loading: list.loading,
            hasMore: list.hasMore,
            onLoadMore: controller.loadMore,
            onOpen: onOpen,
            error: list.error?.message,
            onRetry: () => unawaited(controller.refresh()),
            onRefresh: controller.refresh,
            emptyDescription: t.huya.emptyDescription,
          ),
        ),
      ],
    );
  }
}

/// The station's boards: one strip of boards over the ranked grid.
final class _RankView extends ConsumerWidget {
  const _RankView({required this.entry, required this.scrollController, required this.onOpen});

  final NavigationItem entry;
  final ScrollController scrollController;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaRankProvider);
    final controller = ref.read(huyaRankProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.boards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _viewHead(context, ref, entry: entry, title: t.huya.rank, actions: const []),
          Expanded(
            child: HuyaLoadPanes(
              loading: state.loading,
              error: state.error?.message,
              onRetry: () => unawaited(controller.open()),
            ),
          ),
        ],
      );
    }
    final refresh = DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.common.refresh,
      onPressed: () => unawaited(controller.refresh()),
      icon: const DsIcon(DsIcons.refreshCw, size: 16),
    );
    final updated = state.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _viewHead(
          context,
          ref,
          entry: entry,
          title: t.huya.rank,
          description: updated == null ? null : t.huya.rankUpdated(time: _stamp(updated)),
          actions: [refresh],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, 0),
          child: DsTopNav<String>(
            value: state.boardId,
            items: [for (final board in state.boards) DsTopNavItem(value: board.id, label: Text(board.name))],
            onChanged: (id) => unawaited(controller.select(id)),
          ),
        ),
        Expanded(
          child: HuyaVideoGrid(
            scrollController: scrollController,
            videos: state.videos,
            loading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: controller.loadMore,
            onOpen: onOpen,
            error: state.error?.message,
            onRetry: () => unawaited(controller.refresh()),
            onRefresh: controller.refresh,
            ranked: true,
          ),
        ),
      ],
    );
  }
}

/// One order's words.
String huyaOrderLabel(Translations t, HuyaVideoOrder order) => switch (order) {
  HuyaVideoOrder.hot => t.huya.orderHot,
  HuyaVideoOrder.new_ => t.huya.orderNew,
  HuyaVideoOrder.most => t.huya.orderMost,
};

/// A wall clock the station prints, as the board's own line reads it: the
/// shared date, the clock beside it.
String _stamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${vodDateText(time)} ${two(time.hour)}:${two(time.minute)}';
}
