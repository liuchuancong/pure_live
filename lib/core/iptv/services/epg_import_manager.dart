import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/parsers/xmltv_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/parsers/json_epg_parser.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class EpgImportManager {
  /// 1. 本地文件浏览器选择导入
  Future<bool> importFromLocalPicker() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['xml', 'gz', 'json'],
    );

    if (result == null || result.files.single.path == null) return false;

    final file = File(result.files.single.path!);
    final name = FileUtils.getBaseName(file.path);
    return await importEpgFile(file: file, sourceName: name);
  }

  /// 2. 远程网络订阅 URL 下载导入
  Future<bool> importFromNetworkUrl(String url, String sourceName) async {
    final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);

    final lowercaseUrl = url.toLowerCase().trim();
    final String ext = lowercaseUrl.endsWith('.json') ? '.json' : (lowercaseUrl.endsWith('.gz') ? '.gz' : '.xml');
    final file = File(p.join(dir.path, 'download_epg_${FileUtils.generateUuid()}$ext'));

    try {
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

      final success = await importEpgFile(file: file, sourceName: sourceName);
      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      debugPrint("Network EPG Download Failure: $e");
      ToastUtil.show(i18n("epg_import_failed"));
      if (await file.exists()) await file.delete();
      return false;
    }
  }

  /// 3. Web 文本字符串恢复导入
  Future<bool> importFromWebString(String fileString, String sourceName) async {
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final String ext = fileString.trim().startsWith('{') ? '.json' : '.xml';
      final file = File(p.join(dir.path, 'web_epg_${FileUtils.generateUuid()}$ext'));
      await file.writeAsString(fileString);

      final success = await importEpgFile(file: file, sourceName: sourceName);
      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  /// 4. 系统分享接收导入
  /// 4. 从系统 Share 管道媒体数据中恢复 EPG 节目单（已添加安全格式校验）
  Future<bool> importFromSharedMedia(dynamic media) async {
    try {
      if (media.content == null || media.content!.isEmpty) {
        ToastUtil.show(i18n("epg_import_failed"));
        return false;
      }

      File file = await FileUtils.convertPhysicalFile(media.content!);
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.xml' && ext != '.gz' && ext != '.json') {
        ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }
      final success = await importEpgFile(file: file, sourceName: FileUtils.getBaseName(file.path));
      return success;
    } catch (e) {
      debugPrint("Shared EPG Import Process Crash: $e");
      ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  /// 5. 核心：EPG 处理与【已修复的同名弹窗】拦截逻辑
  Future<bool> importEpgFile({required File file, required String sourceName, bool forceUpdate = false}) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      final ext = p.extension(file.path).toLowerCase();
      String sourceId = FileUtils.generateUuid();

      final existing = await db.getAllEpgSources();
      final matchedList = existing.where((e) => (e.name).trim().toLowerCase() == cleanName).toList();

      // 【核心修复：检测到同名节目单，阻断并弹出 Dialog】
      if (matchedList.isNotEmpty && !forceUpdate) {
        final completer = Completer<bool>();
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(i18n("provider_name_exists_tip")),
            content: Text('${i18n("active_epg_source")} "$sourceName" ${i18n("delete_confirm_message")}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(Get.context!).pop();
                  completer.complete(false); // 取消则返回 false
                },
                child: Text(i18n("cancel")),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(Get.context!).pop();
                  // 确认后，带上 forceUpdate = true 递归调用
                  final success = await importEpgFile(file: file, sourceName: sourceName, forceUpdate: true);
                  completer.complete(success);
                },
                child: Text(i18n("confirm")),
              ),
            ],
          ),
          barrierDismissible: false,
        );
        return await completer.future; // 挂起挂起，等待弹窗用户的选择结果
      }

      if (matchedList.isNotEmpty && forceUpdate) {
        sourceId = matchedList.first.id;
        if (matchedList.length > 1) {
          await db.transaction(() async {
            for (int i = 1; i < matchedList.length; i++) {
              final duplicateItem = matchedList[i];
              await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
              await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
              await (db.delete(db.epgSources)..where((t) => t.id.equals(duplicateItem.id))).go();
            }
          });
        }
      }

      String content;
      if (ext == '.gz') {
        final bytes = await file.readAsBytes();
        final decoded = GZipDecoder().decodeBytes(bytes);
        content = utf8.decode(decoded);
      } else {
        content = await file.readAsString();
      }

      await db.upsertEpgSource(
        database.EpgSourcesCompanion.insert(
          id: sourceId,
          name: sourceName,
          url: file.path,
          lastRefresh: drift.Value(DateTime.now()),
        ),
      );

      await db.transaction(() async {
        await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(sourceId))).go();
        await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(sourceId))).go();
      });

      if (ext == '.xml' || ext == '.gz') {
        await _parseAndInsertXmltvOptimized(content, sourceId, db);
      } else if (ext == '.json') {
        await _parseAndInsertJsonEpgOptimized(content, sourceId, db);
      }

      await db.pruneOldProgrammes(maxAge: const Duration(days: 2));

      ToastUtil.show(i18n("epg_import_success")); // 补充回上层成功提示
      return true;
    } catch (e) {
      debugPrint("EPG Import Failure: $e");
      ToastUtil.show(i18n("epg_import_failed")); // 补充回上层失败提示
      return false;
    }
  }

  Future<void> _parseAndInsertXmltvOptimized(String content, String sourceId, dynamic db) async {
    final parser = XmltvParser();
    final result = parser.parse(content, sourceId: sourceId);

    if (result.channels.isNotEmpty) {
      final channelCompanions = result.channels.map((e) {
        return database.EpgChannelsCompanion.insert(
          id: e.id,
          sourceId: e.sourceId,
          channelId: e.id,
          displayName: e.displayNames.isNotEmpty ? e.displayNames.first : e.id,
          iconUrl: drift.Value(e.iconUrl),
        );
      }).toList();
      await db.upsertEpgChannels(channelCompanions);
    }

    if (result.programmes.isNotEmpty) {
      const int batchSize = 500;
      List<database.EpgProgrammesCompanion> chunk = [];

      for (var e in result.programmes) {
        if (e.channelId.isEmpty || e.title.isEmpty) continue;

        chunk.add(
          database.EpgProgrammesCompanion.insert(
            sourceId: e.sourceId,
            epgChannelId: e.channelId,
            title: e.title,
            start: e.start,
            stop: e.stop,
            description: drift.Value(e.description),
            subtitle: drift.Value(e.subtitle),
            episodeNum: drift.Value(e.episodeNum),
          ),
        );

        if (chunk.length >= batchSize) {
          await db.transaction(() async {
            await db.insertProgrammes(chunk);
          });
          chunk.clear();
          await Future.delayed(Duration.zero);
        }
      }

      if (chunk.isNotEmpty) {
        await db.transaction(() async {
          await db.insertProgrammes(chunk);
        });
        chunk.clear();
      }
    }
  }

  Future<void> _parseAndInsertJsonEpgOptimized(String content, String sourceId, dynamic db) async {
    final parser = JsonEpgParser();
    final result = parser.parse(content, sourceId: sourceId);

    if (result.channels.isNotEmpty) {
      final channelCompanions = result.channels.map((e) {
        return database.EpgChannelsCompanion.insert(
          id: e.id,
          sourceId: e.sourceId,
          channelId: e.id,
          displayName: e.displayNames.isNotEmpty ? e.displayNames.first : e.id,
          iconUrl: drift.Value(e.iconUrl),
        );
      }).toList();
      await db.upsertEpgChannels(channelCompanions);
    }

    if (result.programmes.isNotEmpty) {
      const int batchSize = 500;
      List<database.EpgProgrammesCompanion> chunk = [];

      for (var e in result.programmes) {
        if (e.channelId.isEmpty || e.title.isEmpty) continue;

        chunk.add(
          database.EpgProgrammesCompanion.insert(
            sourceId: e.sourceId,
            epgChannelId: e.channelId,
            title: e.title,
            start: e.start,
            stop: e.stop,
            description: drift.Value(e.description),
            subtitle: drift.Value(e.subtitle),
            episodeNum: drift.Value(e.episodeNum),
          ),
        );
        if (chunk.length >= batchSize) {
          await db.transaction(() async {
            await db.insertProgrammes(chunk);
          });
          chunk.clear();
          await Future.delayed(Duration.zero);
        }
      }
      if (chunk.isNotEmpty) {
        await db.transaction(() async {
          await db.insertProgrammes(chunk);
        });
        chunk.clear();
      }
    }
  }
}
