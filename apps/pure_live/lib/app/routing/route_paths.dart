/// Every route path the app answers, in one table.
///
/// The `@TypedGoRoute` annotations read their `path` from here, so this
/// class is the single place a path is spelled — a rename or a prefix
/// change is one edit and the generated route tables follow. Navigation
/// itself never needs these strings: the typed route classes
/// (`FollowRoute`, `SearchRoute`, ...) carry their own `go`/`push`/`location`
/// and are the way pages and the chrome move around. The table is also
/// what deep links and route tests quote.
abstract final class RoutePath {
  /// The start-up splash, the launch route ahead of the shell.
  static const String splash = '/splash';

  /// The favorites branch's root, and the shell's first screen — the
  /// reference's favorites tab (3.x `HomeMenu.favorites`).
  static const String favorites = '/';

  /// The history page, pushed from the shell's menu.
  static const String history = '/history';

  /// The popular feed.
  static const String popular = '/popular';

  /// The category catalogue.
  static const String areas = '/areas';

  /// The recording centre, the reference's fourth tab (3.x `record_center`).
  static const String recorder = '/recorder';

  /// One area's room list — [areas] with the site and area ids as path
  /// segments.
  static const String areaRooms = '/areas/:siteId/:areaId';

  /// A live room, above the shell. The path carries the site and room ids;
  /// a title hint rides as the query.
  static const String room = '/room/:siteId/:roomId';

  /// The about page.
  static const String about = '/about';

  /// The version page, one level under the about cluster.
  static const String version = '/about/version';

  /// The release history page, under the version page (the reference's
  /// `kVersionHistory`).
  static const String versionHistory = '/about/version/history';

  /// The toolbox: link resolution.
  static const String toolbox = '/toolbox';

  /// The LAN sync page (the toolbox's remote receiver).
  static const String remoteSync = '/remote-sync';

  /// The IPTV library page.
  static const String iptv = '/iptv';

  /// One IPTV channel playing; the name rides as the query.
  static const String iptvPlay = '/iptv/play/:channelId';

  /// The multi-view page.
  static const String multiview = '/multiview';

  /// The search page, a full page above the shell.
  static const String search = '/search';

  /// The settings cluster's index page, a full page above the shell.
  static const String settings = '/settings';

  /// The appearance page, one level under the settings index.
  static const String settingsAppearance = '/settings/appearance';

  /// The font manager, one level under the settings index.
  static const String settingsFonts = '/settings/fonts';

  /// The wallpaper picker, one level under the settings index.
  static const String settingsWallpaper = '/settings/wallpaper';

  /// The cache & data page, one level under the settings index.
  static const String settingsData = '/settings/data';

  /// The danmaku shield, under the settings cluster.
  static const String settingsShield = '/settings/shield';

  /// The backup and restore page, under the settings cluster.
  static const String settingsBackup = '/settings/backup';

  /// The general settings page, one level under the settings index.
  static const String settingsGeneral = '/settings/general';

  /// The refresh settings page, one level under the settings index.
  static const String settingsRefresh = '/settings/refresh';

  /// The page settings page (shell branches), one level under the settings
  /// index.
  static const String settingsPages = '/settings/pages';

  /// The navigation settings page, one level under the settings index.
  static const String settingsNavigation = '/settings/navigation';

  /// The network proxy settings page, one level under the settings index.
  static const String settingsProxy = '/settings/proxy';

  /// The loading style settings page, one level under the settings index.
  static const String settingsLoadingStyle = '/settings/loading-style';

  /// The room card settings page, one level under the settings index.
  static const String settingsRoomCard = '/settings/room-card';

  /// The video and danmaku settings, one level under the settings index.
  static const String settingsVideo = '/settings/video';

  /// The mpv tuning, one level under the settings index.
  static const String settingsMpv = '/settings/mpv';

  /// The read-only local configuration dump, under the settings index.
  static const String settingsLocalConfig = '/settings/local-config';

  /// The recorder page, one level under the settings index.
  static const String settingsRecorder = '/settings/recorder';

  /// The account page, one level under the settings index.
  static const String settingsAccount = '/settings/account';

  /// The platforms page (visibility, order, accounts, tags), under the
  /// settings index.
  static const String settingsPlatforms = '/settings/platforms';

  /// The danmaku settings page, under the settings index.
  static const String settingsDanmaku = '/settings/danmaku';

  /// The recording settings page, under the settings index.
  static const String settingsRecording = '/settings/recording';

  /// The local interaction settings page, under the settings index.
  static const String settingsLocalInteraction = '/settings/local-interaction';

  /// The log page, under the settings index.
  static const String settingsLogs = '/settings/logs';

  /// The platform visibility/order page, pushed from the platforms page.
  static const String settingsHotAreas = '/settings/hot-areas';

  /// The tag manager page, pushed from the platforms page.
  static const String settingsTags = '/settings/tags';

  /// The bilibili QR login page, pushed from the account page.
  static const String login = '/login';
}
