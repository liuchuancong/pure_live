import '../interface/unified_player_interface.dart';

class PreloadPlayerManager {
  UnifiedPlayer? current;

  UnifiedPlayer? standby;

  Future<void> preload(UnifiedPlayer player, String url, List<String> playUrls, Map<String, String> headers) async {
    standby = player;

    await standby!.setDataSource(url, playUrls, headers);

    await standby!.pause();
  }

  Future<void> switchToStandby() async {
    if (standby == null) return;

    current = standby;

    standby = null;

    await current?.play();
  }
}
