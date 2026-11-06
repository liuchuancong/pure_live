import 'dart:async' show Timer, unawaited;
import 'dart:io' show Platform;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/modules/live/areas/areas.dart' show areaLayoutProvider;
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/search/search_capability.dart';
import 'package:pure_live/modules/live/search/search_controller.dart';
import 'package:pure_live/modules/live/search/search_scope.dart';
import 'package:pure_live/modules/live/search/web_search_page.dart' show WebSearchRequest;
import 'package:pure_live/modules/live/search/web_search_urls.dart' show hasWebSearch, webSearchUrl;
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:webview_all/webview_all.dart' show WebViewPlatform;

/// How many completions the panel shows at most: a handful keeps the field's
/// reach honest while bounding the panel's height in a short window.
const int _maxSuggestionsShown = 5;

/// The order the room/anchor results show in. [smart] keeps the platforms'
/// merged order; the others sort the received pages locally, so paging
/// keeps asking the same server pages.
enum _SearchSort { smart, platform, audience, followers }

/// The search page (the reference's `SearchPage`): a platform scope above
/// the field — every platform at once, or one — the committed query's
/// target switching on the segments, the rooms paging in as a card grid
/// and the streamers and areas as list cards, and the viewer's last
/// queries waiting under the empty field as tappable history.
final class SearchPage extends ConsumerStatefulWidget {
  /// The live search page.
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _field = TextEditingController();
  Timer? _suggestDebounce;

  /// The field's current text — the draft the completions follow, distinct
  /// from the committed query the results answer to.
  String _draft = '';

  /// The link in the draft whose platforms have been asked; the banner waits
  /// for an answer, so an ordinary address does not claim to be a room.
  String? _checkedLink;

  /// The viewer's local filters over the received results.
  _SearchSort _sort = _SearchSort.smart;
  bool _includeOffline = true;

  /// The failed-platform set whose notice the viewer closed; the same
  /// failure stays closed, a changed set (another search, a retry that
  /// loses or gains a platform) speaks again.
  String? _dismissedFailures;

  @override
  void initState() {
    super.initState();
    // A word handed from outside (the toolbar): taken once on arrival,
    // searched as though typed here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final word = ref.read(pendingSearchProvider.notifier).take();
      if (word == null || word.isEmpty || !mounted) return;
      _field.value = TextEditingValue(
        text: word,
        selection: TextSelection.collapsed(offset: word.length),
      );
      unawaited(ref.read(searchProvider.notifier).search(word));
      unawaited(ref.read(searchHistoryProvider.notifier).commit(word));
    });
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  /// Asks for completions once the typing has rested: a change in the
  /// trimmed draft restarts the wait, so only the last stroke asks.
  void _onDraftChanged(String draft) {
    final word = draft.trim();
    if (word == _draft) return;
    if (_linkIn(word) == null) _checkedLink = null;
    setState(() => _draft = word);
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(searchProvider.notifier).suggest(draft));
      final link = _linkIn(draft);
      if (link != null && link != _checkedLink) {
        _checkedLink = link;
        // The previous room's answer must not stand in for this link while
        // the platforms are still being asked.
        ref.read(linkToolProvider.notifier).reset();
        unawaited(ref.read(linkToolProvider.notifier).resolve(link));
      }
    });
  }

  /// Runs the draft: a link the platforms recognise opens its room; a
  /// keyword is recorded and searched. A link that resolves to nothing falls
  /// through to the keyword search, as the reference does.
  void _onSubmitted(String draft) {
    _suggestDebounce?.cancel();
    setState(() => _draft = draft.trim());
    unawaited(_submit(draft));
  }

  Future<void> _submit(String draft) async {
    final word = draft.trim();
    if (word.isEmpty) {
      showDsToast(context: context, title: context.t.search.inputRequired);
      return;
    }
    final link = _linkIn(word);
    if (link != null && await _openLink(link)) return;
    if (!mounted) return;
    unawaited(ref.read(searchHistoryProvider.notifier).commit(word));
    unawaited(ref.read(searchProvider.notifier).search(word));
  }

  /// A phone asks for the result's conditions in a panel; a wider window
  /// keeps them in the field row's popover.
  void _openFilterPanel() {
    unawaited(
      showDsPanel<void>(
        context: context,
        builder: (context) => DsPanel(
          title: Text(context.t.search.filterTitle),
          child: _SearchFilterPanel(
            sort: _sort,
            options: [
              for (final sort in _SearchSort.values) DsSelectOption(value: sort, label: _sortLabel(context, sort)),
            ],
            includeOffline: _includeOffline,
            onSortChanged: (sort) => setState(() => _sort = sort),
            onIncludeOfflineChanged: (value) => setState(() => _includeOffline = value),
            onReset: () => setState(() {
              _sort = _SearchSort.smart;
              _includeOffline = true;
            }),
          ),
        ),
      ),
    );
  }

  /// Takes a completion: it becomes the field's text and the query at once.
  void _onSuggestionPicked(String word) {
    _field.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    _onSubmitted(word);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final scope = ref.watch(searchSiteIdProvider);
    final targets = ref.watch(searchProvider.notifier).supportedTargetsOf(scope);
    // The platform-display choice is a browse-wide choice: a switched-off
    // platform is not offered as a search scope either.
    ref.watch(sitesDisplayProvider);
    final visible = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final nativeTls = ref.watch(nativeTlsPlatformsProvider);
    final allPlatformIds = [
      for (final site in ref.watch(sitesProvider).all)
        if (visible.contains(site.manifest.id) &&
            !SiteFacts.isRetired(site.manifest.id) &&
            (!SiteFacts.requiresNativeTls.contains(site.manifest.id) || nativeTls.contains(site.manifest.id)))
          site.manifest.id,
    ];
    final word = _draft.trim().isEmpty ? search.query.trim() : _draft.trim();
    // A platform with a web-search page keeps the button usable even before
    // the field has a word; pressing it says what is missing instead of
    // offering a dead control. "All" offers the platform picker.
    final canWebSearch = scope == kSearchAllPlatforms ? allPlatformIds.any(hasWebSearch) : hasWebSearch(scope);
    final link = _linkIn(word);
    final linkState = ref.watch(linkToolProvider);
    // Only a link a platform actually resolved is offered; an ordinary URL
    // in the field is just text until the search runs.
    final showLink = link != null && link == _checkedLink && linkState.resolved != null;
    final failed = ref.watch(searchFailuresProvider);
    final failureNames = [for (final id in failed) _platformName(id)].join('、');
    final failureKey = ([...failed]..sort()).join('|');
    final excluded = ref.watch(searchExcludedProvider);
    final view = _viewOf(search);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final platforms = [kSearchAllPlatforms, ...allPlatformIds];
    void chooseScope(String id) {
      if (id == scope) return;
      // The reference re-runs the field's text on the new scope instead of
      // discarding what the viewer typed.
      final word = _draft.trim().isEmpty ? search.query.trim() : _draft.trim();
      ref.read(searchSiteIdProvider.notifier).selected = id;
      if (word.isEmpty) {
        unawaited(ref.read(searchProvider.notifier).search(''));
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(searchProvider.notifier).search(word));
      });
    }

    void managePlatforms() =>
        unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // A small screen keeps the scope tabs alone; the layout and the
          // platform wall move behind the page's more icon.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The shell's one width decision, never a local measure.
              final narrow = PageLayoutScope.isNarrow(context);
              final tabs = PlatformTabRow(
                platforms: platforms,
                current: scope,
                nameOf: _platformName,
                semanticLabel: context.t.search.targetsLabel,
                showPlatformWall: !narrow,
                // The head row ends in the target's own layout switch (the
                // page draws it after the tabs), so the tabs carry none.
                showLayoutToggle: false,
                // The panel's way to the hide/reorder setting.
                onManagePlatforms: managePlatforms,
                onChanged: chooseScope,
              );
              // The target switch leads the head row at its start — the
              // areas page's own head: its view switch opens the 44 px row
              // and the platform tabs follow.
              final targetSwitch = targets.length >= 2
                  ? _TargetSegments(
                      targets: targets,
                      selected: search.target,
                      onChanged: (target) => unawaited(ref.read(searchProvider.notifier).switchTarget(target)),
                    )
                  : null;
              if (narrow) {
                // A stacked toolbar hands the platform menu to the shell's
                // head line; this row keeps the scope tabs alone, and the
                // target switch stays with the results below.
                publishPageHeadActions(context, ref, NavigationItem.search, [
                  PlatformToolbarMore(
                    platforms: platforms,
                    current: scope,
                    nameOf: _platformName,
                    onChanged: chooseScope,
                    onManagePlatforms: managePlatforms,
                  ),
                ]);
                return SizedBox(height: 44, child: tabs);
              }
              return SizedBox(
                height: 44,
                child: Row(
                  spacing: DsSpace.s12,
                  children: [
                    ?targetSwitch,
                    Expanded(child: tabs),
                    _SearchLayoutToggle(target: search.target),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: DsSearchField(
                  controller: _field,
                  autofocus: true,
                  placeholder: context.t.common.searchHint,
                  onChanged: _onDraftChanged,
                  onSubmitted: _onSubmitted,
                ),
              ),
              // The result's own conditions sit behind one button, the kit's
              // filter-button pattern, so the field row stays two controls.
              if (_showFilters(search))
                if (PageLayoutScope.isNarrow(context))
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: context.t.search.filterTitle,
                    onPressed: _openFilterPanel,
                    icon: const DsIcon(DsIcons.slidersHorizontal, size: 16),
                  )
                else
                  DsPopover(
                    align: DsAlign.end,
                    semanticLabel: context.t.search.filterTitle,
                    style: const DsPopoverStyle(width: 264),
                    contentBuilder: (context) => _SearchFilterPanel(
                      sort: _sort,
                      options: [
                        for (final sort in _SearchSort.values)
                          DsSelectOption(value: sort, label: _sortLabel(context, sort)),
                      ],
                      includeOffline: _includeOffline,
                      onSortChanged: (sort) => setState(() => _sort = sort),
                      onIncludeOfflineChanged: (value) => setState(() => _includeOffline = value),
                      onReset: () => setState(() {
                        _sort = _SearchSort.smart;
                        _includeOffline = true;
                      }),
                    ),
                    builder: (context, controller, _) {
                      final active = (_sort == _SearchSort.smart ? 0 : 1) + (_includeOffline ? 0 : 1);
                      // The popover only opens where the toolbar is one line
                      // — the window then clears the compact class by a wide
                      // margin — so the button always carries its label.
                      return DsButton(
                        variant: active == 0 ? DsButtonVariant.secondary : DsButtonVariant.tinted,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.slidersHorizontal, size: 16),
                        trailing: active == 0 ? null : DsCount(active),
                        semanticLabel: active == 0
                            ? context.t.search.filterTitle
                            : '${context.t.search.filterTitle}, $active',
                        onPressed: controller.toggle,
                        child: Text(context.t.search.filterTitle),
                      );
                    },
                  ),
              if (scope == kSearchAllPlatforms)
                DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  semanticLabel: context.t.search.scopeTitle,
                  onPressed: () => unawaited(_openScope()),
                  icon: const DsIcon(DsIcons.listChecks, size: 16),
                ),
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: context.t.search.webSearch,
                onPressed: canWebSearch ? () => unawaited(_openWebSearch()) : null,
                icon: const DsIcon(DsIcons.globe, size: 16),
              ),
            ],
          ),
        ),
        if (_showHistory(search))
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: _SearchHistory(
              onPicked: _onSuggestionPicked,
              onCleared: () {
                unawaited(ref.read(searchHistoryProvider.notifier).clear());
                setState(() {});
              },
            ),
          ),
        // The narrow page keeps the target switch beside the results: its
        // head row is the scope tabs alone, the areas head's own answer.
        if (PageLayoutScope.isNarrow(context) && targets.length >= 2)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
            child: _TargetSegments(
              targets: targets,
              selected: search.target,
              onChanged: (target) => unawaited(ref.read(searchProvider.notifier).switchTarget(target)),
            ),
          ),
        if (scope != kSearchAllPlatforms && targets.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: Text(
              searchCoverageText(context.t, SearchCapabilities.of(scope), _platformName(scope)),
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textMuted),
            ),
          ),
        if (search.query.isNotEmpty &&
            failed.isNotEmpty &&
            _dismissedFailures != failureKey &&
            (search.rooms.isNotEmpty || search.anchors.isNotEmpty))
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: DsAlert(
              title: Text(context.t.search.partialFailureTitle),
              description: Text(
                context.t.search.partialFailureDescription(platforms: failureNames),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              action: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(ref.read(searchProvider.notifier).retry()),
                    child: Text(context.t.search.partialFailureRetry),
                  ),
                  if (scope == kSearchAllPlatforms)
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: () => unawaited(_openScope()),
                      child: Text(context.t.search.partialFailureScope),
                    ),
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: context.t.common.close,
                    onPressed: () => setState(() => _dismissedFailures = failureKey),
                    icon: const DsIcon(DsIcons.x, size: 16),
                  ),
                ],
              ),
            ),
          ),
        if (showLink)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: DsAlert(
              title: Text(context.t.search.linkDetected),
              description: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              action: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                loading: linkState.resolving,
                onPressed: linkState.resolving ? null : () => unawaited(_openLink(link)),
                child: Text(context.t.search.linkOpen),
              ),
            ),
          ),
        if (_showSuggestions(search))
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
            child: DsListSection(
              header: Text(context.t.search.suggestionsTitle),
              children: [
                for (final word in search.suggestions.take(_maxSuggestionsShown))
                  DsListRow(
                    leading: const DsIcon(DsIcons.search),
                    title: Text(word),
                    onPressed: () => _onSuggestionPicked(word),
                  ),
              ],
            ),
          ),
        // The scope's sentence (the reference's scope line): "all" counts the
        // platforms it asks — in the anchors' target, the ones that can
        // answer it. A single platform's own line already sits under the
        // target segments. It opens the scope panel, where the excluded
        // platforms and every platform's words live.
        if (scope == kSearchAllPlatforms)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s4),
            child: DsPressable(
              onPressed: () => unawaited(_openScope()),
              builder: (context, states, _) {
                final colors = DsTheme.colorsOf(context);
                return Row(
                  children: [
                    DsIcon(DsIcons.info, size: 14, color: colors.accent),
                    const SizedBox(width: DsSpace.s3),
                    Expanded(
                      child: Text(
                        _scopeSentence(context, search, scope: scope, platformIds: allPlatformIds, excluded: excluded),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Expanded(
          child: _SearchResults(
            search: view,
            targets: targets,
            unsupportedCoverage: scope == kSearchAllPlatforms
                ? null
                : searchCoverageText(context.t, SearchCapabilities.of(scope), _platformName(scope)),
            hasHiddenOffline: !_includeOffline && view.target == LiveSearchTarget.rooms && search.rooms.isNotEmpty,
            onShowOffline: () => setState(() => _includeOffline = true),
          ),
        ),
      ],
    );
  }

  /// Opens the chosen platform's own search page in the app's web view.
  Future<void> _openWebSearch() async {
    final t = context.t;
    final word = (_draft.trim().isEmpty ? ref.read(searchProvider).query : _draft).trim();
    if (word.isEmpty) {
      showDsToast(context: context, title: t.search.inputRequired);
      return;
    }
    var scope = ref.read(searchSiteIdProvider);
    if (scope == kSearchAllPlatforms) {
      final picked = await _pickWebSearchPlatform();
      if (picked == null || !mounted) return;
      scope = picked;
    }
    final uri = webSearchUrl(scope, word);
    if (uri == null) {
      showDsToast(context: context, title: t.search.webSearchUnavailable);
      return;
    }
    if (!mounted) return;
    // A Windows without WebView2 asks before leaving the app: cancel, the
    // runtime's download page, or the system browser (the reference's c15).
    if (Platform.isWindows && WebViewPlatform.instance == null) {
      final proceed = await _askWithoutWebView2();
      if (!proceed || !mounted) return;
    }
    await context.push(
      RouteNames.webSearch,
      extra: WebSearchRequest(uri: uri, platform: scope, keyword: word),
    );
  }

  /// The platforms "all" may open a web search for: visible, not retired,
  /// reachable by this host and carrying a search page.
  List<LiveSite> _webSearchSites() {
    final visible = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final nativeTls = ref.read(nativeTlsPlatformsProvider);
    return [
      for (final site in ref.read(sitesProvider).all)
        if (visible.contains(site.manifest.id) &&
            !SiteFacts.isRetired(site.manifest.id) &&
            (!SiteFacts.requiresNativeTls.contains(site.manifest.id) || nativeTls.contains(site.manifest.id)) &&
            hasWebSearch(site.manifest.id))
          site,
    ];
  }

  /// Asks which platform's web search "all" should open.
  Future<String?> _pickWebSearchPlatform() {
    final sites = _webSearchSites();
    if (sites.isEmpty) {
      showDsToast(context: context, title: context.t.search.webSearchUnavailable);
      return Future<String?>.value();
    }
    return showDsPanel<String>(
      context: context,
      builder: (context) => DsPanel(
        title: Text(context.t.search.webSearchTitle),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              for (final site in sites)
                DsListRow(
                  leading: localizedSiteIcon(site, size: 24),
                  title: Text(localizedSiteName(site)),
                  onPressed: () => Navigator.of(context).pop(site.manifest.id),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Asks what to do without WebView2: the system browser continues the
  /// search, the download action leaves for Microsoft's page, cancel stops.
  Future<bool> _askWithoutWebView2() async {
    final choice = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(context.t.search.webView2MissingTitle),
        description: Text(context.t.search.webView2MissingBody),
        actions: [
          DsButton(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t.common.cancel),
          ),
          DsButton(
            variant: DsButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop('download'),
            child: Text(context.t.search.webView2Download),
          ),
          DsButton(
            variant: DsButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop('browser'),
            child: Text(context.t.search.webSearchOpenExternal),
          ),
        ],
      ),
    );
    if (choice == 'download') {
      await launchUrl(
        Uri.parse('https://developer.microsoft.com/microsoft-edge/webview2/'),
        mode: LaunchMode.externalApplication,
      );
      return false;
    }
    return choice == 'browser';
  }

  /// Whether the result's conditions are offered: a committed search whose
  /// results can be sorted or thinned (the areas list cannot).
  bool _showFilters(SearchState search) => search.query.isNotEmpty && search.target != LiveSearchTarget.areas;

  /// Whether the completions panel shows: only while a draft that is not the
  /// committed query has completions to offer.
  bool _showSuggestions(SearchState search) {
    final word = _draft.trim();
    return word.isNotEmpty && word != search.query && search.suggestions.isNotEmpty;
  }

  /// Whether the history panel shows: an empty field and a committed search
  /// that is not showing results — the moments the history is useful.
  bool _showHistory(SearchState search) {
    return _draft.isEmpty && search.query.isEmpty;
  }

  /// The filtered/ordered copy of [search] the page draws: the controller
  /// keeps the raw platform pages, so a new sort or the offline toggle is
  /// instant and never re-asks the servers.
  ///
  /// "Offline" means not playable now, so hiding it keeps replays (the
  /// reference's `isPlayableNow` rule); the order puts live first, then
  /// replay, then the rest under every sort mode.
  SearchState _viewOf(SearchState search) {
    if (search.target == LiveSearchTarget.areas) return search;
    final rooms = [
      for (final room in search.rooms)
        if (_includeOffline || room.broadcast.isPlayableNow) room,
    ];
    final anchors = [
      for (final anchor in search.anchors)
        if (_includeOffline || anchor.liveStatus == LiveStatus.live) anchor,
    ];
    return (
      query: search.query,
      target: search.target,
      rooms: _sortRooms(rooms),
      anchors: _sortAnchors(anchors),
      areas: search.areas,
      nextPage: search.nextPage,
      hasMore: search.hasMore,
      loading: search.loading,
      error: search.error,
      suggestions: search.suggestions,
    );
  }

  List<LiveRoom> _sortRooms(List<LiveRoom> rooms) {
    final order = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final ranks = {for (var i = 0; i < order.length; i++) order[i].trim().toLowerCase(): i};
    final metric = ref.read(audienceMetricProvider);
    final policy = ref.read(audiencePolicyProvider);
    int audience(LiveRoom room) => audienceFigureOf(room, metric, policy: policy) ?? -1;
    int followers(LiveRoom room) {
      final explicit = room.anchor?.followerCount ?? 0;
      if (explicit > 0) return explicit;
      // A platform whose audience number is followers publishes it there,
      // not on the anchor (the reference's follower fallback).
      if (room.audience.primaryMetric == LiveAudienceMetricType.followers) return audience(room);
      return 0;
    }

    int platform(LiveRoom room) => ranks[room.ref.platform] ?? ranks.length;
    int state(LiveRoom room) => room.broadcast.isLiveNow ? 2 : (room.broadcast.isPlayableNow ? 1 : 0);
    final sorted = [...rooms]
      ..sort((a, b) {
        final byState = state(b).compareTo(state(a));
        if (byState != 0) return byState;
        final comparisons = switch (_sort) {
          _SearchSort.smart => <int Function()>[
            () => audience(b).compareTo(audience(a)),
            () => followers(b).compareTo(followers(a)),
            () => platform(a).compareTo(platform(b)),
          ],
          _SearchSort.platform => <int Function()>[
            () => platform(a).compareTo(platform(b)),
            () => audience(b).compareTo(audience(a)),
            () => followers(b).compareTo(followers(a)),
          ],
          _SearchSort.audience => <int Function()>[
            () => audience(b).compareTo(audience(a)),
            () => platform(a).compareTo(platform(b)),
            () => followers(b).compareTo(followers(a)),
          ],
          _SearchSort.followers => <int Function()>[
            () => followers(b).compareTo(followers(a)),
            () => audience(b).compareTo(audience(a)),
            () => platform(a).compareTo(platform(b)),
          ],
        };
        for (final compare in comparisons) {
          final result = compare();
          if (result != 0) return result;
        }
        final title = a.content.title.toLowerCase().compareTo(b.content.title.toLowerCase());
        if (title != 0) return title;
        return a.identityKey.compareTo(b.identityKey);
      });
    return sorted;
  }

  List<LiveAnchor> _sortAnchors(List<LiveAnchor> anchors) {
    final order = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final ranks = {for (var i = 0; i < order.length; i++) order[i].trim().toLowerCase(): i};
    int platform(LiveAnchor anchor) => ranks[anchor.platform] ?? ranks.length;
    int followers(LiveAnchor anchor) => anchor.followerCount ?? 0;
    int state(LiveAnchor anchor) => anchor.liveStatus == LiveStatus.live ? 1 : 0;
    final sorted = [...anchors]
      ..sort((a, b) {
        final comparisons = switch (_sort) {
          _SearchSort.smart => <int Function()>[
            () => state(b).compareTo(state(a)),
            () => followers(b).compareTo(followers(a)),
            () => platform(a).compareTo(platform(b)),
          ],
          _SearchSort.platform => <int Function()>[
            () => platform(a).compareTo(platform(b)),
            () => state(b).compareTo(state(a)),
            () => followers(b).compareTo(followers(a)),
          ],
          _SearchSort.audience || _SearchSort.followers => <int Function()>[
            () => followers(b).compareTo(followers(a)),
            () => state(b).compareTo(state(a)),
            () => platform(a).compareTo(platform(b)),
          ],
        };
        for (final compare in comparisons) {
          final result = compare();
          if (result != 0) return result;
        }
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return name != 0 ? name : a.anchorId.compareTo(b.anchorId);
      });
    return sorted;
  }

  static String? _linkIn(String text) => RegExp(r'https?://[^\s，。；;“”‘’<>]+').firstMatch(text)?.group(0);

  /// The scope's sentence (the reference's scope line): a single platform
  /// names what it finds, "all" counts the platforms it asks — in the
  /// anchors' target, the platforms that can answer it at all.
  String _scopeSentence(
    BuildContext context,
    SearchState search, {
    required String scope,
    required List<String> platformIds,
    required Set<String> excluded,
  }) {
    final t = context.t;
    if (scope != kSearchAllPlatforms) {
      final capability = SearchCapabilities.of(scope);
      if (search.target == LiveSearchTarget.anchors && !capability.anchors) {
        return t.search.anchorUnsupported(site: _platformName(scope));
      }
      return searchCoverageText(t, capability, _platformName(scope));
    }
    if (search.target == LiveSearchTarget.anchors) {
      final names = [
        for (final id in platformIds)
          if (!excluded.contains(id) && SearchCapabilities.of(id).anchors) _platformName(id),
      ];
      return t.search.anchorPlatforms(sites: names.join('、'));
    }
    final chosen = [
      for (final id in platformIds)
        if (!excluded.contains(id) && SearchCapabilities.of(id).native) id,
    ];
    final left = platformIds.length - chosen.length;
    return left > 0
        ? t.search.scopeSummaryExcluded(count: '${chosen.length}', total: '${platformIds.length}', excluded: '$left')
        : t.search.scopeSummary(count: '${chosen.length}');
  }

  String _sortLabel(BuildContext context, _SearchSort sort) => switch (sort) {
    _SearchSort.smart => context.t.search.sortSmart,
    _SearchSort.platform => context.t.search.sortPlatform,
    _SearchSort.audience => context.t.search.sortAudience,
    _SearchSort.followers => context.t.search.sortFollowers,
  };

  /// Opens the "all" scope panel: which platforms the combined search asks.
  /// A saved choice re-runs the field's text, as the reference does.
  Future<void> _openScope() async {
    final visible = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final nativeTls = ref.read(nativeTlsPlatformsProvider);
    final sites = [
      for (final id in visible)
        if (ref.read(sitesProvider).getById(id) case final site?
            when !SiteFacts.isRetired(id) && (!SiteFacts.requiresNativeTls.contains(id) || nativeTls.contains(id)))
          site,
    ];
    final next = await showSearchScopePanel(context, sites: sites, excluded: ref.read(searchExcludedProvider));
    if (!mounted) return;
    await ref.read(searchExcludedProvider.notifier).save(next);
    final word = _draft.trim().isEmpty ? ref.read(searchProvider).query.trim() : _draft.trim();
    if (word.isNotEmpty) unawaited(ref.read(searchProvider.notifier).search(word));
  }

  Future<bool> _openLink(String text) async {
    await ref.read(linkToolProvider.notifier).resolve(text);
    if (!mounted) return false;
    final link = ref.read(linkToolProvider);
    if (link.resolved case final room?) {
      await openRoom(context, platform: room.platform, roomId: room.roomId);
      return true;
    }
    final failure = link.failure;
    final action = failure != null && failure.isTransient ? () => unawaited(_openLink(text)) : null;
    showDsToast(
      context: context,
      title: context.t.search.linkFailed,
      status: DsStatus.danger,
      actionLabel: action != null ? context.t.common.retry : null,
      onAction: action,
    );
    return false;
  }

  String _platformName(String id) {
    if (id == kSearchAllPlatforms) return context.t.search.scopeAll;
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// The search history: the last committed queries as rows, each opening the
/// search again, an x dropping one, the header's button dropping all.
final class _SearchHistory extends ConsumerWidget {
  const _SearchHistory({required this.onPicked, required this.onCleared});

  /// Runs the picked word as the field's text and query.
  final ValueChanged<String> onPicked;

  /// Drops every entry.
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) return const SizedBox.shrink();
    final colors = DsTheme.colorsOf(context);
    return DsListSection(
      header: Row(
        children: [
          Expanded(child: Text(context.t.search.historyTitle)),
          DsPressable(
            semanticLabel: context.t.search.clearHistory,
            onPressed: onCleared,
            builder: (context, states, _) => Text(
              context.t.search.clearHistory,
              style: DsTheme.of(context).typography.caption
                  .copyWith(color: states.contains(WidgetState.hovered) ? colors.text : colors.textMuted),
            ),
          ),
        ],
      ),
      children: [
        for (final word in history)
          DsListRow(
            leading: const DsIcon(DsIcons.history),
            title: Text(word),
            onPressed: () => onPicked(word),
            trailing: DsPressable(
              semanticLabel: context.t.search.clearHistory,
              onPressed: () => unawaited(ref.read(searchHistoryProvider.notifier).remove(word)),
              builder: (context, states, _) => DsIcon(
                DsIcons.x,
                size: 14,
                color: states.contains(WidgetState.hovered) ? colors.text : colors.textSubtle,
              ),
            ),
          ),
      ],
    );
  }
}

/// The result's conditions behind the filter button: the sort order and
/// whether offline hits stay, applied at once, with the way back. The panel
/// keeps its own copy, like the kit's filter popovers, so a change paints
/// here even though the page behind it rebuilds apart from the overlay.
final class _SearchFilterPanel extends StatefulWidget {
  const _SearchFilterPanel({
    required this.sort,
    required this.options,
    required this.includeOffline,
    required this.onSortChanged,
    required this.onIncludeOfflineChanged,
    required this.onReset,
  });

  /// The order in force.
  final _SearchSort sort;

  /// The order's choices, labelled by the page.
  final List<DsSelectOption<_SearchSort>> options;

  /// Whether offline hits stay shown.
  final bool includeOffline;

  /// Receives a newly chosen order.
  final ValueChanged<_SearchSort> onSortChanged;

  /// Receives the offline switch.
  final ValueChanged<bool> onIncludeOfflineChanged;

  /// Puts both conditions back to their defaults.
  final VoidCallback onReset;

  @override
  State<_SearchFilterPanel> createState() => _SearchFilterPanelState();
}

final class _SearchFilterPanelState extends State<_SearchFilterPanel> {
  late _SearchSort _sort = widget.sort;
  late bool _includeOffline = widget.includeOffline;

  void _reset() {
    setState(() {
      _sort = _SearchSort.smart;
      _includeOffline = true;
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final active = _sort != _SearchSort.smart || !_includeOffline;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        DsField(
          label: Text(t.search.sort),
          child: AdaptiveChoiceField<_SearchSort>(
            value: _sort,
            title: t.search.sort,
            semanticLabel: t.search.sort,
            onChanged: (sort) {
              setState(() => _sort = sort);
              widget.onSortChanged(sort);
            },
            options: widget.options,
          ),
        ),
        DsSwitch(
          value: _includeOffline,
          label: Text(t.search.includeOffline),
          onChanged: (value) {
            setState(() => _includeOffline = value);
            widget.onIncludeOfflineChanged(value);
          },
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DsButton(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            onPressed: active ? _reset : null,
            child: Text(t.search.filterReset),
          ),
        ),
      ],
    );
  }
}

/// The search's target switch: one segment per target the site actually
/// searches, each with its own icon; the selection rides the radio group.
final class _TargetSegments extends StatelessWidget {
  const _TargetSegments({required this.targets, required this.selected, required this.onChanged});

  /// The targets the site searches, in canonical order.
  final List<LiveSearchTarget> targets;

  /// The target the current search runs on.
  final LiveSearchTarget selected;

  /// Receives a newly chosen target.
  final ValueChanged<LiveSearchTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsSegmentedControl<LiveSearchTarget>(
      value: selected,
      onChanged: onChanged,
      semanticLabel: t.search.targetsLabel,
      segments: [
        for (final target in targets)
          DsSegment(
            value: target,
            icon: DsIcon(switch (target) {
              LiveSearchTarget.rooms => DsIcons.tv,
              LiveSearchTarget.anchors => DsIcons.users,
              LiveSearchTarget.areas => DsIcons.grid2x2,
            }),
            label: Text(switch (target) {
              LiveSearchTarget.rooms => t.search.tabRooms,
              LiveSearchTarget.anchors => t.search.tabAnchors,
              LiveSearchTarget.areas => t.search.tabAreas,
            }),
          ),
      ],
    );
  }
}

/// The results for the current search: the room grid, the streamer and area
/// lists, or an honest skeleton, empty state or error in their place.
final class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.search,
    required this.targets,
    required this.hasHiddenOffline,
    required this.onShowOffline,
    this.unsupportedCoverage,
  });

  /// The search being shown.
  final SearchState search;

  /// The targets the site searches; empty when it cannot search at all.
  final List<LiveSearchTarget> targets;

  /// What the chosen platform finds, said in its own words; the generic
  /// sentence when null (the "all" scope cannot be unsupported).
  final String? unsupportedCoverage;

  /// Whether the only hits were non-playable rooms the offline filter hid.
  final bool hasHiddenOffline;

  /// Shows the hidden offline rooms.
  final VoidCallback onShowOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final anchorRooms = ref.watch(anchorRoomsProvider);
    final empty = search.rooms.isEmpty && search.anchors.isEmpty && search.areas.isEmpty;
    if (search.query.isEmpty) {
      if (targets.isEmpty) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.searchX),
            title: Text(t.search.unsupportedTitle),
            description: Text(unsupportedCoverage ?? t.search.unsupportedDescription),
          ),
        );
      }
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.search),
          title: Text(t.search.idleTitle),
          description: Text(t.search.idleDescription),
        ),
      );
    }
    if (empty && search.loading) {
      return switch (search.target) {
        LiveSearchTarget.rooms => const _RoomSkeletonGrid(),
        LiveSearchTarget.anchors => const _ListSkeleton(),
        LiveSearchTarget.areas => _AreaSkeleton(search: search),
      };
    }
    if (empty && search.error != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.common.empty),
          description: Text(search.error!.message),
          actions: [DsButton(onPressed: ref.read(searchProvider.notifier).retry, child: Text(t.common.retry))],
        ),
      );
    }
    if (empty && hasHiddenOffline) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.search.noLiveResultsTitle),
          description: Text(t.search.noLiveResultsDescription),
          actions: [DsButton(onPressed: onShowOffline, child: Text(t.search.includeOffline))],
        ),
      );
    }
    if (empty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.search.noResultsTitle),
          description: Text(t.search.noResultsDescription),
        ),
      );
    }
    return switch (search.target) {
      LiveSearchTarget.rooms => _RoomResults(search: search),
      LiveSearchTarget.anchors => _ListResults(
        items: search.anchors,
        itemBuilder: (context, item) {
          final anchor = item as LiveAnchor;
          final roomId = (anchorRooms[searchAnchorKey(anchor)] ?? '').trim();
          final platform = anchor.platform.trim();
          final profile = (anchor.profileUrl ?? '').trim();
          final openRoomById = roomId.isEmpty || platform.isEmpty
              ? null
              : () => unawaited(openRoom(context, platform: platform, roomId: roomId));
          return _AnchorCard(
            anchor: anchor,
            onOpen:
                openRoomById ??
                (profile.isEmpty
                    ? null
                    : () => unawaited(launchUrl(Uri.parse(profile), mode: LaunchMode.externalApplication))),
          );
        },
        hasMore: search.hasMore,
        loading: search.loading,
        // The streamer row is the room card's small row, so it keeps the
        // room row's own height and slices into the rooms list's columns.
        listMainAxisExtent: kRoomCardListDesignHeight,
      ),
      LiveSearchTarget.areas => _AreaResults(search: search),
    };
  }
}

/// The rooms target's grid: the home feed's own cards in the same masonry,
/// paging in as the view nears its end.
final class _RoomResults extends ConsumerWidget {
  const _RoomResults({required this.search});

  /// The search whose rooms are shown.
  final SearchState search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchProvider.notifier);
    Widget cardFor(BuildContext context, LiveRoom room, {bool listRow = false}) {
      void open() =>
          openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, room: room, playlist: search.rooms);
      return RoomCardMenu(
        room: room,
        onOpen: open,
        child: RoomCard(room: room, listRow: listRow, onOpen: open),
      );
    }

    final browse = ref.watch(browseSettingsProvider);
    return PagedCardGrid<LiveRoom>(
      items: search.rooms,
      layout: ref.watch(browseLayoutProvider),
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      listMatchesGridWidth: true,
      listMainAxisExtent: kRoomCardListDesignHeight,
      listItemBuilder: (context, room) => cardFor(context, room, listRow: true),
      isLoading: search.loading,
      hasMore: search.hasMore,
      onLoadMore: controller.loadMore,
      onRefresh: controller.retry,
      itemBuilder: cardFor,
    );
  }
}

/// The areas target's grid: the areas page's own cards in the page's tile
/// or row preference, paging in like the rooms grid — the catalogue's own
/// measure, so a hit reads exactly as it does on the areas page.
final class _AreaResults extends ConsumerWidget {
  const _AreaResults({required this.search});

  /// The search whose areas are shown.
  final SearchState search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchProvider.notifier);
    final browse = ref.watch(browseSettingsProvider);
    final tileLayout = ref.watch(areaLayoutProvider);
    return PagedCardGrid<LiveArea>(
      items: search.areas,
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      aspectRatio: areaCardAspectRatio(tileLayout),
      cardExtent: tileLayout == AreaCardLayout.tile ? kAreaTileDesignWidth : null,
      oneColumnWhenCompact: tileLayout == AreaCardLayout.row,
      compactMainAxisExtent: tileLayout == AreaCardLayout.row ? kAreaRowDesignHeight : null,
      isLoading: search.loading,
      hasMore: search.hasMore,
      onLoadMore: controller.loadMore,
      onRefresh: controller.retry,
      itemBuilder: (context, area) {
        final openable = area.platform.trim().isNotEmpty && area.areaId.trim().isNotEmpty;
        return AreaCard(
          area: area,
          layout: tileLayout,
          onPressed: openable
              ? () => unawaited(
                  context.push(
                    AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
                    extra: area,
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// The anchors target's list: the room card's small rows, slicing into the
/// same columns the rooms' list does and paging in exactly like the grid.
final class _ListResults extends ConsumerWidget {
  const _ListResults({
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.loading,
    this.listMainAxisExtent,
  });

  /// The hits shown, in order.
  final List<Object> items;

  /// Builds the card at each index.
  final Widget Function(BuildContext context, Object item) itemBuilder;

  /// Whether another page can be loaded.
  final bool hasMore;

  /// Whether a page is loading now.
  final bool loading;

  /// The rows' fixed height; null lets a row measure itself.
  final double? listMainAxisExtent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchProvider.notifier);
    final browse = ref.watch(browseSettingsProvider);
    // The rows page like the rooms grid: a wide window slices them into
    // columns under the pager, a narrow one appends.
    return PagedCardGrid<Object>(
      items: items,
      layout: CardLayout.list,
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      // The streamer rows wear the rooms' list measure: a wide window
      // slices them into the same small columns, a narrow one appends.
      listMatchesGridWidth: true,
      listMainAxisExtent: listMainAxisExtent,
      listItemBuilder: itemBuilder,
      hasMore: hasMore,
      isLoading: loading,
      onLoadMore: controller.loadMore,
      onRefresh: controller.retry,
      itemBuilder: itemBuilder,
    );
  }
}

/// One streamer hit in the room card's small list-row shape: the avatar
/// leads, the name carries its verified mark, the self description fills
/// the second line and the meta line names the live state — a live pill,
/// a muted offline word — beside the follower count. The row opens the
/// streamer's room when the result carries one, else the platform profile;
/// without either it stays inert rather than pretending a page exists.
final class _AnchorCard extends StatelessWidget {
  const _AnchorCard({required this.anchor, this.onOpen});

  /// The streamer shown.
  final LiveAnchor anchor;

  /// Opens the streamer's room or profile; null leaves the row inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final live = anchor.liveStatus == LiveStatus.live;
    final followers = AudienceFormat.format(anchor.followerCount);
    final introduction = (anchor.introduction ?? '').trim();
    final caption = theme.typography.caption.copyWith(color: colors.textSubtle);
    return DsCard(
      onPressed: onOpen,
      semanticLabel: anchor.name,
      style: const DsCardStyle(padding: EdgeInsets.zero),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s8),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsAvatar(
                initials: avatarInitials(anchor.name),
                image: anchor.avatarUrl == null ? null : cachedImage(anchor.avatarUrl!, policy: ImageCachePolicies.avatar),
                size: DsSize.lg,
                semanticLabel: anchor.name,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      spacing: DsSpace.s3,
                      children: [
                        Flexible(
                          child: Text(
                            anchor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.bodyStrong.copyWith(color: colors.text),
                          ),
                        ),
                        if (anchor.isVerified ?? false)
                          DsIcon(DsIcons.badgeCheck, size: theme.sizes.iconXs, color: colors.accentText),
                      ],
                    ),
                    if (introduction.isNotEmpty)
                      Text(
                        introduction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        if (live)
                          DsBadge(
                            status: DsStatus.danger,
                            label: Text(context.t.search.liveBadge),
                            style: DsBadgeStyle(
                              height: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              textStyle: theme.typography.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                            ),
                          )
                        else
                          Text(context.t.search.offlineBadge, style: caption),
                        if (followers.isNotEmpty) ...[
                          DsIcon(DsIcons.users, size: 12, color: colors.textSubtle),
                          Text(followers, style: theme.typography.numeric(caption)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rooms target's first-page placeholder: the home feed's own skeleton
/// cards in the same masonry shape, no content.
final class _RoomSkeletonGrid extends ConsumerWidget {
  const _RoomSkeletonGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardGrid<LiveRoom>(
      items: const [],
      layout: ref.watch(browseLayoutProvider),
      listMatchesGridWidth: true,
      listMainAxisExtent: kRoomCardListDesignHeight,
      isLoading: true,
      itemBuilder: (context, room) => const SizedBox.shrink(),
    );
  }
}

/// The head row's layout switch, one pair per target: the rooms' grid and
/// list follow the browse choice; the streamers' small row is the only
/// shape its card has, so the grid's segment stands disabled; the areas'
/// pair is the areas page's own tile and row choice.
final class _SearchLayoutToggle extends ConsumerWidget {
  const _SearchLayoutToggle({required this.target});

  /// The target whose shapes the switch speaks for.
  final LiveSearchTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return switch (target) {
      LiveSearchTarget.rooms => const LayoutToggle(),
      LiveSearchTarget.anchors => DsTooltip(
        message: t.common.layout,
        child: DsSegmentedControl<CardLayout>(
          value: CardLayout.list,
          onChanged: (_) {},
          semanticLabel: t.common.layout,
          segments: [
            DsSegment(
              value: CardLayout.grid,
              enabled: false,
              icon: const DsIcon(DsIcons.layoutGrid, size: 16),
              semanticLabel: t.common.layoutGrid,
            ),
            DsSegment(
              value: CardLayout.list,
              icon: const DsIcon(DsIcons.layoutList, size: 16),
              semanticLabel: t.common.layoutList,
            ),
          ],
        ),
      ),
      LiveSearchTarget.areas => DsTooltip(
        message: t.common.layout,
        child: DsSegmentedControl<AreaCardLayout>(
          value: ref.watch(areaLayoutProvider),
          onChanged: (layout) => unawaited(ref.read(areaLayoutProvider.notifier).set(layout)),
          semanticLabel: t.common.layout,
          segments: [
            DsSegment(
              value: AreaCardLayout.tile,
              icon: const DsIcon(DsIcons.layoutGrid, size: 16),
              semanticLabel: t.areas.iconTop,
            ),
            DsSegment(
              value: AreaCardLayout.row,
              icon: const DsIcon(DsIcons.layoutList, size: 16),
              semanticLabel: t.areas.iconLeft,
            ),
          ],
        ),
      ),
    };
  }
}

/// The areas target's first-page placeholder: the catalogue's own grid in
/// the page's tile or row preference, no content.
final class _AreaSkeleton extends ConsumerWidget {
  const _AreaSkeleton({required this.search});

  /// The search whose areas are loading.
  final SearchState search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browse = ref.watch(browseSettingsProvider);
    final tileLayout = ref.watch(areaLayoutProvider);
    return CardGrid<LiveArea>(
      items: const [],
      crossSpacing: browse.crossSpacing,
      mainSpacing: browse.mainSpacing,
      aspectRatio: areaCardAspectRatio(tileLayout),
      cardExtent: tileLayout == AreaCardLayout.tile ? kAreaTileDesignWidth : null,
      oneColumnWhenCompact: tileLayout == AreaCardLayout.row,
      compactMainAxisExtent: tileLayout == AreaCardLayout.row ? kAreaRowDesignHeight : null,
      isLoading: true,
      itemBuilder: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// The anchors and areas targets' first-page placeholder: the list card's
/// own shape — a round tile and two text lines — no content.
final class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return CardList<Object>(items: const [], isLoading: true, skeletonBuilder: (context) => const _ListCardSkeleton());
  }
}

/// One list card's placeholder while its page loads: the same shape, no
/// content.
final class _ListCardSkeleton extends StatelessWidget {
  const _ListCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s12),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsSkeleton.circle(size: theme.sizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                DsSkeleton(width: DsSpace.s64, height: DsSpace.s12),
                DsSkeleton(width: DsSpace.s40, height: DsSpace.s8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
