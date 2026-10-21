import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveDiscoveryProvider, LivePageRequest, LiveRoom, LiveSite;
import 'package:pure_live/app/app_providers.dart' show sitesProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_live/platforms/tv/widgets/tv_room_wall.dart';
import 'package:pure_live/shared/utilities/sites_order.dart' show orderedSites;
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/navigation/app_router.dart' show RoomRoute;
import 'package:pure_uikit/pure_uikit.dart';

/// 热门 on the ten-foot screen: the platform pills, then the recommended
/// rooms of the chosen platform as the focus wall the follows tab uses.
///
/// One request per platform open (the first page, as large as the wall fills);
/// the pill row carries 刷新 for the remote. Errors keep the last wall and
/// say so under the pills, the phone page's own contract, minus the paging.
final class TvPopularView extends ConsumerStatefulWidget {
  /// The TV popular pane.
  const new({super.key});

  @override
  ConsumerState<TvPopularView> createState() => _TvPopularViewState();
}

final class _TvPopularViewState extends ConsumerState<TvPopularView> {
  /// How many rooms one wall asks for.
  static const int _pageSize = 40;

  LiveSite? _site;
  List<LiveRoom>? _rooms;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<LiveSite> _sites() {
    final preferences = ref.read(appPreferencesProvider);
    return orderedSites(
      ref.watch(sitesProvider).registry.all.where((site) => site.capability<LiveDiscoveryProvider>() != null).toList(),
      preferences.siteOrder,
    ).where((site) => !preferences.hiddenSiteIds.contains(site.manifest.id)).toList();
  }

  Future<void> _load() async {
    final sites = _sites();
    if (sites.isEmpty) {
      return;
    }
    final preferences = ref.read(appPreferencesProvider);
    final current = _site;
    final site = current != null && sites.any((candidate) => candidate.manifest.id == current.manifest.id)
        ? current
        : sites.firstWhere(
            (candidate) => candidate.manifest.id == preferences.preferredSiteId,
            orElse: () => sites.first,
          );
    final capability = site.capability<LiveDiscoveryProvider>();
    if (capability == null) {
      return;
    }
    setState(() {
      _site = site;
      _loading = true;
      _failed = false;
    });
    try {
      final page = (await capability.getRecommendedRooms(request: const LivePageRequest(pageSize: _pageSize)))
          .fold((error) => throw StateError('$error'), (value) => value);
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

  void _select(LiveSite site) {
    if (_site?.manifest.id == site.manifest.id) {
      return;
    }
    setState(() {
      _site = site;
      _rooms = null;
    });
    unawaited(_load());
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
    final rooms = _rooms ?? const <LiveRoom>[];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.tabs.popular, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 24),
                const Spacer(),
                TvPill(
                  key: const ValueKey('tv-popular-refresh'),
                  label: t.common.refresh,
                  onTap: () => unawaited(_load()),
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
                    key: ValueKey('tv-popular-platform-${site.manifest.id}'),
                    label: site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN'),
                    selected: _site?.manifest.id == site.manifest.id,
                    onTap: () => _select(site),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading && rooms.isEmpty
                ? const Center(child: PureSpinner(size: 40))
                : _failed && rooms.isEmpty
                ? Center(
                    child: PureError(
                      message: t.errors.network,
                      onRetry: () => unawaited(_load()),
                      retryLabel: t.common.retry,
                    ),
                  )
                : TvRoomWall(
                    rooms: rooms,
                    onSelect: _open,
                    emptyTitle: t.popular.empty,
                    emptyIcon: Icons.local_fire_department,
                  ),
          ),
        ],
      ),
    );
  }
}
