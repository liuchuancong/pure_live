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
  String get backupDirectory => SettingsService.to.backup.backupDirectory.v;
  String get m3uDirectory => SettingsService.to.iptv.m3uDirectory.v;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("backup_recover"))),
      body: Obx(() {
        final auth = Get.find<AuthController>();
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            context.buildGroupTitle("Firebase"),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.account_circle_line,
                title: auth.isLogin ? i18n('firebase_mine') : i18n('firebase_sign_in'),
                subtitle: auth.isLogin ? i18n('firebase_logged_in_desc') : i18n('firebase_login_desc'),
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
                  await BackupRecoveryService().createAppSettingsBackup(backupDirectory);
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
            context.buildGroupTitle(i18n("auto_backup")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.folder_open_line,
                title: i18n("backup_directory"),
                subtitle: backupDirectory.isEmpty ? i18n('please_set_backup_directory') : backupDirectory,
                onTap: () async {
                  await BackupRecoveryService().updateBackupDirectory();
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}
