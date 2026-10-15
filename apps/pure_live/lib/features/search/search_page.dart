import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart'
    show LiveRoom, LiveSearchProvider, LiveSearchRequest, LiveSearchTarget, LiveSite, RoomSearchResult;
import 'package:live_uikit/styling.dart' show LiveButton, LiveEmpty;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Search: every search-capable platform as a tab over its room results
/// (3.x `SearchPage`; the cross-site fan-out with ranking is the next
/// slice of the reference's search engine).
final class SearchPage extends ConsumerWidget {
  /// The search page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final searchable = sites.registry.all.where((site) => site.capability<LiveSearchProvider>() != null).toList();
    if (searchable.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t.tabs.search), actions: const [SettingsEntryButton()]),
        body: LiveEmpty(title: context.t.common.empty),
      );
    }
    return DefaultTabController(
      length: searchable.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t.tabs.search),
          actions: const [SettingsEntryButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final site in searchable) Tab(text: site.manifest.localizedName(_tag(context), 'zh-CN'))],
          ),
        ),
        body: TabBarView(
          children: [for (final site in searchable) _SiteSearch(key: ValueKey(site.manifest.id), site: site)],
        ),
      ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One platform's search: a keyword bar over an infinite room grid. The
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
  InfiniteController<LiveRoom>? _controller;
  ScrollController? _scroll;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _keyword.dispose();
    _controller?.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  /// Starts a search for the bar's text; a blank query clears the results.
  void _submit() {
    final query = _keyword.text.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _controller?.dispose();
        _controller = null;
        _scroll?.dispose();
        _scroll = null;
      });
      return;
    }
    setState(() {
      _query = query;
      _controller?.dispose();
      _controller = InfiniteController(loader: _load)..addListener(_onState);
      _scroll = ScrollController()..addListener(_onScroll);
      unawaited(_controller!.initialize());
    });
  }

  void _onState(InfiniteState<LiveRoom> state) {
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

  Future<PageResult<LiveRoom>> _load(PageRequest request) async {
    final capability = widget.site.capability<LiveSearchProvider>();
    if (capability == null) {
      throw StateError('${widget.site.manifest.id} lost its search capability');
    }
    final result = await capability.search(
      LiveSearchRequest(query: _query, target: LiveSearchTarget.rooms, page: request.page, pageSize: request.pageSize),
    );
    // Rooms only this slice; anchors arrive with the anchor list wave.
    final page = result.fold((error) => throw _SearchException(error), (page) => page);
    return PageResult(
      items: [
        for (final entry in page.items)
          if (entry is RoomSearchResult) entry.room,
      ],
      totalCount: page.totalCount,
      hasMore: page.hasMore,
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
        Expanded(child: controller == null ? _idle(context) : _results(context, controller)),
      ],
    );
  }

  Widget _idle(BuildContext context) => LiveEmpty(title: context.t.search.hint);

  Widget _results(BuildContext context, InfiniteController<LiveRoom> controller) {
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
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(color: Colors.white24),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Text('XXXXXXXXXXXXXXXX'), SizedBox(height: 4), Text('XXXX')],
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
final class _SearchException implements Exception {
  const new(this.cause);

  /// The site error behind the failure.
  final Object cause;

  @override
  String toString() => 'search failed: $cause';
}
