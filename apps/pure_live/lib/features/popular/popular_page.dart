import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/popular/popular_controller.dart';
import 'package:pure_live/features/popular/room_card.dart' show RoomCard;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/platforms/platform_picker.dart';

/// The popular page (the reference's `PopularPage`): one tab per platform
/// of the discovery-capable sites, each tab holding its own paged feed of
/// recommendations — the feeds stay while the app runs, so switching tabs
/// never refetches; the ⌄ at the tabs' end opens every platform in a menu.
///
/// A platform without recommendations says so in the feed's place instead
/// of failing silently.
final class PopularPage extends ConsumerStatefulWidget {
  /// The popular page.
  const PopularPage({super.key});

  @override
  ConsumerState<PopularPage> createState() => _PopularPageState();
}

final class _PopularPageState extends ConsumerState<PopularPage> with WidgetsBindingObserver {
  /// One scroll controller per platform, kept while the page lives: a
  /// platform left and returned to lands where the viewer left it (the
  /// reference's TabBarView behaviour).
  final Map<String, ScrollController> _scrolls = {};

  /// Platform display names, built once per build from the registry
  /// instead of a linear lookup per tab.
  late final Map<String, String> _names = {
    for (final site in ref.watch(sitesProvider).all) site.manifest.id: site.manifest.name['zh-CN'] ?? site.manifest.id,
  };
  /// How long the viewer looks at a platform before the next one warms.
  static const Duration _warmDelay = Duration(milliseconds: 700);

  /// A return from the background after this long refreshes the shown
  /// platform (the reference's resume rule).
  static const Duration _resumeRefreshAfter = Duration(seconds: 15);

  Timer? _warmTimer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The feed never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(popularCatalogProvider.notifier).open(ref.read(popularSiteProvider)));
      _armWarmUp();
    });
    // A platform chosen elsewhere (the tabs) re-arms the warm-up; the
    // listen lands outside build, where a timer belongs.
    ref.listenManual(popularSiteProvider, (_, _) => _armWarmUp());
  }

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

  ScrollController _scrollOf(String platform) => _scrolls[platform] ??= ScrollController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (away >= _resumeRefreshAfter) {
        unawaited(ref.read(popularCatalogProvider.notifier).refresh(ref.read(popularSiteProvider)));
      }
    }
  }

  /// The tab after the shown one (or the one before, at the end) warms its
  /// first page once the viewer has settled on this one.
  void _armWarmUp() {
    _warmTimer?.cancel();
    final ids = ref.read(popularCatalogProvider.notifier).platformIds();
    if (ids.length < 2) return;
    final index = ids.indexOf(ref.read(popularSiteProvider));
    if (index < 0) return;
    final next = index + 1 < ids.length ? index + 1 : index - 1;
    _warmTimer = Timer(_warmDelay, () {
      if (!mounted) return;
      unawaited(ref.read(popularCatalogProvider.notifier).warm(ids[next]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platform = ref.watch(popularSiteProvider);
    final ids = ref.watch(popularCatalogProvider.notifier).platformIds();
    if (ids.isEmpty) {
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(t.common.empty)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: PlatformTabRow(
            platforms: ids,
            current: platform,
            nameOf: _platformName,
            semanticLabel: t.navigation.hot,
            onChanged: (id) {
              ref.read(popularSiteProvider.notifier).selected = id;
              unawaited(ref.read(popularCatalogProvider.notifier).open(id));
            },
          ),
        ),
        Expanded(
          child: _PlatformFeed(
            key: ValueKey(platform),
            platform: platform,
            scrollController: _scrollOf(platform),
          ),
        ),
      ],
    );
  }

  String _platformName(String id) => _names[id] ?? id;
}

/// One platform's feed: the home feed's own card grid over the catalogue's
/// entry for [platform].
final class _PlatformFeed extends ConsumerWidget {
  const _PlatformFeed({required this.platform, this.scrollController, super.key});

  /// The platform whose recommendations show.
  final String platform;

  /// The kept controller of this platform's tab (see the page's state).
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(popularCatalogProvider.notifier);
    final feed = ref.watch(popularCatalogProvider.select((catalog) => catalog[platform]));
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final state =
        feed ?? (rooms: const <LiveRoom>[], nextPage: 1, hasMore: true, loading: false, error: null);
    return CardGrid<LiveRoom>(
      scrollController: scrollController,
      items: state.rooms,
      cardExtent: cardExtent,
      isLoading: state.loading,
      hasMore: state.hasMore,
      onLoadMore: () => controller.loadMore(platform),
      error: state.error?.message,
      onRetry: () => controller.refresh(platform),
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      ),
    );
  }
}
