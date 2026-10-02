import 'dart:async';

import 'package:media_core_floating/media_core_floating.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/player/kernel/live_player_facade.dart';

///

class FloatingPlayback {
  FloatingPlayback({required this.facade});

  final LivePlayerFacade facade;

  final RxBool isFloating = false.obs;
  final RxBool isFloatingVideoVisible = true.obs;
  OverlayEntry? _entry;
  FacadeStreamCommit? _reentrySeed;
  bool _prepared = false;

  void prepare() {
    final commit = facade.commit;
    _reentrySeed = commit != null && commit.room == facade.room ? commit : null;
    _prepared = true;
  }

  FacadeStreamCommit? consumeRoomReentry() {
    final seed = _reentrySeed;
    _reentrySeed = null;
    _prepared = false;
    return seed;
  }

  void cancelRoomReentry() {
    _reentrySeed = null;
    _prepared = false;
  }

  bool get isAppFloatingActive => _prepared || isFloating.value || _entry != null;

  Future<void> showAppFloating({Widget Function(BuildContext)? danmakuBuilder}) async {
    if (!_prepared || _entry != null) return;
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      await closeAppFloating();
      return;
    }
    isFloatingVideoVisible.value = true;

    final entry = OverlayEntry(
      builder: (context) => FloatingWindowOverlay(
        visible: isFloatingVideoVisible.stream,
        initiallyVisible: true,
        // 160×90 (the library default) is a thumbnail, not a watchable
        // window: a 16:9 stream gets a 380×214 surface with a 200×112 drag
        // floor, still capped at half the screen by maxWidthFraction.
        placement: const FloatingWindowPlacement(
          config: FloatingPlacementConfig(width: 380, height: 214, minWidth: 200, minHeight: 112),
        ),
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: Obx(
                  () => isFloatingVideoVisible.value ? facade.getVideoWidget(BoxFit.contain) : const SizedBox.shrink(),
                ),
              ),
              if (danmakuBuilder != null) Positioned.fill(child: danmakuBuilder(context)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    StreamBuilder<bool>(
                      stream: facade.onPlaying,
                      initialData: facade.isPlayingNow,
                      builder: (context, snapshot) {
                        final isPlay = snapshot.data ?? true;
                        return _floatingControlButton(
                          icon: isPlay ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          semanticLabel: isPlay ? '暂停' : '播放',
                          onTap: facade.togglePlayPause,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _floatingControlButton(
                      icon: Icons.open_in_full,
                      semanticLabel: '回到直播间',
                      onTap: () async {
                        final room = facade.room;
                        if (room != null) await AppNavigator.toLiveRoomDetail(liveRoom: room);
                      },
                    ),
                    const SizedBox(width: 6),
                    _floatingControlButton(
                      icon: Icons.close,
                      semanticLabel: '关闭',
                      onTap: () async => closeAppFloating(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
    isFloating.value = true;
  }

  Future<void> closeAppFloating() async {
    final entry = _entry;
    _entry = null;
    isFloatingVideoVisible.value = false;
    _prepared = false;
    if (entry != null && entry.mounted) {
      await Future<void>.delayed(Duration.zero);
      entry.remove();
    }
    isFloating.value = false;
  }

  Widget _floatingControlButton({
    required IconData icon,
    required String semanticLabel,
    required Future<void> Function() onTap,
  }) {
    return IconButton(
      iconSize: 20,
      tooltip: semanticLabel,
      style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
      icon: Icon(icon),
      onPressed: () => unawaited(onTap()),
    );
  }
}
