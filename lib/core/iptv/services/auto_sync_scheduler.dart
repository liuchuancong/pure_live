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
    if (!SettingsService.to.iptv.isAutoSyncEnabled.v) return;

    final db = Get.find<DbService>().db;
    final int hoursInterval = SettingsService.to.iptv.autoSyncHoursInterval.v;
    final Duration checkInterval = Duration(hours: hoursInterval);

    try {
      final expiredPlaylists = await db.getExpiredNetworkProviders(checkInterval);
      for (var playlist in expiredPlaylists) {
        await IptvSyncEngine.instance.syncPlaylist(playlist);
      }
      final expiredEpgs = await db.getExpiredEpgSources(checkInterval);
      for (var epg in expiredEpgs) {
        await EpgSyncEngine.instance.updateEpgCache(epg, forceUpdate: true, showTips: false);
      }
    } catch (e) {
      log("Auto sync background task working failed: $e");
    }
  }

  Future<void> loadHotResources() async {
    final mirror = GitHubMirror(owner: 'best-fan', repo: 'iptv-sources', branch: 'main');
    final urls = mirror.mirrors('cn_all.m3u8');
    final fastUrl = await RaceHttp.findFastestUrl(urls);
    IptvImportManager().importFromNetworkUrl(
      fastUrl!,
      AppPathManager.iptvHotFile,
      forceUpdate: true,
      showTips: false,
      isHot: true,
    );
  }

  Future<void> loadDefaultEpgResources() async {
    final epgSource = 'https://epg.zsdc.eu.org/t.xml.gz';
    await EpgImportManager().importFromNetworkUrl(
      epgSource,
      AppPathManager.iptvHotFile,
      forceUpdate: true,
      showTips: false,
    );
    if (SettingsService.to.iptv.selectedSourceId.v.isEmpty) {
      final db = Get.find<DbService>().db;
      List<EpgSource> epgSources = await db.getAllEpgSources();
      if (epgSources.isNotEmpty && SettingsService.to.iptv.selectedSourceId.v.isEmpty) {
        final activeSource = epgSources.first;
        SettingsService.to.iptv.selectedSourceId.v = activeSource.id;
        SettingsService.to.iptv.selectedSourceName.v = activeSource.name;
      }
    }
  }
}
