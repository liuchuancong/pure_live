import 'package:freezed_annotation/freezed_annotation.dart';

part 'site_metadata.freezed.dart';
part 'site_metadata.g.dart';

/// The stable program identifier and display facts of a live site.
///
/// [id] is the persistence and registry key — never a localized name.
/// [displayName] is what the UI shows by default and may be overridden
/// per locale. [logoUrl] points at a remote brand asset; [iconAsset]
/// names an app-bundled one. A site sets exactly the one it ships.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand; the lint cannot be satisfied
// for generated-model constructors.
@freezed
abstract class SiteMetadata with _$SiteMetadata {
  /// Builds the metadata bundle.
  const factory SiteMetadata({
    required String id,
    required String displayName,
    String? homeUrl,
    String? logoUrl,
    String? iconAsset,
  }) = _SiteMetadata;

  /// Restores metadata from JSON (registry fixtures and diagnostics).
  factory SiteMetadata.fromJson(Map<String, Object?> json) => _$SiteMetadataFromJson(json);
}
