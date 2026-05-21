import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/services/epg_sync_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';

class IptvAutoSyncScheduler {
  static final IptvAutoSyncScheduler instance = IptvAutoSyncScheduler._internal();
  IptvAutoSyncScheduler._internal();

  Future<void> checkAndExecuteAutoSync() async {
    final settings = Get.find<SettingsService>();
    if (!settings.isAutoSyncEnabled.value) return;

    final db = Get.find<DbService>().db;
    final int hoursInterval = settings.autoSyncHoursInterval.value;
    final Duration checkInterval = Duration(hours: hoursInterval);

    try {
      final expiredPlaylists = await db.getExpiredNetworkProviders(checkInterval);
      for (var playlist in expiredPlaylists) {
        await IptvSyncEngine.instance.syncPlaylist(playlist);
      }

      final expiredEpgs = await db.getExpiredEpgSources(checkInterval);
      for (var epg in expiredEpgs) {
        await EpgSyncManager().updateEpgCache(sourceName: epg.name, downloadUrl: epg.url, forceUpdate: true);
      }
    } catch (e) {
      log("Auto sync background task working failed: $e");
    }
  }
}
