// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:live_sites/src/models/enums/live_asset_type.dart';

part 'live_asset_ref.g.dart';

/// A reference to a platform asset (an icon, an image) — never a widget.
///
/// The UI layer decides how to render it; the domain only says where the
/// bytes live. [fallback] chains a deterministic substitute for missing or
/// unreachable sources.
abstract class LiveAssetRef implements Built<LiveAssetRef, LiveAssetRefBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveAssetRef([void Function(LiveAssetRefBuilder)? updates]) = _$LiveAssetRef;

  /// Creates a LiveAssetRef with already-normalized fields.
  /// Creates a LiveAssetRef with already-normalized fields.
  factory LiveAssetRef.of({required LiveAssetType type, String? path, Uri? uri, LiveAssetRef? fallback}) =>
      LiveAssetRef(
        (b) => b
          ..type = type
          ..path = path
          ..uri = uri
          ..fallback = fallback?.toBuilder(),
      );

  LiveAssetRef._();

  /// Where the bytes live.
  LiveAssetType get type;

  /// A bundled asset path, when [type] is bundled.
  String? get path;

  /// A remote address, when [type] is remote.
  Uri? get uri;

  /// The substitute to fall back to when this source misses.
  LiveAssetRef? get fallback;
}
