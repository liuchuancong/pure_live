import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

class LivePlayVideo extends StatelessWidget {
  const LivePlayVideo({
    super.key,
    required this.controller,
    this.expandToParent = false,
    this.transparentSurface = false,
    this.videoViewportAspectRatio,
    this.portraitFullscreenDisplayMode,
  });

  final LivePlayController controller;
  final bool expandToParent;
  final bool transparentSurface;
  final double? videoViewportAspectRatio;
  final PortraitFullscreenDisplayMode? portraitFullscreenDisplayMode;

  @override
  Widget build(BuildContext context) {
    return LivePlayVideoFrame(
      expandToParent: expandToParent,
      child: ColoredBox(
        color: transparentSurface ? Colors.transparent : Colors.black,
        child: Obx(() {
          final state = controller.state.value;
          final videoController = state.player.videoController;
          if (videoController == null) {
            return switch (livePlayPlaceholderFor(state.room)) {
              LivePlayPlaceholder.loading => const VideoLoading(),
              LivePlayPlaceholder.loadFailed => RoomLoadFailedWidget(onRetry: controller.onInitPlayerState),
              LivePlayPlaceholder.notLiving => NotLivingVideoWidget(controller: controller),
            };
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: transparentSurface ? Colors.transparent : Colors.black,
                child: VideoPlayer(
                  controller: videoController,
                  surfaceColor: transparentSurface ? Colors.transparent : Colors.black,
                  videoViewportAspectRatio: videoViewportAspectRatio,
                  portraitFullscreenDisplayMode: portraitFullscreenDisplayMode,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

enum LivePlayPlaceholder { loading, loadFailed, notLiving }

/// What the video area shows before a player exists. A finished load that
/// recorded an error must not keep spinning: `isLiving` defaults to true, so
/// a failed room request previously left an endless spinner with no retry.
@visibleForTesting
LivePlayPlaceholder livePlayPlaceholderFor(RoomState room) {
  if (room.isLoading) return LivePlayPlaceholder.loading;
  if (room.loadError != null) return LivePlayPlaceholder.loadFailed;
  return room.isLiving ? LivePlayPlaceholder.loading : LivePlayPlaceholder.notLiving;
}

class RoomLoadFailedWidget extends StatelessWidget {
  const RoomLoadFailedWidget({super.key, required this.onRetry});

  final Future<Object?> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 36),
            const SizedBox(height: 8),
            Text(
              i18n('get_room_info_failed_retry'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('room-load-retry'),
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(i18n('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the legacy 16:9 contract for every ordinary landscape room.
///
/// Only a caller that already owns an explicit adaptive portrait/fullscreen
/// frame may opt into expansion. Making the generic video widget expand by
/// default lets an unrelated parent constraint change every playback mode at
/// once, which caused the v3.0.1 landscape/PiP regression.
@visibleForTesting
class LivePlayVideoFrame extends StatelessWidget {
  const LivePlayVideoFrame({super.key, required this.child, required this.expandToParent});

  final Widget child;
  final bool expandToParent;

  @override
  Widget build(BuildContext context) {
    if (expandToParent) return SizedBox.expand(child: child);
    return AspectRatio(aspectRatio: 16 / 9, child: child);
  }
}
