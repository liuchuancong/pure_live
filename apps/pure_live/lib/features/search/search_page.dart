import 'dart:async' show Timer, unawaited;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_helper_utils/flutter_helper_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/app/preferences/app_preferences.dart' show AppPreferences;
import 'package:pure_live/app/preferences/app_preferences_providers.dart' show appPreferencesProvider;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/features/hot_areas/hot_areas_page.dart' show HotAreasPage;
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/features/search/search_providers.dart';
import 'package:pure_live/features/search/web_search_url.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart' show RoomBoneTile;
import 'package:pure_live/shared/widgets/room_grid.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// How long typing waits for company before the search runs (the debounce
/// that makes typing itself a query trigger; submitting always runs at once).
const Duration _searchDebounce = Duration(milliseconds: 500);

/// From this width the field and the platform strip share the app bar line
/// (the reference's `searchOneRowWidth`, A09.7 c12).
const double searchOneRowWidth = 600;

/// The widest the search field gets on that shared line (the reference's
/// `searchFieldMaxWidth`).
const double searchFieldMaxWidth = 480;

/// Search across every search-capable platform (3.x `SearchPage`): one
/// keyword bar over a scope strip — every site at once, or one site — with
/// the recent searches persisted locally and shown while the bar is empty.
///
/// The query is page-level: committing it (submit, the search action, or the
/// debounce after typing) re-runs the current scope; a per-site request asks
/// only for a target that site answers, per the capability contract.
final class SearchPage extends ConsumerStatefulWidget {
  /// The search page.
  const new({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _keyword = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _selected = 0;
  LiveSearchTarget _target = LiveSearchTarget.rooms;

  /// The tabs already opened; a pane searches the shared query the first
  /// time it is shown, so typing runs one scope, not every tab at once.
  final Set<int> _visited = {0};

  @override
  void dispose() {
    _debounce?.cancel();
    _keyword.dispose();
    super.dispose();
  }

  /// The platforms the search asks. The platform-display setting is the same
  /// one the popular and areas tabs honour — a hidden platform answers no
  /// query, and the stored order is the tab order — so the settings page's
  /// promise holds here too. [preferences] comes from the caller: the tabs
  /// watch it, a tap reads it.
  List<LiveSite> _searchable(AppSites sites, AppPreferences preferences) =>
      HotAreasPage.orderedSites(sites.registry.all, preferences.siteOrder)
          .where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id))
          .where((site) => site.capability<LiveSearchProvider>() != null)
          .toList();

  /// The targets the current scope answers; a request for any other must
  /// fail, so the picker only ever offers these.
  Set<LiveSearchTarget> _targetsFor(List<LiveSite> searchable) {
    if (_selected == 0) {
      return {for (final site in searchable) ...?site.capability<LiveSearchProvider>()?.supportedTargets};
    }
    final index = (_selected - 1).clamp(0, searchable.length - 1);
    return searchable[index].capability<LiveSearchProvider>()?.supportedTargets ?? const {};
  }

  /// The committed query, debounced off the bar's changes; a blank bar shows
  /// the recent searches again instead of a stale result list.
  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      if (_query.isNotEmpty) {
        setState(() => _query = '');
      }
      return;
    }
    _debounce = Timer(_searchDebounce, () {
      if (mounted) {
        unawaited(_commit(query));
      }
    });
  }

  /// Runs the search now: the submit action and the bar's search button.
  void _searchNow() {
    _debounce?.cancel();
    unawaited(_commit(_keyword.text.trim()));
  }

  /// The chosen platform's web search (3.x `openWebSearch`, A09.8): the
  /// search page keeps the "all sites" tab for API scopes only — a web
  /// search is one platform's page. On a build without an in-app WebView
  /// the route itself answers with the system browser.
  Future<void> _openWebSearch([LiveSite? site]) async {
    final t = context.t;
    final searchable = _searchable(ref.read(sitesProvider), ref.read(appPreferencesProvider));
    final target = site ?? (searchable.isEmpty || _selected == 0 ? null : searchable[_selected - 1]);
    if (target == null) {
      PureToast.show(context, t.search.selectPlatformFirst);
      return;
    }
    final text = _keyword.text.trim();
    if (text.isEmpty) {
      PureToast.show(context, t.search.needKeyword);
      return;
    }
    final uri = webSearchUrl(target.manifest.id, text);
    if (uri == null) {
      PureToast.show(
        context,
        t.search.webUnavailableFor(
          site: target.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN'),
        ),
      );
      return;
    }
    await WebSearchRoute(url: uri.toString(), platform: target.manifest.id, keyword: text).push<void>(context);
  }

  Future<void> _commit(String query) async {
    context.unfocus();
    if (query.isEmpty) {
      if (_query.isNotEmpty) {
        setState(() => _query = '');
      }
      return;
    }
    setState(() => _query = query);
    await ref.read(searchHistoryProvider.notifier).add(query);
  }

  void _useHistoryEntry(String query) {
    _keyword.text = query;
    unawaited(_commit(query));
  }

  /// The targets picker's labels, in enum order.
  List<String> _targetLabels(Set<LiveSearchTarget> targets) => [
    for (final target in LiveSearchTarget.values)
      if (targets.contains(target))
        switch (target) {
          LiveSearchTarget.rooms => context.t.search.rooms,
          LiveSearchTarget.anchors => context.t.search.anchors,
          LiveSearchTarget.areas => context.t.search.areas,
        },
  ];

  @override
  Widget build(BuildContext context) {
    final searchable = _searchable(ref.watch(sitesProvider), ref.watch(appPreferencesProvider));
    if (searchable.isEmpty) {
      return PureScaffold(
        appBar: PureAppBar(title: context.t.tabs.search, actions: const [SettingsEntryButton()]),
        body: PureEmpty(title: context.t.common.empty),
      );
    }
    _selected = _selected.clamp(0, searchable.length);
    // A scope that does not answer the picked target falls back to rooms —
    // the picker never offers a target the scope would have to reject.
    final targets = _targetsFor(searchable);
    if (!targets.contains(_target)) {
      _target = LiveSearchTarget.rooms;
    }
    final orderedTargets = LiveSearchTarget.values.where(targets.contains).toList();
    final query = _query;
    // The reference's split (A09.7 c12/c13): from 600 the field and the
    // platform strip share the app bar's title line; below it the field owns
    // the bar and the strip rides at the head of the body.
    final oneRow = MediaQuery.sizeOf(context).width >= searchOneRowWidth;
    final field = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: searchFieldMaxWidth),
      child: SearchBar(
        controller: _keyword,
        hintText: context.t.search.hint,
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: (_) => _searchNow(),
        trailing: [PureIconButton(icon: Icons.search, tooltip: context.t.tabs.search, onPressed: _searchNow)],
      ),
    );
    // The platform count is dynamic, so the strip scrolls: PureTabs owns that
    // for every language rather than the page wrapping it in its own scroll
    // view — an outer scroll view handed the strip an unbounded width, and the
    // forui and wind renderers throw there.
    final strip = PureTabs(
      index: _selected,
      isScrollable: true,
      onChanged: (value) => setState(() {
        _selected = value;
        _visited.add(value);
      }),
      tabs: [
        PureTab(label: context.t.search.allSites),
        for (final site in searchable) PureTab(label: site.manifest.localizedName(_tag(context), 'zh-CN')),
      ],
    );
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.tabs.search,
        titleWidget: oneRow
            ? Row(
                children: [
                  Flexible(child: field),
                  const SizedBox(width: 4),
                  Expanded(child: strip),
                ],
              )
            : field,
        actions: [
          // A09.8: the chosen platform's web search, next to the settings
          // entry the shell always carries.
          PureIconButton(
            key: const ValueKey('search-web-entry'),
            tooltip: context.t.search.webSearchTooltip,
            icon: Icons.language,
            onPressed: () => unawaited(_openWebSearch()),
          ),
          const SettingsEntryButton(),
        ],
      ),
      body: Column(
        children: [
          if (!oneRow)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(alignment: AlignmentDirectional.centerStart, child: strip),
            ),
          if (query.isNotEmpty && orderedTargets.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: PureSegmented(
                labels: _targetLabels(targets),
                index: orderedTargets.indexOf(_target),
                onChanged: (index) => setState(() => _target = orderedTargets[index]),
              ),
            ),
          Expanded(
            child: query.isEmpty
                ? _SearchHistoryPanel(onSelect: _useHistoryEntry)
                : PureTabView(
                    index: _selected,
                    onIndexChanged: (value) => setState(() {
                      _selected = value;
                      _visited.add(value);
                    }),
                    pages: [
                      _AllSitesPane(
                        key: ValueKey('all|$query|$_target'),
                        sites: searchable,
                        query: query,
                        target: _target,
                        activated: _visited.contains(0),
                      ),
                      for (var i = 0; i < searchable.length; i++)
                        _SitePane(
                          key: ValueKey('${searchable[i].manifest.id}|$query|$_target'),
                          site: searchable[i],
                          query: query,
                          target: _target,
                          activated: _visited.contains(i + 1),
                          // The escape hatch appears only where a web page
                          // for these words exists (A09.8 继续网页搜索).
                          onContinueWebSearch: webSearchUrl(searchable[i].manifest.id, query) == null
                              ? null
                              : () => unawaited(_openWebSearch(searchable[i])),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// The bar's idle state: the recent searches, each one tappable and
/// individually removable, the whole list clearable.
final class _SearchHistoryPanel extends ConsumerWidget {
  const new({required this.onSelect});

  /// Runs the tapped query.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) {
      return PureEmpty(title: context.t.search.hint, icon: Icons.travel_explore_outlined);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t.search.historyTitle,
                  style: PureTheme.of(context).text.bodySmall
                      .copyWith(color: PureTheme.of(context).colors.textSecondary),
                ),
              ),
              PureButton(
                label: context.t.common.clear,
                variant: ButtonVariant.ghost,
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              return PureListRow(
                leading: const Icon(Icons.history),
                title: entry,
                trailing: PureIconButton(
                  tooltip: context.t.search.historyRemove,
                  icon: Icons.close,
                  onPressed: () => ref.read(searchHistoryProvider.notifier).remove(entry),
                ),
                divided: false,
                onTap: () => onSelect(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One platform's search: an infinite result grid over its search
/// capability. The pane runs only once shown ([activated]), and re-runs
/// whenever the shared query or target changes.
final class _SitePane extends StatefulWidget {
  const new({
    required this.site,
    required this.query,
    required this.target,
    required this.activated,
    this.onContinueWebSearch,
    super.key,
  });

  final LiveSite site;
  final String query;
  final LiveSearchTarget target;
  final bool activated;

  /// The A09.8 escape hatch under the empty state: the same words in this
  /// platform's web search. Null when the platform has no web page for it.
  final VoidCallback? onContinueWebSearch;

  @override
  State<_SitePane> createState() => _SitePaneState();
}

final class _SitePaneState extends State<_SitePane> with AutomaticKeepAliveClientMixin {
  InfiniteController<LiveSearchResult>? _controller;
  ScrollController? _scroll;
  ({String query, LiveSearchTarget target})? _ran;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.activated && widget.query.isNotEmpty) {
      _run();
    }
  }

  @override
  void didUpdateWidget(covariant _SitePane old) {
    super.didUpdateWidget(old);
    if (widget.activated && widget.query.isNotEmpty && _ran != (query: widget.query, target: widget.target)) {
      _run();
      return;
    }
    if (widget.query.isEmpty) {
      _teardown();
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _controller
      ?..removeListener(_onState)
      ..dispose();
    _controller = null;
    _scroll?.dispose();
    _scroll = null;
    _ran = null;
  }

  void _run() {
    _teardown();
    _ran = (query: widget.query, target: widget.target);
    final controller = InfiniteController<LiveSearchResult>(loader: _load)..addListener(_onState);
    _controller = controller;
    _scroll = ScrollController()..addListener(_onScroll);
    unawaited(controller.initialize());
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

  Future<PageResult<LiveSearchResult>> _load(PageRequest request) => searchPage(
    site: widget.site,
    query: widget.query,
    target: widget.target,
    page: request.page,
    pageSize: request.pageSize,
  );

  /// The empty state with the A09.8 escape hatch underneath: the same
  /// words in this platform's web page, where one exists.
  Widget _emptyWithWebSearch(BuildContext context, String title) {
    if (widget.onContinueWebSearch == null) {
      return PureEmpty(title: title, icon: Icons.search_off_outlined);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PureEmpty(title: title, icon: Icons.search_off_outlined),
        const SizedBox(height: 8),
        PureButton(
          key: const ValueKey('search-continue-web'),
          label: context.t.search.continueWeb,
          icon: Icons.language,
          variant: ButtonVariant.secondary,
          onPressed: widget.onContinueWebSearch,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    if (controller == null) {
      return PureEmpty(title: context.t.search.hint, icon: Icons.travel_explore_outlined);
    }
    final state = controller.state;
    if (state.items.isEmpty) {
      if (state.error != null) {
        return PureError(
          message: context.t.errors.network,
          onRetry: controller.retry,
          retryLabel: context.t.common.retry,
        );
      }
      if (state.isRefreshing || state.isUnloaded) {
        return const _SkeletonGrid();
      }
      return _emptyWithWebSearch(context, context.t.errors.notFound);
    }
    return CustomRefreshIndicator(
      onRefresh: controller.refresh,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            // The bar needs bounded constraints: a Positioned pinned on `top`
            // alone hands its child unbounded constraints, which a progress bar
            // cannot resolve to a size — a kept-alive off-screen tab then
            // crashes the hit test. Pinning the sides and fixing the width
            // keeps the box laid out in every state.
            child: Center(
              child: SizedBox(
                width: 140,
                child: Opacity(
                  opacity: indicator.value.clamp(0, 1),
                  child: IgnorePointer(
                    child: PureProgress(value: indicator.isLoading ? null : indicator.value, height: 4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: RoomGrid(
        scrollController: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.xs, PureSpacing.sm, PureSpacing.xl),
        itemCount: state.items.length,
        itemBuilder: (context, index) => SearchResultTile(result: state.items[index]),
        footer: state.isLoadingMore ? const Center(child: PureSpinner()) : null,
      ),
    );
  }
}

/// The "all sites" scope: every site that answers the picked target gets its
/// own section under one scroll, each filling in as its answers arrive — the
/// whole grid never waits behind the slowest site.
final class _AllSitesPane extends StatefulWidget {
  const new({required this.sites, required this.query, required this.target, required this.activated, super.key});

  final List<LiveSite> sites;
  final String query;
  final LiveSearchTarget target;
  final bool activated;

  @override
  State<_AllSitesPane> createState() => _AllSitesPaneState();
}

final class _AllSitesPaneState extends State<_AllSitesPane> with AutomaticKeepAliveClientMixin {
  final Map<String, InfiniteController<LiveSearchResult>> _sections = {};
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);
  ({String query, LiveSearchTarget target})? _ran;

  @override
  bool get wantKeepAlive => true;

  // Every section still filling in loads its next page near the bottom;
  // loadNext is a no-op for the ones that are busy or done.
  void _onScroll() {
    if (_scroll.position.extentAfter < 800) {
      for (final controller in _sections.values) {
        unawaited(controller.loadNext());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.activated && widget.query.isNotEmpty) {
      _run();
    }
  }

  @override
  void didUpdateWidget(covariant _AllSitesPane old) {
    super.didUpdateWidget(old);
    if (widget.activated && widget.query.isNotEmpty && _ran != (query: widget.query, target: widget.target)) {
      _run();
      return;
    }
    if (widget.query.isEmpty) {
      _teardown();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _teardown();
    super.dispose();
  }

  void _teardown() {
    for (final controller in _sections.values) {
      controller
        ..removeListener(_onSectionState)
        ..dispose();
    }
    _sections.clear();
    _ran = null;
  }

  void _run() {
    _teardown();
    _ran = (query: widget.query, target: widget.target);
    for (final site in widget.sites) {
      final capability = site.capability<LiveSearchProvider>();
      if (capability == null || !capability.supportedTargets.contains(widget.target)) {
        continue;
      }
      final controller = InfiniteController<LiveSearchResult>(
        loader: (request) => searchPage(
          site: site,
          query: widget.query,
          target: widget.target,
          page: request.page,
          pageSize: request.pageSize,
        ),
      )..addListener(_onSectionState);
      _sections[site.manifest.id] = controller;
      unawaited(controller.initialize());
    }
  }

  void _onSectionState(InfiniteState<LiveSearchResult> state) {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([for (final controller in _sections.values) controller.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_sections.isEmpty) {
      return PureEmpty(title: context.t.errors.unsupported, icon: Icons.search_off_outlined);
    }
    final anyLoading = _sections.values.any((controller) => controller.state.isRefreshing);
    final totalItems = _sections.values.fold(0, (sum, controller) => sum + controller.state.items.length);
    final anyError = _sections.values.any((controller) => controller.state.error != null);
    if (totalItems == 0 && !anyLoading) {
      if (anyError && _sections.values.every((controller) => controller.state.items.isEmpty)) {
        return PureError(message: context.t.errors.network, onRetry: _refreshAll, retryLabel: context.t.common.retry);
      }
      if (_sections.values.every((controller) => !controller.state.isRefreshing && !controller.state.isUnloaded)) {
        return PureEmpty(title: context.t.errors.notFound, icon: Icons.search_off_outlined);
      }
    }
    return CustomRefreshIndicator(
      onRefresh: _refreshAll,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            // The bar needs bounded constraints: a Positioned pinned on `top`
            // alone hands its child unbounded constraints, which a progress bar
            // cannot resolve to a size — a kept-alive off-screen tab then
            // crashes the hit test. Pinning the sides and fixing the width
            // keeps the box laid out in every state.
            child: Center(
              child: SizedBox(
                width: 140,
                child: Opacity(
                  opacity: indicator.value.clamp(0, 1),
                  child: IgnorePointer(
                    child: PureProgress(value: indicator.isLoading ? null : indicator.value, height: 4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.xs, PureSpacing.sm, PureSpacing.xl),
        children: [for (final entry in _sections.entries) _section(context, entry.key, entry.value)],
      ),
    );
  }

  Widget _section(BuildContext context, String siteId, InfiniteController<LiveSearchResult> controller) {
    final site = widget.sites.firstWhere((candidate) => candidate.manifest.id == siteId);
    final name = site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');
    final state = controller.state;
    // A section that answered nothing stays quiet — the pane's overall empty
    // state speaks for it once every section has answered. A failed one keeps
    // only its header with the retry where the spinner would sit.
    if (state.items.isEmpty && !state.isRefreshing && !state.isUnloaded && state.error == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, PureSpacing.sm, 4, PureSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(name, style: PureTheme.of(context).text.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (state.isRefreshing || state.isUnloaded)
                const Padding(padding: EdgeInsets.all(PureSpacing.sm), child: PureSpinner(size: 16))
              else if (state.error != null && state.items.isEmpty)
                PureButton(
                  label: context.t.common.retry,
                  variant: ButtonVariant.ghost,
                  icon: Icons.refresh,
                  onPressed: controller.retry,
                ),
            ],
          ),
        ),
        if (state.items.isEmpty)
          if (state.isRefreshing || state.isUnloaded)
            const _SkeletonGrid(compact: true)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.t.errors.network,
                style: PureTheme.of(context).text.bodySmall.copyWith(color: PureTheme.of(context).colors.textSecondary),
              ),
            )
        else
          RoomGrid(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: state.items.length,
            itemBuilder: (context, index) => SearchResultTile(result: state.items[index]),
          ),
      ],
    );
  }
}

/// One typed search hit, drawn with the shared room card — anchors keep
/// their avatar tile and areas open their room list.
final class SearchResultTile extends StatelessWidget {
  /// Renders [result].
  const new({required this.result, super.key});

  /// The search hit this tile shows.
  final LiveSearchResult result;

  @override
  Widget build(BuildContext context) => switch (result) {
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
      onOpen: () =>
          AreaRoomsRoute(siteId: area.platform, areaId: area.areaId, areaName: area.areaName).push<void>(context),
    ),
  };
}

/// One found anchor: avatar and name — the room page wave gives the tile
/// somewhere to go.
final class AnchorTile extends StatelessWidget {
  /// Shows [anchor].
  const new({required this.anchor, super.key});

  /// The anchor the search answered with.
  final LiveAnchor anchor;

  @override
  Widget build(BuildContext context) => PureCard(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PureAvatar(
          name: anchor.name,
          size: 60,
          src: anchor.avatarUrl == null || anchor.avatarUrl!.isEmpty
              ? null
              : CachedNetworkImageProvider(anchor.avatarUrl!),
        ),
        const SizedBox(height: 8),
        Text(anchor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PureTheme.of(context).text.body),
      ],
    ),
  );
}

/// The first-load placeholder: a bone grid shaped exactly like the result
/// grid, so content replaces the skeleton without a layout jump. [compact]
/// trims it to one row for the all-sites pane's sections.
final class _SkeletonGrid extends StatelessWidget {
  const new({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = RoomGridMetrics.columnsFor(constraints.maxWidth);
      return Skeletonizer(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PureSpacing.sm),
          gridDelegate: RoomGridMetrics.delegateFor(context, constraints.maxWidth),
          itemCount: compact ? columns : columns * 3,
          itemBuilder: (context, index) => const RoomBoneTile(),
        ),
      );
    },
  );
}

/// Runs one search page against [site]; errors throw so the pagination
/// controller keeps its shown data and exposes the failure on its state.
Future<PageResult<LiveSearchResult>> searchPage({
  required LiveSite site,
  required String query,
  required LiveSearchTarget target,
  required int page,
  required int pageSize,
}) {
  final capability = site.capability<LiveSearchProvider>();
  if (capability == null) {
    throw StateError('${site.manifest.id} lost its search capability');
  }
  if (!capability.supportedTargets.contains(target)) {
    throw StateError('${site.manifest.id} does not answer ${target.name}');
  }
  final request = LiveSearchRequest(query: query, target: target, page: page, pageSize: pageSize);
  return capability
      .search(request)
      .then(
        (result) => result.fold(
          (error) => throw _SearchException(error),
          (page) => PageResult(items: page.items, totalCount: page.totalCount, hasMore: page.hasMore),
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
