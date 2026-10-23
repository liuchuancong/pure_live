/// The route paths, in one place: the shell's branches and the pushed
/// screens name themselves here, and nothing builds a path inline.
abstract final class RouteNames {
  /// The home branch.
  static const String home = '/';

  /// The live branch.
  static const String live = '/live';

  /// The favorites branch.
  static const String favorites = '/favorites';

  /// The history branch.
  static const String history = '/history';

  /// The search branch.
  static const String search = '/search';

  /// The playlist branch.
  static const String playlist = '/playlist';

  /// The settings branch.
  static const String settings = '/settings';

  /// A pushed player screen, above the shell.
  static const String player = '/player';
}
