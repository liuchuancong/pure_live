import 'dart:async';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LiveDiscoveryProvider, LivePageRequest, LiveRoom, LiveSite;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/shell/home_views.dart' show isHomeRailWidth;
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/features/room/paging.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/utilities/sites_order.dart' show orderedSites;
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_live/shared/widgets/room_card.dart';
import 'package:pure_live/shared/widgets/room_grid.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/layout/main_layout.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Popular, in the reference's v5 shape (A09.2): one tab per visible,
/// discovery-capable platform — the platform list honours the platform
/// display setting (hidden platforms have no tab, the stored order drives
/// the tabs) — and the tabs sit where the app bar's title would be, with a
/// ⌄ at their end that opens "all platforms" in a panel (a bottom sheet on
/// a phone, a right panel from the rail width up).
///
/// A tab loads once it settles (80 ms) and the next platform is fetched
/// 700 ms after this one shows its rooms; an empty platform list says where
/// to choose them. The feed itself is the workspace's infinite grid.
final class PopularPage extends ConsumerStatefulWidget {
  /// The popular page.
  const new({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

final class _PopularPageState extends ConsumerState<PopularPage> {
  int _selected = 0;
  final Set<String> _shouldLoad = {};
  Timer? _settle;
  Timer? _warm;
  String? _currentId;

  @override
  void dispose() {
    _settle?.cancel();
    _warm?.cancel();
    super.dispose();
  }

  void _selectTo(List<LiveSite> sites, int index) {
    setState(() => _selected = index);
    final id = sites[index].manifest.id;
    _settle?.cancel();
    _warm?.cancel();
    _settle = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _shouldLoad.add(id));
      _currentId = id;
    });
  }

  void _firstContent(String id, List<LiveSite> sites) {
    if (!mounted || _currentId != id) return;
    final index = sites.indexWhere((site) => site.manifest.id == id);
    if (index < 0 || sites.length < 2) return;
    // Fetch the next platform while the user looks at this one (3.x).
    _warm?.cancel();
    _warm = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _currentId != id) return;
      final next = index + 1 < sites.length ? index + 1 : index - 1;
      setState(() => _shouldLoad.add(sites[next].manifest.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final sites = ref
        .watch(sitesProvider)
        .registry
        .all
        .where((site) => site.capability<LiveDiscoveryProvider>() != null)
        .toList();
    final visible = orderedSites(
      sites,
      preferences.siteOrder,
    ).where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id)).toList();
    final phoneTab = MainPageFrame.showsHomeBarButtons(context, inHome: true);
    final index = visible.isEmpty ? 0 : _selected.clamp(0, visible.length - 1);
    if (_currentId == null && visible.isNotEmpty) {
      // The first tab loads after the same settle the switches use.
      _currentId = visible[index].manifest.id;
      _settle = Timer(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _shouldLoad.add(visible[index].manifest.id));
      });
    }

    final title = visible.isEmpty
        ? null
        : Row(
            children: [
              Expanded(
                child: PureTabs(
                  tabs: [for (final site in visible) PureTab(label: _name(context, site))],
                  index: index,
                  // One tab per visible platform in the space left of the
                  // "all platforms" button; the count is the user's.
                  isScrollable: true,
                  onChanged: (value) => _selectTo(visible, value),
                ),
              ),
              PureIconButton(
                key: const ValueKey('popular-all-platforms'),
                icon: Icons.expand_more_rounded,
                tooltip: t.popular.allPlatforms,
                onPressed: () => unawaited(_pickPlatform(visible, index)),
              ),
            ],
          );

    return PureScaffold(
      appBar: PureAppBar(
        leading: phoneTab ? const HomeMenuButton() : null,
        title: t.tabs.popular,
        titleWidget: title,
        actions: phoneTab ? const [CommonAppBarActions()] : const [],
      ),
      body: visible.isEmpty
          ? PureEmpty(
              title: t.popular.noPlatforms,
              message: t.popular.noPlatformsHint,
              icon: Icons.live_tv_outlined,
              action: PureButton(
                label: t.hotAreas.title,
                icon: Icons.visibility_outlined,
                onPressed: () => unawaited(const HotAreasRoute().push<void>(context)),
              ),
            )
          : PureTabView(
              index: index,
              onIndexChanged: (value) => _selectTo(visible, value),
              pages: [
                for (var i = 0; i < visible.length; i++)
                  _SiteFeed(
                    key: ValueKey('popular-${visible[i].manifest.id}'),
                    site: visible[i],
                    shouldLoad: _shouldLoad.contains(visible[i].manifest.id),
                    selected: i == index,
                    onFirstContent: () => _firstContent(visible[i].manifest.id, visible),
                  ),
              ],
            ),
    );
  }

  static String _name(BuildContext context, LiveSite site) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');

  Future<void> _pickPlatform(List<LiveSite> sites, int current) async {
    final width = MediaQuery.sizeOf(context).width;
    final side = isHomeRailWidth(width);
    final picker = _PlatformPicker(sites: sites, current: current);
    final picked = side
        ? await showGeneralDialog<int>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'platform-picker',
            pageBuilder: (context, _, _) => Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Material(
                color: PureTheme.of(context).colors.bgElevated,
                elevation: 8,
                child: SizedBox(width: 360, child: picker),
              ),
            ),
          )
        : await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) => ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.71),
              child: picker,
            ),
          );
    if (picked != null && mounted) _selectTo(sites, picked);
  }
}

/// "All platforms" (A09.2 c2): every platform of the tabs with its mark and
/// name, the current one ticked; a tap switches to it and closes the panel;
/// "平台显示" opens the settings that hide and order them. The same content
/// rises from the bottom on phones and sits on the right on wide screens.
class _PlatformPicker extends StatelessWidget {
  const new({required this.sites, required this.current});

  final List<LiveSite> sites;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text(t.popular.allPlatforms, style: theme.text.title)),
                PureButton(
                  key: const ValueKey('popular-platform-settings'),
                  label: t.hotAreas.title,
                  variant: ButtonVariant.ghost,
                  icon: Icons.settings_outlined,
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(const HotAreasRoute().push<void>(context));
                  },
                ),
                PureIconButton(
                  icon: Icons.close_rounded,
                  tooltip: t.common.close,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              t.popular.allPlatformsHint,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
          ),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 84).floor().clamp(3, 6);
                return GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 4,
                    mainAxisExtent: 84,
                  ),
                  itemCount: sites.length,
                  itemBuilder: (context, index) => _PlatformTile(
                    site: sites[index],
                    selected: index == current,
                    onTap: () => Navigator.of(context).pop(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const new({required this.site, required this.selected, required this.onTap});

  final LiveSite site;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final name = _PopularPageState._name(context, site);
    return PureBox(
      key: ValueKey('popular-platform-${site.manifest.id}'),
      style: (state) => Style(
        background: selected
            ? theme.colors.fillSecondary
            : switch (state) {
                InteractionState.hovered => theme.colors.fillQuaternary,
                InteractionState.pressed => theme.colors.fillTertiary,
                _ => null,
              },
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
      child: Semantics(
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colors.fillTertiary,
                      child: Text(name.characters.first, style: theme.text.title.copyWith(color: theme.colors.text)),
                    ),
                    if (selected)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colors.bgElevated, width: 2),
                          ),
                          child: Icon(Icons.check_rounded, size: 12, color: theme.colors.textLightSolid),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // A long Latin name (SHOWROOM, YouTube Live) narrows a
              // little rather than losing its end to an ellipsis.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: theme.text.bodySmall.copyWith(
                    color: selected ? theme.colors.text : theme.colors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One platform's recommend feed: an infinite grid over the discovery
/// capability, kept alive across tab switches.
///
/// The feed loads when the page says it may — when its tab settles or when
/// the previous platform pre-warmed it — and reports its first content so
/// the page can schedule the next pre-warm (the reference's 80 ms / 700 ms
/// rhythm).
final class _SiteFeed extends ConsumerStatefulWidget {
  /// A feed for [site].
  const new({
    required this.site,
    required this.shouldLoad,
    required this.selected,
    required this.onFirstContent,
    super.key,
  });

  final LiveSite site;

  /// Whether the page has settled on (or pre-warmed) this platform.
  final bool shouldLoad;

  /// Whether this platform's tab is the one on screen — its paged mode owns
  /// the keyboard focus that ← → land on.
  final bool selected;

  /// Called once, when the first rooms (or the empty/error answer) show.
  final VoidCallback onFirstContent;

  @override
  ConsumerState<_SiteFeed> createState() => _SiteFeedState();
}

final class _SiteFeedState extends ConsumerState<_SiteFeed>
    with AutomaticKeepAliveClientMixin, FeedAutoRefresh<_SiteFeed> {
  late final InfiniteController<LiveRoom> _controller = InfiniteController(loader: _load);
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);
  bool _started = false;
  bool _reported = false;
  bool _active = true;

  /// The shown desktop page and the pager's per-page pick (the reference's
  /// `RoomFeed` keeps one accumulating list and slices it per page).
  int _page = 1;
  int? _sizeOverride;

  /// Whether an "append until this page is filled" walk is running.
  bool _ensuring = false;

  /// The node the paged mode's ← → keys land on. Every tab is kept alive,
  /// so the focus is taken on selection rather than by autofocus alone —
  /// `Focus(autofocus:)` only fires when the node first attaches.
  final FocusNode _pagerFocus = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  bool get feedVisible => _active;

  @override
  Future<void> feedRefresh() => _controller.refresh();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
    _maybeStart();
  }

  @override
  void didUpdateWidget(_SiteFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldLoad && !_started) _maybeStart();
    // The tab that just came on screen owns the ← → keys; an unattached
    // node simply ignores the request, which is right off the paged mode.
    if (widget.selected && !oldWidget.selected) _pagerFocus.requestFocus();
  }

  void _maybeStart() {
    if (_started || !widget.shouldLoad) return;
    _started = true;
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _scroll.dispose();
    _pagerFocus.dispose();
    super.dispose();
  }

  void _onState(InfiniteState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
    if (!_reported && (state.items.isNotEmpty || state.error != null || (!state.isRefreshing && !state.isUnloaded))) {
      _reported = true;
      widget.onFirstContent();
    }
    if (state.items.isEmpty) {
      return;
    }
    if (_desktopPages()) {
      // The shown page needs its rooms: keep appending until the window is
      // filled or the walk ends (the reference's `feed.ensure`).
      unawaited(_ensureFilled(_page * _pageSize()));
      return;
    }
    // A list shorter than the screen cannot be scrolled to its end: ask for
    // more right away (3.x's footer needed a drag).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _scroll.positions.length != 1) {
        return;
      }
      final current = _controller.state;
      if (_scroll.position.maxScrollExtent <= 0 &&
          current.hasMore &&
          !current.isLoadingMore &&
          !current.isRefreshing &&
          current.error == null) {
        unawaited(_controller.loadNext());
      }
    });
  }

  bool _desktopPages() => desktopPagesIn(ref, MediaQuery.sizeOf(context).width);

  int _pageSize() =>
      _sizeOverride ?? pageSizesOf(ref.read(appPreferencesProvider), MediaQuery.sizeOf(context).width).size;

  Future<void> _ensureFilled(int count) async {
    if (_ensuring) {
      return;
    }
    _ensuring = true;
    try {
      while (mounted) {
        final state = _controller.state;
        if (state.items.length >= count ||
            !state.hasMore ||
            state.isLoadingMore ||
            state.isRefreshing ||
            state.error != null) {
          break;
        }
        final before = state.items.length;
        final appended = await _controller.loadNext();
        if (!appended && _controller.state.items.length == before) {
          break;
        }
      }
    } finally {
      _ensuring = false;
    }
  }

  /// A page change: start at the top, then make sure the page has rooms.
  Future<void> _goToPage(int page) async {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    setState(() => _page = page);
    await _ensureFilled(page * _pageSize());
  }

  void _onScroll() {
    // Desktop pages never grow at the end; the bar is the only way on.
    if (_desktopPages()) {
      return;
    }
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
    _active = widget.shouldLoad;
    final coverAspect = ref.watch(roomCardStyleProvider).aspect.ratio;
    final gutter = MainLayout.gutterOf(context);
    final state = _controller.state;
    if (state.items.isEmpty) {
      if (!_started) {
        return const SizedBox.shrink();
      }
      if (state.error != null) {
        return PureError(
          message: context.t.errors.network,
          onRetry: _controller.retry,
          retryLabel: context.t.common.retry,
        );
      }
      if (state.isRefreshing || state.isUnloaded) {
        return FeedLoadingPlaceholder(
          padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xl),
          delegateBuilder: (width) =>
              RoomGridMetrics.delegateFor(context, width, coverAspect: coverAspect, gutter: gutter),
        );
      }
      return PureEmpty(
        title: context.t.popular.empty,
        icon: Icons.local_fire_department_outlined,
        action: PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _controller.retry),
      );
    }
    // One accumulating feed, two ways to read it (the reference's
    // `RoomFeedView`): phones grow the list at its end, wide windows slice
    // it into numbered pages — the slice for page N waits on the appends
    // that fill it.
    final preferences = ref.watch(appPreferencesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = desktopPagesIn(ref, width);
    final sizes = pageSizesOf(preferences, width);
    final pageSize = _sizeOverride ?? sizes.size;
    final lastPage = state.totalCount == null ? null : (state.totalCount! / pageSize).ceil().clamp(1, 1 << 31);
    final canNext = state.hasMore || state.items.length > _page * pageSize;
    final maxPage = lastPage ?? (state.items.isEmpty ? 1 : ((state.items.length - 1) ~/ pageSize) + 1);
    final page = _page.clamp(1, maxPage);
    final busy = state.isRefreshing || state.isLoadingMore;
    final shown = desktop
        ? state.items.sublist(
            ((page - 1) * pageSize).clamp(0, state.items.length),
            (page * pageSize).clamp(0, state.items.length),
          )
        : state.items;

    Widget grid() => RoomGrid(
      scrollController: _scroll,
      padding: EdgeInsets.fromLTRB(gutter, PureSpacing.sm, gutter, PureSpacing.xl),
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final room = shown[index];
        return RoomCard(
          room: room,
          onOpen: () => RoomRoute(
            siteId: room.ref.platform,
            roomId: room.ref.roomId,
            roomName: room.content.title,
          ).push<void>(context),
        );
      },
      // A phone has no pager row to press, so the end of the list is where the
      // next page announces itself — as a row of its own, not as one more card:
      // in a waterfall a spinner that is a tile sits in one column at half the
      // window's width.
      footer: !desktop && state.isLoadingMore ? const Center(child: PureSpinner()) : null,
    );

    // The floating to-top/to-bottom buttons answer to the same setting on
    // both interaction models.
    Widget withJumps(Widget child) => Stack(
      children: [
        Positioned.fill(child: child),
        if (preferences.pageShowScrollTop)
          Positioned(
            right: 16,
            bottom: 16,
            child: PureJumpButtons(controller: _scroll, heroTag: 'popular-${widget.site.manifest.id}'),
          ),
      ],
    );

    if (!desktop) {
      return CustomRefreshIndicator(
        onRefresh: _controller.refresh,
        builder: (context, child, indicator) => Stack(
          alignment: Alignment.topCenter,
          children: [
            child,
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              // The bar needs bounded constraints: a Positioned pinned on `top`
              // alone hands its child unbounded constraints in both axes, which a
              // progress bar cannot resolve to a size — a kept-alive off-screen
              // tab then crashes the hit test ("Cannot hit test a render box with
              // no size"). Pinning the sides and fixing the width keeps the box
              // laid out in every state.
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
        child: withJumps(grid()),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (page > 1 && !busy) {
            unawaited(_goToPage(page - 1));
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!busy && canNext) {
            unawaited(_goToPage(page + 1));
          }
        },
      },
      child: Focus(
        focusNode: _pagerFocus,
        // Only the tab on screen may take the focus the ← → keys land on;
        // the kept-alive neighbours are built but idle.
        autofocus: widget.shouldLoad && widget.selected,
        child: Column(
          children: [
            Expanded(child: withJumps(grid())),
            PurePaginationBar(
              page: page,
              lastPage: lastPage,
              canNext: canNext,
              busy: busy,
              pageSize: pageSize,
              pageSizes: preferences.pageShowSizeSelector ? sizes.options : null,
              showGoto: preferences.pageShowGoto,
              onPage: (value) => unawaited(_goToPage(value)),
              onPageSize: (size) {
                // Keep the first room of the page in view (3.x).
                final first = (page - 1) * pageSize;
                setState(() {
                  _sizeOverride = size;
                  _page = first ~/ size + 1;
                });
                unawaited(_ensureFilled(_page * size));
              },
              onRefresh: () => unawaited(_controller.refresh()),
            ),
          ],
        ),
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
