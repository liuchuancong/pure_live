import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class IptvSyncEngine {
  static final IptvSyncEngine instance = IptvSyncEngine._internal();
  IptvSyncEngine._internal();

  final _iptvImportManager = IptvImportManager();

  Future<bool> syncPlaylist(database.Provider provider, {bool showTips = false}) async {
    if (provider.url == null || provider.url!.trim().isEmpty) return false;

    File? tempFile;
    try {
      final String rawStringContent = await HttpClient.instance.getText(provider.url!);
      final String trimmedContent = rawStringContent.trim();

      if (trimmedContent.isEmpty) {
        return false;
      }

      final String ext = provider.type.startsWith('.') ? provider.type : '.${provider.type}';

      if (ext.toLowerCase() == '.m3u' || ext.toLowerCase() == '.m3u8') {
        if (!trimmedContent.startsWith('#EXTM3U')) {
          return false;
        }
      } else if (ext.toLowerCase() == '.txt') {
        if (!trimmedContent.contains(',') && !trimmedContent.contains('#genre#')) {
          return false;
        }
      }

      await deletePlaylistsByName(provider.name);

      final tempDir = Directory.systemTemp;
      tempFile = File(p.join(tempDir.path, 'sync_${provider.id}$ext'));
      await tempFile.writeAsString(rawStringContent);

      final bool success = await _iptvImportManager.importIptvFile(
        file: tempFile,
        providerName: provider.name,
        isHot: provider.id == FileUtils.systemHotProviderId,
        url: provider.url!,
        forceUpdate: true,
        showTips: false,
      );

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (showTips) {
        ToastUtil.show(i18n('sync_success'));
      }
      return success;
    } catch (e) {
      debugPrint("❌ IPTV Sync Process Error (Network or IO Fails): $e");
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      return false;
    }
  }

  Future<bool> deletePlaylistsByName(String providerName) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = providerName.trim().toLowerCase();
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);

      final List<database.Provider> existingProviders = await db.getAllProviders();
      final matchedItems = existingProviders.where((p) => p.name.trim().toLowerCase() == cleanName).toList();

      if (matchedItems.isNotEmpty) {
        for (final item in matchedItems) {
          await db.deleteProviderAndChannels(item.id);
          await db.deleteMappingsByProviderId(item.id);

          final String dotExt = item.type.startsWith('.') ? item.type : '.${item.type}';
          final cachedFile = File(p.join(dir.path, '${item.id}$dotExt'));
          if (await cachedFile.exists()) {
            await cachedFile.delete();
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint("Delete playlists by name crashed: $e");
      return false;
    }
  }
}
