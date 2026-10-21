import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowRepository, LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveFollowGroup;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/app/shell/shell_destinations.dart' show ShellBranch;
import 'package:pure_live/features/follow/follow_rules.dart';
import 'package:pure_live/features/follow/live_alert_service.dart';
import 'package:pure_live/features/room/paging.dart';
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_live/shared/widgets/room_card.dart';
import 'package:pure_live/shared/widgets/room_grid.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/layout/main_layout.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page width from which the platform tabs join the status tabs in the
/// app bar (the reference's `favoriteOneRowWidth`, A09.3 c3).
const double favoriteOneRowWidth = 840;

/// The reference's `favoriteLargeCardMinWidth`: the smallest large card when
/// the grid is not compact — one column on a phone, like 3.x.
const double favoriteLargeCardMinWidth = 300;

/// Follows, in the reference's v5 shape (FavoritePage, A09.3): the
/// live/replay/offline tabs where the title would be (both tab rows show
/// their numbers), the platform tabs ("all" and every platform with
/// follows) — from [favoriteOneRowWidth] sitting right of the status tabs in
/// one row, below it in the bar's second line — the tag strip, and one grid
/// per platform, swipeable.
///
/// Live and replay follows draw cards; offline follows draw compact rows.
/// Desktops get numbered pages with ← → keys; elsewhere pull to refresh.
/// Re-selecting the follows tab refreshes it; a refresh failure toasts its
/// count. The whole list reads the repository's own store, so a second
/// window's follows appear here too.
final class FollowPage extends ConsumerStatefulWidget {
  /// The follow page.
  const new({super.key});

  @override
  ConsumerState<FollowPage> createState() => _FollowPageState();
}

final class _FollowPageState extends ConsumerState<FollowPage> with FeedAutoRefresh<FollowPage> {
  static const String _allPlatforms = '';

  StreamSubscription<void>? _changes;
  StreamSubscription<String>? _reTaps;
  bool _loaded = false;
  int _status = 0;
  int _platform = 0;
  String? _tagId;
  final ValueNotifier<double?> _progress = ValueNotifier(null);
  List<String> _platforms = const [_allPlatforms];

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  LiveFollowGroup get _group => LiveFollowGroup.values[_status];

  @override
  bool get feedVisible => true;

  @override
  Future<void> feedRefresh() async {
    _progress.value = 0;
    try {
      await _repository.load();
      // The stored list is only as good as the last time someone asked the
      // platforms: this is the pass that turns 关注 into "who is live now", and
      // the same pass the interval clock runs.
      final result = await ref.read(liveAlertServiceProvider).refresh();
      if (result.failed > 0 && mounted) {
        PureToast.show(context, context.t.follow.refreshFailed(count: result.failed), type: PureToastType.warning);
      }
    } on Object {
      // The list keeps whatever it already showed, and the viewer hears that
      // this refresh did not land. Without the catch the failure left the
      // `unawaited(...)` that starts it and nothing on screen moved — the
      // class doc's promise of a toast was the one thing the code did not do.
      if (mounted) {
        PureToast.show(context, context.t.errors.network, type: PureToastType.error);
      }
    } finally {
      _progress.value = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      _repository.load().then((_) {
        if (mounted) setState(() => _loaded = true);
      }),
    );
    _changes = _repository.changes.listen((_) {
      if (mounted) setState(_syncPlatforms);
    });
    // Re-tapping the tab already on screen refreshes the follows — the
    // reference's favorites special case.
    _reTaps = ref
        .read(shellReTapSignalsProvider)
        .reTaps
        .where((branchId) => branchId == ShellBranch.follow.name)
        .listen((_) => unawaited(feedRefresh()));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_reTaps?.cancel());
    _progress.dispose();
    super.dispose();
  }

  /// One platform tab per platform with follows, keeping the platform shown
  /// by id; a platform that lost its last follow falls back to "all".
  void _syncPlatforms() {
    final records = _repository.rooms;
    final preferences = ref.read(appPreferencesProvider);
    final ids = <String>[
      _allPlatforms,
      ...followPlatformTabs(
        [for (final record in records) record.room],
        preferences.siteOrder,
        registryOrder: [for (final site in ref.read(sitesProvider).registry.all) site.manifest.id],
      ),
    ];
    if (_sameIds(ids, _platforms)) return;
    final current = _platforms[_platform.clamp(0, _platforms.length - 1)];
    _platforms = ids;
    final index = ids.indexOf(current);
    _platform = index < 0 ? 0 : index;
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The follows of the shown tag, in the repository's order.
  List<LibraryRoom> get _tagged {
    final tagId = _tagId;
    final records = _repository.rooms;
    if (tagId == null) return records;
    return [
      for (final record in records)
        if (record.groupIds.contains(tagId)) record,
    ];
  }

  /// The rooms of one status group on one platform (the reference's
  /// `roomsFor`): filtered, then ordered — live and replay follows by the
  /// tag and audience ranking, offline follows in the user's own order.
  List<LibraryRoom> _roomsFor(LiveFollowGroup group, String platform) {
    final rooms = [
      for (final record in _tagged)
        if (record.room.broadcast.followGroup == group &&
            (platform == _allPlatforms || record.room.ref.platform == platform))
          record,
    ];
    if (group != LiveFollowGroup.offline) {
      final preferences = ref.read(appPreferencesProvider);
      final ordering = FollowOrdering(
        preferRealOnline: preferences.preferRealOnlineCounts,
        realOnlinePlatforms: preferences.realOnlinePlatforms.toSet(),
        tagRank: _tagRanks(),
      );
      rooms.sort((a, b) => ordering.compare(a.room, b.room));
    }
    return rooms;
  }

  /// Each room's best tag rank, when a tag is chosen: the strip's order is
  /// the weight, so the first tag outweighs the ones under it.
  Map<String, int> _tagRanks() {
    final tagId = _tagId;
    if (tagId == null) {
      return const {};
    }
    final groups = _repository.groups;
    final index = groups.indexWhere((group) => group.id == tagId);
    if (index < 0) {
      return const {};
    }
    final weight = groups.length - index;
    return {
      for (final record in _repository.rooms)
        if (record.groupIds.contains(tagId)) '${record.room.ref.platform}:${record.room.ref.roomId}': weight,
    };
  }

  String _platformLabel(String id) {
    if (id == _allPlatforms) return context.t.follow.all;
    final site = ref.read(sitesProvider).registry.getById(id);
    if (site == null) return id;
    return site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final tagged = _tagged;
    final phoneTab = MainPageFrame.showsHomeBarButtons(context, inHome: true);
    final oneRow = MediaQuery.sizeOf(context).width >= favoriteOneRowWidth;

    // Both tab rows show their numbers, counted within the other row's
    // selection (the reference's groupCounts).
    final statusCounts = [
      for (final group in LiveFollowGroup.values)
        _roomsFor(group, _platforms[_platform.clamp(0, _platforms.length - 1)]).length,
    ];
    final platformCounts = [for (final id in _platforms) _roomsFor(_group, id).length];

    final statusTabs = PureTabs(
      tabs: [
        PureTab(label: _statusLabel(LiveFollowGroup.values[0], statusCounts[0])),
        PureTab(label: _statusLabel(LiveFollowGroup.values[1], statusCounts[1])),
        PureTab(label: _statusLabel(LiveFollowGroup.values[2], statusCounts[2])),
      ],
      index: _status,
      onChanged: (index) => setState(() => _status = index),
    );
    final platformTabs = PureTabs(
      tabs: [
        for (var index = 0; index < _platforms.length; index++)
          PureTab(label: '${_platformLabel(_platforms[index])} ${platformCounts[index]}'),
      ],
      index: _platform.clamp(0, _platforms.length - 1),
      // One tab per followed platform, and the count is the user's: the strip
      // has to scroll rather than squeeze eight labels into a phone bar.
      isScrollable: true,
      onChanged: (index) => setState(() => _platform = index),
    );

    final title = oneRow
        ? Row(
            children: [
              Flexible(child: statusTabs),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: theme.colors.border,
              ),
              Expanded(child: platformTabs),
            ],
          )
        : statusTabs;

    return PureScaffold(
      appBar: PureAppBar(
        leading: phoneTab ? const HomeMenuButton() : null,
        title: t.tabs.follow,
        titleWidget: title,
        bottom: oneRow
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Align(alignment: AlignmentDirectional.centerStart, child: platformTabs),
              ),
      ),
      body: _body(context, tagged),
    );
  }

  String _statusLabel(LiveFollowGroup group, int count) {
    final t = context.t;
    final name = switch (group) {
      LiveFollowGroup.live => t.follow.liveRoom,
      LiveFollowGroup.replay => t.follow.replayRoom,
      LiveFollowGroup.offline => t.follow.offlineRoom,
    };
    return '$name $count';
  }

  Widget _body(BuildContext context, List<LibraryRoom> tagged) {
    final t = context.t;
    final Widget content;
    if (!_loaded) {
      content = FeedLoadingPlaceholder(
        delegateBuilder: (width) =>
            RoomGridMetrics.delegateFor(context, width, coverAspect: ref.watch(roomCardStyleProvider).aspect.ratio),
      );
    } else if (tagged.isEmpty) {
      content = PureEmpty(
        title: t.follow.empty,
        icon: Icons.favorite_border,
        action: PureButton(label: t.tabs.search, onPressed: () => openMenuBranch(context, ShellBranch.search)),
      );
    } else {
      content = Column(
        children: [
          _TagStrip(selectedId: _tagId, onSelected: (id) => setState(() => _tagId = id)),
          Expanded(
            child: PureTabView(
              index: _platform.clamp(0, _platforms.length - 1),
              onIndexChanged: (index) => setState(() => _platform = index),
              pages: [
                for (final id in _platforms)
                  _FollowGrid(
                    key: ValueKey('favorite-grid-$id-$_status'),
                    rooms: _roomsFor(_group, id),
                    allRooms: _roomsFor(_group, _allPlatforms),
                    mixed: id == _allPlatforms,
                    offline: _group == LiveFollowGroup.offline,
                    heroTag: 'favorite-$id',
                    selected: id == _platforms[_platform.clamp(0, _platforms.length - 1)],
                    progress: _progress,
                    onRefresh: feedRefresh,
                    onOpen: (record) => unawaited(
                      RoomRoute(
                        siteId: record.room.ref.platform,
                        roomId: record.room.ref.roomId,
                        roomName: record.room.content.title,
                      ).push<void>(context),
                    ),
                    onLongPress: (record) => unawaited(_assignGroups(record)),
                    emptyLabel: switch (_group) {
                      LiveFollowGroup.live => t.follow.emptyLive,
                      LiveFollowGroup.replay => t.follow.emptyReplay,
                      LiveFollowGroup.offline => t.follow.emptyOffline,
                    },
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double?>(
            valueListenable: _progress,
            builder: (context, value, _) =>
                value == null ? const SizedBox.shrink() : const PureProgress(value: null, height: 2.5),
          ),
        ),
      ],
    );
  }

  /// Long-press on a followed room: move it between tags (the same store the
  /// tag manager edits).
  Future<void> _assignGroups(LibraryRoom record) async {
    final selected = {...record.groupIds};
    final confirmed = await showSettingsSurface<bool>(
      context,
      ref.settingsFormFactor,
      title: context.t.follow.assign,
      body: (surfaceContext) => StatefulBuilder(
        builder: (context, setSurfaceState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in _repository.groups)
              PureCheckbox(
                label: group.name,
                value: selected.contains(group.id),
                onChanged: (checked) => setSurfaceState(() {
                  checked ? selected.add(group.id) : selected.remove(group.id);
                }),
              ),
          ],
        ),
      ),
      actions: (surfaceContext) => [
        PureButton(
          label: surfaceContext.t.common.confirm,
          icon: Icons.check,
          onPressed: () => Navigator.of(surfaceContext).pop(true),
        ),
        PureButton(
          label: surfaceContext.t.follow.unfollow,
          icon: Icons.heart_broken_outlined,
          onPressed: () {
            unawaited(_repository.unfollow(record.room));
            Navigator.of(surfaceContext).pop(true);
          },
        ),
      ],
    );
    if (confirmed == true) {
      await _repository.setGroups(record.room, selected.toList());
    }
  }
}

/// "All" and the tags the shown follows have (the reference's
/// `FavoriteTagStrip`, 48 high); hidden when there are none.
class _TagStrip extends ConsumerWidget {
  const new({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(followRepositoryProvider).groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    // One choice out of a scrolling strip is the tab strip's own contract;
    // the library's chip needs a Material sheet to print on, and this page
    // has none.
    final ids = <String?>[null, for (final group in groups) group.id];
    final selected = ids.indexOf(selectedId).clamp(0, ids.length - 1);
    return SizedBox(
      key: const ValueKey('favorite-tag-strip'),
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: PureTabs(
          index: selected,
          isScrollable: true,
          onChanged: (value) => onSelected(ids[value]),
          tabs: [
            PureTab(label: context.t.follow.all),
            for (final group in groups) PureTab(label: group.name),
          ],
        ),
      ),
    );
  }
}

/// The follows of one platform in the shown tab (the reference's
/// `_FollowGrid`): cards for live and replay follows, compact rows for
/// offline ones; wide windows get the shared numbered pager with ← →,
/// elsewhere pull to refresh. The jump buttons and the pager's size
/// selector and goto field answer to their settings, as in the reference.
class _FollowGrid extends ConsumerStatefulWidget {
  const new({
    required this.rooms,
    required this.allRooms,
    required this.mixed,
    required this.offline,
    required this.heroTag,
    required this.selected,
    required this.progress,
    required this.onRefresh,
    required this.onOpen,
    required this.onLongPress,
    required this.emptyLabel,
    super.key,
  });

  final List<LibraryRoom> rooms;
  final List<LibraryRoom> allRooms;
  final bool mixed;
  final bool offline;

  /// Unique per grid — the jump buttons of two grids may be alive at once.
  final String heroTag;

  /// Whether this grid's platform tab is the one on screen; its paged mode
  /// owns the ← → keys.
  final bool selected;

  /// The page's refresh progress; non-null while a refresh runs (pager busy).
  final ValueNotifier<double?> progress;

  final Future<void> Function() onRefresh;
  final void Function(LibraryRoom record) onOpen;
  final void Function(LibraryRoom record) onLongPress;
  final String emptyLabel;

  @override
  ConsumerState<_FollowGrid> createState() => _FollowGridState();
}

class _FollowGridState extends ConsumerState<_FollowGrid> {
  final ScrollController _scroll = ScrollController();

  /// The node the paged mode's ← → keys land on; every platform grid is
  /// kept alive, so the focus is taken on selection rather than by
  /// autofocus alone (`Focus(autofocus:)` only fires when the node first
  /// attaches).
  final FocusNode _pagerFocus = FocusNode();
  int _page = 1;

  /// A pager's per-page pick, until the window's width answers change the
  /// rule (the reference's local `_pageSize` override).
  int? _pageSizeOverride;

  @override
  void dispose() {
    _scroll.dispose();
    _pagerFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FollowGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      // An unattached node ignores the request, which is right off paging.
      _pagerFocus.requestFocus();
    }
  }

  void _goTo(int page) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = desktopPagesIn(ref, width);
    final sizes = pageSizesOf(preferences, width);
    final pageSize = _pageSizeOverride ?? sizes.size;
    final lastPage = widget.rooms.isEmpty ? 1 : (widget.rooms.length / pageSize).ceil();
    final page = _page.clamp(1, lastPage);
    final rooms = desktop
        ? widget.rooms.sublist((page - 1) * pageSize, (page * pageSize).clamp(0, widget.rooms.length))
        : widget.rooms;

    Widget grid() {
      if (rooms.isEmpty) {
        return Center(
          child: PureEmpty(
            title: widget.emptyLabel,
            icon: widget.offline ? Icons.cloud_off_outlined : Icons.live_tv_outlined,
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final listWidth = constraints.maxWidth;
          final gutter = MainLayout.gutterOf(context);
          if (widget.offline) {
            return ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xxl),
              itemCount: rooms.length,
              itemBuilder: (context, index) => _OfflineRow(
                record: rooms[index],
                onTap: () => widget.onOpen(rooms[index]),
                onLongPress: () => widget.onLongPress(rooms[index]),
              ),
            );
          }
          return RoomGrid(
            scrollController: _scroll,
            padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xxl),
            // The favourites ladder reads one card wider than the discovery grid
            // at the same width; the cards themselves set their own height.
            columns: RoomGridMetrics.favouriteColumnsFor(listWidth),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final record = rooms[index];
              return RoomCard(
                room: record.room,
                onOpen: () => widget.onOpen(record),
                onLongPress: () => widget.onLongPress(record),
              );
            },
          );
        },
      );
    }

    // The jump buttons answer to the same setting the paged lists honour, on
    // both interaction models (the reference's `showJumps`).
    Widget list() => Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: PrimaryScrollController(
              controller: _scroll,
              child: Builder(
                builder: (context) => SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(height: MediaQuery.sizeOf(context).height, child: grid()),
                ),
              ),
            ),
          ),
        ),
        if (preferences.pageShowScrollTop && widget.rooms.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: PureJumpButtons(controller: _scroll, heroTag: widget.heroTag),
          ),
      ],
    );

    if (!desktop) return list();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (page > 1) {
            _goTo(page - 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (page < lastPage) {
            _goTo(page + 1);
          }
        },
      },
      child: Focus(
        focusNode: _pagerFocus,
        autofocus: widget.selected,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: grid()),
                  if (preferences.pageShowScrollTop && widget.rooms.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: PureJumpButtons(controller: _scroll, heroTag: widget.heroTag),
                    ),
                ],
              ),
            ),
            ValueListenableBuilder<double?>(
              valueListenable: widget.progress,
              builder: (context, progress, _) => PurePaginationBar(
                page: page,
                lastPage: lastPage,
                canNext: page < lastPage,
                busy: progress != null,
                pageSize: pageSize,
                pageSizes: preferences.pageShowSizeSelector ? sizes.options : null,
                showGoto: preferences.pageShowGoto,
                onPage: _goTo,
                onPageSize: (size) {
                  // Keep the first room of the page in view (3.x).
                  final first = (page - 1) * pageSize;
                  setState(() {
                    _pageSizeOverride = size;
                    _page = first ~/ size + 1;
                  });
                },
                onRefresh: () => unawaited(widget.onRefresh()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact row for an offline follow (the reference's `RoomRow`): title,
/// anchor and an offline mark.
class _OfflineRow extends StatelessWidget {
  const new({required this.record, required this.onTap, required this.onLongPress});

  final LibraryRoom record;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final room = record.room;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: PureListRow(
        title: room.content.title.isEmpty ? context.t.room.offline : room.content.title,
        subtitle: room.anchor?.name,
        leading: const Icon(Icons.cloud_off_outlined),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: theme.colors.fillSecondary, borderRadius: BorderRadius.circular(10)),
          child: Text(context.t.follow.offlineRoom, style: theme.text.bodySmall),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
