import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' as dio;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class IptvSyncEngine {
  static final IptvSyncEngine instance = IptvSyncEngine._internal();
  IptvSyncEngine._internal();

  Future<void> syncPlaylist(database.Provider provider) async {
    if (provider.url == null || provider.url!.isEmpty) return;

    try {
      final dioInstance = dio.Dio(
        dio.BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)),
      );

      final response = await dioInstance.get(provider.url!, options: dio.Options(responseType: dio.ResponseType.bytes));

      if (response.statusCode != 200) throw Exception("Network Error");

      final tempDir = Directory.systemTemp;
      final String ext = provider.type.startsWith('.') ? provider.type : '.${provider.type}';
      final tempFile = File(p.join(tempDir.path, 'sync_${provider.id}$ext'));

      await tempFile.writeAsBytes(response.data as List<int>);

      final bool success = await FileRecoverUtils().importIptvFile(
        file: tempFile,
        providerName: provider.name,
        isHot: provider.id == 'hot',
        url: provider.url!,
        forceUpdate: true,
      );

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (success) {
        ToastUtil.show("${provider.name} ${i18n('epg_source_updated')}");
      }
    } catch (e) {
      debugPrint("$e");
      ToastUtil.show("${provider.name} ${i18n('epg_import_failed')}");
    }
  }
}
