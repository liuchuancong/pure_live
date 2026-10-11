/// The operating system family the app runs on.
///
/// OS is one dimension; desktop deployment style lives separately in
/// `DesktopDistribution`.
enum PlatformKind {
  /// Microsoft Windows.
  windows,

  /// Google Android (phones, tablets and TV form factors).
  android,

  /// Apple iOS.
  ios,

  /// Apple macOS.
  macos,

  /// Linux distributions.
  linux,

  /// The platform could not be identified; capability defaults are the
  /// most conservative.
  unknown,
}
