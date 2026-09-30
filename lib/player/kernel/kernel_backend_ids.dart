import 'package:media_core_better_player/media_core_video_player.dart' show kBetterPlayerBackendId;
import 'package:media_core_fvp/media_core_fvp.dart' show kFvpPlayerBackendId;
import 'package:media_core_ijk_player/media_core_ijk_player.dart' show kIjkPlayerBackendId;
import 'package:media_core_media_kit/media_core_media_kit.dart' show kMediaKitPlayerBackendId;
import 'package:pure_live/player/models/player_engine.dart';

/// 引擎设置 → kernel 后端 id 的唯一映射。
String backendIdOfEngine(PlayerEngine engine) => switch (engine) {
  PlayerEngine.mediaKit => kMediaKitPlayerBackendId,
  PlayerEngine.fijk => kIjkPlayerBackendId,
  PlayerEngine.exo => kBetterPlayerBackendId,
  PlayerEngine.fvp => kFvpPlayerBackendId,
};
