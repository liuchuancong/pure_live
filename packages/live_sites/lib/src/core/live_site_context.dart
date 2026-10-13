/// A platform (device target) a site declares support for.
enum LiveTargetPlatform {
  /// Android phones and tablets.
  android,

  /// iOS devices.
  ios,

  /// Android TV.
  androidTv,

  /// Windows desktop.
  windows,

  /// macOS desktop.
  macos,

  /// Linux desktop.
  linux,
}

/// The environment a site is initialized into.
///
/// A site reads this at its `initialize` step to adapt to the running device,
/// locale and application settings; it must not store it as immutable metadata
/// and must not assume the locale never changes.
class LiveSiteContext {
  /// Creates a context for the running [platform] and [locale], with the
  /// [defaultLocale] used when a resource has no exact match, an optional
  /// [applicationVersion] and free-form [configuration].
  const new({
    required this.platform,
    required this.locale,
    required this.defaultLocale,
    this.applicationVersion,
    this.configuration = const {},
  });

  /// The device target the site runs on.
  final LiveTargetPlatform platform;

  /// The active locale as a BCP 47 tag (for example `zh-CN`).
  final String locale;

  /// The fallback locale when [locale] has no match.
  final String defaultLocale;

  /// The application version, when the site needs it.
  final String? applicationVersion;

  /// Application-supplied settings the site may read to adapt.
  final Map<String, Object?> configuration;
}
