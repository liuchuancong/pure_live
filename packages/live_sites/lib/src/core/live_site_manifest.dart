import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/models/live_asset_ref/live_asset_ref.dart';

/// Stable platform identity and metadata, distinct from runtime health.
///
/// [id] never changes because of a display-name change; credentials and
/// transient availability never live here. The localized text maps use BCP 47
/// keys resolved through [localizedName]'s fallback chain.
class LiveSiteManifest {
  /// Creates a manifest with a stable [id], localized [name] and [version],
  /// its [contractVersion] against this package's public contract, and the
  /// optional descriptive fields.
  const new({
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

  /// The stable, lowercase ASCII, unique site id.
  final String id;

  /// The localized display name, keyed by BCP 47 tag.
  final Map<String, String> name;

  /// The localized description, keyed by BCP 47 tag.
  final Map<String, String> description;

  /// The platform implementation version.
  final String version;

  /// The public contract version this implementation is compatible with.
  final String contractVersion;

  /// Alternative ids (user input, legacy names) that must still resolve here.
  final List<String> aliases;

  /// The author, when recorded.
  final String? author;

  /// The license, when recorded.
  final String? license;

  /// The project homepage, when recorded.
  final Uri? homepage;

  /// The icon reference; the UI layer renders it.
  final LiveAssetRef? icon;

  /// Named extra assets.
  final Map<String, LiveAssetRef> assets;

  /// Declared target-platform support (not guaranteed current availability).
  final Set<LiveTargetPlatform> supportedPlatforms;

  /// The display name for [locale], falling back through [fallbackLocale] and
  /// finally the [id].
  String localizedName(String locale, String fallbackLocale) => _resolve(name, locale, fallbackLocale) ?? id;

  /// The description for [locale], falling back to [fallbackLocale], or null
  /// when neither matches.
  String? localizedDescription(String locale, String fallbackLocale) => _resolve(description, locale, fallbackLocale);

  String? _resolve(Map<String, String> values, String locale, String fallbackLocale) {
    final normalizedLocale = locale.replaceAll('_', '-');
    final normalizedFallback = fallbackLocale.replaceAll('_', '-');
    return _find(values, normalizedLocale) ??
        _find(values, normalizedLocale.split('-').first) ??
        _find(values, normalizedFallback) ??
        _find(values, normalizedFallback.split('-').first);
  }

  String? _find(Map<String, String> values, String locale) {
    for (final entry in values.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == locale.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }
}
