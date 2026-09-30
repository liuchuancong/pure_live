import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';

class PlayerKernelService {
  PlayerKernelService._();

  static final PlayerKernelService instance = PlayerKernelService._();

  PlayerKernel? _kernel;

  PlayerKernel get kernel {
    _kernel ??= PlayerKernel()..registerBackend(const MediaKitAdapterFactory().registration());
    return _kernel!;
  }

  static Future<void> ensureInitialized() async {
    MediaKitPlayerAdapter.ensureInitialized();
    instance.kernel;
  }
}
