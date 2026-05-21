import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final settings = Get.find<SettingsService>();
  late String backupDirectory = settings.backupDirectory.value;
  late String m3uDirectory = settings.m3uDirectory.value;

  SizedBox spacer(double height) {
    return SizedBox(height: height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SectionTitle(title: i18n("backup_recover")),

          ListTile(
            title: Text(i18n("webdav")),
            subtitle: Text(i18n("backup_to_webdav")),
            onTap: () async {
              Get.toNamed(RoutePath.kWebDavPage);
            },
          ),
          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              title: Text(i18n("sync_tv_data")),
              subtitle: Text(i18n("sync_tv_data_subtitle")),
              onTap: () async {
                Get.to(() => const ScanCodePage());
              },
            ),

          ListTile(
            title: Text(i18n("create_backup")),
            subtitle: Text(i18n("create_backup_subtitle")),
            onTap: () async {
              if (backupDirectory.isEmpty) {
                ToastUtil.show(i18n('please_set_backup_directory'));
                return;
              }
              final selectedDirectory = await FileRecoverUtils().createBackup(backupDirectory);
              if (selectedDirectory != null) {
                setState(() {
                  backupDirectory = selectedDirectory;
                });
              }
            },
          ),

          ListTile(
            title: Text(i18n("recover_backup")),
            subtitle: Text(i18n("recover_backup_subtitle")),
            onTap: () => FileRecoverUtils().recoverBackup(),
          ),

          SectionTitle(title: i18n("auto_backup")),

          ListTile(
            title: Text(i18n("backup_directory")),
            subtitle: Text(backupDirectory),
            onTap: () async {
              final selectedDirectory = await FileRecoverUtils().selectBackupDirectory(backupDirectory);

              if (selectedDirectory != null) {
                setState(() {
                  backupDirectory = selectedDirectory;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
