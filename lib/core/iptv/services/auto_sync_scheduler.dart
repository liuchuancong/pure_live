import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/services/epg_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class AutoSyncScheduler {
  static final AutoSyncScheduler instance = AutoSyncScheduler._internal();
  AutoSyncScheduler._internal();

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
        await EpgSyncEngine.instance.updateEpgCache(epg, forceUpdate: true);
      }
    } catch (e) {
      log("Auto sync background task working failed: $e");
    }
  }

  Future<void> loadHotResources() async {
    final mirror = GitHubMirror(owner: 'taksssss', repo: 'tv', branch: 'main');
    final urls = mirror.mirrors('assets/51zmt.m3u');
    final fastUrl = await RaceHttp.findFastestUrl(urls);
    IptvImportManager().importFromNetworkUrl(fastUrl!, AppPathManager.iptvHotFile, forceUpdate: true, showTips: false);
  }

  Future<void> loadDefaultEpgResources() async {
    final mirror = GitHubMirror(owner: 'taksssss', repo: 'tv', branch: 'main');
    final urls = mirror.mirrors('epg/51zmt.xml');
    final fastUrl = await RaceHttp.findFastestUrl(urls);
    await EpgImportManager().importFromNetworkUrl(
      fastUrl!,
      AppPathManager.iptvHotFile,
      forceUpdate: true,
      showTips: false,
    );
    var settings = Get.find<SettingsService>();
    if (settings.selectedSourceId.isEmpty) {
      final db = Get.find<DbService>().db;
      List<EpgSource> epgSources = await db.getAllEpgSources();
      if (epgSources.isNotEmpty && settings.selectedSourceId.value.isEmpty) {
        final activeSource = epgSources.first;
        settings.selectedSourceId.value = activeSource.id;
        settings.selectedSourceName.value = activeSource.name;
      }
    }
  }
}
