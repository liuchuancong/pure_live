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
import 'package:pure_live/modules/live_play/live_play_page.dart';
import 'package:pure_live/modules/shield/danmu_shield_page.dart';
import 'package:pure_live/modules/search/web_search_binding.dart';
import 'package:pure_live/modules/settings/settings_binding.dart';
import 'package:pure_live/modules/areas/favorite_areas_page.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_page.dart';
import 'package:pure_live/modules/tags/tag_management_binding.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_binding.dart';
import 'package:pure_live/modules/live_play/live_play_binding.dart';
import 'package:pure_live/modules/shield/danmu_shield_binding.dart';
import 'package:pure_live/modules/areas/favorite_areas_binding.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_page.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:pure_live/modules/account/bilibili/qr_login_page.dart';
import 'package:pure_live/modules/auth/components/update_password.dart';
import 'package:pure_live/modules/account/bilibili/bilibili_bings.dart';
import 'package:pure_live/modules/account/bilibili/web_login_page.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_binding.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_binding.dart';
import 'package:pure_live/modules/account/douyin/douyin_cookie_page.dart';
import 'package:pure_live/modules/account/douyin/douyin_cookie_binding.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_page.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_binding.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_page.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_binding.dart';

// auth

class AppPages {
  AppPages._();

  static final routes = [
    GetPage(name: RoutePath.kInitial, page: HomePage.new, participatesInRootNavigator: true, preventDuplicates: true),
    GetPage(name: RoutePath.kSignIn, page: SignInPage.new),
    GetPage(name: RoutePath.kUpdatePassword, page: UpdatePassword.new),
    GetPage(name: RoutePath.kMine, page: MinePage.new),
    GetPage(name: RoutePath.kUserManage, page: () => const UserManager()),
    GetPage(name: RoutePath.kFavorite, page: FavoritePage.new),
    GetPage(name: RoutePath.kPopular, page: PopularPage.new),
    GetPage(name: RoutePath.kAreas, page: AreasPage.new),
    GetPage(name: RoutePath.kSettings, page: SettingsPage.new, bindings: [SettingsBinding()]),
    GetPage(name: RoutePath.kHistory, page: HistoryPage.new),
    GetPage(name: RoutePath.kSearch, page: SearchPage.new, bindings: [SearchBinding()]),
    GetPage(name: RoutePath.kBackup, page: BackupPage.new),
    GetPage(name: RoutePath.kIptv, page: IptvPage.new),
    GetPage(name: RoutePath.kAbout, page: AboutPage.new),
    GetPage(name: RoutePath.kAreaRooms, page: AreasRoomPage.new, bindings: [AreaRoomsBinding()]),
    GetPage(
      name: RoutePath.kLivePlay,
      page: () => LivePlayPage(),
      preventDuplicates: false,
      bindings: [LivePlayBinding()],
    ),
    //账号设置
    GetPage(name: RoutePath.kSettingsAccount, page: () => const AccountPage(), bindings: [AccountBinding()]),
    //哔哩哔哩Web登录
    GetPage(
      name: RoutePath.kBiliBiliWebLogin,
      page: () => const BiliBiliWebLoginPage(),
      bindings: [BilibiliWebLoginBinding()],
    ),
    //哔哩哔哩二维码登录
    GetPage(
      name: RoutePath.kBiliBiliQRLogin,
      page: () => const BiliBiliQRLoginPage(),
      bindings: [BilibiliQrLoginBinding()],
    ),
    GetPage(
      name: RoutePath.kSettingsDanmuShield,
      page: () => const DanmuShieldPage(),
      bindings: [DanmuShieldBinding()],
    ),
    GetPage(name: RoutePath.kSettingsHotAreas, page: () => const HotAreasPage(), bindings: [HotAreasBinding()]),

    GetPage(name: RoutePath.kVersionHistory, page: () => const VersionHistoryPage()),

    GetPage(name: RoutePath.kToolbox, page: () => const ToolBoxPage(), bindings: [ToolBoxBinding()]),

    GetPage(name: RoutePath.kFavoriteAreas, page: () => const FavoriteAreasPage(), bindings: [FavoriteAreasBinding()]),

    GetPage(name: RoutePath.kHuyaCookie, page: () => const HuyaCookiePage(), bindings: [HuyaCookieBinding()]),

    GetPage(name: RoutePath.kDouyuCookie, page: () => const DouyinCookiePage(), bindings: [DouyinCookieBinding()]),

    GetPage(
      name: RoutePath.kKuaishouCookie,
      page: () => const KuaishouCookiePage(),
      bindings: [KuaishouCookieBinding()],
    ),

    GetPage(name: RoutePath.kWebDavPage, page: () => WebDavPage(), bindings: [WebDavBinding()]),

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
          onNextPressed: () {
            Get.offAllNamed(RoutePath.kInitial);
          },
          duration: const Duration(seconds: 1),
        );
      },
    ),
    // VersionPage
    GetPage(name: RoutePath.kVersionPage, page: () => const VersionPage(), bindings: [VersionBinding()]),
    GetPage(name: RoutePath.kRecordPage, page: () => const RecorderPage(), bindings: [RecorderBinding()]),
    GetPage(
      name: RoutePath.kRecordSettings,
      page: () => const RecordSettingsPage(),
      bindings: [RecordSettingsBinding()],
    ),
    GetPage(name: RoutePath.kWebSearch, page: () => const WebSearchPage(), bindings: [WebSearchBinding()]),

    GetPage(name: RoutePath.kSettingsTags, page: () => const TagManagementPage(), bindings: [TagManagementBinding()]),
  ];
}
