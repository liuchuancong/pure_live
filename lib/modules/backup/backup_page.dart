import 'dart:async';
import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/plugins/backup_recovery_service.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

enum _BackupAction { create, restore, directory }

class _BackupPageState extends State<BackupPage> {
  final LogController logController = LogController.to;
  String get backupDirectory => SettingsService.to.backup.backupDirectory.v;
  _BackupAction? _backupAction;

  Future<void> _runBackupAction(
    _BackupAction action,
    String failureMessageKey,
    Future<void> Function() operation,
  ) async {
    if (_backupAction != null) return;
    setState(() => _backupAction = action);
    try {
      await operation();
    } catch (error, stackTrace) {
      debugPrint('Backup action $action failed: $error\n$stackTrace');
      if (mounted) ToastUtil.show(i18n(failureMessageKey));
    } finally {
      if (mounted) setState(() => _backupAction = null);
    }
  }

  Widget? _backupActionIndicator(_BackupAction action) {
    if (_backupAction != action) return null;
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: i18n('refresh_loading')),
    );
  }

  Future<void> _openLogDirectory() async {
    try {
      final logDir = await LogFileWriter.resolveLogDirectory();
      if (!await logDir.exists()) {
        ToastUtil.show(i18n('log_dir_not_exist'));
        return;
      }
      if (!await FileUtils.openFileOrUrl(logDir.path)) {
        ToastUtil.show(i18n('open_log_dir_failed'));
      }
    } catch (_) {
      ToastUtil.show(i18n('open_log_dir_failed'));
    }
  }

  Future<void> _openLogBrowser(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) ToastUtil.show(i18n('open_log_browser_failed'));
    } catch (_) {
      if (mounted) ToastUtil.show(i18n('open_log_browser_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("backup_recover"))),
      body: Obx(() {
        final auth = Get.find<AuthController>();
        return ListView(
          physics: const PureLiveScrollPhysics(),
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
                isLong: true,
                stackTrailingOnNarrow: auth.isConnecting,
                showNavigationChevronWhenStacked: false,
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
                isLong: true,
                onTap: () => Get.toNamed(RoutePath.kWebDavPage),
              ),
              if (Platform.isAndroid || Platform.isIOS)
                context.buildTile(
                  icon: Remix.qr_code_line,
                  title: i18n("sync_tv_data"),
                  subtitle: i18n("sync_tv_data_subtitle"),
                  isLong: true,
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
                isLong: true,
                trailing: _backupActionIndicator(_BackupAction.create),
                onTap: _backupAction == null
                    ? () => unawaited(
                        _runBackupAction(_BackupAction.create, 'create_backup_failed', () async {
                          // The export flow chooses a directory and remembers the first
                          // successful choice; no separate first-run settings step.
                          await BackupRecoveryService().createAppSettingsBackup(backupDirectory);
                        }),
                      )
                    : null,
              ),
              context.buildTile(
                icon: Remix.file_upload_line,
                title: i18n("recover_backup"),
                subtitle: i18n("recover_backup_subtitle"),
                isLong: true,
                trailing: _backupActionIndicator(_BackupAction.restore),
                onTap: _backupAction == null
                    ? () => unawaited(
                        _runBackupAction(
                          _BackupAction.restore,
                          'recover_backup_failed',
                          BackupRecoveryService().recoverSettingsFromFile,
                        ),
                      )
                    : null,
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("backup_settings")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.folder_open_line,
                title: i18n("backup_directory"),
                subtitle: backupDirectory.isEmpty ? i18n('please_set_backup_directory') : backupDirectory,
                isLong: true,
                trailing: _backupActionIndicator(_BackupAction.directory),
                onTap: _backupAction == null
                    ? () => unawaited(
                        _runBackupAction(_BackupAction.directory, 'backup_directory_update_failed', () async {
                          await BackupRecoveryService().updateBackupDirectory();
                        }),
                      )
                    : null,
              ),
            ]),
            const SizedBox(height: 20),
            context.buildGroupTitle(i18n("log_manage")),
            context.buildModernCard([
              Obx(() {
                final applying = logController.isApplyingLogStatus.v;
                final statusKey = logController.logStatusKey.v;
                final subtitleKey = applying
                    ? 'local_log_applying'
                    : statusKey.isNotEmpty
                    ? statusKey
                    : 'enable_local_log_desc';
                return context.buildTile(
                  icon: Remix.file_text_line,
                  title: i18n("enable_local_log"),
                  subtitle: i18n(subtitleKey),
                  subtitleColor: statusKey.isNotEmpty && !applying ? Theme.of(context).colorScheme.error : null,
                  isLong: true,
                  stackTrailingOnNarrow: true,
                  showNavigationChevronWhenStacked: false,
                  trailing: Switch(
                    key: const ValueKey('local-log-switch'),
                    value: logController.storedEnableLog.v,
                    onChanged: applying ? null : (value) => unawaited(logController.setLoggingEnabled(value)),
                  ),
                  onTap: applying
                      ? null
                      : () => unawaited(logController.setLoggingEnabled(!logController.storedEnableLog.v)),
                );
              }),
              Obx(() {
                if (!logController.enableLog ||
                    logController.isApplyingLogStatus.v ||
                    logController.serverPort.value == 0) {
                  return const SizedBox.shrink();
                }
                final uri = Uri(
                  scheme: 'http',
                  host: logController.serverAddress.value,
                  port: logController.serverPort.value,
                );
                return context.buildTile(
                  icon: Remix.global_line,
                  title: i18n("view_logs_in_browser"),
                  subtitle: uri.toString(),
                  isLong: true,
                  trailing: const Icon(Remix.arrow_right_s_line),
                  onTap: () => _openLogBrowser(uri),
                );
              }),

              context.buildTile(
                icon: Remix.folder_open_line,
                title: i18n("open_log_dir"),
                subtitle: i18n("open_log_dir_desc"),
                isLong: true,
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
