import 'package:media_core/media_core.dart';
import 'package:media_core_better_player/media_core_video_player.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core_fvp/media_core_fvp.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/player/adapters/kernel_owned_input.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:pure_live/player/utils/windows_pip_driver.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  static final FloatingDriver floatingDriver = FloatingDriver();

  PlayerKernel? _kernel;

  PlayerKernel get kernel {
    _kernel ??= PlayerKernel()
      ..registerBackend(
        const MediaKitAdapterFactory(
          config: MediaKitPlayerConfig(customInputOpener: openOwnedInputOnKernelPlayer),
        ).registration(),
      )
      ..registerBackend(const IjkPlayerAdapterFactory().registration())
      ..registerBackend(const BetterPlayerAdapterFactory().registration())
      ..registerBackend(const FvpAdapterFactory().registration(priority: 80))
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
    instance.kernel;
  }
}
