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
      appBar: AppBar(title: Text(i18n('supabase_mine'))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('supabase_mine')),
          context.buildModernCard([
            if (isManager())
              context.buildTile(
                icon: Remix.shield_user_line,
                title: i18n('manage_users'),
                subtitle: i18n('allow_user_uploads'),
                onTap: () => Get.toNamed(RoutePath.kUserManage),
              ),
            context.buildTile(
              icon: Remix.download_cloud_line, // 🎯 修正：从云端下载配置
              title: i18n('download_user_configs'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: downloadUserConifg,
            ),
            context.buildTile(
              icon: Remix.upload_cloud_line, // 🎯 修正：上传配置到云端
              title: i18n('supabase_mine_profiles'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: uploadUserConifg,
            ),
            context.buildTile(
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
}
