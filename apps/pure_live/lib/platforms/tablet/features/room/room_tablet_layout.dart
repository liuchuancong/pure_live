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

/// The touch tablet's split, the reference's `desktopSplit` drawn for a finger.
///
/// The structure is the split the reference uses above its 680-point threshold:
/// the picture takes what is left after the rail, and the rail is the quality
/// row above the chat. What a tablet does differently from a desktop window is
/// the chrome: no hover lease exists, so the bars stay up until the surface is
/// tapped, and the header carries a back affordance a finger can reach.
final class RoomTabletLayout extends StatelessWidget {
  /// The tablet layout for [identity].
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

  @override
  Widget build(BuildContext context) {
    if (state.presentation != RoomPresentation.normal) {
      return ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: RoomVideoSurface(identity: identity, controller: controller, state: state, barrageRows: 5),
        ),
      );
    }
    final theme = PureTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final rail = (width * 0.34).clamp(300.0, 420.0);
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
                  child: RoomVideoSurface(identity: identity, controller: controller, state: state, barrageRows: 5),
                ),
                SizedBox(
                  width: rail,
                  child: ColoredBox(
                    color: theme.colors.bgContainer,
                    child: Column(
                      children: [
                        RoomResolutionRow(identity: identity, controller: controller, state: state),
                        const PureDivider(),
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
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  PureIconButton(
                    icon: Icons.arrow_back,
                    tooltip: context.t.common.back,
                    onPressed: Navigator.of(context).maybePop,
                  ),
                Expanded(
                  child: RoomIdentityBadge(room: room, siteName: siteName),
                ),
                RoomFollowButton(room: room),
                const SizedBox(width: 6),
                RoomRecordButton(identity: identity, room: room),
                RoomOverflowMenu(identity: identity, controller: controller, state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
