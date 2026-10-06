import 'package:pure_live/app/router/page_bindings.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/home/home_page.dart';
import 'package:pure_live/domains/account/presentation/auth/mine_page.dart';
import 'package:pure_live/domains/iptv/presentation/iptv_page.dart';
import 'package:pure_live/features/about/about_page.dart';
import 'package:pure_live/domains/live/presentation/areas/areas_page.dart';
import 'package:pure_live/domains/account/presentation/auth/sign_in_page.dart';
import 'package:pure_live/domains/live/presentation/search/search_page.dart';
import 'package:pure_live/features/backup/backup_page.dart';
import 'package:pure_live/features/splash/splash_screen.dart';
import 'package:pure_live/features/version/version_page.dart';
import 'package:pure_live/features/web_dav/web_dav_page.dart';
import 'package:pure_live/features/toolbox/toolbox_page.dart';
import 'package:pure_live/domains/account/presentation/account/account_page.dart';
import 'package:pure_live/domains/live/presentation/popular/popular_page.dart';
import 'package:pure_live/domains/live/presentation/history/history_page.dart';
import 'package:pure_live/domains/account/presentation/auth/user_manage_page.dart';
import 'package:pure_live/features/about/version_history.dart';
import 'package:pure_live/domains/live/presentation/search/web_search_page.dart';
import 'package:pure_live/domains/live/presentation/favorite/favorite_page.dart';
import 'package:pure_live/features/settings/settings_page.dart';
import 'package:pure_live/domains/live/presentation/tags/tag_management_page.dart';
import 'package:pure_live/domains/live/presentation/hot_areas/hot_areas_page.dart';
import 'package:pure_live/domains/live/presentation/shield/danmu_shield_page.dart';
import 'package:pure_live/domains/live/presentation/multiview/multiview_page.dart';
import 'package:pure_live/domains/account/presentation/account/yy/yy_cookie_page.dart';
import 'package:pure_live/domains/account/presentation/account/bigo/bigo_cookie_page.dart';
import 'package:pure_live/domains/live/presentation/areas/favorite_areas_page.dart';
import 'package:pure_live/domains/live/presentation/area_rooms/area_rooms_page.dart';
import 'package:pure_live/domains/account/presentation/account/soop/soop_cookie_page.dart';
import 'package:pure_live/domains/account/presentation/account/huya/huya_cookie_page.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_page.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/qr_login_page.dart';
import 'package:pure_live/domains/live/presentation/playback/pages/live_play_page.dart';
import 'package:pure_live/domains/account/presentation/account/douyu/douyu_cookie_page.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/bilibili_bindings.dart';
import 'package:pure_live/domains/account/presentation/account/bilibili/web_login_page.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_page.dart';
import 'package:pure_live/domains/account/presentation/account/twitch/twitch_cookie_page.dart';
import 'package:pure_live/domains/account/presentation/account/douyin/douyin_cookie_page.dart';
import 'package:pure_live/domains/account/presentation/account/kuaishou/kuaishou_cookie_page.dart';
import 'package:pure_live/domains/recorder/presentation/pages/record_settings/record_settings_page.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_page.dart';
import 'package:pure_live/domains/live/presentation/favorite/favorite_controller.dart';

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
    GetPage(
      name: RoutePath.kSettingsAccount,
      page: _smoothPage(() => const AccountPage()),
      bindings: [AccountBinding()],
    ),
    GetPage(
      name: RoutePath.kBiliBiliWebLogin,
      page: _smoothPage(() => const BiliBiliWebLoginPage()),
      bindings: [BilibiliWebLoginBinding()],
    ),
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
      name: RoutePath.kDouyuAccountCookie,
      page: _smoothPage(() => const DouyuCookiePage()),
      bindings: [DouyuCookieBinding()],
    ),

    GetPage(
      name: RoutePath.kDouyinCookie,
      page: _smoothPage(() => const DouyinCookiePage()),
      bindings: [DouyinCookieBinding()],
    ),

    // Preserve the historical misnamed deep link while all in-app navigation
    // uses the canonical Douyin path above.
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
    GetPage(
      name: RoutePath.kBigoCookie,
      page: _smoothPage(() => const BigoCookiePage()),
      bindings: [BigoCookieBinding()],
    ),

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
        final bool isDarkMode = Get.isDarkMode;

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
    GetPage(
      name: RoutePath.kLocalVideoPlayer,
      page: _smoothPage(() => const LocalVideoPlayerPage()),
      bindings: [LocalVideoPlayerBinding()],
    ),
    GetPage(name: RoutePath.kWebSearch, page: _smoothPage(() => const WebSearchPage()), bindings: [WebSearchBinding()]),

    GetPage(
      name: RoutePath.kSettingsTags,
      page: _smoothPage(() => const TagManagementPage()),
      bindings: [TagManagementBinding()],
    ),
    GetPage(
      name: RoutePath.kRemoteSync,
      page: _smoothPage(() => const RemoteSyncPage()),
      bindings: [RemoteSyncBinding()],
    ),
  ];
}
