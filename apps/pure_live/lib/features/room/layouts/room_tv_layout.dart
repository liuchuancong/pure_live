import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/features/room/danmaku_pane.dart' show DanmakuPane;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_header_parts.dart';
import 'package:pure_live/features/room/widgets/room_resolution_row.dart';
import 'package:pure_live/features/room/widgets/room_video_surface.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The 10-foot room.
///
/// No app bar: a TV has no title bar to sit under and no finger to hit a
/// back affordance with — the remote's Back is the system's and leaves the
/// route. The picture is full-bleed, the rail carries who is streaming and the
/// selectors, and every glyph is sized for a seat three metres away. Focus
/// traversal (which control a D-pad lands on next) joins the TV wave this build
/// does not own yet; what it does own is a layout that leaves room for it.
final class RoomTvLayout extends StatelessWidget {
  /// The TV layout for [identity].
  const new({
    required this.identity,
    required this.controller,
    required this.state,
    required this.room,
    required this.siteName,
    super.key,
  });

  /// The room on screen.
  final RoomIdentity identity;

  /// The page logic.
  final RoomController controller;

  /// The snapshot it renders.
  final RoomState state;

  /// The detail, or the route's stub before it arrives.
  final LiveRoom room;

  /// The platform's display name for the rail's head.
  final String siteName;

  /// The rail's share of a 1920-point screen: enough for a chat line without
  /// shrinking the picture below the source's own height.
  static const _railWidth = 460.0;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RoomVideoSurface(
                identity: identity,
                controller: controller,
                state: state,
                // Six rows of an 18-point line, and the bars never collapse:
                // a remote has no hover to bring hidden chrome back.
                barrageRows: 6,
                barrageFontSize: 18,
              ),
            ),
            SizedBox(
              width: _railWidth,
              child: ColoredBox(
                color: theme.colors.bgContainer,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: RoomIdentityBadge(
                        room: room,
                        siteName: siteName,
                        size: 56,
                        titleStyle: theme.text.headline,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Row(
                        children: [
                          RoomFollowButton(room: room),
                          const SizedBox(width: 8),
                          RoomRecordButton(identity: identity, room: room),
                        ],
                      ),
                    ),
                    RoomResolutionRow(identity: identity, controller: controller, state: state, dense: true),
                    const Divider(height: 1),
                    Expanded(child: DanmakuPane(identity: identity, dark: false)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
