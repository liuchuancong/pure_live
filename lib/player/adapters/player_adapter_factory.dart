import 'package:media_core_better_player/media_core_video_player.dart' show kBetterPlayerBackendId;
import 'package:media_core_fvp/media_core_fvp.dart' show kFvpPlayerBackendId;
import 'package:media_core_ijk_player/media_core_ijk_player.dart' show kIjkPlayerBackendId;
import 'package:pure_live/player/adapters/kernel_unified_player.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/models/player_engine.dart';

class PlayerAdapterFactory {
  static Future<UnifiedPlayer> create(PlayerEngine engine) async {
    return switch (engine) {
      PlayerEngine.mediaKit => KernelUnifiedPlayer(),
      PlayerEngine.fijk => KernelUnifiedPlayer(backendId: kIjkPlayerBackendId),
      PlayerEngine.exo => KernelUnifiedPlayer(backendId: kBetterPlayerBackendId),
      PlayerEngine.fvp => KernelUnifiedPlayer(backendId: kFvpPlayerBackendId),
    };
  }
}
