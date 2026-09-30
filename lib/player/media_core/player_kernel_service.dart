import 'package:media_core/media_core.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/player/utils/windows_pip_driver.dart';
import 'package:pure_live/player/kernel/media_kit_live_properties.dart';
import 'package:pure_live/player/kernel/owned_input_opener.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_logging/media_core_logging.dart' as mlog;
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:media_core_better_player/media_core_video_player.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  static final FloatingDriver floatingDriver = FloatingDriver();

  static mlog.MemoryLogSink? logRing;

  PlayerKernel? _kernel;

  PlayerKernel get kernel {
    _kernel ??= PlayerKernel()
      ..registerBackend(
        MediaKitAdapterFactory(
          config: const MediaKitPlayerConfig(customInputOpener: openOwnedInputOnKernelPlayer),
          // The app declares every tuning value it wants; the adapter applies
          // only what it is told.
          configure: (adapter) => adapter.config = MediaKitLiveProperties.applyTo(adapter.config),
        ).registration(),
      )
      ..registerBackend(const IjkPlayerAdapterFactory().registration())
      ..registerBackend(const BetterPlayerAdapterFactory().registration())
      ..attachPresentation(
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
    return _kernel!;
  }

  static Future<void> ensureInitialized() async {
    MediaKitPlayerAdapter.ensureInitialized();
    logRing = mlog.MediaCoreLog.attachMemorySink(capacity: 500);
    if (!const bool.fromEnvironment('dart.vm.product')) {
      mlog.MediaCoreLog.level = mlog.LogLevel.debug;
    }
    await MediaSessionBootstrap.attachTo(instance.kernel, config: const MediaSessionConfig.video());
  }
}
