import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/player/kernel/live_player_facade.dart';

///

class FloatingPlayback {
  FloatingPlayback({required this.facade});

  final LivePlayerFacade facade;

  final RxBool isFloating = false.obs;
  final RxBool isHovered = false.obs;
  final RxBool isFloatingVideoVisible = true.obs;
  OverlayEntry? _entry;
  Timer? _hideTimer;
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
    _hideTimer?.cancel();
    final touch = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    void resetHideTimer() {
      if (touch) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 3), () => isHovered.value = false);
      }
    }

    final entry = OverlayEntry(
      builder: (context) => FloatingWindowOverlay(
        visible: isFloatingVideoVisible.stream,
        initiallyVisible: true,
        onExpand: () async {
          final room = facade.room;
          if (room != null) await AppNavigator.toLiveRoomDetail(liveRoom: room);
        },
        onClose: () async => closeAppFloating(),
        child: MouseRegion(
          onEnter: (_) => isHovered.value = true,
          onExit: (_) => isHovered.value = false,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Obx(
                    () =>
                        isFloatingVideoVisible.value ? facade.getVideoWidget(BoxFit.contain) : const SizedBox.shrink(),
                  ),
                ),
                if (danmakuBuilder != null) Positioned.fill(child: danmakuBuilder(context)),
                Center(
                  child: Obx(
                    () => AnimatedOpacity(
                      opacity: isHovered.value ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !isHovered.value,
                        child: StreamBuilder<bool>(
                          stream: facade.onPlaying,
                          initialData: facade.isPlayingNow,
                          builder: (context, snapshot) {
                            final isPlay = snapshot.data ?? true;
                            return IconButton(
                              iconSize: 42,
                              style: IconButton.styleFrom(backgroundColor: Colors.black45),
                              icon: Icon(
                                isPlay ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                facade.togglePlayPause();
                                resetHideTimer();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
    isFloating.value = true;
    if (touch) {
      isHovered.value = true;
      resetHideTimer();
    }
  }

  Future<void> closeAppFloating() async {
    _hideTimer?.cancel();
    _hideTimer = null;
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
}
