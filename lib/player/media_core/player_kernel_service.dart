import 'package:media_core/media_core.dart';
import 'package:media_core_better_player/media_core_video_player.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core_fvp/media_core_fvp.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_logging/media_core_logging.dart' as mlog;
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/player/adapters/kernel_owned_input.dart';
import 'package:pure_live/player/utils/fullscreen.dart';
import 'package:pure_live/player/utils/windows_pip_driver.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  static final FloatingDriver floatingDriver = FloatingDriver();

  /// kernel 侧日志的内存环（恢复梯/墙/呈现决策都在这里），供排障页拉取。
  static mlog.MemoryLogSink? logRing;

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
    // media_core 日志默认完全静默。debug 构建开到 debug 级并挂 500 条内存环；
    // release 只挂环不设级（宿主排障页可随时调级拉取）。
    logRing = mlog.MediaCoreLog.attachMemorySink(capacity: 500);
    if (!const bool.fromEnvironment('dart.vm.product')) {
      mlog.MediaCoreLog.level = mlog.LogLevel.debug;
    }
    // 系统媒体面：一次挂载，之后 kernel 的每个播放器自动上通知/SMTC/MPRIS。
    await MediaSessionBootstrap.attachTo(instance.kernel, config: const MediaSessionConfig.video());
  }
}
