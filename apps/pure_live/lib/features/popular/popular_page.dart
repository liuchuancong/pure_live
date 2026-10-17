import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LiveDiscoveryProvider, LivePageRequest, LiveRoom, LiveSite;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Popular: every discovery-capable platform as a tab over its recommend
/// feed.
///
/// The tabs come from the sites themselves — a platform without the
/// discovery capability simply has no tab, per the capability contract.
final class PopularPage extends ConsumerStatefulWidget {
  /// The popular page.
  const new({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

final class _PopularPageState extends ConsumerState<PopularPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final discoverable = sites.registry.all.where((site) => site.capability<LiveDiscoveryProvider>() != null).toList();
    if (discoverable.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(title: context.t.tabs.popular, actions: const [SettingsEntryButton()]),
        body: PureEmpty(title: context.t.common.empty),
      );
    }
    final index = _selected.clamp(0, discoverable.length - 1);
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.tabs.popular,
        actions: const [SettingsEntryButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PureTabs(
              index: index,
              onChanged: (value) => setState(() => _selected = value),
              tabs: [
                for (final site in discoverable)
                  PureTab(label: site.manifest.localizedName(_tag(context, site), 'zh-CN')),
              ],
            ),
          ),
        ),
      ),
      body: PureTabView(
        index: index,
        onIndexChanged: (value) => setState(() => _selected = value),
        pages: [for (final site in discoverable) _SiteFeed(site: site)],
      ),
    );
  }

  static String _tag(BuildContext context, LiveSite site) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');
}

/// One platform's recommend feed: an infinite grid over the discovery
/// capability, kept alive across tab switches.
final class _SiteFeed extends StatefulWidget {
  /// A feed for [site].
  const new({required this.site});

  final LiveSite site;

  @override
  State<_SiteFeed> createState() => _SiteFeedState();
}

final class _SiteFeedState extends State<_SiteFeed> with AutomaticKeepAliveClientMixin {
  late final InfiniteController<LiveRoom> _controller = InfiniteController(loader: _load);
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onState(InfiniteState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) {
      unawaited(_controller.loadNext());
    }
  }

  Future<PageResult<LiveRoom>> _load(PageRequest request) {
    final capability = widget.site.capability<LiveDiscoveryProvider>();
    if (capability == null) {
      throw StateError('${widget.site.manifest.id} lost its discovery capability');
    }
    // The loader contract: errors throw, the controller keeps the shown
    // data and exposes the failure on its state.
    return capability
        .getRecommendedRooms(
          request: LivePageRequest(page: request.page, pageSize: request.pageSize),
        )
        .then(
          (result) => result.fold(
            (error) => throw _FeedException(error),
            (page) => PageResult(items: page.items, totalCount: page.totalCount, hasMore: page.hasMore),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = _controller.state;
    if (state.items.isEmpty) {
      if (state.error != null) {
        return PureError(
          message: context.t.errors.network,
          onRetry: _controller.retry,
          retryLabel: context.t.common.retry,
        );
      }
      if (state.isRefreshing || state.isUnloaded) {
        return const _SkeletonFeed();
      }
      return PureEmpty(
        title: context.t.popular.empty,
        icon: Icons.local_fire_department_outlined,
        action: PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _controller.retry),
      );
    }
    return CustomRefreshIndicator(
      onRefresh: _controller.refresh,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            child: Opacity(
              opacity: indicator.value.clamp(0, 1),
              child: IgnorePointer(child: PureProgress(value: indicator.isLoading ? null : indicator.value, height: 4)),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.sm, PureSpacing.sm, PureSpacing.xl),
          gridDelegate: RoomGridMetrics.delegateFor(context, constraints.maxWidth),
          itemCount: state.items.length + 1,
          itemBuilder: (context, index) {
            if (index < state.items.length) {
              final room = state.items[index];
              return RoomCard(
                room: room,
                onOpen: () => RoomRoute(
                  siteId: room.ref.platform,
                  roomId: room.ref.roomId,
                  roomName: room.content.title,
                ).push<void>(context),
              );
            }
            return state.isLoadingMore ? const Center(child: PureSpinner()) : const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

/// The first-load placeholder: a bone grid shaped exactly like the room
/// grid, so content replaces the skeleton without a layout jump.
final class _SkeletonFeed extends StatelessWidget {
  /// The skeleton feed.
  const new();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Fixed-height bars rather than placeholder letters: a skeleton
      // has to fit its tile in every design language and text scale,
      // and a `Text('XXXX')` is measured by whichever of those is
      // active — under a larger one it pushed this column past the
      // tile and the grid reported an overflow on every card.
      return Skeletonizer(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PureSpacing.sm),
          gridDelegate: RoomGridMetrics.delegateFor(context, width),
          itemCount: RoomGridMetrics.columnsFor(width) * 3,
          itemBuilder: (context, index) => PureCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 12, width: double.infinity, child: ColoredBox(color: Colors.white24)),
                            SizedBox(height: 6),
                            SizedBox(width: 96, height: 10, child: ColoredBox(color: Color(0x26FFFFFF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Wraps a site error for the loader contract; the controller stores it on
/// its state and the view renders the generic network copy over it.
final class _FeedException implements Exception {
  const new(this.cause);

  /// The site error behind the failure.
  final Object cause;

  @override
  String toString() => 'feed failed: $cause';
}
