import 'package:flutter/material.dart';
import 'package:live_library/live_library.dart';
import 'package:live_log/live_log.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/src/pages/discover_page.dart';
import 'package:pure_live/src/pages/room_page.dart';
import 'package:pure_live/src/services.dart';

/// The followed rooms, with their status refreshed from the sites.
///
/// This page is where the LiveRoom-first contract pays off: the list holds
/// *stored* rooms, and refreshing feeds each stored room straight back into
/// its site's `refreshLiveStatus`, which returns the same identity with a
/// fresh status. The stored snapshot is replaced through the library's
/// `replaceRoom`, which merges the fresh fields and never touches the user's
/// own metadata (position, note, groups).
class FollowsPage extends StatefulWidget {
  /// A follows page over [services].
  const new({required this.services, super.key});

  /// The service graph.
  final PureLiveServices services;

  @override
  State<FollowsPage> createState() => _FollowsPageState();
}

class _FollowsPageState extends State<FollowsPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    widget.services.library.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _refreshAll() async {
    setState(() => _refreshing = true);
    final log = widget.services.log.forCategory('app.follows');
    final library = widget.services.library;
    for (final record in library.rooms) {
      final site = widget.services.sites[record.room.platform];
      if (site == null) {
        continue;
      }
      try {
        final fresh = await site.refreshLiveStatus(record.room);
        await library.replaceRoom(fresh);
      } on Object catch (error, stack) {
        log.log(LogLevel.warning, 'refreshing ${record.room.identity} failed', error: error, stackTrace: stack);
      }
    }
    if (mounted) {
      setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);
    final geometry = theme.componentTheme;
    final rooms = widget.services.library.rooms;
    return Padding(
      padding: geometry.pagePaddingFor(environment.layoutMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Follows',
                  style: environment.layoutMode == LiveLayoutMode.tv
                      ? theme.typography.display
                      : theme.typography.headline,
                ),
              ),
              if (_refreshing)
                const LiveProgressIndicator(size: LiveControlSize.small)
              else
                LiveButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  variant: LiveButtonVariant.outline,
                  onPressed: rooms.isEmpty ? null : _refreshAll,
                ),
            ],
          ),
          SizedBox(height: geometry.sectionGap),
          Expanded(
            child: rooms.isEmpty
                ? const LiveEmptyView(
                    title: 'No followed rooms',
                    message: 'Follow a room on its page and it appears here, with its status refreshed from the site.',
                  )
                : LiveTvContentGrid(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final record = rooms[index];
                      return _FollowedRoomCard(
                        record: record,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RoomPage(services: widget.services, room: record.room),
                          ),
                        ),
                        onRemove: () => widget.services.library.unfollow(record.room),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A followed room: the stored snapshot plus the user's own note, if any.
class _FollowedRoomCard extends StatelessWidget {
  const new({required this.record, required this.onOpen, required this.onRemove});

  final LibraryRoom record;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final room = record.room;
    return Stack(
      children: [
        LiveRoomCard(room: room, onTap: onOpen),
        Positioned(
          top: theme.componentTheme.iconGap,
          right: theme.componentTheme.iconGap,
          child: LiveIconButton(
            icon: Icons.favorite,
            tooltip: 'Unfollow',
            selected: true,
            size: LiveControlSize.small,
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
