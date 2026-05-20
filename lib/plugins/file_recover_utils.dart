import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as p;
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:date_format/date_format.dart' hide S;
import 'package:pure_live/core/iptv/iptv_utils.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class FileRecoverUtils {
  ///获取后缀
  static String getName(String fullName) {
    return fullName.split(Platform.pathSeparator).last;
  }

  ///获取uuid
  static String getUUid() {
    var currentTime = DateTime.now().millisecondsSinceEpoch;
    var randomValue = Random().nextInt(4294967295);
    var result = (currentTime % 10000000000 * 1000 + randomValue) % 4294967295;
    return result.toString();
  }

  ///验证URL
  static bool isUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    List<String?> urlMatches = urlRegExp.allMatches(value).map((m) => m.group(0)).toList();
    return urlMatches.isNotEmpty;
  }

  ///验证URL
  static bool isHostUrl(String value) {
    final urlRegExp = RegExp(
      r"((https?:www\.)|(https?:\/\/))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?",
    );
    List<String?> urlMatches = urlRegExp.allMatches(value).map((m) => m.group(0)).toList();
    return urlMatches.isNotEmpty;
  }

  ///验证URL
  static bool isPort(String value) {
    final portRegExp = RegExp(r"\d+");
    List<String?> portMatches = portRegExp.allMatches(value).map((m) => m.group(0)).toList();
    return portMatches.isNotEmpty;
  }

  Future<bool> recoverNetworkM3u8Backup(String url, String fileName) async {
    final dioInstance = dio.Dio(
      dio.BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
    );

    try {
      final Directory cacheDir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final File m3ufile = File(p.join(cacheDir.path, '$fileName.m3u'));
      final File categories = File(p.join(cacheDir.path, AppPathManager.iptvCategoryFile));
      dio.Response response = await dioInstance.download(url, m3ufile.path);
      if (response.statusCode != 200 && response.statusCode != 304) {
        SnackBarUtil.error(i18n("file_download_failed_retry"));
        return false;
      }
      if (!categories.existsSync()) {
        categories.createSync();
      }

      String jsonData = await categories.readAsString();
      List jsonArr = jsonData.isNotEmpty ? jsonDecode(jsonData) : [];
      List<IptvCategory> categoriesArr = jsonArr.map((e) => IptvCategory.fromJson(e)).toList();
      final int existingIndex = categoriesArr.indexWhere((element) => element.id == url);

      if (existingIndex == -1) {
        categoriesArr.add(IptvCategory(id: url, name: p.basenameWithoutExtension(m3ufile.path), path: m3ufile.path));
      } else {
        categoriesArr[existingIndex].name = fileName;
      }

      categories.writeAsStringSync(jsonEncode(categoriesArr.map((e) => e.toJson()).toList()));

      SnackBarUtil.success(i18n("recover_backup_success"));
      return true;
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
      return false;
    }
  }

  Future<bool> requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isDenied) {
      final status = Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
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
    if (selectedDirectory == null) return null;

    final dateStr = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
    final file = File('$selectedDirectory/purelive_$dateStr.txt');
    if (settings.backup(file)) {
      SnackBarUtil.success(i18n("create_backup_success"));
      // 首次同步备份目录
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
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (settings.recover(file)) {
      SnackBarUtil.success(i18n("recover_backup_success"));
    } else {
      SnackBarUtil.error(i18n("recover_backup_failed"));
    }
  }

  // 选择备份目录
  Future<String?> selectBackupDirectory(String backupDirectory) async {
    final settings = Get.find<SettingsService>();
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) return null;
    settings.backupDirectory.value = selectedDirectory;
    return selectedDirectory;
  }

  Future<bool> recoverM3u8BackupByWeb(String fileString, String fileName) async {
    try {
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final m3ufile = File(p.join(dir.path, fileName));
      m3ufile.writeAsStringSync(fileString);
      List jsonArr = [];
      final categories = File(p.join(dir.path, AppPathManager.iptvCategoryFile));
      if (!categories.existsSync()) {
        categories.createSync();
      }
      String jsonData = await categories.readAsString();
      jsonArr = jsonData.isNotEmpty ? jsonDecode(jsonData) : [];
      List<IptvCategory> categoriesArr = jsonArr.map((e) => IptvCategory.fromJson(e)).toList();
      if (categoriesArr.indexWhere((element) => element.path == m3ufile.path) == -1) {
        categoriesArr.add(
          IptvCategory(id: getUUid(), name: getName(m3ufile.path).replaceAll(RegExp(r'.m3u'), ''), path: m3ufile.path),
        );
      }
      categories.writeAsStringSync(jsonEncode(categoriesArr.map((e) => e.toJson()).toList()));
      SnackBarUtil.success(i18n("recover_backup_success"));
      return true;
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
      return false;
    }
  }

  Future<bool> recoverM3u8Backup() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['m3u'],
    );
    if (result == null || result.files.single.path == null) return false;

    try {
      final file = File(result.files.single.path!);
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final m3ufile = File(p.join(dir.path, getName(file.path)));
      List jsonArr = [];
      final categories = File(p.join(dir.path, AppPathManager.iptvCategoryFile));
      if (!categories.existsSync()) {
        categories.createSync();
      }
      String jsonData = await categories.readAsString();
      jsonArr = jsonData.isNotEmpty ? jsonDecode(jsonData) : [];
      List<IptvCategory> categoriesArr = jsonArr.map((e) => IptvCategory.fromJson(e)).toList();
      if (categoriesArr.indexWhere((element) => element.path == m3ufile.path) == -1) {
        categoriesArr.add(
          IptvCategory(id: getUUid(), name: getName(m3ufile.path).replaceAll(RegExp(r'.m3u'), ''), path: m3ufile.path),
        );
      }

      categories.writeAsStringSync(jsonEncode(categoriesArr.map((e) => e.toJson()).toList()));
      file.copySync(m3ufile.path);
      SnackBarUtil.success(i18n("recover_backup_success"));
      return true;
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
      return false;
    }
  }

  Future<bool> recoverSettingsBackup(String httpAddress) async {
    final SettingsService service = Get.find<SettingsService>();
    try {
      final response = await await HttpClient.instance.postJson(
        '$httpAddress/api/setSettings',
        queryParameters: {"settings": jsonEncode(service.toJson())},
      );
      return jsonDecode(response)['data'];
    } catch (e) {
      return false;
    }
  }

  Future<bool> recoverM3u8BackupByShare(SharedMedia media) async {
    try {
      File file = await toFile(media.content!);
      var dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);
      final m3ufile = File(p.join(dir.path, getName(file.path)));
      List jsonArr = [];
      final categories = File(p.join(dir.path, AppPathManager.iptvCategoryFile));
      if (!categories.existsSync()) {
        categories.createSync();
      }
      String jsonData = await categories.readAsString();
      jsonArr = jsonData.isNotEmpty ? jsonDecode(jsonData) : [];
      List<IptvCategory> categoriesArr = jsonArr.map((e) => IptvCategory.fromJson(e)).toList();
      if (categoriesArr.indexWhere((element) => element.path == m3ufile.path) == -1) {
        categoriesArr.add(
          IptvCategory(id: getUUid(), name: getName(m3ufile.path).replaceAll(RegExp(r'.m3u'), ''), path: m3ufile.path),
        );
      }
      categories.writeAsStringSync(jsonEncode(categoriesArr.map((e) => e.toJson()).toList()));
      file.copySync(m3ufile.path);
      SnackBarUtil.success(i18n("recover_backup_success"));
      return true;
    } catch (e) {
      SnackBarUtil.error(i18n("recover_backup_failed"));
      return false;
    }
  }
}
