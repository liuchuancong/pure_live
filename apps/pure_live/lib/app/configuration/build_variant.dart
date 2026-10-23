/// Which flavor of the app this process runs.
///
/// The variant is fixed at compile time through the `PURE_LIVE_VARIANT`
/// define; a build made without one is `standard`.
enum BuildVariant {
  /// The everyday release.
  standard;

  /// Reads the variant from the compile-time environment. Unknown keys fall
  /// back to [standard] rather than failing the start-up.
  static BuildVariant fromEnvironment({String key = 'PURE_LIVE_VARIANT'}) =>
      switch (const String.fromEnvironment('PURE_LIVE_VARIANT')) {
        'standard' => BuildVariant.standard,
        _ => BuildVariant.standard,
      };
}

/// The variant this build was made as, read once.
const BuildVariant kBuildVariant = BuildVariant.standard;
