/// How the desktop application was deployed on the host machine.
///
/// Distribution is a deployment dimension, independent of the operating
/// system: Windows alone has three of these. [unknown] is the honest
/// default — portable mode must be confirmed by the launcher, a native
/// bridge or an explicit startup parameter, never guessed from a
/// directory or file name.
enum DesktopDistribution {
  /// Installed via a standard installer; data belongs in the user's
  /// application-data directories, never next to the executable.
  installed,

  /// Packaged as MSIX; data goes through the package's container rules.
  msix,

  /// Standalone bundle; data lives next to the executable when that
  /// directory is writable, with a user-data fallback otherwise. Declared
  /// by a `portable.marker` file or the launcher — and un-declared by
  /// removing the marker and the cached claim beside the executable.
  portable,

  /// Deployment could not be confirmed; treat as installed but keep the
  /// uncertainty visible to diagnostics.
  unknown,
}
