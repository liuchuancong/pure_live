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

  /// The search page, a full page above the shell.
  static const String search = '/search';

  /// The settings cluster's index page, a full page above the shell.
  static const String settings = '/settings';
}
