import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/adapters/fijk_adapter.dart';
import 'package:pure_live/player/adapters/media_kit_adapter.dart';
import 'package:pure_live/player/adapters/video_player_adapter.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class PlayerAdapterFactory {
  static Future<UnifiedPlayer> create(PlayerEngine engine) async {
    switch (engine) {
      case PlayerEngine.mediaKit:
        return MediaKitAdapter();

      case PlayerEngine.fijk:
        return FijkAdapter();

      case PlayerEngine.exo:
        return BetterPlayerAdapter();
    }
  }
}
