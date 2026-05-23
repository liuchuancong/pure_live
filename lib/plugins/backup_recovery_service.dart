import 'dart:io';
import 'dart:convert';
import 'file_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:date_format/date_format.dart' hide S;
import 'package:pure_live/core/common/http_client.dart';

class BackupRecoveryService {
  /// 导出应用纯设置参数 (AppSettings) 文本快照
  Future<String?> createAppSettingsBackup(String backupDirectory) async {
    final settings = Get.find<SettingsService>();
    final granted = await FileUtils.requestStoragePermission();
    if (!granted) {
      ToastUtil.show(i18n("grant_storage_permission_first"));
      return null;
    }

    String? selectedDirectory = await FilePicker.getDirectoryPath(
      initialDirectory: backupDirectory.isEmpty ? '/' : backupDirectory,
    );
    if (selectedDirectory == null) return null;

    final dateStr = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
    final file = File('$selectedDirectory/purelive_$dateStr.txt');

    if (settings.backup(file)) {
      ToastUtil.show(i18n("create_backup_success"));
      if (settings.backupDirectory.value.isEmpty) {
        settings.backupDirectory.value = selectedDirectory;
      }
      return selectedDirectory;
    } else {
      ToastUtil.show(i18n("create_backup_failed"));
      return null;
    }
  }

  /// 导入 TXT 全局覆盖恢复设置参数 (AppSettings)
  void recoverSettingsFromFile() async {
    final settings = Get.find<SettingsService>();
    FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (settings.recover(file)) {
      ToastUtil.show(i18n("recover_backup_success"));
    } else {
      ToastUtil.show(i18n("recover_backup_failed"));
    }
  }

  /// 修改并记录系统的默认备份文件夹
  Future<String?> updateBackupDirectory() async {
    final settings = Get.find<SettingsService>();
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) return null;

    settings.backupDirectory.value = selectedDirectory;
    return selectedDirectory;
  }

  /// 局域网推送同步：将当前的设置通过接口同步给远端控制台
  Future<bool> pushSettingsToRemoteServer(String httpAddress) async {
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
