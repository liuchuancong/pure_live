import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';
import 'package:pure_live/modules/auth/components/user_detail_main_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n('firebase_mine')),
        actions: [
          TextButton(
            onPressed: () {
              final uid = FirebaseManager.getInstance().auth.currentUser?.uid;
              Get.to(() => UserDetailConfigMainPage(documentId: uid!));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Remix.file_text_line, size: 18), const SizedBox(width: 4), Text(i18n("config_preview"))],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('firebase_mine')),
          context.buildModernCard([
            if (FirebaseManager.getInstance().hasManagementPower())
              context.buildTile(
                icon: Remix.shield_user_line,
                title: i18n('manage_users'),
                subtitle: i18n('allow_user_uploads'),
                onTap: () => Get.toNamed(RoutePath.kUserManage),
              ),
            context.buildTile(
              icon: Remix.download_cloud_line,
              title: i18n('download_user_configs'),
              subtitle: i18n('firebase_mine_streams'),
              onTap: downloadUserConfig,
            ),
            context.buildTile(
              icon: Remix.upload_cloud_line,
              title: i18n('firebase_mine_profiles'),
              subtitle: i18n('firebase_mine_streams'),
              onTap: uploadUserConfig,
            ),
            context.buildTile(
              icon: Remix.logout_box_r_line,
              title: i18n('firebase_log_out'),
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
