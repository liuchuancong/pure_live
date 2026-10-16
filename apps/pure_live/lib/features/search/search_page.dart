import 'dart:async' show unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Search: every search-capable platform as a tab over its results, across
/// the targets the site answers — rooms, anchors and areas.
final class SearchPage extends ConsumerStatefulWidget {
  /// The search page.
  const new({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final searchable = sites.registry.all.where((site) => site.capability<LiveSearchProvider>() != null).toList();
    if (searchable.isEmpty) {
      return LiveScaffold(
        appBar: LiveAppBar(title: context.t.tabs.search, actions: const [SettingsEntryButton()]),
        body: LiveEmpty(title: context.t.common.empty),
      );
    }
    final index = _selected.clamp(0, searchable.length - 1);
    return LiveScaffold(
      appBar: LiveAppBar(
        title: context.t.tabs.search,
        actions: const [SettingsEntryButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LiveTabs(
              index: index,
              onChanged: (value) => setState(() => _selected = value),
              tabs: [
                for (final site in searchable) LiveTab(label: site.manifest.localizedName(_tag(context), 'zh-CN')),
              ],
            ),
          ),
        ),
      ),
      body: LiveTabView(
        index: index,
        onIndexChanged: (value) => setState(() => _selected = value),
        pages: [for (final site in searchable) _SiteSearch(key: ValueKey(site.manifest.id), site: site)],
      ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One platform's search: a keyword bar over an infinite result grid. The
/// query is per tab — switching platform keeps what was typed there.
final class _SiteSearch extends StatefulWidget {
  /// A search pane for [site].
  const new({required this.site, super.key});

  final LiveSite site;

  @override
  State<_SiteSearch> createState() => _SiteSearchState();
}

final class _SiteSearchState extends State<_SiteSearch> with AutomaticKeepAliveClientMixin {
  final _keyword = TextEditingController();
  InfiniteController<LiveSearchResult>? _controller;
  ScrollController? _scroll;
  String _query = '';
  LiveSearchTarget _target = LiveSearchTarget.rooms;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _keyword.dispose();
    _controller?.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  /// Starts a search for the bar's text against the chosen target; a blank
  /// query clears the results. Switching target re-runs the query — the
  /// modes answer different questions.
  void _submit({LiveSearchTarget? target}) {
    final query = _keyword.text.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _target = target ?? _target;
        _controller?.dispose();
        _controller = null;
        _scroll?.dispose();
        _scroll = null;
      });
      return;
    }
    setState(() {
      _query = query;
      _target = target ?? _target;
      _controller?.dispose();
      _controller = InfiniteController(loader: _load)..addListener(_onState);
      _scroll = ScrollController()..addListener(_onScroll);
      unawaited(_controller!.initialize());
    });
  }

  void _onState(InfiniteState<LiveSearchResult> state) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    final scroll = _scroll;
    if (scroll != null && scroll.position.extentAfter < 600) {
      unawaited(_controller?.loadNext());
    }
  }

  Future<PageResult<LiveSearchResult>> _load(PageRequest request) {
    final capability = widget.site.capability<LiveSearchProvider>();
    if (capability == null) {
      throw StateError('${widget.site.manifest.id} lost its search capability');
    }
    final search = LiveSearchRequest(query: _query, target: _target, page: request.page, pageSize: request.pageSize);
    // Errors throw; the controller keeps the shown data and exposes the
    // failure on its state.
    return capability
        .search(search)
        .then(
          (result) => result.fold(
            (error) => throw _SearchException(error),
            (page) => PageResult(items: page.items, totalCount: page.totalCount, hasMore: page.hasMore),
          ),
        );
  }

  static int _columns(BuildContext context) => switch (BreakpointsQualifier().qualify(context)) {
    ScreenSize.small => 2,
    ScreenSize.medium => 3,
    ScreenSize.large => 4,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SearchBar(
            controller: _keyword,
            hintText: context.t.search.hint,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            trailing: [IconButton(icon: const Icon(Icons.search), onPressed: _submit)],
          ),
        ),
        if (controller != null) _modeRow(context)!,
        Expanded(child: controller == null ? _idle(context) : _results(context, controller)),
      ],
    );
  }

  /// The target switch, only where the site searches anchors — a request
  /// for a target the site does not answer must fail, not silently narrow.
  Widget? _modeRow(BuildContext context) {
    final capability = widget.site.capability<LiveSearchProvider>();
    final targets = capability?.supportedTargets ?? const <LiveSearchTarget>{};
    if (!targets.contains(LiveSearchTarget.anchors)) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: LiveSegmented(
        labels: [context.t.search.rooms, context.t.search.anchors],
        index: _target == LiveSearchTarget.rooms ? 0 : 1,
        onChanged: (index) => _submit(target: index == 0 ? LiveSearchTarget.rooms : LiveSearchTarget.anchors),
      ),
    );
  }

  Widget _idle(BuildContext context) => LiveEmpty(title: context.t.search.hint);

  Widget _results(BuildContext context, InfiniteController<LiveSearchResult> controller) {
    final state = controller.state;
    if (state.items.isEmpty) {
      if (state.error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t.errors.network, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: controller.retry),
            ],
          ),
        );
      }
      if (state.isRefreshing || state.isUnloaded) {
        return Skeletonizer(
          child: GridView.count(
            crossAxisCount: _columns(context),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < _columns(context) * 3; i++)
                LiveCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(color: Colors.white24),
                      ),
                      // Fixed-height bars rather than placeholder letters, so
                      // the skeleton fits its tile in every language and text
                      // scale (see popular_page's skeleton for why).
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 12, child: ColoredBox(color: Color(0x33FFFFFF))),
                            SizedBox(height: 6),
                            SizedBox(width: 96, height: 8, child: ColoredBox(color: Color(0x26FFFFFF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }
      return LiveEmpty(title: context.t.errors.notFound);
    }
    return CustomRefreshIndicator(
      onRefresh: controller.refresh,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            child: Opacity(
              opacity: indicator.value.clamp(0, 1),
              child: IgnorePointer(
                child: CircularProgressIndicator(value: indicator.isLoading ? null : indicator.value),
              ),
            ),
          ),
        ],
      ),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns(context),
          childAspectRatio: 0.82,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            return switch (state.items[index]) {
              RoomSearchResult(:final room) => RoomCard(
                room: room,
                onOpen: () => RoomRoute(
                  siteId: room.ref.platform,
                  roomId: room.ref.roomId,
                  roomName: room.content.title,
                ).push<void>(context),
              ),
              AnchorSearchResult(:final anchor) => AnchorTile(anchor: anchor),
              AreaSearchResult(:final area) => AreaCard(
                area: area,
                onOpen: () => AreaRoomsRoute(
                  siteId: area.platform,
                  areaId: area.areaId,
                  areaName: area.areaName,
                ).push<void>(context),
              ),
            };
          }
          return state.isLoadingMore ? const Center(child: LiveSpinner()) : const SizedBox.shrink();
        },
      ),
    );
  }
}

/// One found anchor: avatar and name — the room page wave gives the tile
/// somewhere to go.
final class AnchorTile extends StatelessWidget {
  /// Shows [anchor].
  const new({required this.anchor, super.key});

  /// The anchor the search answered with.
  final LiveAnchor anchor;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: anchor.avatarUrl == null || anchor.avatarUrl!.isEmpty
              ? null
              : CachedNetworkImageProvider(anchor.avatarUrl!),
          child: anchor.avatarUrl == null || anchor.avatarUrl!.isEmpty ? const Icon(Icons.person_outlined) : null,
        ),
        const SizedBox(height: 8),
        Text(anchor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

/// Wraps a site error for the loader contract; the controller stores it on
/// its state and the view renders the generic network copy over it.
final class _SearchException implements Exception {
  const new(this.cause);

  /// The site error behind the failure.
  final Object cause;

  @override
  String toString() => 'search failed: $cause';
}
