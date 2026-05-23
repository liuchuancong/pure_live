import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';

class EpgSyncEngine {
  static final EpgSyncEngine instance = EpgSyncEngine._internal();
  EpgSyncEngine._internal();

  Future<bool> updateEpgCache(database.EpgSource source, {bool forceUpdate = false, bool showTips = false}) async {
    if (source.url.trim().isEmpty) return false;
    try {
      final tempDir = Directory.systemTemp;
      final lowercaseUrl = source.url.toLowerCase();
      final String ext = lowercaseUrl.endsWith('.json') ? '.json' : (lowercaseUrl.endsWith('.gz') ? '.gz' : '.xml');

      File tempFile = File(p.join(tempDir.path, 'sync_epg_${FileUtils.generateUuid()}$ext'));

      await HttpClient.instance.download(
        source.url,
        tempFile.path,
        header: {
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
        },
      );
      final bool success = await EpgImportManager().importEpgFile(
        file: tempFile,
        sourceName: source.name,
        forceUpdate: forceUpdate,
        url: source.url,
      );

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

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
          await db.deleteEpgSourceCascading(item.id);
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
