import 'package:live_sites/src/contracts/live_site.dart';
import 'package:live_sites/src/contracts/site_capability.dart';
import 'package:live_sites/src/contracts/site_error.dart';
import 'package:live_sites/src/registry/site_metadata.dart';

/// Lazy, id-keyed site registry.
///
/// Factories run once per site and are cached — adapters may hold per-site
/// session state without re-creating on every lookup. Sites that declare a
/// mismatched metadata id fail fast at registration time, not at first
/// use.
final class SiteRegistry {
  /// A registry over [factories], keyed by site id.
  new({required Map<String, LiveSite Function()> factories}) : _factories = Map.of(factories) {
    for (final entry in _factories.entries) {
      final metadataId = _probe(entry.value).metadata.id;
      if (metadataId != entry.key) {
        throw ArgumentError.value(entry.key, 'factories', 'factory builds a site whose metadata id is "$metadataId"');
      }
    }
  }

  final Map<String, LiveSite Function()> _factories;
  final Map<String, LiveSite> _instances = {};

  @override
  String toString() => 'SiteRegistry(${_factories.keys.toList()})';

  /// All registered site ids.
  Iterable<String> get ids => _factories.keys;

  /// The sites whose directory browsing works.
  ///
  /// A page that offers a site picker uses this instead of `ids`: an adapter
  /// that has not implemented its directory yet implements neither
  /// [LiveDirectoryCapability] nor [LiveSearchCapability], and offering it
  /// would put the user on a page that can only fail.
  Iterable<LiveSite> get browsable sync* {
    for (final id in ids) {
      final site = this[id];
      if (site != null && site is LiveDirectoryCapability) {
        yield site;
      }
    }
  }

  /// The sites whose search works.
  Iterable<LiveSite> get searchable sync* {
    for (final id in ids) {
      final site = this[id];
      if (site != null && site is LiveSearchCapability) {
        yield site;
      }
    }
  }

  /// The site for [id], or null when not registered.
  LiveSite? operator [](String id) {
    final existing = _instances[id];
    if (existing != null) {
      return existing;
    }
    final factory = _factories[id];
    if (factory == null) {
      return null;
    }
    return _instances[id] = factory();
  }

  /// The site for [id]; throws [SiteNotFoundError] when not registered.
  LiveSite require(String id) => this[id] ?? (throw SiteNotFoundError('site "$id" is not registered'));

  /// Every registered site, built and cached.
  List<LiveSite> get sites => [for (final id in _factories.keys) this[id]!];

  /// Metadata of every registered site without building the adapters —
  /// for settings screens and platform pickers.
  List<SiteMetadata> get metadataList {
    final list = <SiteMetadata>[];
    for (final entry in _factories.entries) {
      list.add(_instances[entry.key]?.metadata ?? _probe(entry.value).metadata);
    }
    return list;
  }

  static LiveSite _probe(LiveSite Function() factory) => factory();
}
