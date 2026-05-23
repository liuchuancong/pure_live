import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  void uploadUserConifg() {
    SupaBaseManager().uploadConfig();
  }

  void downloadUserConifg() {
    SupaBaseManager().readConfig();
  }

  void singOut() {
    SupaBaseManager().signOut();
  }

  bool isManager() {
    final AuthController authController = Get.find<AuthController>();
    if (!authController.isLogin) return false;
    return SupaBaseManager.supabasePolicy.owner == authController.user.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('supabase_mine'), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, i18n('supabase_mine')),
          _buildModernCard(theme, [
            if (isManager())
              _buildTile(
                context,
                icon: Remix.shield_user_line,
                title: i18n('manage_users'),
                subtitle: i18n('allow_user_uploads'),
                onTap: () => Get.toNamed(RoutePath.kUserManage),
              ),
            _buildTile(
              context,
              icon: Remix.download_cloud_line, // 🎯 修正：从云端下载配置
              title: i18n('download_user_configs'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: downloadUserConifg,
            ),
            _buildTile(
              context,
              icon: Remix.upload_cloud_line, // 🎯 修正：上传配置到云端
              title: i18n('supabase_mine_profiles'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: uploadUserConifg,
            ),
            _buildTile(
              context,
              icon: Remix.logout_box_r_line,
              title: i18n('supabase_log_out'),
              subtitle: "",
              iconColor: theme.colorScheme.error.withValues(alpha: 0.8),
              onTap: singOut,
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
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty
          ? null
          : Padding(
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
