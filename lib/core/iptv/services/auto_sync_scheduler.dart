import 'dart:developer';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/services/epg_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class AutoSyncScheduler {
  static final AutoSyncScheduler instance = AutoSyncScheduler._internal();
  AutoSyncScheduler._internal();

  final IptvResourceLoadGate _hotResourcesGate = IptvResourceLoadGate();
  final IptvResourceLoadGate _defaultEpgResourcesGate = IptvResourceLoadGate();

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

  Future<void> loadHotResources() => _hotResourcesGate.run(_loadHotResources);

  Future<void> _loadHotResources() async {
    final iptvUrl = 'https://iptv-org.github.io/iptv/countries/cn.m3u';
    await IptvImportManager().importFromNetworkUrl(
      iptvUrl,
      AppPathManager.iptvHotFile,
      forceUpdate: true,
      showTips: false,
      isHot: true,
    );
  }

  Future<void> loadDefaultEpgResources() => _defaultEpgResourcesGate.run(_loadDefaultEpgResources);

  Future<void> _loadDefaultEpgResources() async {
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

/// Coalesces simultaneous feature-entry requests into one import without
/// caching a failure or a completed operation forever.
@visibleForTesting
class IptvResourceLoadGate {
  Future<void>? _inFlight;

  Future<void> run(Future<void> Function() operation) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> tracked;
    tracked = Future<void>.sync(operation).whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    _inFlight = tracked;
    return tracked;
  }
}
