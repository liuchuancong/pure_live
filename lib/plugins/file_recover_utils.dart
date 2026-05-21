import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:uuid/uuid.dart';
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

  Future<bool> importIptvFile({required File file, required String providerName, bool isHot = false}) async {
    try {
      final db = Get.find<DbService>().db;
      final providerId = isHot ? 'hot' : FileRecoverUtils.getUUid();
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
        ProvidersCompanion.insert(
          id: providerId,
          name: providerName,
          type: ext.replaceAll('.', ''),
          url: drift.Value<String?>(file.path),
        ),
      );
      final content = await savedFile.readAsString();
      final result = ext.toLowerCase() == '.txt'
          ? TxtParser().parse(content, providerId: providerId)
          : M3uParser().parse(content, providerId: providerId);

      await db.upsertChannels(
        result.channels.map((e) {
          return ChannelsCompanion.insert(
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

      SnackBarUtil.success(i18n("recover_backup_success"));

      return true;
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
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
    SnackBarUtil.error('Unsupported file format');
    return false;
  }

  Future<bool> importEpgFile({required File file, required String sourceName}) async {
    try {
      final db = Get.find<DbService>().db;
      final ext = p.extension(file.path).toLowerCase();
      String content;
      if (ext == '.gz') {
        final bytes = await file.readAsBytes();
        final decoded = GZipDecoder().decodeBytes(bytes);
        content = utf8.decode(decoded);
      } else {
        content = await file.readAsString();
      }
      final sourceId = Uuid().v4();
      await db.upsertEpgSource(EpgSourcesCompanion.insert(id: sourceId, name: sourceName, url: file.path));
      if (ext == '.xml' || ext == '.gz') {
        final parser = XmltvParser();
        final result = parser.parse(content, sourceId: sourceId);
        // channels
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

        // programmes
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
      // =========================================================
      // JSON EPG
      // =========================================================
      else if (ext == '.json') {
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

        // programmes
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
      SnackBarUtil.success('EPG imported');
      return true;
    } catch (e) {
      SnackBarUtil.error('EPG import failed');

      return false;
    }
  }

  Future<bool> recoverNetworkM3u8Backup(String url, String fileName) async {
    try {
      final dioInstance = dio.Dio(
        dio.BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
      );
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final file = File(p.join(dir.path, '$fileName.m3u'));
      await dioInstance.download(url, file.path);
      return await importIptvFile(file: file, providerName: fileName, isHot: fileName == 'hot');
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));

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
      SnackBarUtil.error(i18n("recover_backup_failed"));

      return false;
    }
  }

  Future<bool> recoverM3u8BackupByShare(SharedMedia media) async {
    try {
      File file = await toFile(media.content!);
      return await importIptvFile(file: file, providerName: p.basenameWithoutExtension(file.path));
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
      return false;
    }
  }

  Future<String?> createBackup(String backupDirectory) async {
    final settings = Get.find<SettingsService>();
    if (Platform.isAndroid || Platform.isIOS) {
      final granted = await requestStoragePermission();
      if (!granted) {
        SnackBarUtil.error(i18n("grant_storage_permission_first"));
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
      SnackBarUtil.success(i18n("create_backup_success"));
      if (settings.backupDirectory.isEmpty) {
        settings.backupDirectory.value = selectedDirectory;
      }
      return selectedDirectory;
    } else {
      SnackBarUtil.error(i18n("create_backup_failed"));

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
      SnackBarUtil.success(i18n("recover_backup_success"));
    } else {
      SnackBarUtil.error(i18n("recover_backup_failed"));
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
