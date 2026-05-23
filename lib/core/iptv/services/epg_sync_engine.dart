import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';

class EpgSyncEngine {
  // 私有化构造函数，防止外部实例化
  EpgSyncEngine._();

  /// 远程同步网络 EPG 节目单（使用 database.EpgSource 实体作为统一入参）
  /// 返回 [true] 表示解析更新成功，[false] 表示失败。
  static Future<bool> updateEpgCache(database.EpgSource source, {bool forceUpdate = false}) async {
    if (source.url.trim().isEmpty) return false;

    File? tempFile;
    try {
      // 1. 发起网络请求获取原始字节数据（兼容 .xml, .json 以及二进制压缩包 .gz）
      final response = await HttpClient.instance.get(
        source.url,
        header: dio.Options(
          responseType: dio.ResponseType.bytes,
          headers: {
            "user-agent":
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
          },
        ).headers,
      );

      if (response.statusCode != 200) {
        throw Exception("Network Error with status: ${response.statusCode}");
      }

      final tempDir = Directory.systemTemp;
      final lowercaseUrl = source.url.toLowerCase();
      final String ext = lowercaseUrl.endsWith('.json') ? '.json' : (lowercaseUrl.endsWith('.gz') ? '.gz' : '.xml');

      tempFile = File(p.join(tempDir.path, 'sync_epg_${source.id}$ext'));

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

      final bool success = await EpgImportManager().importEpgFile(
        file: tempFile,
        sourceName: source.name,
        forceUpdate: forceUpdate,
      );

      // 无论解析入库成功或失败，安全释放临时缓存文件
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (success) {
        ToastUtil.show("${source.name} ${i18n('epg_source_updated')}");
      } else {
        ToastUtil.show("${source.name} ${i18n('epg_import_failed')}");
      }
      return success;
    } catch (e) {
      debugPrint("EPG Sync Process Error: $e");
      ToastUtil.show("${source.name} ${i18n('epg_import_failed')}");
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      return false;
    }
  }
}
