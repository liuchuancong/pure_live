import 'dart:async';

import 'package:flutter/material.dart';
import 'package:live_log/live_log.dart';
import 'package:live_sites/live_sites.dart' as sites;
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/src/pages/room_page.dart';
import 'package:pure_live/src/services.dart';

/// Room discovery: pick a site, browse its rooms, open one.
///
/// The page is the same in every layout mode and every design language; what
/// changes is the chrome (the shell) and the density (the tokens). The three
/// states a remote data page must get right — loading, failed with a retry,
/// and genuinely empty — go through the shared state views, so an error here
/// looks like an error everywhere else in the app.
class DiscoverPage extends StatefulWidget {
  /// A discovery page over [services].
  const new({required this.services, super.key});

  /// The service graph.
  final PureLiveServices services;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final ScrollController _scroll = ScrollController();
  final List<sites.LiveRoom> _rooms = [];
  String? _siteId;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  Object? _failure;

  /// The sites this build can actually browse.
  ///
  /// Not every adapter's directory is migrated yet, and the ones that are not
  /// say so through the capability markers — so the picker offers the working
  /// sites instead of putting the user on a page whose only outcome is an
  /// error. IPTV is excluded because it is its own page: its "directory" is
  /// the channel library the user imported.
  List<sites.LiveSite> get _browsableSites =>
      widget.services.sites.browsable.where((site) => site.id != sites.SiteIds.iptv).toList()
        ..sort((a, b) => a.metadata.displayName.compareTo(b.metadata.displayName));

  sites.LiveSite? get _site {
    final id = _siteId;
    return id == null ? null : widget.services.sites[id];
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _siteId = _browsableSites.isEmpty ? null : _browsableSites.first.id;
    // The first load starts after the first frame so the page never calls
    // setState while it is building.
    if (_siteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadFirstPage()));
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore) {
      return;
    }
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _rooms.clear();
      _page = 0;
      _hasMore = true;
      _failure = null;
    });
    await _load(page: 1, replace: true);
  }

  Future<void> _loadNextPage() => _load(page: _page + 1, replace: false);

  Future<void> _load({required int page, required bool replace}) async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _failure = null;
    });
    final siteId = _siteId;
    final site = _site;
    if (site == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      final result = await site.getRecommendRooms(page: page);
      if (!mounted || siteId != _siteId) {
        // The user switched sites while this page was in flight; the answer
        // is about a site nobody is looking at any more.
        return;
      }
      setState(() {
        if (replace) {
          _rooms.clear();
        }
        _rooms.addAll(result.items);
        _page = page;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on Object catch (error, stack) {
      widget.services.log
          .forCategory('app.discover')
          .log(LogLevel.warning, 'recommend page $page of $siteId failed', error: error, stackTrace: stack);
      if (mounted && siteId == _siteId) {
        setState(() {
          _failure = error;
          _loading = false;
        });
      }
    }
  }

  void _selectSite(String id) {
    if (id == _siteId) {
      return;
    }
    setState(() => _siteId = id);
    unawaited(_loadFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);
    final site = _site;
    if (site == null) {
      return Padding(
        padding: theme.componentTheme.pagePaddingFor(environment.layoutMode),
        child: const LiveEmptyView(
          title: 'No browsable site in this build',
          message:
              'The adapters whose directory is migrated declare it; the rest land site by site, '
              'and the IPTV library has its own page.',
        ),
      );
    }
    final header = Padding(
      padding: EdgeInsets.only(bottom: theme.componentTheme.sectionGap),
      child: Row(
        children: [
          Expanded(
            child: Text(
              site.metadata.displayName,
              style: environment.layoutMode == LiveLayoutMode.tv ? theme.typography.display : theme.typography.headline,
            ),
          ),
          LiveMenuButton(
            tooltip: 'Choose a site',
            entries: [
              for (final browsable in _browsableSites)
                LiveMenuEntry(
                  id: browsable.id,
                  label: browsable.metadata.displayName,
                  selected: browsable.id == _siteId,
                ),
            ],
            onSelected: _selectSite,
            child: const LiveIconButton(icon: Icons.switch_video_outlined, tooltip: 'Choose a site'),
          ),
        ],
      ),
    );

    return Padding(
      padding: theme.componentTheme.pagePaddingFor(environment.layoutMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_failure != null && _rooms.isEmpty) {
      return LiveErrorView(
        message: 'Loading rooms from $_siteId failed.',
        details: '$_failure',
        retryLabel: 'Retry',
        onRetry: _loadFirstPage,
      );
    }
    if (_rooms.isEmpty) {
      return _loading ? const LiveLoadingView(message: 'Loading rooms…') : const LiveEmptyView(title: 'No rooms');
    }
    return LiveTvContentGrid(
      controller: _scroll,
      itemCount: _rooms.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _rooms.length) {
          return LiveLoadingView(compact: true, message: _loading ? null : 'Loading more…');
        }
        return LiveRoomCard(
          room: _rooms[index],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => RoomPage(services: widget.services, room: _rooms[index]),
            ),
          ),
        );
      },
    );
  }
}

/// A room tile: cover, title, streamer and status.
class LiveRoomCard extends StatelessWidget {
  /// A card for [room].
  const new({required this.room, this.onTap, super.key});

  /// The room to show.
  final sites.LiveRoom room;

  /// Opens the room.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final status = switch (room.status) {
      sites.LiveStatus.live => (label: 'LIVE', color: theme.colors.success),
      sites.LiveStatus.offline => (label: 'Offline', color: theme.colors.textDisabled),
      sites.LiveStatus.replay => (label: 'Replay', color: theme.colors.secondary),
      sites.LiveStatus.banned => (label: 'Banned', color: theme.colors.error),
      sites.LiveStatus.carousel => (label: 'Carousel', color: theme.colors.warning),
      sites.LiveStatus.unknown => (label: 'Unknown', color: theme.colors.textSecondary),
    };
    return LiveCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LiveBackground(
              style: room.cover == null
                  ? LiveBackgroundStyle.solid(color: theme.colors.surfaceVariant)
                  : LiveBackgroundStyle.image(
                      image: NetworkImage(room.cover!),
                      scrim: theme.colors.scrim,
                      scrimStrength: 0.15,
                    ),
              clipRadius: BorderRadius.vertical(top: Radius.circular(geometry.cardRadius)),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(geometry.iconGap),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(LiveRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: LiveSpacing.sm, vertical: LiveSpacing.xxs),
                      child: Text(
                        status.label,
                        style: theme.typography.caption.copyWith(color: theme.colors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: geometry.cardPaddingDense,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title.isEmpty ? room.roomId : room.title,
                  style: theme.typography.subtitle.copyWith(color: theme.colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: LiveSpacing.xxs),
                Text(
                  room.nick.isEmpty ? room.platform : '${room.nick} · ${room.platform}',
                  style: theme.typography.caption.copyWith(color: theme.colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
