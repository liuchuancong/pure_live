import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:date_format/date_format.dart' hide S;
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/iptv/local/database.dart';
import 'package:pure_live/core/iptv/parsers/m3u_parser.dart';
import 'package:pure_live/core/iptv/parsers/txt_parser.dart';
import 'package:pure_live/core/iptv/parsers/xmltv_parser.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/parsers/json_epg_parser.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class FileRecoverUtils {
  static String getName(String fullName) {
    return fullName.split(Platform.pathSeparator).last;
  }

  static String getUUid() {
    var currentTime = DateTime.now().millisecondsSinceEpoch;

    var randomValue = Random().nextInt(4294967295);

    var result = (currentTime % 10000000000 * 1000 + randomValue) % 4294967295;

    return result.toString();
  }

  static bool isUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );

    List<String?> urlMatches = urlRegExp.allMatches(value).map((m) => m.group(0)).toList();

    return urlMatches.isNotEmpty;
  }

  static bool isHostUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );

    List<String?> urlMatches = urlRegExp.allMatches(value).map((m) => m.group(0)).toList();

    return urlMatches.isNotEmpty;
  }

  static bool isPort(String value) {
    final portRegExp = RegExp(r"\d+");

    List<String?> portMatches = portRegExp.allMatches(value).map((m) => m.group(0)).toList();

    return portMatches.isNotEmpty;
  }

  Future<bool> requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isDenied) {
      final status = await Permission.manageExternalStorage.request();

      return status.isGranted;
    }

    return true;
  }

  Future<bool> importIptvFile({
    required File file,
    required String providerName,
    bool isHot = false,
    String url = '',
    bool forceUpdate = false,
  }) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = providerName.trim().toLowerCase();
      String providerId = isHot ? 'hot' : FileRecoverUtils.getUUid();

      if (!isHot) {
        final existing = await db.getAllProviders();
        final matchedList = existing.where((p) => p.name.trim().toLowerCase() == cleanName).toList();

        if (matchedList.isNotEmpty) {
          if (!forceUpdate) {
            Get.dialog(
              AlertDialog(
                title: Text(i18n("provider_name_exists_tip")),
                content: Text('${i18n("active_epg_source")} "$providerName" ${i18n("delete_confirm_message")}'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(Get.context!).pop();
                      await importIptvFile(
                        file: file,
                        providerName: providerName,
                        isHot: isHot,
                        url: url,
                        forceUpdate: true,
                      );
                    },
                    child: Text(i18n("confirm")),
                  ),
                ],
              ),
            );
            return false;
          }
          providerId = matchedList.first.id;
          if (matchedList.length > 1) {
            for (int i = 1; i < matchedList.length; i++) {
              final duplicateItem = matchedList[i];
              await (db.delete(db.channels)..where((t) => t.providerId.equals(duplicateItem.id))).go();
              await (db.delete(db.providers)..where((t) => t.id.equals(duplicateItem.id))).go();
            }
          }
        }
      }

      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final ext = p.extension(file.path);
      final savedFile = File(p.join(dir.path, '$providerId$ext'));
      if (isHot && await savedFile.exists()) {
        await savedFile.delete();
      }
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

      final content = await savedFile.readAsString();
      final result = ext.toLowerCase() == '.txt'
          ? TxtParser().parse(content, providerId: providerId)
          : M3uParser().parse(content, providerId: providerId);

      await (db.delete(db.channels)..where((t) => t.providerId.equals(providerId))).go();
      await (db.delete(db.epgMappings)..where((t) => t.providerId.equals(providerId))).go();

      await db.upsertChannels(
        result.channels.map((e) {
          return database.ChannelsCompanion.insert(
            id: e.id,
            providerId: e.providerId,
            name: e.name,
            streamUrl: e.streamUrl,
            groupTitle: drift.Value(e.groupTitle),
            tvgId: drift.Value(e.tvgId),
            tvgName: drift.Value(e.tvgName),
            tvgLogo: drift.Value(e.tvgLogo),
          );
        }).toList(),
      );

      ToastUtil.show(i18n("sync_success"));
      return true;
    } catch (e) {
      ToastUtil.show(i18n("sync_failed"));
      return false;
    }
  }

  /// =========================================================
  /// 本地导入 m3u/txt
  /// =========================================================

  Future<bool> recoverM3u8Backup() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['m3u', 'txt', 'xml', 'gz', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      return false;
    }

    final file = File(result.files.single.path!);
    final ext = p.extension(file.path).toLowerCase();
    final name = p.basenameWithoutExtension(file.path);
    if (ext == '.m3u' || ext == '.txt') {
      return await importIptvFile(file: file, providerName: name);
    }
    if (ext == '.xml' || ext == '.gz' || ext == '.json') {
      return await importEpgFile(file: file, sourceName: name);
    }
    ToastUtil.show(i18n('unsupported_file_format'));
    return false;
  }

  Future<bool> importEpgFile({required File file, required String sourceName, bool forceUpdate = false}) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = sourceName.trim().toLowerCase();
      final ext = p.extension(file.path).toLowerCase();
      String sourceId = FileRecoverUtils.getUUid();

      final existing = await db.getAllEpgSources();
      final matchedList = existing.where((e) => (e.name).trim().toLowerCase() == cleanName).toList();

      if (matchedList.isNotEmpty) {
        if (!forceUpdate) {
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(i18n("provider_name_exists_tip")),
              content: Text('${i18n("active_epg_source")} "$sourceName" ${i18n("delete_confirm_message")}'),
              actions: [
                TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
                TextButton(
                  onPressed: () async {
                    Navigator.of(Get.context!).pop();
                    await importEpgFile(file: file, sourceName: sourceName, forceUpdate: true);
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            ),
          );
          return false;
        }

        sourceId = matchedList.first.id;
        if (matchedList.length > 1) {
          for (int i = 1; i < matchedList.length; i++) {
            final duplicateItem = matchedList[i];
            await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
            await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(duplicateItem.id))).go();
            await (db.delete(db.epgSources)..where((t) => t.id.equals(duplicateItem.id))).go();
          }
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
        EpgSourcesCompanion.insert(
          id: sourceId,
          name: sourceName,
          url: file.path,
          lastRefresh: drift.Value(DateTime.now()),
        ),
      );

      await (db.delete(db.epgProgrammes)..where((t) => t.sourceId.equals(sourceId))).go();
      await (db.delete(db.epgChannels)..where((t) => t.sourceId.equals(sourceId))).go();

      if (ext == '.xml' || ext == '.gz') {
        final parser = XmltvParser();
        final result = parser.parse(content, sourceId: sourceId);

        await db.upsertEpgChannels(
          result.channels.map((e) {
            return EpgChannelsCompanion.insert(
              id: e.id,
              sourceId: e.sourceId,
              channelId: e.id,
              displayName: e.displayNames.isNotEmpty ? e.displayNames.first : e.id,
              iconUrl: drift.Value(e.iconUrl),
            );
          }).toList(),
        );

        await db.insertProgrammes(
          result.programmes.map((e) {
            return EpgProgrammesCompanion.insert(
              sourceId: e.sourceId,
              epgChannelId: e.channelId,
              title: e.title,
              start: e.start,
              stop: e.stop,
              description: drift.Value(e.description),
              subtitle: drift.Value(e.subtitle),
              episodeNum: drift.Value(e.episodeNum),
            );
          }).toList(),
        );
      } else if (ext == '.json') {
        final parser = JsonEpgParser();
        final result = parser.parse(content, sourceId: sourceId);

        await db.upsertEpgChannels(
          result.channels.map((e) {
            return EpgChannelsCompanion.insert(
              id: e.id,
              sourceId: e.sourceId,
              channelId: e.id,
              displayName: e.displayNames.isNotEmpty ? e.displayNames.first : e.id,
              iconUrl: drift.Value(e.iconUrl),
            );
          }).toList(),
        );

        await db.insertProgrammes(
          result.programmes.map((e) {
            return EpgProgrammesCompanion.insert(
              sourceId: e.sourceId,
              epgChannelId: e.channelId,
              title: e.title,
              start: e.start,
              stop: e.stop,
              description: drift.Value(e.description),
              subtitle: drift.Value(e.subtitle),
              episodeNum: drift.Value(e.episodeNum),
            );
          }).toList(),
        );
      }

      await db.pruneOldProgrammes(maxAge: const Duration(days: 2));
      ToastUtil.show(i18n("epg_import_success"));
      return true;
    } catch (e) {
      debugPrint("$e");
      ToastUtil.show(i18n("epg_import_failed"));
      return false;
    }
  }

  Future<bool> recoverNetworkM3u8Backup(String url, String fileName) async {
    try {
      final lowercaseUrl = url.toLowerCase().trim();
      if (!lowercaseUrl.endsWith('.m3u') && !lowercaseUrl.endsWith('.txt') && !lowercaseUrl.endsWith('.m3u8')) {
        ToastUtil.show(i18n("unsupported_file_format"));
        return false;
      }
      final dioInstance = dio.Dio(
        dio.BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
      );
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final file = File(p.join(dir.path, '$fileName.m3u'));

      await dioInstance.download(url, file.path);
      return await importIptvFile(
        file: file,
        providerName: fileName,
        isHot: fileName == 'hot',
        url: url,
        forceUpdate: false,
      );
    } catch (e) {
      debugPrint("$e");
      ToastUtil.show(i18n("network_import_failed"));
      return false;
    }
  }

  Future<bool> recoverM3u8BackupByWeb(String fileString, String fileName) async {
    try {
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);

      final file = File(p.join(dir.path, fileName));

      await file.writeAsString(fileString);

      return await importIptvFile(
        file: file,
        providerName: p.basenameWithoutExtension(fileName),
        isHot: fileName == 'hot',
      );
    } catch (e) {
      ToastUtil.show(i18n("network_import_failed"));

      return false;
    }
  }

  Future<bool> recoverM3u8BackupByShare(SharedMedia media) async {
    try {
      File file = await toFile(media.content!);
      return await importIptvFile(file: file, providerName: p.basenameWithoutExtension(file.path));
    } catch (e) {
      ToastUtil.show(i18n("local_import_failed"));
      return false;
    }
  }

  Future<String?> createBackup(String backupDirectory) async {
    final settings = Get.find<SettingsService>();
    if (Platform.isAndroid || Platform.isIOS) {
      final granted = await requestStoragePermission();
      if (!granted) {
        ToastUtil.show(i18n("grant_storage_permission_first"));
        return null;
      }
    }

    String? selectedDirectory = await FilePicker.getDirectoryPath(
      initialDirectory: backupDirectory.isEmpty ? '/' : backupDirectory,
    );
    if (selectedDirectory == null) {
      return null;
    }
    final dateStr = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
    final file = File('$selectedDirectory/purelive_$dateStr.txt');
    if (settings.backup(file)) {
      ToastUtil.show(i18n("create_backup_success"));
      if (settings.backupDirectory.isEmpty) {
        settings.backupDirectory.value = selectedDirectory;
      }
      return selectedDirectory;
    } else {
      ToastUtil.show(i18n("create_backup_failed"));

      return null;
    }
  }

  void recoverBackup() async {
    final settings = Get.find<SettingsService>();

    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final file = File(result.files.single.path!);

    if (settings.recover(file)) {
      ToastUtil.show(i18n("recover_backup_success"));
    } else {
      ToastUtil.show(i18n("recover_backup_failed"));
    }
  }

  Future<String?> selectBackupDirectory(String backupDirectory) async {
    final settings = Get.find<SettingsService>();

    String? selectedDirectory = await FilePicker.getDirectoryPath();

    if (selectedDirectory == null) {
      return null;
    }

    settings.backupDirectory.value = selectedDirectory;

    return selectedDirectory;
  }

  Future<bool> recoverSettingsBackup(String httpAddress) async {
    final SettingsService service = Get.find<SettingsService>();

    try {
      final response = await HttpClient.instance.postJson(
        '$httpAddress/api/setSettings',
        queryParameters: {"settings": jsonEncode(service.toJson())},
      );

      return jsonDecode(response)['data'];
    } catch (e) {
      return false;
    }
  }
}
