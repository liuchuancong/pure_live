import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/utils.dart';

class SiteAccountController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initAllSiteCookie();
  }

  SettingsService settings = Get.find<SettingsService>();

  /// 初始化所有站点的cookie
  void initAllSiteCookie() {
    var siteCookies = settings.siteCookies;
    for (var key in siteCookies.keys) {
      var cookie = siteCookies[key] ?? "";
      var site = Sites.of(key);
      site.liveSite.loadUserInfo(site, cookie);
    }
  }

  /// 跳转至直播平台登录
  Future toSiteLogin(Site site) async {
    Utils.showRightOrBottomSheet(
      title: "${S.current.supabase_sign_in} ${Sites.getSiteName(site.id)}",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: site.liveSite.isSupportWebLogin(),
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text("Web ${S.current.supabase_sign_in}"),
              subtitle: Text(S.current.login_by_username_password),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(Get.context!).pop();
                Get.toNamed(RoutePath.kSiteWebLogin, parameters: {"site": site.id});
              },
            ),
          ),
          Visibility(
              visible: site.liveSite.isSupportQrLogin(),
              child: ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(S.current.login_by_qr),
                subtitle: Text(S.current.login_by_qr_info(Sites.getSiteName(site.id))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(Get.context!).pop();
                  Get.toNamed(RoutePath.kSiteQRLogin, parameters: {"site": site.id});
                },
              )),
          Visibility(
              visible: site.liveSite.isSupportCookieLogin(),
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text("Cookie ${S.current.supabase_sign_in}"),
                subtitle: Text(S.current.login_by_cookie_info),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(Get.context!).pop();
                  doCookieLogin(site);
                },
              )),
        ],
      ),
    );
  }

  /// cookie登录
  void doCookieLogin(Site site) async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: S.current.input_cookie,
      hintText: S.current.input_cookie,
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    bool flag = await site.liveSite.loadUserInfo(site, cookie);
    if (!flag) {
      Utils.showAlertDialog(S.current.cookie_check_failed);
    }
  }

  /// 点击
  void onTap(Site site) async {
    if (site.liveSite.isLogin.value) {
      var result = await Utils.showAlertDialog(S.current.login_account_exit(Sites.getSiteName(site.id)), title: S.current.supabase_log_out);
      if (result) {
        site.liveSite.logout(site);
      }
    } else {
      toSiteLogin(site);
    }
  }
}
