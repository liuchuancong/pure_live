import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:synchronized/synchronized.dart';
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/parsers/xmltv_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/parsers/json_epg_parser.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/local/epg_channel_identity.dart';

class EpgImportManager {
  EpgImportManager({Future<Directory> Function()? cacheDirectory})
    : _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory;

  final Future<Directory> Function() _cacheDirectory;
  static final _importLock = Lock();

  static Future<Directory> _defaultCacheDirectory() => AppPathManager().getDir(AppPathManager.dirIptvCache);

  /// 1. 本地文件浏览器选择导入
  Future<bool> importFromLocalPicker() async {
    final result = await FilePicker.pickFile(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['xml', 'gz', 'json'],
    );

    if (result?.path == null) return false;

    final file = File(result!.path!);
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
    File? file;
    try {
      final dir = await _cacheDirectory();
      String cleanName = p.basename(sourceName);
      while (p.extension(cleanName).isNotEmpty) {
        cleanName = p.basenameWithoutExtension(cleanName);
      }
      sourceName = cleanName;
      final ext = extensionForUrl(url);
      file = File(p.join(dir.path, 'download_epg_${FileUtils.generateUuid()}$ext'));
      await HttpClient.instance.download(
        url,
        file.path,
        header: {
          "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
        },
      );

      final success = await importEpgFile(
        file: file,
        sourceName: sourceName,
        url: url,
        forceUpdate: forceUpdate,
        showTips: showTips,
      );

      return success;
    } catch (e) {
      debugPrint("Network EPG Download Failure: $e");
      if (showTips) {
        ToastUtil.show(i18n("epg_import_failed"));
      }
      return false;
    } finally {
      if (file != null) {
        // HttpClient.download owns a .part sibling until the rename succeeds.
        // Clean only files allocated by this import; cleanup must not mask a commit.
        for (final temporary in [file, File('${file.path}.part')]) {
          try {
            if (await temporary.exists()) await temporary.delete();
          } catch (e) {
            debugPrint('EPG temporary download cleanup failed: $e');
          }
        }
      }
    }
  }

  static String extensionForUrl(String url) {
    final path = Uri.tryParse(url.trim())?.path.toLowerCase() ?? '';
    if (path.endsWith('.json')) return '.json';
    if (path.endsWith('.gz')) return '.gz';
    return '.xml';
  }

  /// 3. Web 文本字符串恢复导入
  Future<bool> importFromWebString(String fileString, String sourceName) async {
    try {
      final dir = await _cacheDirectory();
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

  /// 4. 从系统 Share 管道媒体数据中恢复 EPG 节目单（已添加安全格式校验）
  Future<bool> importFromSharedMedia(dynamic media) async {
    File? file;
    try {
      if (media.content == null || media.content!.isEmpty) {
        ToastUtil.show(i18n("epg_import_failed"));
        return false;
      }

      file = await FileUtils.convertPhysicalFile(media.content!);
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
    } finally {
      if (file != null) await FileUtils.cleanupOwnedSharedMediaFile(file);
    }
  }

  Future<bool> deleteSourceDurably(database.EpgSource expectedSource) {
    return _importLock.synchronized(() async {
      final db = Get.find<DbService>().db;
      final current = await db.getEpgSourceById(expectedSource.id);
      if (current != expectedSource) return false;
      await db.deleteEpgSourceCascading(expectedSource.id);
      return true;
    });
  }

  Future<bool> importEpgFile({
    required File file,
    required String sourceName,
    bool forceUpdate = false,
    String url = '',
    bool showTips = true,
    database.EpgSource? expectedSource,
  }) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      final ext = p.extension(file.path).toLowerCase();
      final typeName = ext.replaceAll('.', '').toUpperCase();
      final bytes = await file.readAsBytes();
      final decoded = ext == '.gz' ? GZipDecoder().decodeBytes(bytes) : bytes;
      // Preserve explicitly declared Latin-1 XML while decoding ordinary XML/JSON
      // as strict UTF-8. Malformed bytes must fail before any saved data is deleted.
      final declaration = latin1.decode(decoded.take(512).toList());
      final isLatin1 =
          ext != '.json' &&
          RegExp(
            r'''^\s*<\?xml\b[^>]*\bencoding\s*=\s*["'](?:iso-8859-1|latin1)["']''',
            caseSensitive: false,
          ).hasMatch(declaration);
      final content = isLatin1 ? latin1.decode(decoded) : utf8.decode(decoded);

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

      var cancelled = false;
      final success = await _importLock.synchronized(() async {
        final List<database.EpgSource> matchedList;
        if (expectedSource != null) {
          final current = await db.getEpgSourceById(expectedSource.id);
          if (current != expectedSource) return false;
          matchedList = [current!];
        } else {
          final existing = await db.getAllEpgSources();
          matchedList = existing.where((e) => (e.name).trim().toLowerCase() == cleanName).toList();
        }

        var finalSourceId = FileUtils.generateUuid();
        if (matchedList.isNotEmpty) finalSourceId = matchedList.first.id;

        if (!forceUpdate && matchedList.isNotEmpty) {
          final confirmed = await Get.dialog<bool>(
            Builder(
              builder: (context) => AlertDialog(
                scrollable: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(i18n("provider_name_exists_tip")),
                content: Text('"$sourceName"\n\n${i18n("replace_confirm_message").replaceAll("{}", typeName)}'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(i18n("cancel"))),
                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(i18n("confirm"))),
                ],
              ),
            ),
            barrierDismissible: false,
          );
          if (confirmed != true) {
            cancelled = true;
            return false;
          }
        }

        // The lock owns source discovery and commit as one operation, so a
        // background refresh cannot replace the source while a user import is
        // awaiting confirmation. The transaction still owns deletion, every
        // programme batch and final pruning.
        return db.transaction(() async {
          for (final source in matchedList) {
            if (await db.getEpgSourceById(source.id) != source) return false;
          }
          for (final duplicate in matchedList.skip(1)) {
            await db.deleteEpgSourceCascading(duplicate.id);
          }
          await db.deleteEpgProgrammesForSource(finalSourceId);
          await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(finalSourceId))).go();
          await _executeDatabaseWrite(
            db: db,
            file: file,
            sourceId: finalSourceId,
            sourceName: sourceName,
            parsedResult: parsedResult,
            url: url,
          );
          return true;
        });
      });

      if (success) {
        if (showTips) ToastUtil.show(i18n("epg_import_success"));
      } else if (!cancelled) {
        if (showTips) ToastUtil.show(i18n("epg_import_failed"));
      }
      return success;
    } catch (e) {
      debugPrint("EPG Import Failure: $e");
      if (showTips) ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  Future<void> _executeDatabaseWrite({
    required database.AppDatabase db,
    required File file,
    required String sourceId,
    required String sourceName,
    required dynamic parsedResult,
    String url = '',
  }) async {
    // Updating only imported fields preserves switches, interval and creation time.
    final updated = await (db.update(db.epgSources)..where((t) => t.id.equals(sourceId))).write(
      database.EpgSourcesCompanion(
        name: drift.Value(sourceName),
        url: drift.Value(url.isNotEmpty ? url : file.path),
        lastRefresh: drift.Value(DateTime.now()),
      ),
    );
    if (updated == 0) {
      await db.upsertEpgSource(
        database.EpgSourcesCompanion.insert(
          id: sourceId,
          name: sourceName,
          url: url.isNotEmpty ? url : file.path,
          lastRefresh: drift.Value(DateTime.now()),
        ),
      );
    }

    if (parsedResult.channels.isNotEmpty) {
      final channelCompanions = parsedResult.channels.map<database.EpgChannelsCompanion>((e) {
        return database.EpgChannelsCompanion.insert(
          id: epgChannelKey(sourceId, e.id),
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
            epgChannelId: epgChannelKey(sourceId, e.channelId),
            title: e.title,
            start: e.start,
            stop: e.stop,
            description: drift.Value(e.description),
            subtitle: drift.Value(e.subtitle),
            episodeNum: drift.Value(e.episodeNum),
            catchupId: drift.Value(e.catchupId),
          ),
        );

        if (chunk.length >= batchSize) {
          await db.insertProgrammes(chunk);
          chunk.clear();
          await Future.delayed(Duration.zero);
        }
      }

      if (chunk.isNotEmpty) {
        await db.insertProgrammes(chunk);
        chunk.clear();
      }
    }

    await db.pruneOldProgrammes(maxAge: const Duration(days: 2));
  }
}
