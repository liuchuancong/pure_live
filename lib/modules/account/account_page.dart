import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';

class AccountPage extends GetView<AccountController> {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('third_party_auth'))),
      body: ListView(
        children: [
          Obx(
            () => ListTile(
              leading: Image.asset('assets/images/bilibili_2.png', width: 36, height: 36),
              title: Text(i18n("site_bilibili")),
              subtitle: Text(BiliBiliAccountService.instance.name.value),
              trailing: BiliBiliAccountService.instance.logined.value
                  ? const Icon(Icons.logout)
                  : const Icon(Icons.chevron_right),
              onTap: controller.bilibiliTap,
            ),
          ),

          ListTile(
            leading: Image.asset('assets/images/huya.png', width: 36, height: 36),
            title: Text(i18n("site_huya")),
            subtitle: Text(i18n("set_cookie")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.toNamed(RoutePath.kHuyaCookie);
            },
          ),

          ListTile(
            leading: Image.asset('assets/images/douyin.png', width: 36, height: 36),
            title: Text(i18n("site_douyin")),
            subtitle: Text(i18n("set_cookie")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.toNamed(RoutePath.kDouyuCookie);
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/kuaishou.png', width: 36, height: 36),
            title: Text(i18n("site_kuaishou")),
            subtitle: Text(i18n("set_cookie")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.toNamed(RoutePath.kKuaishouCookie);
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/douyu.png', width: 36, height: 36),
            title: Text(i18n("site_douyu")),
            subtitle: Text(i18n("set_cookie")),
            enabled: false,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.toNamed(RoutePath.kDouyuCookie);
            },
          ),
        ],
      ),
    );
  }
}
