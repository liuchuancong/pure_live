import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/home/room_card.dart' show RoomCard, RoomCardSkeleton;
import 'package:pure_live/features/search/search_controller.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// How many completions the panel shows at most: a handful keeps the field's
/// reach honest while bounding the panel's height in a short window.
const int _maxSuggestionsShown = 5;

/// The live module's search: one field over the selected site's search.
///
/// Typing asks the site for completions (debounced by the field); submitting
/// runs the query, whose target — rooms, streamers or areas, whichever the
/// site actually searches — switches on the segments above the results.
/// Rooms page in as a masonry grid of cards; streamers and areas page the
/// same way as list cards. A site without search says so in the results'
/// place instead of failing silently.
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

  /// Runs the draft as the search's query and keeps the field's own text.
  void _onSubmitted(String draft) {
    _suggestDebounce?.cancel();
    setState(() => _draft = draft.trim());
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
    final targets = SearchController.supportedTargetsOf(ref.watch(selectedSiteProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: DsSearchField(
            controller: _field,
            autofocus: true,
            placeholder: context.t.common.searchHint,
            onChanged: _onDraftChanged,
            onSubmitted: _onSubmitted,
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
          child: _SearchResults(search: search, targets: targets),
        ),
      ],
    );
  }

  /// Whether the completions panel shows: only while a draft that is not the
  /// committed query has completions to offer.
  bool _showSuggestions(SearchState search) {
    final word = _draft.trim();
    return word.isNotEmpty && word != search.query && search.suggestions.isNotEmpty;
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
        itemCount: search.anchors.length,
        itemBuilder: (context, index) => _AnchorCard(anchor: search.anchors[index]),
        hasMore: search.hasMore,
        loading: search.loading,
        endReachedKey: 'anchors:${search.query}',
      ),
      LiveSearchTarget.areas => _ListResults(
        itemCount: search.areas.length,
        itemBuilder: (context, index) => _AreaCard(area: search.areas[index]),
        hasMore: search.hasMore,
        loading: search.loading,
        endReachedKey: 'areas:${search.query}',
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
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: search.rooms.length,
      itemBuilder: (context, index) => RoomCard(room: search.rooms[index], onOpen: () => context.push(RoomRoute(platform: search.rooms[index].ref.platform, roomId: search.rooms[index].ref.roomId).location)),
      footer: search.loading
          ? const Padding(
              padding: EdgeInsets.all(DsSpace.s16),
              child: Center(child: RoomCardSkeleton()),
            )
          : null,
      onEndReached: search.hasMore ? () => unawaited(controller.loadMore()) : null,
      endReachedKey: 'rooms:${search.query}',
    );
  }
}

/// The anchors and areas targets' list: one full-width column of cards that
/// pages in exactly like the rooms grid, so every target pages the same way.
final class _ListResults extends ConsumerWidget {
  const _ListResults({
    required this.itemCount,
    required this.itemBuilder,
    required this.hasMore,
    required this.loading,
    required this.endReachedKey,
  });

  /// How many cards the list holds.
  final int itemCount;

  /// Builds the card at each index.
  final IndexedWidgetBuilder itemBuilder;

  /// Whether another page can be loaded.
  final bool hasMore;

  /// Whether a page is loading now.
  final bool loading;

  /// What these items were loaded for; a change re-arms the paging.
  final Object endReachedKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(searchProvider.notifier);
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: const MosaicColumns.count(1),
      rowGap: DsSpace.s12,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      footer: loading
          ? const Padding(
              padding: EdgeInsets.all(DsSpace.s16),
              child: Center(child: _ListCardSkeleton()),
            )
          : null,
      onEndReached: hasMore ? () => unawaited(controller.loadMore()) : null,
      endReachedKey: endReachedKey,
    );
  }
}

/// One streamer hit as a list card: the avatar (a dot when live), the name
/// with its verified mark, the self description, and the follower figure. A
/// live hit says so instead of counting followers — that is the actionable
/// fact. The card stays inert until the room page arrives.
final class _AnchorCard extends StatelessWidget {
  const _AnchorCard({required this.anchor});

  /// The streamer shown.
  final LiveAnchor anchor;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final live = anchor.liveStatus == LiveStatus.live;
    final followers = AudienceFormat.format(anchor.followerCount);
    return DsPressable(
      onPressed: null,
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
                image: anchor.avatarUrl == null ? null : NetworkImage(anchor.avatarUrl!),
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
/// under. The card stays inert until the rooms page arrives.
final class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area});

  /// The area shown.
  final LiveArea area;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final parent = (area.parentAreaName ?? '').trim();
    return DsPressable(
      onPressed: null,
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
            : DsImage.network(
                icon,
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
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      children: [for (var i = 0; i < 12; i++) const RoomCardSkeleton()],
    );
  }
}

/// The anchors and areas targets' first-page placeholder: the list card's
/// own shape — a round tile and two text lines — no content.
final class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: const MosaicColumns.count(1),
      rowGap: DsSpace.s12,
      children: [for (var i = 0; i < 8; i++) const _ListCardSkeleton()],
    );
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
