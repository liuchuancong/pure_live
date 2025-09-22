import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.supabase_mine),
      ),
      body: ListView(scrollDirection: Axis.vertical, physics: const BouncingScrollPhysics(), children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              if (isManager())
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, size: 32),
                  subtitle: const Text("允许用户是否可以上传"),
                  title: const Text("用户管理"),
                  onTap: () => Get.toNamed(RoutePath.kUserManage),
                ),
              ListTile(
                leading: const Icon(Icons.sim_card_download_outlined, size: 32),
                subtitle: Text(S.current.supabase_mine_streams),
                title: const Text('下载用户配置'),
                onTap: downloadUserConifg,
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined, size: 32),
                subtitle: Text(S.current.supabase_mine_streams),
                title: Text(S.current.supabase_mine_profiles),
                onTap: uploadUserConifg,
              ),
              ListTile(
                leading: const Icon(Icons.login_outlined, size: 32),
                title: Text(S.current.supabase_log_out),
                onTap: singOut,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
