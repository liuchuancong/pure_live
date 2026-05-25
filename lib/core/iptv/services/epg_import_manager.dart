import 'dart:io';
import 'dart:async';
import 'dart:convert';
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
  Future<bool> importFromNetworkUrl(
    String url,
    String sourceName, {
    bool forceUpdate = false,
    bool showTips = true,
  }) async {
    final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);

    String cleanName = p.basename(sourceName);
    while (p.extension(cleanName).isNotEmpty) {
      cleanName = p.basenameWithoutExtension(cleanName);
    }
    sourceName = cleanName;

    final lowercaseUrl = url.toLowerCase().trim();
    final String ext = lowercaseUrl.endsWith('.json') ? '.json' : (lowercaseUrl.endsWith('.gz') ? '.gz' : '.xml');
    final file = File(p.join(dir.path, 'download_epg_${FileUtils.generateUuid()}$ext'));

    try {
      await HttpClient.instance.download(
        url,
        file.path,
        header: {
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
        },
      );

      final success = await importEpgFile(
        file: file,
        sourceName: sourceName,
        url: url,
        forceUpdate: forceUpdate,
        showTips: showTips,
      );

      if (await file.exists()) await file.delete();
      return success;
    } catch (e) {
      debugPrint("Network EPG Download Failure: $e");
      if (showTips) {
        ToastUtil.show(i18n("epg_import_failed"));
      }
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

  Future<bool> importEpgFile({
    required File file,
    required String sourceName,
    bool forceUpdate = false,
    String url = '',
    bool showTips = true,
  }) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      final ext = p.extension(file.path).toLowerCase();
      final typeName = ext.replaceAll('.', '').toUpperCase();
      String content;
      if (ext == '.gz') {
        final bytes = await file.readAsBytes();
        final decoded = GZipDecoder().decodeBytes(bytes);
        content = utf8.decode(decoded);
      } else {
        content = await file.readAsString(encoding: latin1);
      }

      dynamic parsedResult;
      if (ext == '.xml' || ext == '.gz') {
        parsedResult = XmltvParser().parse(content, sourceId: '');
      } else if (ext == '.json') {
        parsedResult = JsonEpgParser().parse(content, sourceId: '');
      } else {
        if (showTips) ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }

      if (parsedResult == null || (parsedResult.channels.isEmpty && parsedResult.programmes.isEmpty)) {
        if (showTips) ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }

      final existing = await db.getAllEpgSources();
      final matchedList = existing.where((e) => (e.name).trim().toLowerCase() == cleanName).toList();

      String finalSourceId = FileUtils.generateUuid();

      if (matchedList.isNotEmpty) {
        finalSourceId = matchedList.first.id;
      }

      if (!forceUpdate) {
        if (matchedList.isNotEmpty) {
          final completer = Completer<bool>();
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(i18n("provider_name_exists_tip")),
              content: Text('"$sourceName"\n\n${i18n("replace_confirm_message").replaceAll("{}", typeName)}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(Get.context!).pop();
                    completer.complete(false);
                  },
                  child: Text(i18n("cancel")),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(Get.context!).pop();

                    if (matchedList.length > 1) {
                      for (int i = 1; i < matchedList.length; i++) {
                        final duplicateItem = matchedList[i];
                        await db.deleteEpgSourceCascading(duplicateItem.id);
                      }
                    }
                    await db.deleteEpgProgrammesForSource(finalSourceId);
                    await db.deleteEpgSourceCascading(finalSourceId);

                    final success = await _executeDatabaseWrite(
                      db: db,
                      file: file,
                      sourceId: finalSourceId,
                      sourceName: sourceName,
                      ext: ext,
                      parsedResult: parsedResult,
                      url: url,
                    );
                    completer.complete(success);
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          return await completer.future;
        }
      }

      if (matchedList.isNotEmpty) {
        if (matchedList.length > 1) {
          for (int i = 1; i < matchedList.length; i++) {
            await db.deleteEpgSourceCascading(matchedList[i].id);
          }
        }
        await db.deleteEpgProgrammesForSource(finalSourceId);
        await db.deleteEpgSourceCascading(finalSourceId);
      }

      final success = await _executeDatabaseWrite(
        db: db,
        file: file,
        sourceId: finalSourceId,
        sourceName: sourceName,
        ext: ext,
        parsedResult: parsedResult,
        url: url,
      );

      if (success) {
        if (showTips) ToastUtil.show(i18n("epg_import_success"));
      } else {
        if (showTips) ToastUtil.show(i18n("epg_import_failed"));
      }
      return success;
    } catch (e) {
      debugPrint("EPG Import Failure: $e");
      if (showTips) ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  Future<bool> _executeDatabaseWrite({
    required dynamic db,
    required File file,
    required String sourceId,
    required String sourceName,
    required String ext,
    required dynamic parsedResult,
    String url = '',
  }) async {
    try {
      await db.upsertEpgSource(
        database.EpgSourcesCompanion.insert(
          id: sourceId,
          name: sourceName,
          url: url.isNotEmpty ? url : file.path,
          lastRefresh: drift.Value(DateTime.now()),
        ),
      );

      if (parsedResult.channels.isNotEmpty) {
        final channelCompanions = parsedResult.channels.map<database.EpgChannelsCompanion>((e) {
          return database.EpgChannelsCompanion.insert(
            id: e.id,
            sourceId: sourceId, // 绑定正确的映射主键
            channelId: e.id,
            displayName: e.displayNames.isNotEmpty ? e.displayNames.first : e.id,
            iconUrl: drift.Value(e.iconUrl),
          );
        }).toList();
        await db.upsertEpgChannels(channelCompanions);
      }

      if (parsedResult.programmes.isNotEmpty) {
        const int batchSize = 500;
        List<database.EpgProgrammesCompanion> chunk = [];
        for (var e in parsedResult.programmes) {
          if (e.channelId.isEmpty || e.title.isEmpty) continue;
          chunk.add(
            database.EpgProgrammesCompanion.insert(
              sourceId: sourceId, // 绑定正确的映射主键
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

      await db.pruneOldProgrammes(maxAge: const Duration(days: 2));
      return true;
    } catch (e) {
      debugPrint("EPG Database Exec Commit Crash: $e");
      return false;
    }
  }
}
