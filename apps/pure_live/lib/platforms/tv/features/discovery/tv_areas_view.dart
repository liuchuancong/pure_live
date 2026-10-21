import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LivePageRequest, LiveRoom, LiveSite;
import 'package:pure_live/app/app_providers.dart' show sitesProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_live/platforms/tv/widgets/tv_room_wall.dart';
import 'package:pure_live/shared/utilities/sites_order.dart' show orderedSites;
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/navigation/app_router.dart' show RoomRoute;
import 'package:pure_uikit/pure_uikit.dart';

/// 分区 on the ten-foot screen: the platform pills, the areas as a focus grid
/// of name tiles, and — once an area is chosen — its rooms as the same wall
/// the other TV panes draw. 返回 in the area's bar goes back to the tiles.
///
/// The pane keeps one request per level: the catalogue when the platform
/// opens, the first page of rooms when an area opens. The wall is not the
/// phone page's pager; a remote scrolls it.
final class TvAreasView extends ConsumerStatefulWidget {
  /// The TV areas pane.
  const new({super.key});

  @override
  ConsumerState<TvAreasView> createState() => _TvAreasViewState();
}

final class _TvAreasViewState extends ConsumerState<TvAreasView> {
  /// How many rooms one area wall asks for.
  static const int _pageSize = 40;

  LiveSite? _site;
  List<LiveArea>? _areas;
  LiveArea? _area;
  List<LiveRoom>? _rooms;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalogue());
  }

  List<LiveSite> _sites() {
    final preferences = ref.read(appPreferencesProvider);
    return orderedSites(
      ref.watch(sitesProvider).registry.all.where((site) => site.capability<LiveAreaProvider>() != null).toList(),
      preferences.siteOrder,
    ).where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id)).toList();
  }

  LiveSite? _resolved(List<LiveSite> sites) {
    if (sites.isEmpty) {
      return null;
    }
    final preferences = ref.read(appPreferencesProvider);
    final current = _site;
    if (current != null && sites.any((candidate) => candidate.manifest.id == current.manifest.id)) {
      return current;
    }
    return sites.firstWhere(
      (candidate) => candidate.manifest.id == preferences.preferredSiteId,
      orElse: () => sites.first,
    );
  }

  Future<void> _loadCatalogue() async {
    final site = _resolved(_sites());
    final capability = site?.capability<LiveAreaProvider>();
    if (site == null || capability == null) {
      return;
    }
    setState(() {
      _site = site;
      _area = null;
      _rooms = null;
      _loading = true;
      _failed = false;
    });
    try {
      final areas = (await capability.getAreas()).fold((error) => throw StateError('$error'), (value) => value);
      if (mounted) {
        setState(() => _areas = areas);
      }
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openArea(LiveArea area) async {
    final capability = _site?.capability<LiveAreaProvider>();
    if (capability == null) {
      return;
    }
    setState(() {
      _area = area;
      _rooms = null;
      _loading = true;
      _failed = false;
    });
    try {
      final page = (await capability.getAreaRooms(
        areaId: area.areaId,
        request: const LivePageRequest(pageSize: _pageSize),
      )).fold((error) => throw StateError('$error'), (value) => value);
      if (mounted) {
        setState(() => _rooms = page.items);
      }
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectSite(LiveSite site) {
    if (_site?.manifest.id == site.manifest.id) {
      return;
    }
    setState(() {
      _site = site;
      _areas = null;
    });
    unawaited(_loadCatalogue());
  }

  void _open(LiveRoom room) {
    unawaited(
      RoomRoute(siteId: room.ref.platform, roomId: room.ref.roomId, roomName: room.content.title).push<void>(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final sites = _sites();
    final area = _area;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.tabs.areas, style: theme.text.title.copyWith(color: theme.colors.text)),
                if (area != null) ...[
                  const SizedBox(width: 16),
                  Text('· ${area.areaName}', style: theme.text.subtitle.copyWith(color: theme.colors.textSecondary)),
                ],
                const SizedBox(width: 24),
                const Spacer(),
                if (area != null)
                  TvPill(
                    key: const ValueKey('tv-areas-back'),
                    label: t.common.back,
                    onTap: () => setState(() {
                      _area = null;
                      _rooms = null;
                    }),
                  )
                else
                  TvPill(
                    key: const ValueKey('tv-areas-refresh'),
                    label: t.common.refresh,
                    onTap: () => unawaited(_loadCatalogue()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final site in sites)
                  TvPill(
                    key: ValueKey('tv-areas-platform-${site.manifest.id}'),
                    label: site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN'),
                    selected: _site?.manifest.id == site.manifest.id,
                    onTap: () => _selectSite(site),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(context, theme, t, area)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, PureTheme theme, Translations t, LiveArea? area) {
    if (_loading && (_rooms == null && _areas == null)) {
      return const Center(child: PureSpinner(size: 40));
    }
    if (_failed) {
      return Center(
        child: PureError(
          message: t.errors.network,
          onRetry: () => unawaited(area == null ? _loadCatalogue() : _openArea(area)),
          retryLabel: t.common.retry,
        ),
      );
    }
    if (area != null) {
      return TvRoomWall(rooms: _rooms ?? const [], onSelect: _open, emptyTitle: t.popular.empty, emptyIcon: Icons.apps);
    }
    final areas = _areas ?? const <LiveArea>[];
    if (areas.isEmpty) {
      return Center(
        child: PureEmpty(title: t.popular.empty, icon: Icons.apps_outlined),
      );
    }
    // The tiles: a focus grid of names; the wall's card look scaled down to a
    // label is what a remote needs, and artwork is optional everywhere.
    return FocusTraversalGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1600 ? 6 : (constraints.maxWidth >= 1100 ? 5 : 4);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(48, 16, 48, 48),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 3.2,
            ),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final entry = areas[index];
              return TvPill(
                key: ValueKey('tv-area-${entry.areaId}'),
                label: entry.areaName.isEmpty ? entry.areaId : entry.areaName,
                autofocus: index == 0,
                onTap: () => unawaited(_openArea(entry)),
              );
            },
          );
        },
      ),
    );
  }
}
