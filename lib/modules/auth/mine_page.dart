import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  void uploadUserConfig() {
    FirebaseManager.getInstance().uploadConfig();
  }

  void downloadUserConfig() {
    FirebaseManager.getInstance().downloadConfig();
  }

  void signOut() {
    FirebaseManager.getInstance().signOut();
  }

  bool isManager() {
    final AuthController authController = Get.find<AuthController>();

    if (!authController.isLogin || authController.user == null) {
      return false;
    }

    return FirebaseManager.policy.owner == authController.user!.uid;
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
              icon: Remix.download_cloud_line,
              title: i18n('download_user_configs'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: downloadUserConfig,
            ),
            context.buildTile(
              icon: Remix.upload_cloud_line,
              title: i18n('supabase_mine_profiles'),
              subtitle: i18n('supabase_mine_streams'),
              onTap: uploadUserConfig,
            ),
            context.buildTile(
              icon: Remix.logout_box_r_line,
              title: i18n('supabase_log_out'),
              subtitle: "",
              iconColor: theme.colorScheme.error.withValues(alpha: 0.8),
              onTap: signOut,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
