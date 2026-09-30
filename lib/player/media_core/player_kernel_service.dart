import 'package:media_core/media_core.dart';
import 'package:media_core_better_player/media_core_video_player.dart';
import 'package:media_core_fvp/media_core_fvp.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  PlayerKernel? _kernel;

  PlayerKernel get kernel {
    _kernel ??= PlayerKernel()
      ..registerBackend(const MediaKitAdapterFactory().registration())
      ..registerBackend(const IjkPlayerAdapterFactory().registration())
      ..registerBackend(const BetterPlayerAdapterFactory().registration())
      ..registerBackend(const FvpAdapterFactory().registration(priority: 80));
    return _kernel!;
  }

  static Future<void> ensureInitialized() async {
    MediaKitPlayerAdapter.ensureInitialized();
    instance.kernel;
  }
}
