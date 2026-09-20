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
  static final IptvSyncEngine instance = IptvSyncEngine();
  IptvSyncEngine({IptvImportManager? importManager, Future<Directory> Function()? temporaryDirectory})
    : _iptvImportManager = importManager ?? IptvImportManager(),
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final IptvImportManager _iptvImportManager;
  final Future<Directory> Function() _temporaryDirectory;

  Future<bool> syncPlaylist(database.Provider provider, {bool showTips = false}) async {
    Directory? temporary;
    bool success = false;
    try {
      final url = provider.url;
      if (url == null || url.trim().isEmpty) return false;
      final uri = Uri.tryParse(url);
      final network = uri?.scheme == 'http' || uri?.scheme == 'https';
      File file;
      if (network) {
        final content = await HttpClient.instance.getText(url);
        final trimmed = content.trim();
        if (trimmed.isEmpty) return false;
        final ext = provider.type.startsWith('.') ? provider.type.toLowerCase() : '.${provider.type.toLowerCase()}';
        if (!{'.m3u', '.m3u8', '.txt'}.contains(ext)) return false;
        if (ext != '.txt' && !trimmed.startsWith('#EXTM3U')) return false;
        if (ext == '.txt' && !trimmed.contains(',')) return false;
        final root = await _temporaryDirectory();
        await root.create(recursive: true);
        temporary = await root.createTemp('iptv-sync-');
        file = await File(p.join(temporary.path, 'input$ext')).writeAsString(content);
      } else {
        file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(url);
      }
      // The importer verifies this exact snapshot again; never delete by name
      // or recreate a provider removed/edited while the network request ran.
      success = await _iptvImportManager.importIptvFile(
        file: file,
        providerName: provider.name,
        expectedProvider: provider,
        isHot: provider.id == FileUtils.systemHotProviderId,
        url: network ? url : '',
        forceUpdate: true,
        showTips: false,
      );
      return success;
    } catch (e) {
      debugPrint('IPTV Sync Process Error: $e');
      return false;
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } catch (e) {
          debugPrint('IPTV sync temporary cleanup failed: $e');
        }
      }
      if (showTips) ToastUtil.show(i18n(success ? 'sync_success' : 'sync_failed'));
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
          if (!await _iptvImportManager.deleteProviderDurably(item)) return false;

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
