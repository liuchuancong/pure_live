import 'dart:io';
import 'dart:convert';

import '../../core/platform/file_utils.dart';

import 'package:pure_live/core/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:date_format/date_format.dart' hide S;
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/features/backup/backup_controller.dart';
import 'package:pure_live/features/backup/backup_section_picker.dart';

class BackupRecoveryService {
  Future<String?> createAppSettingsBackup(String backupDirectory) async {
    final backup = Get.find<BackupController>();
    // 先勾模块再选目录：取消勾选不该先弹一个系统目录框。
    final sections = await pickBackupSections(
      direction: BackupSectionDirection.export,
      available: BackupController.sectionNames,
    );
    if (sections == null) return null;

    final granted = await FileUtils.requestStoragePermission();
    if (!granted) {
      ToastUtil.show(i18n("grant_storage_permission_first"));
      return null;
    }

    String? selectedDirectory = await FilePicker.getDirectoryPath(
      initialDirectory: backupDirectory.isEmpty ? null : backupDirectory,
    );
    if (selectedDirectory == null) return null;

    final dateStr = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd, 'T', HH, '_', nn, '_', ss]);
    final file = File('$selectedDirectory/purelive_$dateStr.txt');

    if (await backup.backup(file, sections: sections)) {
      if (backup.backupDirectory.v.isEmpty) {
        try {
          await backup.setBackupDirectoryDurably(selectedDirectory);
        } catch (_) {
          ToastUtil.show(i18n('backup_directory_update_failed'));
        }
      }
      ToastUtil.show(i18n("create_backup_success"));
      return selectedDirectory;
    } else {
      ToastUtil.show(i18n("create_backup_failed"));
      return null;
    }
  }

  Future<void> recoverSettingsFromFile() async {
    final backup = Get.find<BackupController>();
    final result = await FilePicker.pickFile(
      dialogTitle: i18n("select_recover_file"),
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result?.path == null) return;

    final file = File(result!.path!);
    final available = await BackupController.readBackupSections(file);
    if (available == null) {
      ToastUtil.show(i18n("recover_backup_failed"));
      return;
    }

    // 旧版扁平备份没有模块划分，只能整份恢复。
    List<String>? sections;
    if (available.isNotEmpty) {
      sections = await pickBackupSections(direction: BackupSectionDirection.import, available: available);
      if (sections == null) return;
    }

    if (await backup.recover(file, sections: sections)) {
      ToastUtil.show(i18n("recover_backup_success"));
    } else {
      ToastUtil.show(i18n("recover_backup_failed"));
    }
  }

  Future<String?> updateBackupDirectory() async {
    final backup = Get.find<BackupController>();
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) return null;

    await backup.setBackupDirectoryDurably(selectedDirectory);
    return selectedDirectory;
  }

  Future<bool> pushSettingsToRemoteServer(String httpAddress, {Iterable<String>? sections}) async {
    final backup = Get.find<BackupController>();
    try {
      final response = await HttpClient.instance.postJson(
        '$httpAddress/api/setSettings',
        queryParameters: {"settings": jsonEncode(backup.exportToTVSettings(sections: sections))},
      );
      return jsonDecode(response)['data'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
