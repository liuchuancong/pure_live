import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/popular/popular.dart';
import 'package:pure_live/features/search/search_controller.dart';
import 'package:pure_live/features/search/web_search_page.dart' show WebSearchRequest;
import 'package:pure_live/features/search/web_search_urls.dart' show webSearchUrl;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/toolbox/toolbox.dart';
import 'package:pure_live/l10n/translations.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: PlatformTabRow(
            platforms: [kSearchAllPlatforms, ...allPlatformIds],
            current: scope,
            nameOf: _platformName,
            semanticLabel: context.t.search.targetsLabel,
            onChanged: (id) {
              if (id == scope) return;
              ref.read(searchSiteIdProvider.notifier).selected = id;
              _field.clear();
              setState(() => _draft = '');
              unawaited(ref.read(searchProvider.notifier).search(''));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
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
              DsButton(
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.globe, size: 16),
                onPressed: canWebSearch ? () => unawaited(_openWebSearch()) : null,
                child: Text(context.t.search.webSearch),
              ),
            ],
          ),
        ),
        if (_showHistory(search))
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
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
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
            child: _TargetSegments(
              targets: targets,
              selected: search.target,
              onChanged: (target) => unawaited(ref.read(searchProvider.notifier).switchTarget(target)),
            ),
          ),
        if (link != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
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
        if (search.query.isNotEmpty && search.target != LiveSearchTarget.areas)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  child: AdaptiveChoiceField<_SearchSort>(
                    value: _sort,
                    title: context.t.search.sort,
                    semanticLabel: context.t.search.sort,
                    onChanged: (value) => setState(() => _sort = value),
                    options: [
                      for (final sort in _SearchSort.values)
                        DsSelectOption(value: sort, label: _sortLabel(context, sort)),
                    ],
                  ),
                ),
                DsChip(
                  label: Text(context.t.search.includeOffline),
                  selected: _includeOffline,
                  onChanged: (value) => setState(() => _includeOffline = value),
                ),
              ],
            ),
          ),
        if (_showSuggestions(search))
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
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
          return _AreaCard(
            area: area,
            onOpen: openable
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
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    return CardGrid<LiveRoom>(
      items: search.rooms,
      layout: ref.watch(browseLayoutProvider),
      aspectRatio: ref.watch(roomCardAppearanceProvider).layout == RoomCardLayout.compact
          ? CardGrid.roomCardCompactAspectRatio
          : CardGrid.roomCardAspectRatio,
      listItemBuilder: (context, room) => RoomCard(
        room: room,
        compact: true,
        onOpen: () => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: search.rooms),
      ),
      cardExtent: cardExtent,
      isLoading: search.loading,
      hasMore: search.hasMore,
      onLoadMore: controller.loadMore,
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: search.rooms),
      ),
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
    return DsPressable(
      onPressed: onOpen,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : theme.shadows.surface,
          ),
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
      },
    );
  }
}

/// One area hit as a list card: the area's icon in a rounded tile (a hash
/// tile when the site ships none), its name, and the parent group it nests
/// under. The card opens the area's room list; null leaves it inert.
final class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, this.onOpen});

  /// The area shown.
  final LiveArea area;

  /// Opens the area's rooms; null leaves the card inert.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final parent = (area.parentAreaName ?? '').trim();
    return DsPressable(
      onPressed: onOpen,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : theme.shadows.surface,
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              _AreaIcon(area: area),
              Expanded(
                child: Text(
                  area.areaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
              ),
              if (parent.isNotEmpty)
                Text(
                  parent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// An area's picture: the icon the site ships, or a hash tile when it ships
/// none — either way the tile keeps its square place beside the name.
final class _AreaIcon extends StatelessWidget {
  const _AreaIcon({required this.area});

  /// The area whose icon shows.
  final LiveArea area;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final icon = (area.iconUrl ?? '').trim();
    final fallback = ColoredBox(
      color: colors.control,
      child: Center(
        child: DsIcon(DsIcons.hash, size: theme.sizes.iconSm, color: colors.textMuted),
      ),
    );
    return SizedBox(
      width: theme.sizes.md,
      height: theme.sizes.md,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.control(theme.sizes.md)),
        child: icon.isEmpty
            ? fallback
            : DsImage(
                image: cachedImage(icon),
                width: theme.sizes.md,
                height: theme.sizes.md,
                semanticLabel: area.areaName,
                fallback: fallback,
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
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    return CardGrid<LiveRoom>(
      items: const [],
      layout: ref.watch(browseLayoutProvider),
      aspectRatio: ref.watch(roomCardAppearanceProvider).layout == RoomCardLayout.compact
          ? CardGrid.roomCardCompactAspectRatio
          : CardGrid.roomCardAspectRatio,
      cardExtent: cardExtent,
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
