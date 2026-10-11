import 'package:meta/meta.dart';

/// The stable program identifier and display facts of a live site.
///
/// [id] is the persistence and registry key — never a localized name.
/// [displayName] is what the UI shows by default and may be overridden
/// per locale. [logoUrl] points at a remote brand asset; [iconAsset]
/// names an app-bundled one. A site sets exactly the one it ships.
@immutable
final class SiteMetadata {
  /// Builds the metadata bundle.
  const new({required this.id, required this.displayName, this.homeUrl, this.logoUrl, this.iconAsset});

  /// Stable program identifier, e.g. `bilibili`.
  final String id;

  /// Human-facing display name.
  final String displayName;

  /// The site's home page, when it has one.
  final String? homeUrl;

  /// Remote logo asset URL.
  final String? logoUrl;

  /// App-bundled icon asset key.
  final String? iconAsset;

  /// Convenience: the remote logo, if the site ships one.
  String? get logoUrlOrNull => logoUrl;

  @override
  String toString() => 'SiteMetadata($id, $displayName)';
}
