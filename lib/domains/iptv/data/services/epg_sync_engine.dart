import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/iptv/data/local/db_service.dart';
import 'package:pure_live/core/platform/file_utils.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/core/widgets/toast_util.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/platform/app_path_manager.dart';
import 'package:pure_live/domains/iptv/data/local/database.dart' as database;
import 'package:pure_live/domains/iptv/data/services/epg_import_manager.dart';

class EpgSyncEngine {
  static final EpgSyncEngine instance = EpgSyncEngine._internal();
  EpgSyncEngine._internal();

  Future<bool> updateEpgCache(database.EpgSource source, {bool forceUpdate = false, bool showTips = false}) async {
    if (source.url.trim().isEmpty) return false;
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final ext = EpgImportManager.extensionForUrl(source.url);

      tempFile = File(p.join(tempDir.path, 'sync_epg_${FileUtils.generateUuid()}$ext'));

      await HttpClient.instance.download(
        source.url,
        tempFile.path,
        header: {
          "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
        },
      );
      final bool success = await EpgImportManager().importEpgFile(
        file: tempFile,
        sourceName: source.name,
        expectedSource: source,
        forceUpdate: forceUpdate,
        url: source.url,
        showTips: showTips,
      );

      if (showTips) {
        if (success) {
          ToastUtil.show("${source.name} ${i18n('epg_source_updated')}");
        } else {
          ToastUtil.show("${source.name} ${i18n('epg_import_failed')}");
        }
      }

      return success;
    } catch (e) {
      debugPrint("❌ EPG Sync Process Error (Network or Decode Fails): $e");
      if (showTips) {
        ToastUtil.show("${source.name} ${i18n('epg_import_failed')}");
      }

      return false;
    } finally {
      if (tempFile != null) {
        for (final temporary in [tempFile, File('${tempFile.path}.part')]) {
          try {
            if (await temporary.exists()) await temporary.delete();
          } catch (e) {
            debugPrint('EPG sync temporary cleanup failed: $e');
          }
        }
      }
    }
  }

  Future<bool> checkEpgSourceDuplication(String sourceName) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();

      final List<database.EpgSource> existingSources = await db.getAllEpgSources();
      final matchedItems = existingSources.where((e) => e.name.trim().toLowerCase() == cleanName).toList();

      return matchedItems.isNotEmpty;
    } catch (e) {
      debugPrint("Database EPG duplication check failure: $e");
      return false;
    }
  }

  static Future<bool> deleteEpgSourcesByName(String sourceName) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final List<database.EpgSource> existingSources = await db.getAllEpgSources();
      final matchedItems = existingSources.where((e) => e.name.trim().toLowerCase() == cleanName).toList();

      if (matchedItems.isNotEmpty) {
        for (final item in matchedItems) {
          if (!await EpgImportManager().deleteSourceDurably(item)) return false;
          final lowercaseUrl = item.url.toLowerCase();
          final String ext = lowercaseUrl.endsWith('.json') ? '.json' : (lowercaseUrl.endsWith('.gz') ? '.gz' : '.xml');
          final cachedFile = File(p.join(dir.path, '${item.id}$ext'));
          if (await cachedFile.exists()) {
            await cachedFile.delete();
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint("Delete epg sources by name crashed: $e");
      return false;
    }
  }
}
