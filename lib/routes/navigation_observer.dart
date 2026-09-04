import 'dart:async';
import 'dart:developer';
import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/fullscreen.dart' show WindowService;
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';


class LiveRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    switch (route.settings.name) {
      case RoutePath.kLivePlay:
        _onLivePlayEnter();
        break;
      case RoutePath.kMultiview:
        _onMultiviewEnter();
      case RoutePath.kRecordPage:
        _setVideoLayerVisible(false);
        break;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    switch (route.settings.name) {
      case RoutePath.kLivePlay:
        _onLivePlayExit(route);
        break;
      case RoutePath.kRecordPage:
        _restoreVideoLayerAfterRouteExit(route);
        break;
    }
  }

  void _onLivePlayEnter() {
    final playerManager = GlobalPlayerService.instance.player;
    unawaited(playerManager.closeAppFloating());
  }

  void _onMultiviewEnter() {
    final playerManager = GlobalPlayerService.instance.player;
    unawaited(playerManager.closeAppFloating());
    unawaited(playerManager.close());
    final controller = _findLivePlayController();
    if (controller == null) return;
    final state = controller.state.value;
    state.player.videoController?.clearListener();
  }

  void _onLivePlayExit(Route<dynamic> route) {
    final controller = _findLivePlayController();
    if (controller == null) return;

    final state = controller.state.value;
    final preventFloating = controller.takeSuppressAppFloatingOnNextPop();

    controller.updateUI(displayVideoLayer: false);
    controller.updateRoom(success: false);

    final playerManager = GlobalPlayerService.instance.player;
    if (_shouldShowFloating(preventFloating)) {
      _showFloatingAfterExit(route: route, controller: controller, playerManager: playerManager);
    } else {
      state.player.videoController?.clearListener();
      unawaited(playerManager.close());
    }

    if (PlatformUtils.isMobile) {
      WindowService().doExitFullScreen();
    }
  }

  void _setVideoLayerVisible(bool visible) {
    final controller = _findLivePlayController();
    if (controller == null) return;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!controller.isClosed) {
        controller.updateUI(displayVideoLayer: visible);
      }
    });
  }

  /// A popped route remains in the overlay during its reverse transition.
  /// Reattaching media_kit's Windows texture in didPop used to overlap that
  /// transition and produced a reproducible flutter_windows.dll access
  /// violation when returning from the recorder centre.  Wait for the route
  /// to be fully removed, then cross one more frame boundary before restoring
  /// the live surface.
  void _restoreVideoLayerAfterRouteExit(Route<dynamic> route) {
    unawaited(
      _waitForRouteExit(route).then((_) async {
        await SchedulerBinding.instance.endOfFrame;
        final controller = _findLivePlayController();
        if (controller != null && !controller.isClosed) {
          controller.updateUI(displayVideoLayer: true);
        }
      }),
    );
  }

  bool _shouldShowFloating(bool preventFloating) {
    return SettingsService.to.player.floatPlay.v && !preventFloating;
  }

  void _showFloatingAfterExit({
    required Route<dynamic> route,
    required LivePlayController controller,
    required PlayerManager playerManager,
  }) {
    final routeExitCompleted = _waitForRouteExit(route);
    controller.prepareAppFloating(routeUnmounted: routeExitCompleted);
    unawaited(routeExitCompleted.then((_) => playerManager.showAppFloating()));
  }

  Future<void> _waitForRouteExit(Route<dynamic> route) {
    if (route is TransitionRoute<dynamic>) {
      return route.completed;
    }
    return SchedulerBinding.instance.endOfFrame;
  }

  LivePlayController? _findLivePlayController() {
    try {
      if (!Get.isRegistered<LivePlayController>()) return null;
      return Get.find<LivePlayController>();
    } catch (e, stackTrace) {
      log('Failed to find LivePlayController', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
