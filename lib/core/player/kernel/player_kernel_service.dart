import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:media_core/media_core.dart';
import 'package:pure_live/core/player/kernel/player_consts.dart';
import 'package:pure_live/core/player/presentation/fullscreen_window.dart';
import 'package:pure_live/core/player/presentation/kernel_floating_window_presenter.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' hide PlayerConsts;
import 'package:pure_live/core/player/presentation/windows_pip_driver.dart';
import 'package:pure_live/core/player/kernel/owned_input_opener.dart';
import 'package:pure_live/core/player/kernel/mpv_log_forwarder.dart';
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
          playerConfiguration: MediaKitLiveProperties.playerConfiguration(),
          customInputOpener: openOwnedInputOnKernelPlayer,
          beforeOpen: (player, source) async {
            attachMpvLogForwarder(player);
            await MediaKitLiveProperties.applyToSource(player, source);
          },
          videoControllerConfigurationBuilder: MediaKitLiveProperties.buildVideoControllerConfiguration,
          // The app declares every tuning value it wants; the adapter applies
          // only what it is told.
          configure: MediaKitLiveProperties.applyTo,
        ).registration(),
      );

    if (PlayerConsts.mobileOnlyEnginesAvailable(defaultTargetPlatform)) {
      kernel
        ..registerBackend(const FlvLzcPlayerAdapterFactory().registration())
        ..registerBackend(const BetterPlayerAdapterFactory().registration());
    }

    kernel.attachPresentation(
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
    // The driver ships with a null presenter, so a `floating` request was
    // silently dropped. Install the host surface so any host that calls
    // kernel.enterFloating (the local video player) actually opens a window for
    // that handle. The live room's own floating path never reaches the driver,
    // so this only enables the kernel-driven path.
    floatingDriver.updatePresenter(KernelFloatingWindowPresenter(kernel: kernel, driver: floatingDriver));
    return kernel;
  }

  static Future<void> ensureInitialized() async {
    MediaKitPlayerAdapter.ensureInitialized();

    // The desktop chrome asks the window, not a player, whether the picture is
    // compact, and the driver is what makes it compact. Start mirroring it
    // before any player can ask for the mode.
    observeWindowsPipState();

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
