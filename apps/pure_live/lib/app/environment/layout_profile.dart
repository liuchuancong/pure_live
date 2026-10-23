/// How much room the window currently gives the shell.
///
/// The device profile is fixed for the process; the layout profile moves
/// every time the viewer drags an edge, so it is computed from the window's
/// width where the shell builds, never stored.
enum LayoutProfile {
  /// Below 640: a single column, bottom navigation.
  compact,

  /// 640 to 1023: a rail appears.
  medium,

  /// 1024 and up: the rail extends its labels.
  expanded;

  /// Reads the profile from the window's width in logical pixels.
  static LayoutProfile fromWidth(double width) => width < 640
      ? LayoutProfile.compact
      : width < 1024
      ? LayoutProfile.medium
      : LayoutProfile.expanded;
}
