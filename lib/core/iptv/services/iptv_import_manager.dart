import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/parsers/m3u_parser.dart';
import 'package:pure_live/core/iptv/parsers/txt_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class IptvImportManager {
  /// 1. 本地文件浏览器选择导入
  Future<bool> importFromLocalPicker() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['m3u', 'txt'],
    );

    if (result == null || result.files.single.path == null) return false;

    final file = File(result.files.single.path!);
    final name = FileUtils.getBaseName(file.path);
    return await importIptvFile(file: file, providerName: name);
  }

  /// 2. 远程网络订阅 URL 下载导入
  Future<bool> importFromNetworkUrl(String url, String fileName) async {
    final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
    final file = File(p.join(dir.path, 'download_iptv_${FileUtils.generateUuid()}.m3u'));

    try {
      final lowercaseUrl = url.toLowerCase().trim();
      if (!{'.m3u', '.txt', '.m3u8'}.any((ext) => lowercaseUrl.endsWith(ext))) {
        ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }

      final response = await HttpClient.instance.get(
        url,
        header: dio.Options(responseType: dio.ResponseType.bytes).headers,
      );
      if (response.statusCode != 200) throw Exception("Download failed");

      List<int> bytes;
      if (response.data is Uint8List) {
        bytes = response.data as Uint8List;
      } else if (response.data is List<int>) {
        bytes = response.data as List<int>;
      } else {
        bytes = (response.data as String).codeUnits;
      }
      await file.writeAsBytes(bytes);

      final success = await importIptvFile(file: file, providerName: fileName, url: url);
      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      debugPrint("Network IPTV Download Failure: $e");
      ToastUtil.show(i18n("network_import_failed"));
      if (await file.exists()) await file.delete();
      return false;
    }
  }

  /// 3. Web 文本字符串恢复导入
  Future<bool> importFromWebString(String fileString, String fileName) async {
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final file = File(p.join(dir.path, 'web_iptv_${FileUtils.generateUuid()}.m3u'));
      await file.writeAsString(fileString);

      final success = await importIptvFile(file: file, providerName: FileUtils.getBaseName(fileName));
      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      ToastUtil.show(i18n("network_import_failed"));
      return false;
    }
  }

  /// 4. 系统分享接收导入
  /// 4. 从系统 Share 管道媒体数据中恢复 IPTV 频道（已添加安全格式校验）
  Future<bool> importFromSharedMedia(dynamic media) async {
    try {
      if (media.content == null || media.content!.isEmpty) {
        ToastUtil.show(i18n("local_import_failed"));
        return false;
      }

      File file = await FileUtils.convertPhysicalFile(media.content!);
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.m3u' && ext != '.txt') {
        ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }
      final success = await importIptvFile(file: file, providerName: FileUtils.getBaseName(file.path));
      return success;
    } catch (e) {
      debugPrint("Shared IPTV Import Process Crash: $e");
      ToastUtil.show(i18n("local_import_failed"));
      return false;
    }
  }

  /// 5. 核心：解析与【已修复的同名弹窗】逻辑
  Future<bool> importIptvFile({
    required File file,
    required String providerName,
    bool isHot = false,
    String url = '',
    bool forceUpdate = false,
  }) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      final typeName = ext == '.txt' ? 'TXT' : 'M3U';
      final content = await file.readAsString();

      final parsedResult = ext == '.txt'
          ? TxtParser().parse(content, providerId: '')
          : M3uParser().parse(content, providerId: '');

      if (parsedResult.channels.isEmpty) {
        ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }

      final db = Get.find<DbService>().db;
      final cleanName = providerName.trim().toLowerCase();
      String providerId = isHot ? 'hot' : FileUtils.generateUuid();
      if (!isHot && !forceUpdate) {
        final existing = await db.getAllProviders();
        final matchedList = existing.where((p) => p.name.trim().toLowerCase() == cleanName).toList();

        if (matchedList.isNotEmpty) {
          final completer = Completer<bool>();
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(i18n("provider_name_exists_tip")),
              content: Text('"$providerName" ${i18n("delete_confirm_message")}(包含旧的 $typeName 数据)'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(Get.context!).pop();
                    completer.complete(false); // 用户取消，返回 false
                  },
                  child: Text(i18n("cancel")),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(Get.context!).pop();
                    final targetId = matchedList.first.id;

                    // 清理残余记录
                    if (matchedList.length > 1) {
                      for (int i = 1; i < matchedList.length; i++) {
                        final duplicateItem = matchedList[i];
                        await (db.delete(db.channels)..where((t) => t.providerId.equals(duplicateItem.id))).go();
                        await (db.delete(db.providers)..where((t) => t.id.equals(duplicateItem.id))).go();
                      }
                    }

                    // 强行覆盖入库
                    final success = await _saveToDatabase(
                      db: db,
                      file: file,
                      ext: ext,
                      providerId: targetId,
                      providerName: providerName,
                      isHot: isHot,
                      url: url,
                      channels: parsedResult.channels,
                    );
                    completer.complete(success);
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          return await completer.future; // 挂起并等待用户在弹窗的选择结果
        }
      }

      // 如果不重名，直接写入
      final success = await _saveToDatabase(
        db: db,
        file: file,
        ext: ext,
        providerId: providerId,
        providerName: providerName,
        isHot: isHot,
        url: url,
        channels: parsedResult.channels,
      );
      if (success) ToastUtil.show(i18n("sync_success"));
      return success;
    } catch (e) {
      debugPrint("IPTV Import Error: $e");
      ToastUtil.show(i18n("sync_failed"));
      return false;
    }
  }

  Future<bool> _saveToDatabase({
    required dynamic db,
    required File file,
    required String ext,
    required String providerId,
    required String providerName,
    required bool isHot,
    required String url,
    required List<dynamic> channels,
  }) async {
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final savedFile = File(p.join(dir.path, '$providerId$ext'));

      if (isHot && await savedFile.exists()) await savedFile.delete();
      await file.copy(savedFile.path);

      if (isHot) {
        try {
          await db.deleteProvider('hot');
        } catch (_) {}
      }

      await db.upsertProvider(
        database.ProvidersCompanion.insert(
          id: providerId,
          name: providerName.trim(),
          type: ext.replaceAll('.', ''),
          url: drift.Value<String?>(url.isNotEmpty ? url : savedFile.path),
        ),
      );

      await (db.delete(db.channels)..where((t) => t.providerId.equals(providerId))).go();
      await (db.delete(db.epgMappings)..where((t) => t.providerId.equals(providerId))).go();

      await db.upsertChannels(
        channels.map((e) {
          return database.ChannelsCompanion.insert(
            id: e.id,
            providerId: providerId,
            name: e.name,
            streamUrl: e.streamUrl,
            groupTitle: drift.Value(e.groupTitle),
            tvgId: drift.Value(e.tvgId),
            tvgName: drift.Value(e.tvgName),
            tvgLogo: drift.Value(e.tvgLogo),
          );
        }).toList(),
      );

      return true;
    } catch (e) {
      debugPrint("Database Write Error: $e");
      return false;
    }
  }
}
