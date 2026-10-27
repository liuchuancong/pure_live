import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/areas/controllers/areas_controller.dart';
import 'package:pure_live/features/areas/data/area_follow_repository.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The areas page (the reference's `AreasPage`): the platforms' own
/// catalogues — one tab per platform, each loaded when its tab first
/// shows and kept while the app runs — beside the followed areas, the
/// segmented control switching between the two views.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

/// The two views the segmented control switches between.
enum _AreasView { platform, followed }

final class _AreasPageState extends ConsumerState<AreasPage> with WidgetsBindingObserver {
  _AreasView _view = _AreasView.platform;

  /// When the viewer last left the app, so a long absence refreshes on return.
  DateTime? _backgroundedAt;

  /// Warms the next platform after the viewer settles on this one.
  Timer? _warmTimer;

  /// Whether a platform-display fallback is already waiting for the frame:
  /// one move per hidden selection, not one per build.
  bool _platformFallbackScheduled = false;

  static const Duration _warmDelay = Duration(milliseconds: 800);
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  /// One scroll controller per platform (the catalogue grid keeps each
  /// platform's place across tab switches); released with the page.
  final Map<String, ScrollController> _scrolls = {};

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmTimer?.cancel();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _resumeRefreshAfter) {
        unawaited(ref.read(areasCatalogProvider.notifier).refresh(ref.read(areasSiteProvider)));
      }
    }
  }

  /// The platform after the shown one (or before, at the end) loads its
  /// catalogue once the viewer has settled.
  void _armWarmUp() {
    _warmTimer?.cancel();
    final ids = ref.read(areasCatalogProvider.notifier).platformIds();
    if (ids.length < 2) return;
    final index = ids.indexOf(ref.read(areasSiteProvider));
    if (index < 0) return;
    final next = index + 1 < ids.length ? index + 1 : index - 1;
    _warmTimer = Timer(_warmDelay, () {
      if (mounted) unawaited(ref.read(areasCatalogProvider.notifier).warm(ids[next]));
    });
  }

  ScrollController _scrollOf(String platform) => _scrolls[platform] ??= ScrollController();

  /// The shown platform was hidden in the settings while another one is
  /// still visible: move to the first visible one and load its catalogue,
  /// rather than leaving the hidden platform's areas behind an absent tab.
  void _schedulePlatformFallback() {
    if (_platformFallbackScheduled) return;
    _platformFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _platformFallbackScheduled = false;
      if (!mounted) return;
      final current = ref.read(areasSiteProvider);
      final visible = ref.read(areasCatalogProvider.notifier).platformIds();
      if (visible.isEmpty || visible.contains(current)) return;
      final next = visible.first;
      ref.read(areasSiteProvider.notifier).selected = next;
      unawaited(ref.read(areasCatalogProvider.notifier).open(next));
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The catalogue never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(areasCatalogProvider.notifier).open(ref.read(areasSiteProvider)));
      _armWarmUp();
    });
    ref.listenManual(areasSiteProvider, (_, _) => _armWarmUp());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platform = ref.watch(areasSiteProvider);
    // The platform list and its order are settings this page follows live:
    // watching the notifier alone would leave the tabs stale until another
    // rebuild.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    final ids = ref.watch(areasCatalogProvider.notifier).platformIds();
    // The platform list can change under an open page (the settings hide
    // the shown platform, or a backup restores another display set): move
    // to a visible one instead of showing areas behind an absent tab.
    if (ids.isNotEmpty && !ids.contains(platform)) _schedulePlatformFallback();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          // A wrap, not a row: the two views and the platform tabs keep
          // their own widths, and a narrow window flows them.
          child: Wrap(
            spacing: DsSpace.s12,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsSegmentedControl<_AreasView>(
                segments: [
                  DsSegment(value: _AreasView.platform, label: Text(t.areas.viewPlatform)),
                  DsSegment(value: _AreasView.followed, label: Text(t.areas.viewFollowed)),
                ],
                value: _view,
                onChanged: (view) => setState(() => _view = view),
              ),
              if (_view == _AreasView.platform && ids.isNotEmpty)
                SizedBox(
                  width: 260,
                  child: PlatformTabRow(
                    platforms: ids,
                    current: platform,
                    nameOf: _platformName,
                    semanticLabel: t.areas.allAreas,
                    // The panel's way to the hide/reorder setting.
                    onManagePlatforms: () => unawaited(
                      context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location),
                    ),
                    onChanged: (id) {
                      ref.read(areasSiteProvider.notifier).selected = id;
                      unawaited(ref.read(areasCatalogProvider.notifier).open(id));
                      _armWarmUp();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _view == _AreasView.platform
              ? (ids.isEmpty
                    ? Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.antenna),
                          title: Text(t.areas.noPlatforms),
                          actions: [
                            DsButton(
                              variant: DsButtonVariant.secondary,
                              size: DsSize.sm,
                              leading: const DsIcon(DsIcons.antenna, size: 16),
                              onPressed: () => unawaited(
                                context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location),
                              ),
                              child: Text(t.settings.sitesDisplay),
                            ),
                          ],
                        ),
                      )
                    : _PlatformAreas(
                        key: ValueKey('areas-$platform'),
                        platform: platform,
                        scrollController: _scrollOf(platform),
                      ))
              : const _FollowedAreas(),
        ),
      ],
    );
  }

  String _platformName(String id) {
    final site = ref.watch(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// One platform's areas catalogue: the platform's secondary category tabs
/// (the reference's category row) over the card grid. A category the
/// platform does not nest leaves the row away.
final class _PlatformAreas extends ConsumerStatefulWidget {
  const _PlatformAreas({required this.platform, this.scrollController, super.key});

  /// The platform whose areas show.
  final String platform;

  /// The kept controller of this platform's tab.
  final ScrollController? scrollController;

  @override
  ConsumerState<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends ConsumerState<_PlatformAreas> {
  /// The chosen parent category id, '' for every area.
  String _category = '';

  /// Moves the category tab one step, wrapping at both ends; a swipe left
  /// goes forward, a swipe right back.
  void _stepCategory(List<(String, String)> categories, int delta) {
    final order = ['', for (final (id, _) in categories) id];
    final index = order.indexOf(_category);
    final next = order[(index + delta) % order.length];
    if (next == _category) return;
    setState(() => _category = next);
    if (widget.scrollController?.hasClients ?? false) widget.scrollController!.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(areasCatalogProvider.notifier);
    final catalog = ref.watch(areasCatalogProvider.select((map) => map[widget.platform]));
    final settings = ref.watch(browseSettingsProvider);
    final followed = ref.watch(followedAreasProvider);
    final followedKeys = {for (final area in followed.areas) area.identityKey};
    final state = catalog ?? (areas: const <LiveArea>[], loading: false, error: null);
    // The platform's own nesting: first-seen order, unique parents.
    final categories = <(String, String)>[];
    for (final area in state.areas) {
      final id = area.parentAreaId;
      final name = area.parentAreaName;
      if (id == null || id.isEmpty || name == null || name.isEmpty) continue;
      if (!categories.any((category) => category.$1 == id)) categories.add((id, name));
    }
    final category = categories.any((entry) => entry.$1 == _category) ? _category : '';
    final items = category.isEmpty
        ? state.areas
        : [
            for (final area in state.areas)
              if (area.parentAreaId == category) area,
          ];
    Widget cardBuilder(BuildContext context, LiveArea area) {
      final followed = followedKeys.contains(area.identityKey);
      return _AreaCard(
        area: area,
        onSelect: () => unawaited(
          context.push(
            AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
            extra: area,
          ),
        ),
        trailing: _AreaFollowButton(
          followed: followed,
          onPressed: () => unawaited(ref.read(followedAreasProvider.notifier).toggle(area)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DsTabs<String>(
                value: category,
                onChanged: (value) => setState(() => _category = value),
                tabs: [
                  DsTab<String>(value: '', label: Text(context.t.areas.categoryAll)),
                  for (final (id, name) in categories) DsTab<String>(value: id, label: Text(name)),
                ],
              ),
            ),
          ),
        Expanded(
          // A horizontal swipe changes the category tab: the reference's
          // category pager, without moving the platform's own tab.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: categories.isEmpty
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() < 240) return;
                    _stepCategory(categories, velocity < 0 ? 1 : -1);
                  },
            child: CardGrid<LiveArea>(
              scrollController: widget.scrollController,
              items: items,
              layout: ref.watch(browseLayoutProvider),
              crossSpacing: settings.crossSpacing,
              mainSpacing: settings.mainSpacing,
              aspectRatio: 3.4,
              isLoading: state.loading,
              error: state.error?.message,
              onRetry: () => controller.refresh(widget.platform),
              // A pull reloads the catalogue; a failure keeps the areas and
              // is explained in the bar over them.
              onRefresh: () => controller.refresh(widget.platform),
              refreshError: state.error?.message,
              emptyIcon: DsIcons.layoutGrid,
              emptyTitle: context.t.areas.noAreas,
              itemBuilder: cardBuilder,
              listItemBuilder: cardBuilder,
            ),
          ),
        ),
      ],
    );
  }
}

/// The heart on a platform area's card: filled while followed, a hollow
/// heart while not; pressing it follows or unfollows the area.
final class _AreaFollowButton extends StatelessWidget {
  const _AreaFollowButton({required this.followed, required this.onPressed});

  final bool followed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: followed ? t.areas.unfollow : t.areas.follow,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return DsIcon(
          DsIcons.heart,
          size: DsTheme.of(context).sizes.iconSm,
          color: followed
              ? hovered
                    ? colors.danger.fill
                    : colors.accent
              : hovered
              ? colors.accent
              : colors.textSubtle,
        );
      },
    );
  }
}

/// The followed areas: the areas the viewer follows, the platform they
/// belong to named under each one; pressing the heart unfollows.
final class _FollowedAreas extends ConsumerWidget {
  const _FollowedAreas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final followed = ref.watch(followedAreasProvider);
    final settings = ref.watch(browseSettingsProvider);
    if (!followed.ready) {
      return CardGrid<LiveArea>(
        items: const [],
        layout: ref.watch(browseLayoutProvider),
        crossSpacing: settings.crossSpacing,
        mainSpacing: settings.mainSpacing,
        aspectRatio: 3.4,
        isLoading: true,
        itemBuilder: (_, _) => const SizedBox.shrink(),
      );
    }
    if (followed.areas.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(t.areas.followedEmpty),
          description: Text(t.areas.followedEmptyHint),
        ),
      );
    }
    Widget cardBuilder(BuildContext context, LiveArea area) => _FollowedAreaCard(
      area: area,
      onUnfollow: () => unawaited(ref.read(followedAreasProvider.notifier).remove(area.identityKey)),
      onSelect: () => unawaited(
        context.push(
          AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
          extra: area,
        ),
      ),
    );
    return CardGrid<LiveArea>(
      items: followed.areas,
      layout: ref.watch(browseLayoutProvider),
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      aspectRatio: 3.4,
      itemBuilder: cardBuilder,
      listItemBuilder: cardBuilder,
    );
  }
}

/// One area as a card: its picture, its name, and the parent group it sits
/// in when the platform nests areas. Opening the area is [onSelect].
final class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onSelect, this.trailing});

  /// The area shown.
  final LiveArea area;

  /// Fired when the card opens the area.
  final VoidCallback onSelect;

  /// A small widget at the card's end, e.g. the follow toggle.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final parent = area.parentAreaName;
    return DsPressable(
      semanticLabel: area.areaName,
      onPressed: onSelect,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.control,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              _AreaIcon(area: area),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      area.areaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    if (parent != null && parent.isNotEmpty)
                      Text(
                        parent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}

/// The followed area's card: the area card with an active heart that
/// unfollows on press.
final class _FollowedAreaCard extends StatelessWidget {
  const _FollowedAreaCard({required this.area, required this.onUnfollow, required this.onSelect});

  final LiveArea area;
  final VoidCallback onUnfollow;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _AreaCard(
      area: area,
      onSelect: onSelect,
      trailing: DsPressable(
        semanticLabel: t.areas.unfollow,
        onPressed: onUnfollow,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return DsIcon(
            DsIcons.heart,
            size: DsTheme.of(context).sizes.iconSm,
            color: hovered ? DsTheme.colorsOf(context).danger.fill : DsTheme.colorsOf(context).textSubtle,
          );
        },
      ),
    );
  }
}

/// The area's picture: the platform's icon when it names one, a tag glyph
/// over the channel fill otherwise.
final class _AreaIcon extends StatelessWidget {
  const _AreaIcon({required this.area});

  /// The area whose icon is shown.
  final LiveArea area;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final fallback = ColoredBox(
      color: colors.channel,
      child: Center(
        child: DsIcon(DsIcons.tag, size: theme.sizes.iconMd, color: colors.textMuted),
      ),
    );
    final url = area.iconUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(width: theme.sizes.md, height: theme.sizes.md, child: fallback);
    }
    return DsImage(
      image: cachedImage(url),
      width: theme.sizes.md,
      height: theme.sizes.md,
      semanticLabel: area.areaName,
      fallback: fallback,
    );
  }
}
