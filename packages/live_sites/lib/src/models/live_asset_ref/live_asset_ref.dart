import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_sites/src/models/live_asset_type/live_asset_type.dart';

part 'live_asset_ref.freezed.dart';

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
