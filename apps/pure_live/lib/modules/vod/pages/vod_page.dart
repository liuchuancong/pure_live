import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account.dart' show showBilibiliWebLoginPage;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/controller/vod_social.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodDynamicRow, VodVideoCard, VodVideoRow;
import 'package:pure_live/shared/shared.dart';

/// The station's home: the reference's 主页 rail entry, on its three tabs in
/// the reference's order and opening on its default tab, 动态.
enum VodTab {
  /// The signed-in viewer's dynamic feed.
  dynamics,

  /// What the platform draws for this viewer, page by page.
  recommend,

  /// The site-wide popular list.
  popular;

  /// The tab's icon.
  DsIconData get icon => switch (this) {
    VodTab.recommend => DsIcons.sparkles,
    VodTab.popular => DsIcons.flame,
    VodTab.dynamics => DsIcons.rss,
  };

  /// The tab's words.
  String label(Translations t) => switch (this) {
    VodTab.recommend => t.vod.tabRecommend,
    VodTab.popular => t.vod.tabPopular,
    VodTab.dynamics => t.vod.tabDynamics,
  };
}

/// The Bilibili station's home: 动态 / 推荐 / 热门, all opening the same video
/// page. Everything the station requests lives in the controllers; the page
/// only asks.
final class VodPage extends ConsumerStatefulWidget {
  /// The station's entry page, opening on [tab].
  const VodPage({this.tab = VodTab.dynamics, super.key});

  /// The tab the station opens on.
  final VodTab tab;

  @override
  ConsumerState<VodPage> createState() => _VodPageState();
}

final class _VodPageState extends ConsumerState<VodPage> {
  late VodTab _tab = widget.tab;
  final Map<String, ScrollController> _scrolls = {};

  @override
  void initState() {
    super.initState();
    _ensureFeed(_keyOf(_tab));
  }

  @override
  void didUpdateWidget(VodPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the station's
    // entries, so a new entry has to move the page to its tab.
    if (widget.tab != _tab) _selectTab(widget.tab);
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  String get _recommendKey => vodFeedKey(VodFeedKind.recommend);

  String get _popularKey => vodFeedKey(VodFeedKind.popular);

  /// The feed [tab] reads, or null for the tab that owns no feed.
  String? _keyOf(VodTab tab) => switch (tab) {
    VodTab.recommend => _recommendKey,
    VodTab.popular => _popularKey,
    VodTab.dynamics => null,
  };

  ScrollController _scrollOf(String key) => _scrolls.putIfAbsent(key, ScrollController.new);

  /// Loads [key]'s first page if it has none; safe to call on every visit.
  void _ensureFeed(String? key) {
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodFeedProvider.notifier).open(key));
    });
  }

  void _selectTab(VodTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    switch (tab) {
      case VodTab.recommend:
        _ensureFeed(_recommendKey);
      case VodTab.popular:
        _ensureFeed(_popularKey);
      case VodTab.dynamics:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(ref.read(vodDynamicsProvider.notifier).open());
        });
    }
  }

  void _openVideo(VodVideo video) {
    final bvid = video.bvid ?? video.id;
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  void _refreshCurrent() {
    switch (_tab) {
      case VodTab.recommend:
        unawaited(ref.read(vodFeedProvider.notifier).refresh(_recommendKey));
      case VodTab.popular:
        unawaited(ref.read(vodFeedProvider.notifier).refresh(_popularKey));
      case VodTab.dynamics:
        unawaited(ref.read(vodDynamicsProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: DsTopNav<VodTab>(
                  value: _tab,
                  onChanged: _selectTab,
                  items: [
                    for (final tab in VodTab.values)
                      DsTopNavItem(value: tab, label: Text(tab.label(t)), icon: DsIcon(tab.icon)),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.s8),
              ChromeIconButton(
                icon: DsIcons.refresh,
                semanticLabel: t.vod.refresh,
                tooltip: t.vod.refresh,
                onPressed: _refreshCurrent,
                size: 36,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            VodTab.recommend => _VodFeedView(
              feedKey: _recommendKey,
              scrollController: _scrollOf(_recommendKey),
              onOpen: _openVideo,
            ),
            VodTab.popular => _VodFeedView(
              feedKey: _popularKey,
              scrollController: _scrollOf(_popularKey),
              onOpen: _openVideo,
            ),
            VodTab.dynamics => _VodDynamicsView(onOpen: _openVideo),
          },
        ),
      ],
    );
  }
}

/// One cached browse feed as the shared card grid.
final class _VodFeedView extends ConsumerWidget {
  const _VodFeedView({required this.feedKey, required this.scrollController, required this.onOpen});

  final String feedKey;
  final ScrollController scrollController;
  final ValueChanged<VodVideo> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final feed = ref.watch(vodFeedProvider.select((feeds) => feeds[feedKey]));
    final state = feed ?? (videos: const <VodVideo>[], nextPage: 1, hasMore: true, loading: false, error: null);
    final controller = ref.read(vodFeedProvider.notifier);
    return CardGrid<VodVideo>(
      scrollController: scrollController,
      items: state.videos,
      layout: ref.watch(browseLayoutProvider),
      // The archive row is a cover beside two text lines: a hair taller
      // than the room row so a two-line title never presses on its edge.
      listMainAxisExtent: 104,
      listItemBuilder: (context, video) => VodVideoRow(video: video, onOpen: () => onOpen(video)),
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: state.loading,
      hasMore: state.hasMore,
      onLoadMore: () => controller.loadMore(feedKey),
      error: state.error?.message,
      onRetry: () => controller.refresh(feedKey),
      onRefresh: () => controller.refresh(feedKey),
      refreshError: state.error?.message,
      emptyIcon: DsIcons.film,
      emptyTitle: t.common.empty,
      emptyDescription: t.vod.noResultsDescription,
      itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onOpen(video)),
    );
  }
}

/// The viewer's dynamic feed: sign-in gated, cursored, read page by page.
final class _VodDynamicsView extends ConsumerWidget {
  const _VodDynamicsView({required this.onOpen});

  final ValueChanged<VodVideo> onOpen;

  void _openPost(BuildContext context, VodDynamic post) {
    final bvid = post.bvid;
    if (bvid == null || bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final account = ref.watch(vodAccountProvider);
    final login = account.value;
    if (account.isLoading && login == null) {
      return const Center(child: DsSpinner());
    }
    if (login == null || !login.isLogin) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.rss),
          title: Text(t.vod.dynamicsLoginTitle),
          description: Text(t.vod.dynamicsLoginDescription),
          actions: [
            DsButton(
              variant: DsButtonVariant.primary,
              onPressed: () => unawaited(showBilibiliWebLoginPage(context)),
              child: Text(t.vod.signIn),
            ),
          ],
        ),
      );
    }
    final state = ref.watch(vodDynamicsProvider);
    final controller = ref.read(vodDynamicsProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(controller.open());
    });
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.rss),
          title: Text(t.vod.dynamicsFailed),
          description: Text(state.error!.message),
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
    if (state.loading && state.items.isEmpty) {
      return const Center(child: DsSpinner());
    }
    if (state.items.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.rss),
          title: Text(t.vod.dynamicsEmptyTitle),
          description: Text(t.vod.dynamicsEmptyDescription),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      itemCount: state.items.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: DsSpace.s4),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          if (!state.hasMore) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s12),
            child: Center(
              child: state.loading
                  ? const DsSpinner()
                  : DsButton(
                      variant: DsButtonVariant.secondary,
                      onPressed: () => unawaited(controller.loadMore()),
                      child: Text(t.vod.loadMore),
                    ),
            ),
          );
        }
        final post = state.items[index];
        return VodDynamicRow(post: post, onOpen: post.bvid == null ? null : () => _openPost(context, post));
      },
    );
  }
}
