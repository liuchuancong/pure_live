import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/features/room/danmaku_pane.dart' show DanmakuPane;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_resolution_row.dart';
import 'package:pure_live/features/room/widgets/room_video_surface.dart';

/// The sideways phone room.
///
/// A phone on its side has the width for a rail but never the height for a
/// column, so the picture takes the whole window and the chat becomes a
/// translucent strip pinned to the trailing edge — up with the chrome, gone
/// without it. The reference folds this case into its desktop split and spends
/// 34% of a 740-point window on the rail; here the strip is narrower and the
/// video never loses pixels it cannot show.
final class RoomPhoneLandscapeLayout extends StatelessWidget {
  /// The landscape phone layout for [identity].
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

  /// The platform's display name; the strip shows it while the room has no
  /// title of its own.
  final String siteName;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The video keeps the whole window: the strip overlays it rather than
          // taking width away from a picture that is already only 360 tall.
          RoomVideoSurface(
            identity: identity,
            controller: controller,
            state: state,
            immersive: true,
            compact: true,
            barrageRows: 3,
          ),
          if (state.chromeVisible)
            Positioned(
              right: 0,
              top: 0,
              bottom: 56,
              // A quarter of the window, floored where a quarter would not fit
              // a line of chat and capped so a foldable never loses its picture.
              width: (width * 0.26).clamp(200.0, 300.0),
              child: _strip(),
            ),
        ],
      ),
    );
  }

  /// The chat strip: a scrim so the barrage under it stays readable, the
  /// quality row, then the pane.
  Widget _strip() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xCC000000),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
      ),
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      room.content.title.isEmpty ? siteName : room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // The strip covers a slice of the picture. Closing it drops
                  // the chrome, which is what a tap on the video does too, so
                  // one gesture reopens both.
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: controller.hideChrome,
                  ),
                ],
              ),
            ),
            RoomResolutionRow(identity: identity, controller: controller, state: state, dense: true),
            Expanded(child: DanmakuPane(identity: identity)),
          ],
        ),
      ),
    );
  }
}
