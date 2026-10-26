import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/room/controller/room_controller.dart' show RoomState, roomProvider;

/// Declares what the open room plays to the display, so the refresh-rate
/// policy can pick a rate for the video (the reference's
/// `RoomRefreshRate`).
///
/// The room's playing line declares its own frame rate; platforms that say
/// nothing keep the selected refresh-rate mode. The provider lives as long
/// as the room page watches it: leaving the room releases the declaration.
final roomRefreshRateProvider = NotifierProvider<RoomRefreshRateController, void>(RoomRefreshRateController.new);

/// What the room contributes: whether a video plays, and its declared rate.
typedef _RoomPlaybackFacts = ({bool playing, double? frameRate});

/// Feeds the playing room's frame rate into `DisplayRefreshRateController`.
final class RoomRefreshRateController extends Notifier<void> {
  @override
  void build() {
    ref.listen(roomProvider.select(_factsOf), (_, _) => _update());
    ref.listen(matchVideoFrameRateProvider, (_, _) => _update());
    ref.onDispose(() {
      try {
        unawaited(ref.read(displayRefreshRateProvider.notifier).setPlaybackFrameRate(null));
      } on Object {
        // The container is already gone (app shutdown); there is no display
        // left to release.
      }
    });
    _update();
  }

  static _RoomPlaybackFacts _factsOf(RoomState room) {
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    return (
      playing: room.handle != null && (room.playback.playing || room.playback.buffering) && !room.audioOnly,
      frameRate: line?.geometry.frameRate?.toDouble(),
    );
  }

  void _update() {
    final facts = _factsOf(ref.read(roomProvider));
    final frameRate = ref.read(matchVideoFrameRateProvider) && facts.playing ? facts.frameRate : null;
    unawaited(ref.read(displayRefreshRateProvider.notifier).setPlaybackFrameRate(frameRate));
  }
}
