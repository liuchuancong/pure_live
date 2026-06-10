import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/plugins/backup_recovery_service.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final LogController logController = LogController.to;
  String get backupDirectory => SettingsService.to.backup.backupDirectory.v;
  String get m3uDirectory => SettingsService.to.iptv.m3uDirectory.v;

  Future<void> _openLogDirectory() async {
    try {
      Directory logDir;
      if (Platform.isAndroid) {
        final dir = await getDownloadsDirectory();
        logDir = Directory(path.join(dir!.path, AppPathManager.dirLogs));
      } else {
        logDir = await AppPathManager().getDir(AppPathManager.dirLogs);
      }

      if (await logDir.exists()) {
        FileUtils.openFileOrUrl(path.join(logDir.path, 'log'));
      } else {
        ToastUtil.show(i18n('log_dir_not_exist'));
      }
    } catch (e) {
      ToastUtil.show(i18n('open_log_dir_failed'));
    }
  }

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
            context.buildGroupTitle(i18n("cloud_backup")),
            context.buildModernCard([
              context.buildTile(
                iconWidget: auth.isConnecting
                    ? RotationTransition(
                        turns: const AlwaysStoppedAnimation(0.5),
                        child: Icon(Remix.refresh_line, color: Theme.of(context).colorScheme.primary, size: 22),
                      )
                    : Icon(
                        Remix.account_circle_line,
                        color: auth.isInitSuccess ? null : Theme.of(context).colorScheme.error,
                        size: 22,
                      ),
                isLong: !auth.isInitSuccess,
                subtitleColor: auth.isInitSuccess ? null : Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                title: auth.isConnecting
                    ? i18n('firebase_connecting_title')
                    : (auth.isInitSuccess
                          ? (auth.isLogin ? i18n('firebase_mine') : i18n('firebase_sign_in'))
                          : i18n('firebase_init_failed')),
                subtitle: auth.isConnecting
                    ? i18n('firebase_connecting_desc')
                    : (auth.isInitSuccess
                          ? (auth.isLogin ? i18n('firebase_logged_in_desc') : i18n('firebase_login_desc'))
                          : i18n('firebase_init_failed_desc')),
                trailing: auth.isConnecting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                        ),
                      )
                    : null,
                onTap: () {
                  if (!auth.isInitSuccess) {
                    if (auth.isConnecting) {
                      Get.snackbar(
                        i18n('firebase_init_failed'),
                        i18n('firebase_connecting_desc'),
                        snackPosition: SnackPosition.bottom,
                      );
                      return;
                    }
                    Get.snackbar(
                      i18n('firebase_init_failed'),
                      i18n('firebase_init_failed_desc'),
                      snackPosition: SnackPosition.bottom,
                    );
                    auth.startAsyncInit();
                    return;
                  }
                  if (auth.isLogin) {
                    Get.toNamed(RoutePath.kMine);
                  } else {
                    Get.toNamed(RoutePath.kSignIn);
                  }
                },
              ),

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
            context.buildGroupTitle(i18n("local_backup")),
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
            context.buildGroupTitle(i18n("backup_settings")),
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
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("log_manage")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.file_text_line,
                title: i18n("enable_local_log"),
                subtitle: i18n("enable_local_log_desc"),
                trailing: Switch(
                  value: logController.storedEnableLog.v,
                  onChanged: (val) => logController.storedEnableLog.v = val,
                ),
                onTap: () => logController.storedEnableLog.v = !logController.storedEnableLog.v,
              ),
              Obx(() {
                if (logController.serverPort.value == 0) return const SizedBox.shrink();
                final String displayAddress = logController.serverAddress.value == '0.0.0.0'
                    ? 'localhost'
                    : logController.serverAddress.value;
                final String urlStr = 'http://$displayAddress:${logController.serverPort.value}';
                return context.buildTile(
                  icon: Remix.global_line,
                  title: i18n("view_logs_in_browser"),
                  subtitle: urlStr,
                  trailing: const Icon(Remix.arrow_right_s_line),
                  onTap: () async {
                    final Uri uri = Uri.parse(urlStr);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                );
              }),

              context.buildTile(
                icon: Remix.folder_open_line,
                title: i18n("open_log_dir"),
                subtitle: i18n("open_log_dir_desc"),
                onTap: _openLogDirectory,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}
