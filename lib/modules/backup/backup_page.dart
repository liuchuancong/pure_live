import 'dart:io';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/plugins/backup_recovery_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final settings = Get.find<SettingsService>();
  late String backupDirectory = settings.backupDirectory.value;
  late String m3uDirectory = settings.m3uDirectory.value;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: Text(i18n("backup_recover"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle("Supabase"),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.account_circle_line,
              title: auth.isLogin ? i18n('supabase_mine') : i18n('supabase_sign_in'),
              subtitle: auth.isLogin ? i18n('supabase_logged_in_desc') : i18n('supabase_login_desc'),
              onTap: () {
                if (auth.isLogin) {
                  Get.toNamed(RoutePath.kMine);
                } else {
                  Get.toNamed(RoutePath.kSignIn);
                }
              },
            ),
          ]),
          context.buildGroupTitle(i18n("webdav")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.cloud_line,
              title: i18n("webdav"),
              subtitle: i18n("backup_to_webdav"),
              onTap: () => Get.toNamed(RoutePath.kWebDavPage),
            ),
            if (Platform.isAndroid || Platform.isIOS)
              context.buildTile(
                icon: Remix.qr_code_line,
                title: i18n("sync_tv_data"),
                subtitle: i18n("sync_tv_data_subtitle"),
                onTap: () => Get.to(() => const ScanCodePage()),
              ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组二：本地数据快照
          context.buildGroupTitle(i18n("create_backup")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.file_download_line,
              title: i18n("create_backup"),
              subtitle: i18n("create_backup_subtitle"),
              onTap: () async {
                if (backupDirectory.isEmpty) {
                  ToastUtil.show(i18n('please_set_backup_directory'));
                  return;
                }
                final selectedDirectory = await BackupRecoveryService().createAppSettingsBackup(backupDirectory);
                if (selectedDirectory != null) {
                  setState(() {
                    backupDirectory = selectedDirectory;
                  });
                }
              },
            ),
            context.buildTile(
              icon: Remix.file_upload_line,
              title: i18n("recover_backup"),
              subtitle: i18n("recover_backup_subtitle"),
              onTap: () => BackupRecoveryService().recoverSettingsFromFile(),
            ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组三：自动化存储
          context.buildGroupTitle(i18n("auto_backup")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.folder_open_line,
              title: i18n("backup_directory"),
              subtitle: backupDirectory.isEmpty ? i18n('please_set_backup_directory') : backupDirectory,
              onTap: () async {
                final selectedDirectory = await BackupRecoveryService().updateBackupDirectory();
                if (selectedDirectory != null) {
                  setState(() {
                    backupDirectory = selectedDirectory;
                  });
                }
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
