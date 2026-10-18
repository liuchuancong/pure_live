import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/features/room/danmaku_pane.dart' show DanmakuPane;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_header_parts.dart';
import 'package:pure_live/features/room/widgets/room_resolution_row.dart';
import 'package:pure_live/features/room/widgets/room_video_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The desktop window's room.
///
/// The same split a tablet gets, with the three things a pointer and a
/// resizable window change: the chrome answers to hover instead of a tap, the
/// rail may go wider because a 2560-point window would otherwise spend more on
/// its divider than on the chat, and the header keeps a back affordance that a
/// keyboard can also reach (Escape leaves the room, the shell's own binding).
final class RoomDesktopLayout extends StatelessWidget {
  /// The desktop layout for [identity].
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

  /// The platform's display name for the header's second line.
  final String siteName;

  /// The narrowest window worth a rail: under it the chat goes under the
  /// picture, which is the upright phone's shape.
  static const _railMinWidth = 760.0;

  @override
  Widget build(BuildContext context) {
    if (state.presentation != RoomPresentation.normal) {
      return ColoredBox(
        color: Colors.black,
        child: RoomVideoSurface(identity: identity, controller: controller, state: state, barrageRows: 6),
      );
    }
    final theme = PureTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final rail = width < _railMinWidth ? 300.0 : (width * 0.3).clamp(300.0, 460.0);
    return ColoredBox(
      color: theme.colors.bgLayout,
      child: Column(
        children: [
          _header(context, theme),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RoomVideoSurface(
                    identity: identity,
                    controller: controller,
                    state: state,
                    barrageRows: 6,
                    barrageFontSize: 16,
                  ),
                ),
                SizedBox(
                  width: rail,
                  child: ColoredBox(
                    color: theme.colors.bgContainer,
                    child: Column(
                      children: [
                        RoomResolutionRow(identity: identity, controller: controller, state: state),
                        const Divider(height: 1),
                        Expanded(child: DanmakuPane(identity: identity, dark: false)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, PureTheme theme) {
    return Material(
      color: theme.colors.bgElevated,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (Navigator.of(context).canPop())
                PureIconButton(
                  icon: Icons.arrow_back,
                  tooltip: context.t.common.back,
                  onPressed: Navigator.of(context).maybePop,
                ),
              Expanded(
                child: RoomIdentityBadge(room: room, siteName: siteName, size: 38),
              ),
              SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    room.content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                  ),
                ),
              ),
              RoomFollowButton(room: room),
              const SizedBox(width: 6),
              RoomRecordButton(identity: identity, room: room),
              RoomOverflowMenu(identity: identity, controller: controller, state: state),
            ],
          ),
        ),
      ),
    );
  }
}
