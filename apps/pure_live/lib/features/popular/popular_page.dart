import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LiveDiscoveryProvider, LivePageRequest, LiveRoom, LiveSite;
import 'package:live_uikit/styling.dart' show LiveButton, LiveEmpty;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/shell/app_shell.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// Popular: every discovery-capable platform as a tab over its recommend
/// feed.
///
/// The tabs come from the sites themselves — a platform without the
/// discovery capability simply has no tab, per the capability contract.
final class PopularPage extends ConsumerWidget {
  /// The popular page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final discoverable = sites.registry.all.where((site) => site.capability<LiveDiscoveryProvider>() != null).toList();
    if (discoverable.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t.tabs.popular), actions: const [SettingsEntryButton()]),
        body: LiveEmpty(title: context.t.common.empty),
      );
    }
    return DefaultTabController(
      length: discoverable.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t.tabs.popular),
          actions: const [SettingsEntryButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final site in discoverable) Tab(text: _displayName(site, context))],
          ),
        ),
        body: TabBarView(children: [for (final site in discoverable) _SiteFeed(site: site)]),
      ),
    );
  }

  static String _displayName(LiveSite site, BuildContext context) =>
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t.errors.network, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _controller.retry),
            ],
          ),
        );
      }
      if (state.isRefreshing || state.isUnloaded) {
        return const Center(child: CircularProgressIndicator());
      }
      return LiveEmpty(title: context.t.common.empty);
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          childAspectRatio: 0.82,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            return RoomCard(room: state.items[index]);
          }
          return state.isLoadingMore ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
        },
      ),
    );
  }
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
