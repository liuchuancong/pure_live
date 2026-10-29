import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/search/search_controller.dart';
import 'package:pure_live/modules/live/search/web_search_page.dart' show WebSearchRequest;
import 'package:pure_live/modules/live/search/web_search_urls.dart' show webSearchUrl;
import 'package:pure_live/modules/live/toolbox/toolbox.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

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

  /// The viewer's local filters over the received results.
  _SearchSort _sort = _SearchSort.smart;
  bool _includeOffline = true;

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
    setState(() => _draft = word);
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(searchProvider.notifier).suggest(draft));
    });
  }

  /// Runs the draft as the search's query, records it in the history and
  /// keeps the field's own text.
  void _onSubmitted(String draft) {
    _suggestDebounce?.cancel();
    setState(() => _draft = draft.trim());
    final word = draft.trim();
    if (word.isNotEmpty) unawaited(ref.read(searchHistoryProvider.notifier).commit(word));
    unawaited(ref.read(searchProvider.notifier).search(draft));
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
    final allPlatformIds = [
      for (final site in ref.watch(sitesProvider).all)
        if (visible.contains(site.manifest.id)) site.manifest.id,
    ];
    final word = _draft.trim().isEmpty ? search.query.trim() : _draft.trim();
    final canWebSearch = scope != kSearchAllPlatforms && webSearchUrl(scope, word) != null;
    final link = _linkIn(word);
    final linkState = ref.watch(linkToolProvider);
    final view = _viewOf(search);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final platforms = [kSearchAllPlatforms, ...allPlatformIds];
    void chooseScope(String id) {
      if (id == scope) return;
      ref.read(searchSiteIdProvider.notifier).selected = id;
      _field.clear();
      setState(() => _draft = '');
      unawaited(ref.read(searchProvider.notifier).search(''));
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
              final narrow = LiveWindow.stacksToolbar(constraints.maxWidth);
              final tabs = PlatformTabRow(
                platforms: platforms,
                current: scope,
                nameOf: _platformName,
                semanticLabel: context.t.search.targetsLabel,
                showPlatformWall: !narrow,
                showLayoutToggle: !narrow,
                // The panel's way to the hide/reorder setting.
                onManagePlatforms: managePlatforms,
                onChanged: chooseScope,
              );
              if (!narrow) return tabs;
              return SizedBox(
                height: 44,
                child: Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(child: tabs),
                    PlatformToolbarMore(
                      platforms: platforms,
                      current: scope,
                      nameOf: _platformName,
                      onChanged: chooseScope,
                      onManagePlatforms: managePlatforms,
                    ),
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
                    // A compact window keeps the secondary action an icon;
                    // the count rides the kit's anchored badge.
                    if (LiveWindow.isCompact(MediaQuery.sizeOf(context).width)) {
                      return DsAnchoredBadge(
                        badge: active == 0 ? const SizedBox.shrink() : DsCount(active, semanticLabel: '$active'),
                        child: DsButton.icon(
                          variant: active == 0 ? DsButtonVariant.secondary : DsButtonVariant.tinted,
                          size: DsSize.sm,
                          semanticLabel: active == 0
                              ? context.t.search.filterTitle
                              : '${context.t.search.filterTitle}, $active',
                          onPressed: controller.toggle,
                          icon: const DsIcon(DsIcons.slidersHorizontal, size: 16),
                        ),
                      );
                    }
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
        if (targets.length >= 2)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
            child: _TargetSegments(
              targets: targets,
              selected: search.target,
              onChanged: (target) => unawaited(ref.read(searchProvider.notifier).switchTarget(target)),
            ),
          ),
        if (link != null)
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
        Expanded(
          child: _SearchResults(search: view, targets: targets),
        ),
      ],
    );
  }

  /// Opens the chosen platform's own search page in the app's web view.
  Future<void> _openWebSearch() async {
    final t = context.t;
    final scope = ref.read(searchSiteIdProvider);
    if (scope == kSearchAllPlatforms) {
      showDsToast(context: context, title: t.search.webSearchSelectPlatform);
      return;
    }
    final word = (_draft.trim().isEmpty ? ref.read(searchProvider).query : _draft).trim();
    final uri = webSearchUrl(scope, word);
    if (uri == null) {
      showDsToast(context: context, title: t.search.webSearchUnavailable);
      return;
    }
    if (!mounted) return;
    await context.push(
      RouteNames.webSearch,
      extra: WebSearchRequest(uri: uri, platform: scope, keyword: word),
    );
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
  SearchState _viewOf(SearchState search) {
    if (search.target == LiveSearchTarget.areas) return search;
    var rooms = search.rooms;
    var anchors = search.anchors;
    if (!_includeOffline) {
      rooms = [
        for (final room in rooms)
          if (room.broadcast.isLiveNow) room,
      ];
      anchors = [
        for (final anchor in anchors)
          if (anchor.liveStatus == LiveStatus.live) anchor,
      ];
    }
    if (_sort != _SearchSort.smart) {
      rooms = _sortRooms(rooms);
      anchors = _sortAnchors(anchors);
    }
    return (
      query: search.query,
      target: search.target,
      rooms: rooms,
      anchors: anchors,
      areas: search.areas,
      nextPage: search.nextPage,
      hasMore: search.hasMore,
      loading: search.loading,
      error: search.error,
      suggestions: search.suggestions,
    );
  }

  List<LiveRoom> _sortRooms(List<LiveRoom> rooms) {
    final indexed = rooms.indexed.toList()
      ..sort((a, b) {
        final left = a.$2;
        final right = b.$2;
        final order = switch (_sort) {
          _SearchSort.platform => left.ref.platform.compareTo(right.ref.platform),
          _SearchSort.audience => _audienceOf(right).compareTo(_audienceOf(left)),
          _SearchSort.followers => _followersOf(right).compareTo(_followersOf(left)),
          _SearchSort.smart => 0,
        };
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, room) in indexed) room];
  }

  List<LiveAnchor> _sortAnchors(List<LiveAnchor> anchors) {
    final indexed = anchors.indexed.toList()
      ..sort((a, b) {
        final order = switch (_sort) {
          _SearchSort.platform => a.$2.platform.compareTo(b.$2.platform),
          _SearchSort.audience ||
          _SearchSort.followers => (b.$2.followerCount ?? -1).compareTo(a.$2.followerCount ?? -1),
          _SearchSort.smart => 0,
        };
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, anchor) in indexed) anchor];
  }

  static int _audienceOf(LiveRoom room) =>
      room.audience.onlineViewers ?? room.audience.popularity ?? room.audience.totalViewers ?? -1;

  static int _followersOf(LiveRoom room) => room.anchor?.followerCount ?? -1;

  static String? _linkIn(String text) => RegExp(r'https?://[^\s，。；;“”‘’<>]+').firstMatch(text)?.group(0);

  String _sortLabel(BuildContext context, _SearchSort sort) => switch (sort) {
    _SearchSort.smart => context.t.search.sortSmart,
    _SearchSort.platform => context.t.search.sortPlatform,
    _SearchSort.audience => context.t.search.sortAudience,
    _SearchSort.followers => context.t.search.sortFollowers,
  };

  Future<void> _openLink(String text) async {
    await ref.read(linkToolProvider.notifier).resolve(text);
    if (!mounted) return;
    final link = ref.read(linkToolProvider);
    if (link.resolved case final room?) {
      await openRoom(context, platform: room.platform, roomId: room.roomId);
      return;
    }
    showDsToast(context: context, title: context.t.search.linkFailed);
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
  const _SearchResults({required this.search, required this.targets});

  /// The search being shown.
  final SearchState search;

  /// The targets the site searches; empty when it cannot search at all.
  final List<LiveSearchTarget> targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final empty = search.rooms.isEmpty && search.anchors.isEmpty && search.areas.isEmpty;
    if (search.query.isEmpty) {
      if (targets.isEmpty) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.searchX),
            title: Text(t.search.unsupportedTitle),
            description: Text(t.search.unsupportedDescription),
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
        LiveSearchTarget.anchors || LiveSearchTarget.areas => const _ListSkeleton(),
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
          final profile = (anchor.profileUrl ?? '').trim();
          return _AnchorCard(
            anchor: anchor,
            onOpen: profile.isEmpty
                ? null
                : () => unawaited(launchUrl(Uri.parse(profile), mode: LaunchMode.externalApplication)),
          );
        },
        hasMore: search.hasMore,
        loading: search.loading,
      ),
      LiveSearchTarget.areas => _ListResults(
        items: search.areas,
        itemBuilder: (context, item) {
          final area = item as LiveArea;
          final openable = area.platform.trim().isNotEmpty && area.areaId.trim().isNotEmpty;
          return AreaCard(
            area: area,
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
        hasMore: search.hasMore,
        loading: search.loading,
      ),
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
      void open() => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: search.rooms);
      return RoomCardMenu(
        room: room,
        onOpen: open,
        child: RoomCard(room: room, listRow: listRow, onOpen: open),
      );
    }

    return CardGrid<LiveRoom>(
      items: search.rooms,
      layout: ref.watch(browseLayoutProvider),
      listMatchesGridWidth: true,
      listMainAxisExtent: kRoomCardListDesignHeight,
      listItemBuilder: (context, room) => cardFor(context, room, listRow: true),
      isLoading: search.loading,
      hasMore: search.hasMore,
      onLoadMore: controller.loadMore,
      itemBuilder: cardFor,
    );
  }
}

/// The anchors and areas targets' list: one full-width column of cards that
/// pages in exactly like the rooms grid, so every target pages the same way.
final class _ListResults extends ConsumerWidget {
  const _ListResults({required this.items, required this.itemBuilder, required this.hasMore, required this.loading});

  /// The hits shown, in order.
  final List<Object> items;

  /// Builds the card at each index.
  final Widget Function(BuildContext context, Object item) itemBuilder;

  /// Whether another page can be loaded.
  final bool hasMore;

  /// Whether a page is loading now.
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchProvider.notifier);
    return CardList<Object>(
      items: items,
      itemBuilder: itemBuilder,
      hasMore: hasMore,
      isLoading: loading,
      onLoadMore: controller.loadMore,
    );
  }
}

/// One streamer hit as a list card: the avatar (a dot when live), the name
/// with its verified mark, the self description, and the follower figure. A
/// live hit says so instead of counting followers — that is the actionable
/// fact. The card opens the streamer's platform profile when the result
/// carries one; without it the card stays inert rather than pretending a
/// page exists.
final class _AnchorCard extends StatelessWidget {
  const _AnchorCard({required this.anchor, this.onOpen});

  /// The streamer shown.
  final LiveAnchor anchor;

  /// Opens the streamer's profile; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final live = anchor.liveStatus == LiveStatus.live;
    final followers = AudienceFormat.format(anchor.followerCount);
    return DsCard(
      onPressed: onOpen,
      semanticLabel: anchor.name,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsAvatar(
            initials: anchor.name,
            image: anchor.avatarUrl == null ? null : cachedImage(anchor.avatarUrl!),
            size: DsSize.md,
            toneIndex: DsAvatar.toneFor(anchor.anchorId.isEmpty ? anchor.name : anchor.anchorId),
            status: live ? DsStatus.success : null,
            statusLabel: live ? context.t.search.liveBadge : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Row(
                  spacing: DsSpace.s6,
                  children: [
                    Flexible(
                      child: Text(
                        anchor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    if (anchor.isVerified ?? false)
                      DsIcon(DsIcons.badgeCheck, size: theme.sizes.iconXs, color: colors.accentText),
                  ],
                ),
                if ((anchor.introduction ?? '').trim().isNotEmpty)
                  Text(
                    anchor.introduction!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          if (live)
            DsBadge(label: Text(context.t.search.liveBadge), status: DsStatus.danger)
          else if (followers.isNotEmpty)
            Row(
              spacing: DsSpace.s4,
              children: [
                DsIcon(DsIcons.users, size: theme.sizes.iconXs, color: colors.textSubtle),
                Text(
                  followers,
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                ),
              ],
            ),
        ],
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
