import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/models/asset/live_asset_ref/live_asset_ref.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Stable platform identity and slow-changing metadata.
///
/// `id` is lower-case ASCII and never changes — not when a display name
/// changes, not across releases. Authentication state, runtime health and
/// temporary failures never appear here; they are runtime information.
class LiveSiteManifest {
  /// Builds an immutable manifest.
  const LiveSiteManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.contractVersion,
    this.description = const {},
    this.aliases = const [],
    this.author,
    this.license,
    this.homepage,
    this.icon,
    this.assets = const {},
    this.supportedPlatforms = const {},
  });

  /// Stable, unique, lower-case platform id.
  final String id;

  /// Localized display names keyed by BCP 47 tag.
  final Map<String, String> name;

  /// Localized descriptions keyed by BCP 47 tag.
  final Map<String, String> description;

  /// The platform implementation's own version.
  final String version;

  /// The version of the shared contract this implementation targets.
  final String contractVersion;

  /// Legacy identifiers accepted for user input.
  final List<String> aliases;

  /// The implementation's maintainer, when attributed.
  final String? author;

  /// The implementation's license, when attributed.
  final String? license;

  /// The platform's homepage.
  final Uri? homepage;

  /// The platform's icon, as a reference.
  final LiveAssetRef? icon;

  /// Other named assets the platform ships.
  final Map<String, LiveAssetRef> assets;

  /// The host platforms this implementation declares compatibility with.
  /// Declared compatibility is not a guarantee of current availability.
  final Set<LiveTargetPlatform> supportedPlatforms;

  /// The display name for [locale], falling back through [fallbackLocale]
  /// and then to the stable [id].
  String localizedName(String locale, String fallbackLocale) =>
      _resolveLocalizedText(name, locale, fallbackLocale) ?? id;

  /// The localized description for [locale], or null when none resolves.
  String? localizedDescription(String locale, String fallbackLocale) =>
      _resolveLocalizedText(description, locale, fallbackLocale);

  String? _resolveLocalizedText(Map<String, String> values, String locale, String fallbackLocale) {
    final normalizedLocale = locale.replaceAll('_', '-');
    final normalizedFallback = fallbackLocale.replaceAll('_', '-');

    final exact = _findLocale(values, normalizedLocale);
    if (exact != null) return exact;

    final languageMatch = _findLocale(values, normalizedLocale.split('-').first);
    if (languageMatch != null) return languageMatch;

    final fallbackExact = _findLocale(values, normalizedFallback);
    if (fallbackExact != null) return fallbackExact;

    return _findLocale(values, normalizedFallback.split('-').first);
  }

  String? _findLocale(Map<String, String> values, String locale) {
    for (final entry in values.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == locale.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }
}
