/// The route paths, in one place: the shell's branches and the pushed
/// screens name themselves here, and nothing builds a path inline.
abstract final class RouteNames {
  /// The home branch.
  static const String home = '/';

  /// The zones branch.
  static const String zones = '/zones';

  /// The live branch.
  static const String live = '/live';

  /// The favorites branch.
  static const String favorites = '/favorites';

  /// The history branch.
  static const String history = '/history';

  /// The search branch.
  static const String search = '/search';

  /// The multi-view branch.
  static const String multiview = '/multiview';

  /// The recording branch.
  static const String recorder = '/recorder';

  /// The toolbox branch.
  static const String toolbox = '/toolbox';

  /// The playlist branch.
  static const String playlist = '/playlist';

  /// The live room detail, pushed on the root navigator.
  static const String room = '/room/:platform/:roomId';

  /// One area's rooms, pushed on the root navigator (the reference's
  /// `kAreaRooms`); the area object rides in as `extra`.
  static const String areaRooms = '/zones/:platform/:areaId';

  /// The settings branch.
  static const String settings = '/settings';

  /// One settings section, pushed as its own route on the phone: the
  /// mobile settings menu navigates into submenus, the desktop pane does
  /// not leave the page.
  static const String settingsSection = '/settings/:section';

  /// A pushed player screen, above the shell.
  static const String player = '/player';
}
