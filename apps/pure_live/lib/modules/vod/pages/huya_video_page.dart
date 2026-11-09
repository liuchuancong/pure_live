import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/huya_video.dart';
import 'package:pure_live/modules/vod/widgets/huya_widgets.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/shared/shared.dart';

/// The station's three surfaces: its home shelves, the channel listings and
/// the ranking boards.
enum HuyaView {
  /// The home's shelves.
  home,

  /// The channel listings.
  browse,

  /// The boards.
  rank;

  /// The view's words.
  String label(Translations t) => switch (this) {
    HuyaView.home => t.vod.huyaHome,
    HuyaView.browse => t.vod.huyaBrowse,
    HuyaView.rank => t.vod.huyaRank,
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
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(HuyaView view) => _scrolls.putIfAbsent(view, ScrollController.new);

  void _select(HuyaView view) {
    ref.read(huyaInlineSearchProvider.notifier).clear();
    if (view == _view) return;
    setState(() => _view = view);
  }

  void _openVideo(String id) {
    if (id.isEmpty) return;
    unawaited(context.push('/huya/$id'));
  }

  Future<void> _refresh() async {
    switch (_view) {
      case HuyaView.home:
        await ref.read(huyaVideoHomeProvider.notifier).refresh();
      case HuyaView.browse:
        await ref.read(huyaBrowseProvider.notifier).refresh();
      case HuyaView.rank:
        await ref.read(huyaRankProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final word = ref.watch(huyaInlineSearchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          child: VodFeedToolbar(
            owner: NavigationItem.huyaVideo,
            tabs: DsTabs<HuyaView>(
              value: _view,
              onChanged: _select,
              style: kVodFeedTabsStyle,
              tabs: [for (final view in HuyaView.values) DsTab(value: view, label: Text(view.label(t)))],
            ),
            showLayout: false,
            onRefresh: _refresh,
          ),
        ),
        Expanded(
          child: word == null
              ? switch (_view) {
                  HuyaView.home => _HomeView(
                    scrollController: _scrollOf(HuyaView.home),
                    onOpen: _openVideo,
                    onMore: (channelId) {
                      _select(HuyaView.browse);
                      unawaited(ref.read(huyaBrowseProvider.notifier).walkInto(channelId));
                    },
                  ),
                  HuyaView.browse => _BrowseView(scrollController: _scrollOf(HuyaView.browse), onOpen: _openVideo),
                  HuyaView.rank => _RankView(scrollController: _scrollOf(HuyaView.rank), onOpen: _openVideo),
                }
              : _SearchView(word: word, onOpen: _openVideo),
        ),
      ],
    );
  }
}

/// The station's home: one shelf per channel the station picked, each with
/// the way into its whole listing.
final class _HomeView extends ConsumerWidget {
  const _HomeView({required this.scrollController, required this.onOpen, required this.onMore});

  final ScrollController scrollController;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaVideoHomeProvider);
    final controller = ref.read(huyaVideoHomeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.home == null) {
      if (state.error case final error?) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.film),
            title: Text(t.vod.errorTitle),
            description: Text(error.message),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(controller.refresh()),
                child: Text(t.common.retry),
              ),
            ],
          ),
        );
      }
      return const Center(child: DsSpinner());
    }
    final shelves = state.home!.shelves;
    if (shelves.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.film), title: Text(t.vod.huyaHomeEmpty)),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
      itemCount: shelves.length,
      separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s24),
      itemBuilder: (context, index) {
        final shelf = shelves[index];
        return HuyaShelf(
          shelf: shelf,
          onOpen: onOpen,
          onMore: shelf.channelId.isEmpty ? null : () => onMore(shelf.channelId),
        );
      },
    );
  }
}

/// The station's listings: the group strip, the group's own channels and the
/// order, over the paged card grid.
final class _BrowseView extends ConsumerWidget {
  const _BrowseView({required this.scrollController, required this.onOpen});

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
            title: Text(t.vod.errorTitle),
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
                semanticLabel: t.vod.sort,
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
            emptyDescription: t.vod.regionEmptyDescription,
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
            title: Text(t.vod.errorTitle),
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
              t.vod.huyaRankUpdated(time: _stamp(updated)),
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

/// The answer to the shell's search field: the word as a callout with the way
/// back to the station's own content, over the result grid.
final class _SearchView extends ConsumerWidget {
  const _SearchView({required this.word, required this.onOpen});

  final String word;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(huyaSearchProvider);
    final controller = ref.read(huyaSearchProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && state.query != word) unawaited(controller.search(word));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
          child: DsAlert(
            title: Text(t.vod.huyaSearchResults(count: state.total, word: word)),
            action: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => ref.read(huyaInlineSearchProvider.notifier).clear(),
              leading: const DsIcon(DsIcons.x, size: 14),
              child: Text(t.vod.huyaBackToBrowse),
            ),
          ),
        ),
        Expanded(
          child: HuyaVideoGrid(
            videos: state.videos,
            loading: state.loading,
            hasMore: false,
            onLoadMore: () async {},
            onOpen: onOpen,
            error: state.error?.message,
            onRetry: () => unawaited(controller.search(word)),
            emptyTitle: t.vod.huyaSearchEmpty,
            emptyDescription: t.vod.huyaSearchEmptyDescription,
          ),
        ),
      ],
    );
  }
}

/// One order's words.
String huyaOrderLabel(Translations t, HuyaVideoOrder order) => switch (order) {
  HuyaVideoOrder.hot => t.vod.huyaOrderHot,
  HuyaVideoOrder.new_ => t.vod.huyaOrderNew,
  HuyaVideoOrder.most => t.vod.huyaOrderMost,
};

/// A wall clock the station prints, as the board's own line reads it.
String _stamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}
