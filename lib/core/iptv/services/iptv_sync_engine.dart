import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class IptvSyncEngine {
  static final IptvSyncEngine instance = IptvSyncEngine._internal();
  IptvSyncEngine._internal();
  final _iptvImportManager = IptvImportManager();

  Future<bool> syncPlaylist(database.Provider provider) async {
    if (provider.url == null || provider.url!.isEmpty) return false;

    try {
      final response = await HttpClient.instance.get(
        provider.url!,
        header: dio.Options(responseType: dio.ResponseType.bytes).headers,
      );
      if (response.statusCode != 200) {
        throw Exception("Network Error with status: ${response.statusCode}");
      }

      final tempDir = Directory.systemTemp;
      final String ext = provider.type.startsWith('.') ? provider.type : '.${provider.type}';
      final tempFile = File(p.join(tempDir.path, 'sync_${provider.id}$ext'));

      List<int> bytes;
      if (response.data is Uint8List) {
        bytes = response.data as Uint8List;
      } else if (response.data is List<int>) {
        bytes = response.data as List<int>;
      } else if (response.data is String) {
        bytes = (response.data as String).codeUnits;
      } else {
        throw Exception("Unsupported payload data type returned from HttpClient");
      }

      await tempFile.writeAsBytes(bytes);

      final bool success = await _iptvImportManager.importIptvFile(
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
      } else {
        ToastUtil.show("${provider.name} ${i18n('epg_import_failed')}");
      }

      return success;
    } catch (e) {
      debugPrint("IPTV Sync Process Error: $e");
      ToastUtil.show("${provider.name} ${i18n('epg_import_failed')}");
      return false;
    }
  }
}
