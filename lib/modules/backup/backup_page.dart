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
    final theme = Theme.of(context);
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("backup_recover"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, "Supabase"),
          _buildModernCard(theme, [
            _buildTile(
              context,
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
          _buildGroupTitle(theme, i18n("webdav")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.cloud_line,
              title: i18n("webdav"),
              subtitle: i18n("backup_to_webdav"),
              onTap: () => Get.toNamed(RoutePath.kWebDavPage),
            ),
            if (Platform.isAndroid || Platform.isIOS)
              _buildTile(
                context,
                icon: Remix.qr_code_line,
                title: i18n("sync_tv_data"),
                subtitle: i18n("sync_tv_data_subtitle"),
                onTap: () => Get.to(() => const ScanCodePage()),
              ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组二：本地数据快照
          _buildGroupTitle(theme, i18n("create_backup")),
          _buildModernCard(theme, [
            _buildTile(
              context,
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
            _buildTile(
              context,
              icon: Remix.file_upload_line,
              title: i18n("recover_backup"),
              subtitle: i18n("recover_backup_subtitle"),
              onTap: () => BackupRecoveryService().recoverSettingsFromFile(),
            ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组三：自动化存储
          _buildGroupTitle(theme, i18n("auto_backup")),
          _buildModernCard(theme, [
            _buildTile(
              context,
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

  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
