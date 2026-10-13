import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_asset_ref.freezed.dart';

/// The kind of backing an asset reference points at.
enum LiveAssetType {
  /// Shipped inside the application bundle, addressed by a package path.
  bundled,

  /// Fetched over the network, addressed by a URI.
  remote,

  /// A platform-supplied default used when nothing better is available.
  platformDefault,
}

/// A reference to an asset (an icon or other image) expressed as data rather
/// than a UI widget, so the domain layer never depends on Flutter rendering.
/// The UI layer decides how to render it; [fallback] gives a deterministic
/// next choice when this reference cannot be resolved.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveAssetRef with _$LiveAssetRef {
  /// Creates an asset reference of [type] addressed by [path] or [uri].
  const factory LiveAssetRef({required LiveAssetType type, String? path, Uri? uri, LiveAssetRef? fallback}) =
      _LiveAssetRef;
}
