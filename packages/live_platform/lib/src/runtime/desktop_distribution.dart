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

  /// Standalone bundle; data lives next to the executable, full stop. A
  /// portable build never falls back into the OS user-data tree — the
  /// medium is the point — so a read-only medium fails resolution loudly
  /// instead of hiding data where the bundle cannot find it again. Declared
  /// by a `portable.marker` file, a bundled build claim or the launcher —
  /// and un-declared by removing all of them beside the executable.
  portable,

  /// Deployment could not be confirmed; treat as installed but keep the
  /// uncertainty visible to diagnostics.
  unknown,
}
