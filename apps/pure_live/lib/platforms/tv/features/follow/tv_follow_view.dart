import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show FollowRepository, LibraryRoom;
import 'package:live_sites/live_sites.dart' show LiveFollowGroup, LiveRoom;
import 'package:pure_live/app/app_providers.dart' show followRepositoryProvider, sitesProvider;
import 'package:pure_live/app/shell/shell_actions.dart' show openMenuBranch;
import 'package:pure_live/app/shell/shell_destinations.dart' show ShellBranch;
import 'package:pure_live/features/follow/follow_rules.dart';
import 'package:pure_live/features/follow/live_alert_service.dart' show liveAlertServiceProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_room_wall.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/navigation/app_router.dart' show RoomRoute;
import 'package:pure_uikit/pure_uikit.dart';

/// 关注 on the ten-foot screen: the three state tabs and the platforms that
/// have follows as big, focusable pills, then the ordered wall — the same
/// ordering the phone grid takes (tag weight, audience, real viewers).
///
/// The remote walks pills and cards with the D-pad; OK on a card opens the
/// room with the wall as its playlist, OK on 刷新 runs a refresh pass. The
/// pane owns no state of its own beyond the two selections: the repository is
/// the list.
final class TvFollowView extends ConsumerStatefulWidget {
  /// The TV follows pane.
  const new({super.key});

  @override
  ConsumerState<TvFollowView> createState() => _TvFollowViewState();
}

final class _TvFollowViewState extends ConsumerState<TvFollowView> {
  static const String _allPlatforms = '';

  int _status = 0;
  String _platform = _allPlatforms;

  FollowRepository get _repository => ref.read(followRepositoryProvider);

  LiveFollowGroup get _group => LiveFollowGroup.values[_status];

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
    // A refresh pass at open keeps "关注" meaning "who is live now", the same
    // contract the phone tab carries.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(liveAlertServiceProvider).refresh());
      }
    });
  }

  /// The platform pills: the user's platform order first, then the rest.
  List<String> _platforms(List<LibraryRoom> records) {
    final preferences = ref.read(appPreferencesProvider);
    return [
      _allPlatforms,
      ...followPlatformTabs(
        [for (final record in records) record.room],
        preferences.siteOrder,
        registryOrder: [for (final site in ref.read(sitesProvider).registry.all) site.manifest.id],
      ),
    ];
  }

  String _platformLabel(String id) {
    if (id == _allPlatforms) {
      return context.t.follow.all;
    }
    final site = ref.read(sitesProvider).registry.getById(id);
    return site?.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN') ?? id;
  }

  /// The wall's rooms for the current selections, ordered like the phone grid.
  List<LiveRoom> _rooms() {
    final preferences = ref.read(appPreferencesProvider);
    final records = _repository.rooms;
    final ordering = FollowOrdering(
      preferRealOnline: preferences.preferRealOnlineCounts,
      realOnlinePlatforms: preferences.realOnlinePlatforms.toSet(),
    );
    final rooms = [
      for (final record in records)
        if (record.room.broadcast.followGroup == _group &&
            followOnPlatform(record.room, _platform == _allPlatforms ? null : _platform))
          record.room,
    ];
    if (_group != LiveFollowGroup.offline) {
      rooms.sort(ordering.compare);
    }
    return rooms;
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
    final records = _repository.rooms;
    final platforms = _platforms(records);
    final platform = platforms.contains(_platform) ? _platform : _allPlatforms;
    final rooms = _rooms();
    final counts = [
      for (final group in LiveFollowGroup.values)
        [
          for (final record in records)
            if (record.room.broadcast.followGroup == group &&
                followOnPlatform(record.room, platform == _allPlatforms ? null : platform))
              record,
        ].length,
    ];

    Widget pill({required String label, required bool selected, required VoidCallback onTap, Key? key}) {
      final color = selected ? theme.colors.primary : theme.colors.textSecondary;
      return FocusTraversalGroup(
        child: _TvPill(key: key, label: label, color: color, selected: selected, onTap: onTap),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.tabs.favorites, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 24),
                for (var index = 0; index < LiveFollowGroup.values.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: pill(
                      key: ValueKey('tv-follow-status-$index'),
                      label:
                          '${switch (LiveFollowGroup.values[index]) {
                            LiveFollowGroup.live => context.t.follow.liveRoom,
                            LiveFollowGroup.replay => context.t.follow.replayRoom,
                            LiveFollowGroup.offline => context.t.follow.offlineRoom,
                          }} ${counts[index]}',
                      selected: _status == index,
                      onTap: () => setState(() => _status = index),
                    ),
                  ),
                const Spacer(),
                pill(
                  key: const ValueKey('tv-follow-refresh'),
                  label: t.common.refresh,
                  selected: false,
                  onTap: () => unawaited(ref.read(liveAlertServiceProvider).refresh()),
                ),
                const SizedBox(width: 12),
                pill(
                  key: const ValueKey('tv-follow-search'),
                  label: t.tabs.search,
                  selected: false,
                  onTap: () => openMenuBranch(context, ShellBranch.search),
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
                for (final id in platforms.where((id) => id.isNotEmpty))
                  pill(
                    key: ValueKey('tv-follow-platform-$id'),
                    label: _platformLabel(id),
                    selected: platform == id,
                    onTap: () => setState(() => _platform = id),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TvRoomWall(
              rooms: rooms,
              onSelect: _open,
              emptyTitle: switch (_group) {
                LiveFollowGroup.live => t.follow.emptyLive,
                LiveFollowGroup.replay => t.follow.emptyReplay,
                LiveFollowGroup.offline => t.follow.emptyOffline,
              },
              emptyIcon: Icons.favorite_border,
            ),
          ),
        ],
      ),
    );
  }
}

/// One focusable TV pill: scale + accent border on focus, accent fill when
/// selected.
final class _TvPill extends StatefulWidget {
  const new({required this.label, required this.color, required this.selected, required this.onTap, super.key});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TvPill> createState() => _TvPillState();
}

final class _TvPillState extends State<_TvPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Focus(
      onFocusChange: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected ? theme.colors.primaryBg : theme.colors.fillQuaternary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? theme.colors.primary : Colors.transparent, width: 2),
          ),
          child: Text(
            widget.label,
            style: theme.text.body.copyWith(
              color: _focused || widget.selected ? theme.colors.primary : widget.color,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
