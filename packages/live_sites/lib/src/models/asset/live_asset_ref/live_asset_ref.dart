import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_asset_ref.freezed.dart';

/// A reference to a platform asset (an icon, an image) — never a widget.
///
/// The UI layer decides how to render it; the domain only says where the
/// bytes live. [fallback] chains a deterministic substitute for missing or
/// unreachable sources.
@freezed
abstract class LiveAssetRef with _$LiveAssetRef {
  /// Creates a LiveAssetRef with already-normalized fields.
  const factory LiveAssetRef({required LiveAssetType type, String? path, Uri? uri, LiveAssetRef? fallback}) =
      _LiveAssetRef;
}
