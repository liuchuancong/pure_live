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

  Future<void> _refresh() async {
    switch (_view) {
      case HuyaView.home:
        await ref.read(huyaVideoHomeProvider.notifier).refresh();
      case HuyaView.channels:
        await ref.read(huyaBrowseProvider.notifier).refresh();
      case HuyaView.rank:
        await ref.read(huyaRankProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) {
            final narrow = PageLayoutScope.isNarrow(context);
            final refresh = DsButton.icon(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              semanticLabel: t.common.refresh,
              onPressed: () => unawaited(_refresh()),
              icon: const DsIcon(DsIcons.refreshCw, size: 16),
            );
            // The rail is the view switcher now, so the page wears no tab row
            // of its own — only its reload. A narrow page hands it to the
            // shell's head under the entry that opened it; a wide one wears it
            // at its own top, the feeds' measure.
            if (narrow) {
              publishPageHeadActions(context, ref, widget.view.entry, [refresh]);
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
              child: SizedBox(height: 44, child: Row(children: [const Spacer(), refresh])),
            );
          },
        ),
        Expanded(
          child: switch (_view) {
            HuyaView.home => _HomeView(scrollController: _scrollOf(HuyaView.home), onOpen: _openVideo),
            HuyaView.channels => _ChannelsView(scrollController: _scrollOf(HuyaView.channels), onOpen: _openVideo),
            HuyaView.rank => _RankView(scrollController: _scrollOf(HuyaView.rank), onOpen: _openVideo),
          },
        ),
      ],
    );
  }
}

/// The station's home: a 游戏分类 tab strip over one card feed — the module's
/// 热门, read the way the live module reads its popular page. 推荐 is the
/// station's recommended videos merged with its shelves; a game tab narrows
/// the feed to that shelf.
final class _HomeView extends ConsumerStatefulWidget {
  const _HomeView({required this.scrollController, required this.onOpen});

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
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaVideoHomeProvider);
    final controller = ref.read(huyaVideoHomeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.open());
    });
    final home = state.home;
    final batch = ref.watch(huyaBatchProvider);
    final batchController = ref.read(huyaBatchProvider.notifier);
    final shelves = home?.shelves ?? const <HuyaVideoShelf>[];
    final selected = (_shelf != null && _shelf! >= 0 && _shelf! < shelves.length) ? _shelf : null;
    final shelf = selected == null ? null : shelves[selected];
    final List<HuyaVideo> videos;
    if (shelf == null) {
      final seen = <String>{};
      videos = <HuyaVideo>[
        if (home != null)
          for (final video in [...home.recommended, for (final item in home.shelves) ...item.videos])
            if (seen.add(video.id)) video,
      ];
    } else if (batch.channelId == shelf.channelId && batch.videos.isNotEmpty) {
      videos = batch.videos;
    } else {
      videos = shelf.videos;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shelves.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
            child: SizedBox(
              height: 40,
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shelves.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
                      itemBuilder: (context, index) {
                        final recommend = index == 0;
                        final chosen = recommend ? selected == null : selected == index - 1;
                        return DsChip(
                          label: Text(recommend ? t.huya.recommend : shelves[index - 1].title),
                          selected: chosen,
                          onChanged: (on) {
                            if (on) setState(() => _shelf = recommend ? null : index - 1);
                          },
                        );
                      },
                    ),
                  ),
                  // 换一批 belongs to a game's tab: 推荐 has no channel to draw
                  // a batch from.
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
                ],
              ),
            ),
          ),
        Expanded(
          child: HuyaVideoGrid(
            scrollController: widget.scrollController,
            videos: videos,
            loading: state.loading || (home == null && state.error == null) || (batch.loading && videos.isEmpty),
            hasMore: false,
            onLoadMore: () async {},
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
}

/// The station's listings: the group strip, the group's own channels and the
/// order, over the paged card grid.
final class _ChannelsView extends ConsumerWidget {
  const _ChannelsView({required this.scrollController, required this.onOpen});

  final ScrollController scrollController;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaBrowseProvider);
    final controller = ref.read(huyaBrowseProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.groups.isEmpty) {
      if (state.error case final error?) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.layoutList),
            title: Text(t.huya.errorTitle),
            description: Text(error.message),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(controller.open()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        );
      }
      return const Center(child: DsSpinner());
    }
    final group = state.groups.where((group) => group.setId == state.groupId).firstOrNull ?? state.groups.first;
    final list = state.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
          child: DsTopNav<int>(
            value: group.setId,
            items: [for (final item in state.groups) DsTopNavItem(value: item.setId, label: Text(item.title))],
            onChanged: (setId) {
              final next = state.groups.where((item) => item.setId == setId).firstOrNull;
              if (next != null) unawaited(controller.selectGroup(next));
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: group.channels.length,
                    separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
                    itemBuilder: (context, index) {
                      final channel = group.channels[index];
                      final selected =
                          channel.id == state.channelId && (channel.id != 'all' || state.setId == group.setId);
                      return DsChip(
                        label: Text(channel.name),
                        selected: selected,
                        onChanged: (on) {
                          if (on) unawaited(controller.selectChannel(group, channel));
                        },
                      );
                    },
                  ),
                ),
              ),
              DsSegmentedControl<HuyaVideoOrder>(
                value: state.order,
                semanticLabel: t.huya.sort,
                segments: [
                  for (final order in HuyaVideoOrder.values)
                    DsSegment(value: order, label: Text(huyaOrderLabel(t, order))),
                ],
                onChanged: (order) => unawaited(controller.selectOrder(order)),
              ),
            ],
          ),
        ),
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
  const _RankView({required this.scrollController, required this.onOpen});

  final ScrollController scrollController;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaRankProvider);
    final controller = ref.read(huyaRankProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.boards.isEmpty) {
      if (state.error case final error?) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.trophy),
            title: Text(t.huya.errorTitle),
            description: Text(error.message),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(controller.open()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        );
      }
      return const Center(child: DsSpinner());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
          child: DsTopNav<String>(
            value: state.boardId,
            items: [for (final board in state.boards) DsTopNavItem(value: board.id, label: Text(board.name))],
            onChanged: (id) => unawaited(controller.select(id)),
          ),
        ),
        if (state.updatedAt case final updated?)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s8, inset, 0),
            child: Text(
              t.huya.rankUpdated(time: _stamp(updated)),
              style: theme.typography.caption.copyWith(color: colors.textMuted),
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

/// A wall clock the station prints, as the board's own line reads it.
String _stamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}
