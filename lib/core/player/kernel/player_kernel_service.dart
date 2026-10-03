import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/kernel/player_consts.dart';
import 'package:pure_live/core/player/presentation/fullscreen_window.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:media_core_floating/media_core_floating.dart';
// media_core_media_kit 里也有一个 PlayerConsts（mpv 词表）；本文件用的是本包的
// 引擎表，隐藏同名导入以消除歧义。
import 'package:media_core_media_kit/media_core_media_kit.dart' hide PlayerConsts;
import 'package:pure_live/core/player/presentation/windows_pip_driver.dart';
import 'package:pure_live/core/player/kernel/owned_input_opener.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_logging/media_core_logging.dart' as mlog;
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:pure_live/core/player/kernel/media_kit_live_properties.dart';
import 'package:media_core_better_player/media_core_better_player.dart';
import 'package:pure_live/core/config/player_settings_controller.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  static final FloatingDriver floatingDriver = FloatingDriver();

  static mlog.MemoryLogSink? logRing;

  PlayerKernel? _kernel;

  PlayerKernel get kernel {
    _kernel ??= _buildKernel();
    return _kernel!;
  }

  PlayerKernel _buildKernel() {
    final kernel = PlayerKernel()
      ..registerBackend(
        MediaKitAdapterFactory(
          customInputOpener: openOwnedInputOnKernelPlayer,
          videoControllerConfigurationBuilder: MediaKitLiveProperties.buildVideoControllerConfiguration,
          // The app declares every tuning value it wants; the adapter applies
          // only what it is told.
          configure: MediaKitLiveProperties.applyTo,
        ).registration(),
      );

    // ijk 与 better_player 只在移动端注册：桌面端发布的只有 libmpv，引擎选择里
    // 也没有这两个键。判定与选择列表共用 PlayerConsts.mobileOnlyEnginesAvailable，
    // 所以不会出现"界面选得到但内核没注册"。
    if (PlayerConsts.mobileOnlyEnginesAvailable(defaultTargetPlatform)) {
      kernel
        ..registerBackend(const FlvLzcPlayerAdapterFactory().registration())
        ..registerBackend(const BetterPlayerAdapterFactory().registration());
    }

    return kernel..attachPresentation(
      PresentationDriverChain(
        bindings: [
          PresentationDriverBinding(
            modes: {PresentationMode.fullscreen, PresentationMode.windowFullscreen},
            driver: fullscreenDriver,
          ),
          PresentationDriverBinding(modes: {PresentationMode.pip}, driver: windowsPipDriver),
          PresentationDriverBinding(modes: {PresentationMode.floating}, driver: floatingDriver),
        ],
      ),
    );
  }

  static Future<void> ensureInitialized() async {
    MediaKitPlayerAdapter.ensureInitialized();

    // Output settings ride two rails: mpv-property changes (hwdec, tuning
    // table, shaders, ao, ...) apply to the live engine through engine
    // options; a render-context change (vo / custom-output switch) needs a
    // same-backend engine rebuild, which preserves source, position and
    // play intent.
    PlayerSettingsController.outputSettingsDispatcher = ({required bool rebuild}) {
      final handle = GlobalPlayerService.instance.player.handle;
      if (handle == null) return;
      if (rebuild) {
        unawaited(handle.rebuildEngine(reason: 'video output settings changed'));
        return;
      }
      unawaited(MediaKitLiveProperties.engineOptions().then((options) => handle.applyEngineOptions(options)));
    };
    logRing = mlog.MediaCoreLog.attachMemorySink(capacity: 500);
    if (!const bool.fromEnvironment('dart.vm.product')) {
      mlog.MediaCoreLog.level = mlog.LogLevel.debug;
    }
    await MediaSessionBootstrap.attachTo(instance.kernel, config: const MediaSessionConfig.video());
  }
}
