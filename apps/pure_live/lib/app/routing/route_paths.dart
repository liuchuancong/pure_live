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

  /// The home branch's root.
  static const String home = '/';

  /// The follow branch's root.
  static const String follow = '/follow';

  /// The history branch's root.
  static const String history = '/history';

  /// The popular feed, a full page above the shell.
  static const String popular = '/popular';

  /// The category catalogue, a full page above the shell.
  static const String areas = '/areas';

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

  /// The recorder page, one level under the settings index.
  static const String settingsRecorder = '/settings/recorder';

  /// The account page, one level under the settings index.
  static const String settingsAccount = '/settings/account';

  /// The bilibili QR login page, pushed from the account page.
  static const String login = '/login';
}
