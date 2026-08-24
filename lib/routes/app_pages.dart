import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/home/home_page.dart';
import 'package:pure_live/modules/auth/mine_page.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/modules/about/about_page.dart';
import 'package:pure_live/modules/areas/areas_page.dart';
import 'package:pure_live/modules/auth/sign_in_page.dart';
import 'package:pure_live/modules/search/search_page.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/splash/splash_screen.dart';
import 'package:pure_live/modules/version/version_page.dart';
import 'package:pure_live/modules/web_dav/web_dav_page.dart';
import 'package:pure_live/modules/toolbox/toolbox_page.dart';
import 'package:pure_live/modules/account/account_bing.dart';
import 'package:pure_live/modules/account/account_page.dart';
import 'package:pure_live/modules/popular/popular_page.dart';
import 'package:pure_live/modules/history/history_page.dart';
import 'package:pure_live/modules/auth/user_manage_page.dart';
import 'package:pure_live/modules/about/version_history.dart';
import 'package:pure_live/modules/search/search_binding.dart';
import 'package:pure_live/modules/search/web_search_page.dart';
import 'package:pure_live/modules/favorite/favorite_page.dart';
import 'package:pure_live/modules/settings/settings_page.dart';
import 'package:pure_live/modules/version/version_binding.dart';
import 'package:pure_live/modules/web_dav/web_dav_binding.dart';
import 'package:pure_live/modules/toolbox/boolbox_binding.dart';
import 'package:pure_live/modules/tags/tag_management_page.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_page.dart';
import 'package:pure_live/modules/shield/danmu_shield_page.dart';
import 'package:pure_live/modules/multiview/multiview_page.dart';
import 'package:pure_live/modules/account/yy/yy_cookie_page.dart';
import 'package:pure_live/modules/search/web_search_binding.dart';
import 'package:pure_live/modules/settings/settings_binding.dart';
import 'package:pure_live/modules/areas/favorite_areas_page.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_page.dart';
import 'package:pure_live/modules/tags/tag_management_binding.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_binding.dart';
import 'package:pure_live/modules/shield/danmu_shield_binding.dart';
import 'package:pure_live/modules/account/yy/yy_cookie_binding.dart';
import 'package:pure_live/modules/areas/favorite_areas_binding.dart';
import 'package:pure_live/modules/account/soop/soop_cookie_page.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_page.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:pure_live/modules/account/bilibili/qr_login_page.dart';
import 'package:pure_live/modules/live_play/pages/live_play_page.dart';
import 'package:pure_live/modules/account/bilibili/bilibili_bings.dart';
import 'package:pure_live/modules/account/bilibili/web_login_page.dart';
import 'package:pure_live/modules/account/soop/soop_cookie_binding.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_binding.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_binding.dart';
import 'package:pure_live/modules/account/twitch/twitch_cookie_page.dart';
import 'package:pure_live/modules/account/douyin/douyin_cookie_page.dart';
import 'package:pure_live/modules/account/twitch/twitch_cookie_binding.dart';
import 'package:pure_live/modules/live_play/bindings/live_play_binding.dart';
import 'package:pure_live/modules/multiview/bindings/multiview_binding.dart';
import 'package:pure_live/modules/account/douyin/douyin_cookie_binding.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_page.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_binding.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_page.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_binding.dart';

// auth

class AppPages {
  AppPages._();

  static Widget Function() _smoothPage(Widget Function() builder) {
    return () => PureLiveRouteScrollScope(child: builder());
  }

  static final routes = [
    GetPage(name: RoutePath.kInitial, page: HomePage.new, participatesInRootNavigator: true, preventDuplicates: true),
    GetPage(name: RoutePath.kSignIn, page: _smoothPage(SignInPage.new)),
    GetPage(name: RoutePath.kMine, page: _smoothPage(MinePage.new)),
    GetPage(name: RoutePath.kUserManage, page: _smoothPage(UserManager.new)),
    GetPage(name: RoutePath.kFavorite, page: _smoothPage(FavoritePage.new)),
    GetPage(name: RoutePath.kPopular, page: _smoothPage(PopularPage.new)),
    GetPage(name: RoutePath.kAreas, page: _smoothPage(AreasPage.new)),
    GetPage(name: RoutePath.kSettings, page: _smoothPage(SettingsPage.new), bindings: [SettingsBinding()]),
    GetPage(name: RoutePath.kHistory, page: _smoothPage(HistoryPage.new)),
    GetPage(name: RoutePath.kSearch, page: _smoothPage(SearchPage.new), bindings: [SearchBinding()]),
    GetPage(name: RoutePath.kBackup, page: _smoothPage(BackupPage.new)),
    GetPage(name: RoutePath.kIptv, page: _smoothPage(IptvPage.new)),
    GetPage(name: RoutePath.kAbout, page: _smoothPage(AboutPage.new)),
    GetPage(
      name: RoutePath.kAreaRooms,
      page: _smoothPage(() => AreasRoomPage(site: Get.arguments[0], subCategory: Get.arguments[1])),
      bindings: [AreaRoomsBinding()],
    ),
    GetPage(
      name: RoutePath.kLivePlay,
      page: () => LivePlayPage(),
      preventDuplicates: false,
      bindings: [LivePlayBinding()],
    ),
    GetPage(
      name: RoutePath.kMultiview,
      page: () => const MultiviewPage(),
      preventDuplicates: false,
      bindings: [MultiviewBinding()],
    ),
    //账号设置
    GetPage(
      name: RoutePath.kSettingsAccount,
      page: _smoothPage(() => const AccountPage()),
      bindings: [AccountBinding()],
    ),
    //哔哩哔哩Web登录
    GetPage(
      name: RoutePath.kBiliBiliWebLogin,
      page: _smoothPage(() => const BiliBiliWebLoginPage()),
      bindings: [BilibiliWebLoginBinding()],
    ),
    //哔哩哔哩二维码登录
    GetPage(
      name: RoutePath.kBiliBiliQRLogin,
      page: _smoothPage(() => const BiliBiliQRLoginPage()),
      bindings: [BilibiliQrLoginBinding()],
    ),
    GetPage(
      name: RoutePath.kSettingsDanmuShield,
      page: _smoothPage(() => const DanmuShieldPage()),
      bindings: [DanmuShieldBinding()],
    ),
    GetPage(
      name: RoutePath.kSettingsHotAreas,
      page: _smoothPage(() => const HotAreasPage()),
      bindings: [HotAreasBinding()],
    ),

    GetPage(name: RoutePath.kVersionHistory, page: _smoothPage(() => const VersionHistoryPage())),

    GetPage(name: RoutePath.kToolbox, page: _smoothPage(() => const ToolBoxPage()), bindings: [ToolBoxBinding()]),

    GetPage(
      name: RoutePath.kFavoriteAreas,
      page: _smoothPage(() => const FavoriteAreasPage()),
      bindings: [FavoriteAreasBinding()],
    ),

    GetPage(
      name: RoutePath.kHuyaCookie,
      page: _smoothPage(() => const HuyaCookiePage()),
      bindings: [HuyaCookieBinding()],
    ),

    GetPage(
      name: RoutePath.kDouyuCookie,
      page: _smoothPage(() => const DouyinCookiePage()),
      bindings: [DouyinCookieBinding()],
    ),

    GetPage(
      name: RoutePath.kTwitchCookie,
      page: _smoothPage(() => const TwitchCookiePage()),
      bindings: [TwitchCookieBinding()],
    ),
    GetPage(name: RoutePath.kYyCookie, page: _smoothPage(() => const YyCookiePage()), bindings: [YyCookieBinding()]),

    GetPage(name: RoutePath.kSoop, page: _smoothPage(() => const SoopCookiePage()), bindings: [SoopCookieBinding()]),

    GetPage(
      name: RoutePath.kKuaishouCookie,
      page: _smoothPage(() => const KuaishouCookiePage()),
      bindings: [KuaishouCookieBinding()],
    ),

    GetPage(name: RoutePath.kWebDavPage, page: _smoothPage(WebDavPage.new), bindings: [WebDavBinding()]),

    GetPage(
      name: RoutePath.kSplash,
      page: () {
        // 判断是否为夜间模式
        final bool isDarkMode = Get.isDarkMode;

        // 根据模式选择渐变色
        final LinearGradient bgGradient = isDarkMode
            ? const LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF141E27)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

        // 夜间模式下的文字颜色
        final Color textColor = isDarkMode ? Colors.white70 : Colors.black54;

        return SplashScreen(
          bgGradient: bgGradient,
          logo: Image.asset('assets/icons/icon.png', width: 150),
          showTextLogo: true,
          logoText: i18n("welcome_use"),
          textStyle: AppTextStyles.t20.copyWith(fontWeight: FontWeight.bold, color: textColor),
          loaderType: LoaderType.progressBar,
          onNextPressed: () async {
            // Spend a small, bounded part of the existing launch transition on
            // the already-running favourite verification. Fast networks enter
            // Home with a settled grid; slow platforms never hold the splash
            // beyond this budget and finish in the background.
            if (Get.isRegistered<FavoriteController>()) {
              try {
                await Future.any<void>([
                  Get.find<FavoriteController>().refreshPersistedRoomsOnStartup(),
                  Future<void>.delayed(const Duration(milliseconds: 350)),
                ]);
              } catch (_) {}
            }
            Get.offAllNamed(RoutePath.kInitial);
          },
          duration: const Duration(seconds: 1),
        );
      },
    ),
    // VersionPage
    GetPage(name: RoutePath.kVersionPage, page: _smoothPage(() => const VersionPage()), bindings: [VersionBinding()]),
    GetPage(name: RoutePath.kRecordPage, page: _smoothPage(() => const RecorderPage()), bindings: [RecorderBinding()]),
    GetPage(
      name: RoutePath.kRecordSettings,
      page: _smoothPage(() => const RecordSettingsPage()),
      bindings: [RecordSettingsBinding()],
    ),
    GetPage(name: RoutePath.kWebSearch, page: _smoothPage(() => const WebSearchPage()), bindings: [WebSearchBinding()]),

    GetPage(
      name: RoutePath.kSettingsTags,
      page: _smoothPage(() => const TagManagementPage()),
      bindings: [TagManagementBinding()],
    ),
  ];
}
