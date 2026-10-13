// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
/// The host environment a site is initialized for.
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

/// The environment a site runs in, handed to `LiveSite.initialize`.
///
/// Localization falls back through [locale] to [defaultLocale]; the
/// composition root owns both. [configuration] carries app-provided options
/// (proxy, feature flags); authentication credentials never travel here.
class LiveSiteContext {
  /// Hands the environment to `LiveSite.initialize`.
  const LiveSiteContext({
    required this.platform,
    required this.locale,
    required this.defaultLocale,
    this.applicationVersion,
    this.configuration = const {},
  });

  /// The host platform the site should adapt to.
  final LiveTargetPlatform platform;

  /// The user's locale (BCP 47, `zh-CN` shape).
  final String locale;

  /// The application's fallback locale.
  final String defaultLocale;

  /// The application version, for diagnostics.
  final String? applicationVersion;

  /// App-provided configuration options; sites read what they declare.
  final Map<String, Object?> configuration;
}
